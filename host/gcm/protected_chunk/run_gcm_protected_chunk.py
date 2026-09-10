#!/usr/bin/env python3
"""Send an RGB image as independently authenticated CHK3 protected chunks."""

from __future__ import annotations

import argparse
import hashlib
import json
import secrets
from pathlib import Path

try:
    import serial
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    from PIL import Image
except ImportError:
    print("Install dependencies with: py -m pip install -r requirements.txt")
    raise SystemExit(1)

from chk3_protocol import (
    CHUNK_BYTES,
    MAX_HEIGHT,
    MAX_WIDTH,
    build_aad,
    build_header,
    build_iv,
    build_stop_header,
    descriptors_for_image,
)

AES_KEY = bytes.fromhex("2B7E151628AED2A6ABF7158809CF4F3C")
SERIAL_TIMEOUT_SECONDS = 300


def parse_size(text: str) -> tuple[int, int]:
    parts = text.lower().replace(" ", "").split("x")
    if len(parts) != 2:
        raise argparse.ArgumentTypeError("use WIDTHxHEIGHT, for example 256x256")
    try:
        width, height = (int(value) for value in parts)
    except ValueError as error:
        raise argparse.ArgumentTypeError("width and height must be integers") from error
    if not 1 <= width <= MAX_WIDTH or not 1 <= height <= MAX_HEIGHT:
        raise argparse.ArgumentTypeError(
            f"dimensions must be between 1x1 and {MAX_WIDTH}x{MAX_HEIGHT}"
        )
    return width, height


def prepare_image(path: Path, size: tuple[int, int]) -> tuple[bytes, Image.Image]:
    with Image.open(path) as opened:
        rgba = opened.convert("RGBA")
        background = Image.new("RGBA", rgba.size, (0, 0, 0, 255))
        background.alpha_composite(rgba)
        prepared = background.convert("RGB")
    prepared = prepared.resize(size, Image.Resampling.LANCZOS)
    return prepared.tobytes(), prepared


def wait_line(port: serial.Serial, prefix: bytes, transcript: list[str]) -> bytes:
    while True:
        line = port.readline()
        if not line:
            raise TimeoutError(f"timed out waiting for {prefix.decode()}")
        text = line.decode("ascii", errors="replace").strip()
        if text:
            transcript.append(text)
            print(text)
        if line.startswith(prefix):
            return line


def read_exact(port: serial.Serial, size: int) -> bytes:
    output = bytearray()
    while len(output) < size:
        part = port.read(size - len(output))
        if not part:
            raise TimeoutError(f"received {len(output)} of {size} bytes")
        output.extend(part)
        print(f"\rReceiving: {len(output):5d}/{size} bytes", end="", flush=True)
    print()
    return bytes(output)


def marker_value(lines: list[str], name: str) -> int | None:
    prefix = name + " "
    for line in lines:
        if line.startswith(prefix):
            try:
                return int(line[len(prefix):])
            except ValueError:
                return None
    return None


def run_chunk(
    port: serial.Serial,
    chunk: bytes,
    descriptor,
    nonce: bytes,
    output: Path,
    transcript: list[str],
) -> dict[str, object]:
    aad = build_aad(descriptor)
    iv = build_iv(nonce, descriptor.chunk_index)
    header = build_header(descriptor, nonce)
    start = len(transcript)

    print(
        f"\n===== CHUNK {descriptor.chunk_index + 1}/{descriptor.total_chunks} "
        f"({len(chunk)} bytes) ====="
    )
    if port.write(header) != len(header):
        raise OSError("complete CHK3 header was not transmitted")
    port.flush()
    wait_line(port, b"HEADER_ACCEPTED ", transcript)
    wait_line(port, b"READY_FOR_PAYLOAD ", transcript)
    if port.write(chunk) != len(chunk):
        raise OSError("complete chunk payload was not transmitted")
    port.flush()
    wait_line(port, b"IMAGE_RECEIVED ", transcript)
    tag_line = wait_line(port, b"GCM_TAG ", transcript)
    tag = bytes.fromhex(tag_line.decode("ascii").split()[1])

    wait_line(port, b"CIPHERTEXT_BEGIN ", transcript)
    ciphertext = read_exact(port, len(chunk))
    wait_line(port, b"CIPHERTEXT_END", transcript)
    wait_line(port, b"RECOVERED_BEGIN ", transcript)
    recovered = read_exact(port, len(chunk))
    wait_line(port, b"RECOVERED_END", transcript)
    wait_line(port, b"REJECTED_BUFFER_BEGIN ", transcript)
    rejected = read_exact(port, len(chunk))
    wait_line(port, b"REJECTED_BUFFER_END", transcript)
    wait_line(port, b"ZCU104_AES_GCM_TRANSACTION_DONE", transcript)
    wait_line(port, b"TRANSACTION_BUFFERS_ZEROIZED", transcript)
    wait_line(port, b"CHUNK_COMMITTED ", transcript)
    lines = transcript[start:]

    reference = AESGCM(AES_KEY).encrypt(iv, chunk, aad)
    checks = {
        "ciphertext_matches_python": ciphertext == reference[:-16],
        "tag_matches_python": tag == reference[-16:],
        "exact_recovery": recovered == chunk,
        "rejected_output_zeroized": not any(rejected),
        "protected_buffer_locked_between_passes":
            "PROTECTED_BUFFER_LOCKED_BETWEEN_PASSES PASS" in lines,
        "release_replayed_without_recapture":
            "PROTECTED_BUFFER_REPLAYED_WITHOUT_RECAPTURE PASS" in lines,
        "ciphertext_tamper_rejected_before_decrypt":
            "TAMPER_REJECTED_BEFORE_DECRYPT PASS" in lines,
        "aad_tamper_rejected_before_decrypt":
            "AAD_TAMPER_REJECTED_BEFORE_DECRYPT PASS" in lines,
        "protected_tamper_buffer_zeroized":
            "PROTECTED_TAMPER_BUFFER_ZEROIZED" in lines,
        "protected_aad_buffer_zeroized":
            "PROTECTED_AAD_BUFFER_ZEROIZED" in lines,
    }

    chunk_dir = output / f"chunk_{descriptor.chunk_index:04d}"
    chunk_dir.mkdir(parents=True, exist_ok=True)
    (chunk_dir / "aad_128.bin").write_bytes(aad)
    (chunk_dir / "iv_96.bin").write_bytes(iv)
    (chunk_dir / "tag_128.bin").write_bytes(tag)
    (chunk_dir / "ciphertext.bin").write_bytes(ciphertext)
    (chunk_dir / "recovered.bin").write_bytes(recovered)
    return {
        "chunk_index": descriptor.chunk_index,
        "chunk_bytes": len(chunk),
        "final": descriptor.final,
        "iv_hex": iv.hex().upper(),
        "aad_hex": aad.hex().upper(),
        "tag_hex": tag.hex().upper(),
        "ciphertext_sha256": hashlib.sha256(ciphertext).hexdigest(),
        "checks": checks,
        "timing": {
            "auth_only_ns": marker_value(lines, "AUTH_ONLY_GCM_DMA_TIME_NS"),
            "release_ns": marker_value(lines, "DECRYPTION_RELEASE_GCM_DMA_TIME_NS"),
            "combined_ns": marker_value(
                lines, "AUTHENTICATE_THEN_RELEASE_GCM_DMA_TIME_NS"
            ),
        },
        "ciphertext": ciphertext,
        "recovered": recovered,
        "overall_pass": all(checks.values()),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run protected 4096-byte chunk AES-GCM on ZCU104."
    )
    parser.add_argument("image", type=Path)
    parser.add_argument("port", nargs="?", default="COM11")
    parser.add_argument("--size", type=parse_size, default=(17, 19))
    parser.add_argument("--sequence", type=int, default=100)
    parser.add_argument("--output", type=Path, default=Path("protected_chunk_output"))
    args = parser.parse_args()

    if not args.image.exists():
        print(f"ERROR: Input image not found: {args.image}")
        return 1
    if not 1 <= args.sequence <= 0xFFFF:
        print("ERROR: --sequence must be between 1 and 65535")
        return 1
    try:
        raw, prepared = prepare_image(args.image, args.size)
    except OSError as error:
        print(f"ERROR: {error}")
        return 1

    descriptors = descriptors_for_image(*prepared.size, args.sequence)
    nonce = secrets.token_bytes(8)
    while nonce == bytes(8):
        nonce = secrets.token_bytes(8)
    transcript: list[str] = []
    results: list[dict[str, object]] = []

    print(f"Opening {args.port} at 115200 baud")
    print(f"Image: {prepared.width}x{prepared.height} RGB888 ({len(raw)} bytes)")
    print(f"Protected chunks: {len(descriptors)} x up to {CHUNK_BYTES} bytes")
    print(f"Session nonce: {nonce.hex().upper()}")
    print("Keep this open, then launch the protected-chunk Vitis application once.")

    try:
        with serial.Serial(
            args.port,
            115200,
            timeout=SERIAL_TIMEOUT_SECONDS,
            write_timeout=SERIAL_TIMEOUT_SECONDS,
        ) as port:
            port.reset_input_buffer()
            wait_line(port, b"READY_FOR_HEADER ", transcript)
            for descriptor in descriptors:
                start = descriptor.chunk_index * CHUNK_BYTES
                chunk = raw[start:start + descriptor.chunk_bytes]
                result = run_chunk(
                    port, chunk, descriptor, nonce, args.output, transcript
                )
                results.append(result)
                wait_line(port, b"READY_FOR_HEADER ", transcript)
            stop = build_stop_header()
            if port.write(stop) != len(stop):
                raise OSError("complete stop frame was not transmitted")
            port.flush()
            wait_line(port, b"SESSION_STOP_ACCEPTED", transcript)
            wait_line(port, b"ZCU104_AES_GCM_PROTECTED_CHUNK_DONE ", transcript)
    except (serial.SerialException, TimeoutError, OSError, ValueError) as error:
        print(f"ERROR: {error}")
        print("Close other serial terminals, relaunch the Vitis application, and retry.")
        return 2

    ciphertext = b"".join(item.pop("ciphertext") for item in results)
    recovered = b"".join(item.pop("recovered") for item in results)
    overall = all(bool(item["overall_pass"]) for item in results) and recovered == raw
    args.output.mkdir(parents=True, exist_ok=True)
    prepared.save(args.output / "input.png")
    (args.output / "ciphertext.bin").write_bytes(ciphertext)
    (args.output / "recovered.bin").write_bytes(recovered)
    Image.frombytes("RGB", prepared.size, ciphertext).save(
        args.output / "encrypted.png"
    )
    Image.frombytes("RGB", prepared.size, recovered).save(
        args.output / "recovered.png"
    )
    (args.output / "uart_transcript.txt").write_text(
        "\n".join(transcript) + "\n", encoding="utf-8"
    )
    summary = {
        "protocol": "CHK3",
        "image_size": list(prepared.size),
        "image_bytes": len(raw),
        "image_sequence": args.sequence,
        "session_nonce_hex": nonce.hex().upper(),
        "chunk_capacity_bytes": CHUNK_BYTES,
        "chunk_count": len(descriptors),
        "input_sha256": hashlib.sha256(raw).hexdigest(),
        "ciphertext_sha256": hashlib.sha256(ciphertext).hexdigest(),
        "recovered_sha256": hashlib.sha256(recovered).hexdigest(),
        "exact_full_image_recovery": recovered == raw,
        "chunks": results,
        "overall_pass": overall,
    }
    (args.output / "protected_chunk_summary.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    print("\n========== PROTECTED CHUNK TEST COMPLETE ==========")
    print(f"Chunks passed: {sum(bool(item['overall_pass']) for item in results)}/{len(results)}")
    print(f"Full-image recovery: {'PASS' if recovered == raw else 'FAIL'}")
    print(f"OVERALL: {'PASS' if overall else 'FAIL'}")
    print(f"Files saved in: {args.output.resolve()}")
    return 0 if overall else 3


if __name__ == "__main__":
    raise SystemExit(main())
