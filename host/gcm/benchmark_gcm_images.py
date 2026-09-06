#!/usr/bin/env python3
"""Run a reproducible multi-image AES-128-GCM DMA benchmark on ZCU104."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import secrets
import statistics
import sys
from pathlib import Path

try:
    import numpy as np
    import serial
    from cryptography.exceptions import InvalidTag
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    from PIL import Image, ImageOps
except ImportError:
    print("Install dependencies with: py -m pip install -r requirements.txt")
    raise SystemExit(1)

WIDTH = 256
HEIGHT = 256
CHANNELS = 3
IMAGE_SIZE = WIDTH * HEIGHT * CHANNELS
PACKET_MAGIC = b"GCM1"
BATCH_MAGIC = b"GBH1"
AES_KEY = bytes.fromhex("2B7E151628AED2A6ABF7158809CF4F3C")
TAMPER_BYTE_INDEX = 98688
TAMPER_XOR_MASK = 0x01
SUPPORTED_SUFFIXES = {".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff"}
PERFORMANCE_KEYS = {
    "ENCRYPTION_GCM_DMA_TIME_US",
    "ENCRYPTION_GCM_DMA_THROUGHPUT_KBPS",
    "DECRYPTION_GCM_DMA_TIME_US",
    "DECRYPTION_GCM_DMA_THROUGHPUT_KBPS",
    "TAMPERED_DECRYPTION_GCM_DMA_TIME_US",
    "TAMPERED_DECRYPTION_GCM_DMA_THROUGHPUT_KBPS",
}


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
    port: serial.Serial,
    prefix: bytes,
    transcript: list[str],
    performance: dict[str, int] | None = None,
) -> str:
    while True:
        line = port.readline()
        if not line:
            raise TimeoutError(f"Timed out waiting for {prefix.decode()}")
        printable = line.decode("ascii", errors="replace").strip()
        if printable:
            transcript.append(printable)
            print(printable)
            parts = printable.split()
            if performance is not None and len(parts) == 2:
                if parts[0] in PERFORMANCE_KEYS:
                    performance[parts[0]] = int(parts[1])
        if line.startswith(prefix):
            return printable


def shannon_entropy(values: np.ndarray) -> float:
    counts = np.bincount(values.reshape(-1), minlength=256).astype(np.float64)
    probabilities = counts[counts > 0] / values.size
    return float(-np.sum(probabilities * np.log2(probabilities)))


def correlation(left: np.ndarray, right: np.ndarray) -> float | None:
    left_values = left.reshape(-1).astype(np.float64)
    right_values = right.reshape(-1).astype(np.float64)
    if (
        left_values.size == 0
        or np.std(left_values) == 0.0
        or np.std(right_values) == 0.0
    ):
        return None
    return float(np.corrcoef(left_values, right_values)[0, 1])


def image_metrics(raw: bytes) -> dict[str, float | None]:
    rgb = np.frombuffer(raw, dtype=np.uint8).reshape(HEIGHT, WIDTH, CHANNELS)
    gray = np.asarray(Image.frombytes("RGB", (WIDTH, HEIGHT), raw).convert("L"))
    counts = np.bincount(rgb.reshape(-1), minlength=256).astype(np.float64)
    expected = rgb.size / 256.0
    return {
        "entropy_all": shannon_entropy(rgb),
        "entropy_r": shannon_entropy(rgb[:, :, 0]),
        "entropy_g": shannon_entropy(rgb[:, :, 1]),
        "entropy_b": shannon_entropy(rgb[:, :, 2]),
        "corr_horizontal": correlation(gray[:, :-1], gray[:, 1:]),
        "corr_vertical": correlation(gray[:-1, :], gray[1:, :]),
        "corr_diagonal": correlation(gray[:-1, :-1], gray[1:, 1:]),
        "histogram_chi_square": float(np.sum((counts - expected) ** 2 / expected)),
    }


def safe_name(path: Path) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", path.stem).strip("._")
    return cleaned or "image"


def mean_and_stdev(rows: list[dict[str, object]], key: str) -> dict[str, float]:
    values = [float(row[key]) for row in rows]
    return {
        "mean": statistics.mean(values),
        "population_stdev": statistics.pstdev(values),
        "minimum": min(values),
        "maximum": max(values),
    }


def unique_random_iv(used_ivs: set[bytes]) -> bytes:
    while True:
        iv = secrets.token_bytes(12)
        if iv not in used_ivs:
            used_ivs.add(iv)
            return iv


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Benchmark the ZCU104 AES-GCM DMA accelerator on many images."
    )
    parser.add_argument("dataset", type=Path, help="folder containing test images")
    parser.add_argument("port", nargs="?", default="COM11")
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument(
        "--output", type=Path, default=Path("gcm_benchmark_output")
    )
    parser.add_argument(
        "--no-iv-repeat",
        action="store_true",
        help="do not repeat the first image with a second fresh IV",
    )
    args = parser.parse_args()

    if not args.dataset.is_dir():
        print(f"ERROR: Dataset folder not found: {args.dataset}")
        return 1
    if args.limit < 2 or args.limit > 99:
        print("ERROR: --limit must be between 2 and 99")
        return 1

    image_paths = sorted(
        path
        for path in args.dataset.iterdir()
        if path.is_file() and path.suffix.lower() in SUPPORTED_SUFFIXES
    )
    if len(image_paths) < args.limit:
        print(f"ERROR: Found {len(image_paths)} supported images; need {args.limit}")
        return 1
    image_paths = image_paths[: args.limit]

    prepared_items: list[dict[str, object]] = []
    try:
        for path in image_paths:
            raw, image = prepare_image(path)
            prepared_items.append(
                {"path": path, "raw": raw, "image": image, "kind": "dataset"}
            )
    except OSError as error:
        print(f"ERROR preparing images: {error}")
        return 1

    if not args.no_iv_repeat:
        first = prepared_items[0]
        prepared_items.append(
            {
                "path": first["path"],
                "raw": first["raw"],
                "image": first["image"].copy(),
                "kind": "iv_repeat",
            }
        )

    args.output.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, object]] = []
    ciphertexts: list[bytes] = []
    ivs: list[bytes] = []
    transcript: list[str] = []
    used_ivs: set[bytes] = set()
    aesgcm = AESGCM(AES_KEY)

    print(f"Dataset images: {args.limit}")
    print(f"Board transactions: {len(prepared_items)}")
    print(f"Opening {args.port} at 115200 baud")
    print("Keep this open, then launch the GCM batch Vitis application once.")

    try:
        with serial.Serial(args.port, 115200, timeout=360, write_timeout=240) as port:
            port.reset_input_buffer()
            wait_for_line(port, b"READY_FOR_BATCH_COUNT ", transcript)
            batch_header = BATCH_MAGIC + len(prepared_items).to_bytes(4, "big")
            if port.write(batch_header) != len(batch_header):
                raise OSError("Could not send the complete batch header")
            port.flush()
            wait_for_line(port, b"BATCH_COUNT ", transcript)

            for index, item in enumerate(prepared_items):
                path = item["path"]
                raw = item["raw"]
                prepared = item["image"]
                iv = unique_random_iv(used_ivs)
                ivs.append(iv)
                performance: dict[str, int] = {}
                run_lines: list[str] = []

                print(
                    f"\n===== RUN {index + 1}/{len(prepared_items)}: "
                    f"{path.name} ({item['kind']}) ====="
                )
                wait_for_line(port, b"READY_FOR_PACKET ", transcript)
                packet = PACKET_MAGIC + iv + raw
                if port.write(packet) != len(packet):
                    raise OSError("Could not send the complete image packet")
                port.flush()
                received_line = wait_for_line(
                    port, b"IMAGE_RECEIVED ", run_lines, performance
                )
                transcript.extend(run_lines)
                run_lines.clear()
                if int(received_line.split()[1]) != index:
                    raise RuntimeError("Board image index does not match host index")
                tag_line = wait_for_line(port, b"GCM_TAG ", run_lines, performance)
                tag_parts = tag_line.split()
                if int(tag_parts[1]) != index:
                    raise RuntimeError("GCM tag index does not match host index")
                tag = bytes.fromhex(tag_parts[2])
                wait_for_line(port, b"CIPHERTEXT_BEGIN ", run_lines, performance)
                encrypted = read_exact(port, IMAGE_SIZE)
                wait_for_line(port, b"CIPHERTEXT_END ", run_lines, performance)
                wait_for_line(port, b"RECOVERED_BEGIN ", run_lines, performance)
                recovered = read_exact(port, IMAGE_SIZE)
                wait_for_line(port, b"RECOVERED_END ", run_lines, performance)
                wait_for_line(
                    port, b"ZCU104_AES_GCM_DMA_IMAGE_DONE ", run_lines, performance
                )
                transcript.extend(run_lines)

                missing = PERFORMANCE_KEYS.difference(performance)
                if missing:
                    raise RuntimeError(f"Missing board metrics: {sorted(missing)}")

                reference = aesgcm.encrypt(iv, raw, None)
                reference_ciphertext = reference[:-16]
                reference_tag = reference[-16:]
                ciphertext_match = encrypted == reference_ciphertext
                tag_match = tag == reference_tag
                exact_recovery = recovered == raw
                python_valid_decrypt = aesgcm.decrypt(iv, encrypted + tag, None) == raw

                tampered = bytearray(encrypted)
                tampered[TAMPER_BYTE_INDEX] ^= TAMPER_XOR_MASK
                python_rejects_tamper = False
                try:
                    aesgcm.decrypt(iv, bytes(tampered) + tag, None)
                except InvalidTag:
                    python_rejects_tamper = True

                board_accepts_valid = f"AUTHENTICATION_PASS {index}" in run_lines
                board_recovery_pass = f"RECOVERY_PASS {index}" in run_lines
                board_rejects_tamper = (
                    f"AUTHENTICATION_FAIL_EXPECTED PASS {index}" in run_lines
                    and f"TAMPER_REJECTED {index}" in run_lines
                )
                plaintext_not_released = (
                    f"PLAINTEXT_RELEASED NO {index}" in run_lines
                )
                rejected_zeroized = (
                    f"TAMPERED_BUFFER_ZEROIZED {index}" in run_lines
                )

                run_dir = (
                    args.output
                    / f"{index + 1:02d}_{safe_name(path)}_{item['kind']}"
                )
                run_dir.mkdir(parents=True, exist_ok=True)
                prepared.save(run_dir / "input_256.png")
                Image.frombytes("RGB", (WIDTH, HEIGHT), encrypted).save(
                    run_dir / "encrypted.png"
                )
                Image.frombytes("RGB", (WIDTH, HEIGHT), recovered).save(
                    run_dir / "recovered.png"
                )
                (run_dir / "iv_96.bin").write_bytes(iv)
                (run_dir / "gcm_tag_128.bin").write_bytes(tag)
                (run_dir / "ciphertext.bin").write_bytes(encrypted)
                (run_dir / "recovered.bin").write_bytes(recovered)

                original_stats = image_metrics(raw)
                encrypted_stats = image_metrics(encrypted)
                run_pass = all(
                    (
                        ciphertext_match,
                        tag_match,
                        exact_recovery,
                        python_valid_decrypt,
                        python_rejects_tamper,
                        board_accepts_valid,
                        board_recovery_pass,
                        board_rejects_tamper,
                        plaintext_not_released,
                        rejected_zeroized,
                    )
                )
                row: dict[str, object] = {
                    "run": index + 1,
                    "kind": item["kind"],
                    "source": str(path),
                    "iv_hex": iv.hex().upper(),
                    "tag_hex": tag.hex().upper(),
                    "input_sha256": hashlib.sha256(raw).hexdigest(),
                    "ciphertext_sha256": hashlib.sha256(encrypted).hexdigest(),
                    "recovered_sha256": hashlib.sha256(recovered).hexdigest(),
                    "ciphertext_matches_python_aesgcm": ciphertext_match,
                    "tag_matches_python_aesgcm": tag_match,
                    "exact_recovery": exact_recovery,
                    "board_accepts_valid_tag": board_accepts_valid,
                    "board_rejects_modified_ciphertext": board_rejects_tamper,
                    "python_rejects_modified_ciphertext": python_rejects_tamper,
                    "unauthenticated_plaintext_released": not plaintext_not_released,
                    "rejected_buffer_zeroized": rejected_zeroized,
                    "run_pass": run_pass,
                    "encryption_time_us": performance[
                        "ENCRYPTION_GCM_DMA_TIME_US"
                    ],
                    "encryption_throughput_kbps": performance[
                        "ENCRYPTION_GCM_DMA_THROUGHPUT_KBPS"
                    ],
                    "decryption_time_us": performance[
                        "DECRYPTION_GCM_DMA_TIME_US"
                    ],
                    "decryption_throughput_kbps": performance[
                        "DECRYPTION_GCM_DMA_THROUGHPUT_KBPS"
                    ],
                    "tampered_decryption_time_us": performance[
                        "TAMPERED_DECRYPTION_GCM_DMA_TIME_US"
                    ],
                    "tampered_decryption_throughput_kbps": performance[
                        "TAMPERED_DECRYPTION_GCM_DMA_THROUGHPUT_KBPS"
                    ],
                }
                for key, value in original_stats.items():
                    row[f"original_{key}"] = value
                for key, value in encrypted_stats.items():
                    row[f"encrypted_{key}"] = value
                rows.append(row)
                ciphertexts.append(encrypted)
                (run_dir / "run_metadata.json").write_text(
                    json.dumps(row, indent=2) + "\n", encoding="utf-8"
                )
                print("Run verification:", "PASS" if run_pass else "FAIL")

            wait_for_line(
                port, b"ZCU104_AES_GCM_DMA_BATCH_DONE ", transcript
            )
    except (serial.SerialException, TimeoutError, OSError, RuntimeError, ValueError) as error:
        print(f"ERROR: {error}")
        print("Stop the Vitis session, verify COM11/COM13, and relaunch the batch app.")
        return 2
    except KeyboardInterrupt:
        print("\nStopped")
        return 130

    with (args.output / "gcm_benchmark_runs.csv").open(
        "w", newline="", encoding="utf-8"
    ) as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    dataset_rows = [row for row in rows if row["kind"] == "dataset"]
    all_runs_pass = all(bool(row["run_pass"]) for row in rows)
    summary: dict[str, object] = {
        "board": "ZCU104 xczu7ev-ffvc1156-2-e",
        "architecture": "128-bit AXI-DMA plus AES-128-GCM AXI4-Stream",
        "clock_mhz": 75.002,
        "dataset_image_count": len(dataset_rows),
        "board_transaction_count": len(rows),
        "image_format": "256x256 RGB888",
        "image_bytes": IMAGE_SIZE,
        "tag_bits": 128,
        "iv_bits": 96,
        "all_ivs_unique": len(set(ivs)) == len(ivs),
        "all_ciphertexts_match_python_aesgcm": all(
            bool(row["ciphertext_matches_python_aesgcm"]) for row in rows
        ),
        "all_tags_match_python_aesgcm": all(
            bool(row["tag_matches_python_aesgcm"]) for row in rows
        ),
        "all_exact_recoveries_pass": all(
            bool(row["exact_recovery"]) for row in rows
        ),
        "all_valid_tags_accepted_by_board": all(
            bool(row["board_accepts_valid_tag"]) for row in rows
        ),
        "all_modified_ciphertexts_rejected_by_board": all(
            bool(row["board_rejects_modified_ciphertext"]) for row in rows
        ),
        "all_rejected_buffers_zeroized": all(
            bool(row["rejected_buffer_zeroized"]) for row in rows
        ),
        "all_runs_pass": all_runs_pass,
    }
    for key in (
        "encryption_time_us",
        "encryption_throughput_kbps",
        "decryption_time_us",
        "decryption_throughput_kbps",
        "tampered_decryption_time_us",
        "tampered_decryption_throughput_kbps",
        "encrypted_entropy_all",
        "encrypted_corr_horizontal",
        "encrypted_corr_vertical",
        "encrypted_corr_diagonal",
        "encrypted_histogram_chi_square",
    ):
        summary[key] = mean_and_stdev(dataset_rows, key)

    if not args.no_iv_repeat:
        first_cipher = np.frombuffer(ciphertexts[0], dtype=np.uint8)
        repeated_cipher = np.frombuffer(ciphertexts[-1], dtype=np.uint8)
        sensitivity = {
            "source": str(prepared_items[0]["path"]),
            "same_preprocessed_input": bool(
                prepared_items[0]["raw"] == prepared_items[-1]["raw"]
            ),
            "iv_1_hex": ivs[0].hex().upper(),
            "iv_2_hex": ivs[-1].hex().upper(),
            "different_ivs": ivs[0] != ivs[-1],
            "different_tags": rows[0]["tag_hex"] != rows[-1]["tag_hex"],
            "npcr_percent": float(np.mean(first_cipher != repeated_cipher) * 100.0),
            "uaci_percent": float(
                np.mean(
                    np.abs(
                        first_cipher.astype(np.int16)
                        - repeated_cipher.astype(np.int16)
                    )
                    / 255.0
                )
                * 100.0
            ),
            "ciphertext_1_sha256": rows[0]["ciphertext_sha256"],
            "ciphertext_2_sha256": rows[-1]["ciphertext_sha256"],
        }
        summary["iv_sensitivity"] = sensitivity
        (args.output / "iv_sensitivity.json").write_text(
            json.dumps(sensitivity, indent=2) + "\n", encoding="utf-8"
        )

    (args.output / "gcm_benchmark_summary.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    (args.output / "uart_transcript.txt").write_text(
        "\n".join(transcript) + "\n", encoding="utf-8"
    )

    print("\n========== GCM MULTI-IMAGE BENCHMARK COMPLETE ==========")
    print("All unique IVs:", "PASS" if summary["all_ivs_unique"] else "FAIL")
    print("All FPGA ciphertexts match Python:", "PASS" if summary["all_ciphertexts_match_python_aesgcm"] else "FAIL")
    print("All FPGA tags match Python:", "PASS" if summary["all_tags_match_python_aesgcm"] else "FAIL")
    print("All recoveries:", "PASS" if summary["all_exact_recoveries_pass"] else "FAIL")
    print("All board tamper rejections:", "PASS" if summary["all_modified_ciphertexts_rejected_by_board"] else "FAIL")
    print("All rejected buffers zeroized:", "PASS" if summary["all_rejected_buffers_zeroized"] else "FAIL")
    print(
        "Mean encryption throughput (KB/s):",
        f"{summary['encryption_throughput_kbps']['mean']:.2f}",
    )
    print(
        "Mean encrypted entropy:",
        f"{summary['encrypted_entropy_all']['mean']:.6f}",
    )
    if "iv_sensitivity" in summary:
        print(
            "IV-sensitivity NPCR (%):",
            f"{summary['iv_sensitivity']['npcr_percent']:.6f}",
        )
        print(
            "IV-sensitivity UACI (%):",
            f"{summary['iv_sensitivity']['uaci_percent']:.6f}",
        )
    print("OVERALL:", "PASS" if all_runs_pass else "FAIL")
    print("Results:", args.output.resolve())
    return 0 if all_runs_pass else 3


if __name__ == "__main__":
    sys.exit(main())
