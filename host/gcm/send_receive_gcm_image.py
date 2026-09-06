#!/usr/bin/env python3
"""Run the authenticated AES-128-GCM image demo on a ZCU104."""

from __future__ import annotations

import argparse
import hashlib
import json
import secrets
import sys
from pathlib import Path

try:
    import serial
    from cryptography.exceptions import InvalidTag
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    from PIL import Image, ImageOps
except ImportError:
    print("Install dependencies with: py -m pip install -r requirements.txt")
    raise SystemExit(1)

WIDTH = 256
HEIGHT = 256
IMAGE_SIZE = WIDTH * HEIGHT * 3
PACKET_MAGIC = b"GCM1"
AES_KEY = bytes.fromhex("2B7E151628AED2A6ABF7158809CF4F3C")
TAMPER_BYTE_INDEX = 98688
TAMPER_XOR_MASK = 0x01


def prepare_image(path: Path) -> tuple[bytes, Image.Image]:
    source = Image.open(path).convert("RGBA")
    background = Image.new("RGBA", source.size, (0, 0, 0, 255))
    background.alpha_composite(source)
    prepared = ImageOps.pad(
        background.convert("RGB"),
        (WIDTH, HEIGHT),
        method=Image.Resampling.LANCZOS,
        color=(0, 0, 0),
        centering=(0.5, 0.5),
    )
    return prepared.tobytes(), prepared


def read_exact(port: serial.Serial, size: int) -> bytes:
    result = bytearray()
    while len(result) < size:
        chunk = port.read(size - len(result))
        if not chunk:
            raise TimeoutError(f"Received {len(result)} of {size} bytes")
        result.extend(chunk)
        print(f"\rReceiving: {len(result):6d}/{size} bytes", end="", flush=True)
    print()
    return bytes(result)


def wait_for_line(
    port: serial.Serial, prefix: bytes, transcript: list[str]
) -> bytes:
    while True:
        line = port.readline()
        if not line:
            raise TimeoutError(f"Timed out waiting for {prefix.decode()}")
        printable = line.decode("ascii", errors="replace").strip()
        if printable:
            transcript.append(printable)
            print(printable)
        if line.startswith(prefix):
            return line


def parse_iv(value: str | None) -> bytes:
    if value is None:
        return secrets.token_bytes(12)
    compact = value.replace("_", "").replace(" ", "")
    if len(compact) != 24:
        raise ValueError("--iv needs exactly 24 hexadecimal characters (96 bits)")
    return bytes.fromhex(compact)


def transcript_has(transcript: list[str], exact_line: str) -> bool:
    return exact_line in transcript


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Send an image to the ZCU104 AES-GCM DMA application."
    )
    parser.add_argument("image", type=Path)
    parser.add_argument("port", nargs="?", default="COM11")
    parser.add_argument("--output", type=Path, default=Path("gcm_image_output"))
    parser.add_argument("--iv", help="Fixed 96-bit IV in hex; omit for a random IV")
    args = parser.parse_args()

    if not args.image.exists():
        print(f"ERROR: Input image not found: {args.image}")
        return 1
    try:
        raw, prepared = prepare_image(args.image)
        iv = parse_iv(args.iv)
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}")
        return 1

    args.output.mkdir(parents=True, exist_ok=True)
    prepared.save(args.output / "input_256.png")
    transcript: list[str] = []

    print(f"Opening {args.port} at 115200 baud")
    print("IV:", iv.hex().upper())
    print("Keep this open, then launch the new GCM-DMA Vitis application once.")

    try:
        with serial.Serial(args.port, 115200, timeout=240, write_timeout=240) as port:
            port.reset_input_buffer()
            wait_for_line(port, b"READY_FOR_PACKET ", transcript)
            packet = PACKET_MAGIC + iv + raw
            print(f"Sending {len(packet)} bytes to ZCU104...")
            if port.write(packet) != len(packet):
                raise OSError("The complete image packet was not sent")
            port.flush()
            wait_for_line(port, b"IMAGE_RECEIVED ", transcript)
            tag_line = wait_for_line(port, b"GCM_TAG ", transcript)
            tag = bytes.fromhex(tag_line.decode("ascii").split()[1])
            wait_for_line(port, b"CIPHERTEXT_BEGIN ", transcript)
            encrypted = read_exact(port, IMAGE_SIZE)
            wait_for_line(port, b"CIPHERTEXT_END", transcript)
            wait_for_line(port, b"RECOVERED_BEGIN ", transcript)
            recovered = read_exact(port, IMAGE_SIZE)
            wait_for_line(port, b"RECOVERED_END", transcript)
            wait_for_line(port, b"REJECTED_BUFFER_BEGIN ", transcript)
            rejected_buffer = read_exact(port, IMAGE_SIZE)
            wait_for_line(port, b"REJECTED_BUFFER_END", transcript)
            wait_for_line(port, b"ZCU104_AES_GCM_DMA_DONE", transcript)
    except (serial.SerialException, TimeoutError, OSError, ValueError) as error:
        print(f"ERROR: {error}")
        print("Verify COM11/COM13, program the GCM bitstream, and relaunch the GCM app.")
        return 2

    reference = AESGCM(AES_KEY).encrypt(iv, raw, None)
    reference_ciphertext = reference[:-16]
    reference_tag = reference[-16:]
    ciphertext_match = encrypted == reference_ciphertext
    tag_match = tag == reference_tag
    exact_recovery = recovered == raw

    tampered = bytearray(encrypted)
    tampered[TAMPER_BYTE_INDEX] ^= TAMPER_XOR_MASK
    reference_rejects_tamper = False
    try:
        AESGCM(AES_KEY).decrypt(iv, bytes(tampered) + tag, None)
    except InvalidTag:
        reference_rejects_tamper = True

    board_accepts_valid = transcript_has(transcript, "AUTHENTICATION_PASS")
    board_rejects_tamper = transcript_has(
        transcript, "AUTHENTICATION_FAIL_EXPECTED PASS"
    ) and transcript_has(transcript, "TAMPER_REJECTED")
    plaintext_not_released = transcript_has(transcript, "PLAINTEXT_RELEASED NO")
    rejected_zeroized = (
        transcript_has(transcript, "TAMPERED_BUFFER_ZEROIZED")
        and not any(rejected_buffer)
    )

    (args.output / "iv_96.bin").write_bytes(iv)
    (args.output / "gcm_tag_128.bin").write_bytes(tag)
    (args.output / "ciphertext.bin").write_bytes(encrypted)
    (args.output / "recovered.bin").write_bytes(recovered)
    (args.output / "rejected_buffer.bin").write_bytes(rejected_buffer)
    Image.frombytes("RGB", (WIDTH, HEIGHT), encrypted).save(
        args.output / "encrypted.png"
    )
    Image.frombytes("RGB", (WIDTH, HEIGHT), recovered).save(
        args.output / "recovered.png"
    )
    Image.frombytes("RGB", (WIDTH, HEIGHT), rejected_buffer).save(
        args.output / "rejected_zeroized.png"
    )
    (args.output / "uart_transcript.txt").write_text(
        "\n".join(transcript) + "\n", encoding="utf-8"
    )

    overall_pass = all(
        (
            ciphertext_match,
            tag_match,
            exact_recovery,
            reference_rejects_tamper,
            board_accepts_valid,
            board_rejects_tamper,
            plaintext_not_released,
            rejected_zeroized,
        )
    )
    metadata = {
        "architecture": "ZCU104 PS DDR <-> AXI DMA <-> AES-128-GCM AXI-Stream",
        "source_image": str(args.image),
        "image_bytes": IMAGE_SIZE,
        "aes_blocks": IMAGE_SIZE // 16,
        "key_hex": AES_KEY.hex().upper(),
        "iv_hex": iv.hex().upper(),
        "tag_hex": tag.hex().upper(),
        "input_sha256": hashlib.sha256(raw).hexdigest(),
        "ciphertext_sha256": hashlib.sha256(encrypted).hexdigest(),
        "recovered_sha256": hashlib.sha256(recovered).hexdigest(),
        "ciphertext_matches_python_aesgcm": ciphertext_match,
        "tag_matches_python_aesgcm": tag_match,
        "exact_recovery": exact_recovery,
        "python_aesgcm_rejects_modified_ciphertext": reference_rejects_tamper,
        "board_accepts_valid_tag": board_accepts_valid,
        "board_rejects_modified_ciphertext": board_rejects_tamper,
        "unauthenticated_plaintext_released_over_uart": not plaintext_not_released,
        "rejected_output_zeroized": rejected_zeroized,
        "overall_pass": overall_pass,
    }
    (args.output / "gcm_run_metadata.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )

    print("\n========== AES-GCM HARDWARE TEST COMPLETE ==========")
    print("Ciphertext matches Python AESGCM:", "PASS" if ciphertext_match else "FAIL")
    print("128-bit tag matches Python AESGCM:", "PASS" if tag_match else "FAIL")
    print("Original == recovered:", "PASS" if exact_recovery else "FAIL")
    print("Modified ciphertext rejected by board:", "PASS" if board_rejects_tamper else "FAIL")
    print("Modified ciphertext rejected by Python:", "PASS" if reference_rejects_tamper else "FAIL")
    print("Rejected output zeroized:", "PASS" if rejected_zeroized else "FAIL")
    print("OVERALL:", "PASS" if overall_pass else "FAIL")
    print("Files saved in:", args.output.resolve())
    return 0 if overall_pass else 3


if __name__ == "__main__":
    sys.exit(main())
