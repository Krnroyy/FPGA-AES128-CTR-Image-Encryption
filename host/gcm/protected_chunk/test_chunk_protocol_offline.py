#!/usr/bin/env python3
"""Offline checks for CHK3 chunk ordering, AAD, IV, and edge lengths."""

from __future__ import annotations

import struct

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from chk3_protocol import (
    AAD_BYTES,
    CHUNK_BYTES,
    HEADER_BYTES,
    ChunkDescriptor,
    ChunkSessionTracker,
    build_aad,
    build_header,
    build_iv,
    build_stop_header,
    descriptors_for_image,
    expected_chunk_length,
    expected_chunks,
    validate_descriptor,
)

KEY = bytes.fromhex("2B7E151628AED2A6ABF7158809CF4F3C")


def must_fail(item: ChunkDescriptor) -> None:
    try:
        validate_descriptor(item)
    except ValueError:
        return
    raise AssertionError(f"invalid descriptor unexpectedly accepted: {item}")


def main() -> int:
    nonce = bytes.fromhex("0123456789ABCDEF")
    items = descriptors_for_image(256, 256, 100)
    assert len(items) == 48
    assert items[0].chunk_bytes == CHUNK_BYTES
    assert items[-1].chunk_bytes == CHUNK_BYTES
    assert len(build_aad(items[0])) == AAD_BYTES
    assert len(build_header(items[0], nonce)) == HEADER_BYTES
    assert len(build_stop_header()) == HEADER_BYTES
    assert build_iv(nonce, 7)[8:] == struct.pack(">I", 7)
    print("PASS: 256x256 image maps to 48 canonical 4096-byte chunks")

    odd_items = descriptors_for_image(17, 19, 101)
    assert len(odd_items) == 1 and odd_items[0].chunk_bytes == 969
    assert expected_chunks(512, 512) == 192
    assert expected_chunk_length(1, 1, 0) == 3
    print("PASS: first, non-aligned final, and maximum-size chunk layouts")

    sample = bytes((index * 29 + 7) & 0xFF for index in range(969))
    aad = build_aad(odd_items[0])
    iv = build_iv(nonce, 0)
    sealed = AESGCM(KEY).encrypt(iv, sample, aad)
    assert AESGCM(KEY).decrypt(iv, sealed, aad) == sample
    for bad in (
        sealed[:-17] + bytes([sealed[-17] ^ 1]) + sealed[-16:],
        sealed[:-1] + bytes([sealed[-1] ^ 1]),
    ):
        try:
            AESGCM(KEY).decrypt(iv, bad, aad)
        except Exception:
            pass
        else:
            raise AssertionError("tampered ciphertext/tag was accepted")
    try:
        AESGCM(KEY).decrypt(iv, sealed, bytes([aad[0] ^ 1]) + aad[1:])
    except Exception:
        pass
    else:
        raise AssertionError("tampered AAD was accepted")
    print("PASS: ciphertext, tag, and AAD tampering rejected by AESGCM reference")

    base = odd_items[0]
    must_fail(ChunkDescriptor(17, 19, 968, 0, 1, 101))
    must_fail(ChunkDescriptor(17, 19, 969, 1, 1, 101))
    must_fail(ChunkDescriptor(17, 19, 969, 0, 2, 101))
    must_fail(ChunkDescriptor(17, 19, 969, 0, 1, 0))
    try:
        build_iv(bytes(8), 0)
    except ValueError:
        pass
    else:
        raise AssertionError("zero nonce was accepted")
    print("PASS: malformed length/count/index/sequence/nonce cases rejected")

    indexes = [item.chunk_index for item in items]
    assert len(set(build_iv(nonce, index) for index in indexes)) == len(items)
    assert indexes == list(range(len(items)))
    print("PASS: per-chunk IVs are unique and ordering is canonical")

    tracker = ChunkSessionTracker()
    for item in descriptors_for_image(64, 64, 10):
        tracker.accept(item, nonce)
    try:
        tracker.accept(descriptors_for_image(64, 64, 10)[0], b"ABCDEFGH")
    except ValueError:
        pass
    else:
        raise AssertionError("replayed image sequence accepted")
    try:
        tracker.accept(descriptors_for_image(64, 64, 11)[0], nonce)
    except ValueError:
        pass
    else:
        raise AssertionError("reused session nonce accepted")

    ordered = descriptors_for_image(128, 128, 12)
    tracker.accept(ordered[0], b"IJKLMNOP")
    for bad in (ordered[0], ordered[2]):
        try:
            tracker.accept(bad, b"IJKLMNOP")
        except ValueError:
            pass
        else:
            raise AssertionError("duplicate/missing/reordered chunk accepted")
    for item in ordered[1:]:
        tracker.accept(item, b"IJKLMNOP")
    print("PASS: replay, nonce reuse, duplicate, missing, and reordering rejected")
    print("PASS: CHK3 PROTOCOL OFFLINE MILESTONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
