#!/usr/bin/env python3
"""Receive encrypted and recovered 256x256 RGB frames from ZCU104 PS UART."""

import argparse
import hashlib
import re
import sys
from pathlib import Path

try:
    import serial
    from PIL import Image
except ImportError:
    print("Install dependencies with: py -m pip install pyserial pillow")
    raise SystemExit(1)


IMAGE_SIZE = 256 * 256 * 3


def read_exact(port, size: int) -> bytes:
    result = bytearray()
    while len(result) < size:
        chunk = port.read(size - len(result))
        if not chunk:
            raise TimeoutError(f"Received {len(result)} of {size} bytes")
        result.extend(chunk)
        print(f"\rReceiving: {len(result):6d}/{size} bytes", end="", flush=True)
    print()
    return bytes(result)


def wait_for_line(port, prefix: bytes) -> bytes:
    while True:
        line = port.readline()
        if not line:
            raise TimeoutError(f"Timed out waiting for {prefix.decode()}")
        printable = line.decode("ascii", errors="replace").strip()
        if printable:
            print(printable)
        if line.startswith(prefix):
            return line


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("port", nargs="?", default="COM11")
    parser.add_argument("--output", default="full_image_output")
    args = parser.parse_args()

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Opening {args.port} at 115200 baud.")
    print("Keep this receiver open, then launch the Vitis application on the board.")

    try:
        with serial.Serial(args.port, 115200, timeout=120) as port:
            port.reset_input_buffer()

            wait_for_line(port, b"CIPHERTEXT_BEGIN ")
            encrypted = read_exact(port, IMAGE_SIZE)

            wait_for_line(port, b"CIPHERTEXT_END")
            wait_for_line(port, b"RECOVERED_BEGIN ")
            recovered = read_exact(port, IMAGE_SIZE)
            wait_for_line(port, b"RECOVERED_END")
            wait_for_line(port, b"ZCU104_AES_CTR_DONE")

    except (serial.SerialException, TimeoutError) as error:
        print(f"ERROR: {error}")
        print("If this was COM11, try COM13. COM12 belongs to the earlier PL-UART test.")
        return 2
    except KeyboardInterrupt:
        print("\nStopped.")
        return 130

    (output_dir / "car_256_encrypted_from_zcu104.bin").write_bytes(encrypted)
    (output_dir / "car_256_recovered_from_zcu104.bin").write_bytes(recovered)
    Image.frombytes("RGB", (256, 256), encrypted).save(
        output_dir / "car_256_encrypted_from_zcu104.png"
    )
    Image.frombytes("RGB", (256, 256), recovered).save(
        output_dir / "car_256_recovered_from_zcu104.png"
    )

    reference_path = Path(__file__).resolve().parent.parent / "image_assets" / "car_256_rgb.bin"
    reference = reference_path.read_bytes()
    exact_match = recovered == reference

    print("Encrypted SHA-256:", hashlib.sha256(encrypted).hexdigest())
    print("Recovered SHA-256:", hashlib.sha256(recovered).hexdigest())
    print("Original == recovered:", "PASS" if exact_match else "FAIL")
    print("Files saved in:", output_dir.resolve())
    return 0 if exact_match else 3


if __name__ == "__main__":
    sys.exit(main())
