#!/usr/bin/env python3
"""Prepare a 256x256 RGB image and AES-128-CTR reference files."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from PIL import Image, ImageOps


SIZE = (256, 256)
KEY = bytes.fromhex("2B7E151628AED2A6ABF7158809CF4F3C")
INITIAL_COUNTER = bytes.fromhex("F0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF")


def aes_ctr(data: bytes) -> bytes:
    aes = Cipher(algorithms.AES(KEY), modes.ECB()).encryptor()
    counter = int.from_bytes(INITIAL_COUNTER, "big")
    result = bytearray()
    for offset in range(0, len(data), 16):
        block = data[offset : offset + 16]
        keystream = aes.update(counter.to_bytes(16, "big"))
        result.extend(a ^ b for a, b in zip(block, keystream))
        counter = (counter + 1) & ((1 << 128) - 1)
    aes.finalize()
    return bytes(result)


def write_c_header(data: bytes, path: Path) -> None:
    lines = [
        "#ifndef CAR_256_RGB_H",
        "#define CAR_256_RGB_H",
        "",
        "#include <stdint.h>",
        "",
        f"#define IMAGE_WIDTH {SIZE[0]}u",
        f"#define IMAGE_HEIGHT {SIZE[1]}u",
        "#define IMAGE_CHANNELS 3u",
        f"#define IMAGE_SIZE_BYTES {len(data)}u",
        "",
        "static const uint8_t car_256_rgb[IMAGE_SIZE_BYTES] = {",
    ]
    for offset in range(0, len(data), 16):
        values = ", ".join(f"0x{value:02X}" for value in data[offset : offset + 16])
        lines.append(f"    {values},")
    lines.extend(["};", "", "#endif", ""])
    path.write_text("\n".join(lines), encoding="ascii")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path, help="input PNG/JPEG image")
    parser.add_argument("--output", type=Path, default=Path("prepared_image"))
    parser.add_argument(
        "--header",
        type=Path,
        default=Path("software/vitis/src/car_256_rgb.h"),
        help="Vitis C-header output path",
    )
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    args.header.parent.mkdir(parents=True, exist_ok=True)

    source = Image.open(args.image).convert("RGBA")
    background = Image.new("RGBA", source.size, (0, 0, 0, 255))
    background.alpha_composite(source)
    rgb = background.convert("RGB")
    fitted = ImageOps.pad(
        rgb,
        SIZE,
        method=Image.Resampling.LANCZOS,
        color=(0, 0, 0),
        centering=(0.5, 0.5),
    )

    raw = fitted.tobytes()
    encrypted = aes_ctr(raw)
    recovered = aes_ctr(encrypted)
    if recovered != raw:
        raise RuntimeError("AES-CTR golden-reference recovery failed")

    fitted.save(args.output / "input_256.png")
    Image.frombytes("RGB", SIZE, encrypted).save(args.output / "encrypted_reference.png")
    Image.frombytes("RGB", SIZE, recovered).save(args.output / "recovered_reference.png")
    (args.output / "input_rgb.bin").write_bytes(raw)
    (args.output / "cipher_reference.bin").write_bytes(encrypted)
    write_c_header(raw, args.header)

    metadata = {
        "source_file": args.image.name,
        "source_size": list(rgb.size),
        "prepared_size": list(SIZE),
        "pixel_format": "RGB888 row-major",
        "image_bytes": len(raw),
        "aes_blocks": len(raw) // 16,
        "key_hex": KEY.hex().upper(),
        "initial_counter_hex": INITIAL_COUNTER.hex().upper(),
        "input_sha256": hashlib.sha256(raw).hexdigest(),
        "cipher_sha256": hashlib.sha256(encrypted).hexdigest(),
        "recovered_sha256": hashlib.sha256(recovered).hexdigest(),
        "recovery_exact_match": recovered == raw,
    }
    (args.output / "metadata.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()

