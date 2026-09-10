"""Wire format and validation helpers for protected chunk protocol CHK3."""

from __future__ import annotations

import struct
from dataclasses import dataclass

MAGIC = b"CHK3"
STOP_MAGIC = b"END3"
VERSION = 3
FORMAT_RGB888 = 1
CHANNELS = 3
CHUNK_BYTES = 4096
HEADER_BYTES = 32
AAD_BYTES = 16
IV_BYTES = 12
MAX_WIDTH = 512
MAX_HEIGHT = 512


@dataclass(frozen=True)
class ChunkDescriptor:
    width: int
    height: int
    chunk_bytes: int
    chunk_index: int
    total_chunks: int
    image_sequence: int

    @property
    def final(self) -> bool:
        return self.chunk_index + 1 == self.total_chunks


class ChunkSessionTracker:
    """Reference model for the firmware's volatile strict-order checks."""

    def __init__(self) -> None:
        self.last_completed_sequence = 0
        self.active: tuple[int, int, int, int, bytes] | None = None
        self.expected_index = 0
        self.used_nonces: set[bytes] = set()

    def accept(self, item: ChunkDescriptor, session_nonce: bytes) -> None:
        validate_descriptor(item)
        if len(session_nonce) != 8 or session_nonce == bytes(8):
            raise ValueError("invalid session nonce")
        if item.chunk_index == 0:
            if self.active is not None:
                raise ValueError("previous image is incomplete")
            if item.image_sequence <= self.last_completed_sequence:
                raise ValueError("image sequence replay")
            if session_nonce in self.used_nonces:
                raise ValueError("session nonce reuse")
            self.used_nonces.add(session_nonce)
            self.active = (
                item.image_sequence,
                item.total_chunks,
                item.width,
                item.height,
                session_nonce,
            )
            self.expected_index = 1
        else:
            expected = (
                item.image_sequence,
                item.total_chunks,
                item.width,
                item.height,
                session_nonce,
            )
            if self.active != expected or item.chunk_index != self.expected_index:
                raise ValueError("duplicate, missing, or reordered chunk")
            self.expected_index += 1
        if item.final:
            self.last_completed_sequence = item.image_sequence
            self.active = None
            self.expected_index = 0


def expected_chunks(width: int, height: int) -> int:
    total = width * height * CHANNELS
    return (total + CHUNK_BYTES - 1) // CHUNK_BYTES


def expected_chunk_length(width: int, height: int, chunk_index: int) -> int:
    total = width * height * CHANNELS
    count = expected_chunks(width, height)
    if not 0 <= chunk_index < count:
        raise ValueError("chunk index is outside this image")
    if chunk_index + 1 < count:
        return CHUNK_BYTES
    return total - chunk_index * CHUNK_BYTES


def validate_descriptor(item: ChunkDescriptor) -> None:
    if not 1 <= item.width <= MAX_WIDTH or not 1 <= item.height <= MAX_HEIGHT:
        raise ValueError("image dimensions are outside the supported range")
    if not 1 <= item.image_sequence <= 0xFFFF:
        raise ValueError("image sequence must fit in a nonzero uint16")
    count = expected_chunks(item.width, item.height)
    if item.total_chunks != count:
        raise ValueError("total chunk count does not match the image size")
    if item.chunk_bytes != expected_chunk_length(
        item.width, item.height, item.chunk_index
    ):
        raise ValueError("chunk length does not match its position")


def build_aad(item: ChunkDescriptor) -> bytes:
    validate_descriptor(item)
    flags = 1 if item.final else 0
    value = struct.pack(
        ">BBBBHHHHHH",
        VERSION,
        FORMAT_RGB888,
        CHANNELS,
        flags,
        item.width,
        item.height,
        item.chunk_bytes,
        item.chunk_index,
        item.total_chunks,
        item.image_sequence,
    )
    if len(value) != AAD_BYTES:
        raise AssertionError("CHK3 AAD must remain exactly 16 bytes")
    return value


def build_iv(session_nonce: bytes, chunk_index: int) -> bytes:
    if len(session_nonce) != 8 or session_nonce == bytes(8):
        raise ValueError("session nonce must be eight nonzero bytes")
    if not 0 <= chunk_index <= 0xFFFFFFFF:
        raise ValueError("chunk index must fit in uint32")
    return session_nonce + struct.pack(">I", chunk_index)


def build_header(item: ChunkDescriptor, session_nonce: bytes) -> bytes:
    header = MAGIC + build_aad(item) + build_iv(session_nonce, item.chunk_index)
    if len(header) != HEADER_BYTES:
        raise AssertionError("CHK3 header must remain exactly 32 bytes")
    return header


def build_stop_header() -> bytes:
    return STOP_MAGIC + bytes(HEADER_BYTES - len(STOP_MAGIC))


def descriptors_for_image(width: int, height: int, sequence: int) -> list[ChunkDescriptor]:
    count = expected_chunks(width, height)
    return [
        ChunkDescriptor(
            width=width,
            height=height,
            chunk_bytes=expected_chunk_length(width, height, index),
            chunk_index=index,
            total_chunks=count,
            image_sequence=sequence,
        )
        for index in range(count)
    ]
