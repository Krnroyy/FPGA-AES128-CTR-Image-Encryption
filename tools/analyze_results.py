#!/usr/bin/env python3
"""Recompute the published CTR-DMA versus GCM-DMA results and figures."""

from __future__ import annotations

import csv
import hashlib
import json
import re
import statistics
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
CTR = ROOT / "results" / "ctr_dma_run1"
GCM = ROOT / "results" / "gcm_batch_run1"
OUT = ROOT / "results" / "comparison"
FIG = ROOT / "docs" / "images"


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_implementation(prefix: Path) -> dict[str, float]:
    util = (prefix / "reports" / ("gcm_dma_utilization.rpt" if "gcm" in prefix.name else "dma_utilization.rpt")).read_text(errors="replace")
    timing = (prefix / "reports" / ("gcm_dma_timing_summary.rpt" if "gcm" in prefix.name else "dma_timing_summary.rpt")).read_text(errors="replace")
    power = (prefix / "reports" / ("gcm_dma_power.rpt" if "gcm" in prefix.name else "dma_power.rpt")).read_text(errors="replace")

    top = re.search(r"^\|\s*system_wrapper\s*\|.*?\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|", util, re.M)
    timing_row = re.search(r"^\s*(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\d+\s+\d+\s+", timing, re.M)
    clock = re.search(r"^clk_pl_0\s+\{[^}]+\}\s+([0-9.]+)\s+([0-9.]+)", timing, re.M)
    total_power = re.search(r"Total On-Chip Power \(W\)\s*\|\s*([0-9.]+)", power)
    dynamic_power = re.search(r"Dynamic \(W\)\s*\|\s*([0-9.]+)", power)
    static_power = re.search(r"Device Static \(W\)\s*\|\s*([0-9.]+)", power)
    if not all((top, timing_row, clock, total_power, dynamic_power, static_power)):
        raise RuntimeError(f"Could not parse one or more implementation metrics under {prefix}")

    values = [int(value) for value in top.groups()]
    return {
        "luts": values[0],
        "flip_flops": values[4],
        "bram_36": values[5],
        "bram_18": values[6],
        "bram_tile_equivalent": values[5] + values[6] / 2,
        "dsps": values[7],
        "wns_ns": float(timing_row.group(1)),
        "tns_ns": float(timing_row.group(2)),
        "period_ns": float(clock.group(1)),
        "clock_mhz": float(clock.group(2)),
        "power_total_w": float(total_power.group(1)),
        "power_dynamic_w": float(dynamic_power.group(1)),
        "power_static_w": float(static_power.group(1)),
    }


def percent_change(new: float, old: float) -> float:
    return 100.0 * (new / old - 1.0)


def save_bar_chart(path: Path, title: str, ylabel: str, categories, values, labels, colors):
    fig, ax = plt.subplots(figsize=(7.2, 4.4))
    x = np.arange(len(categories))
    width = 0.36
    for index, (series, label, color) in enumerate(zip(values, labels, colors)):
        positions = x + (index - (len(values) - 1) / 2) * width
        bars = ax.bar(positions, series, width, label=label, color=color)
        ax.bar_label(bars, fmt="%.0f", padding=3, fontsize=9)
    ax.set_xticks(x, categories)
    ax.set_ylabel(ylabel)
    ax.set_title(title, weight="bold")
    ax.grid(axis="y", alpha=0.25)
    ax.legend(frameon=False)
    ax.spines[["top", "right"]].set_visible(False)
    fig.tight_layout()
    fig.savefig(path, dpi=300, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    FIG.mkdir(parents=True, exist_ok=True)

    ctr_summary = read_json(CTR / "raw" / "benchmark_summary.json")
    gcm_summary = read_json(GCM / "raw" / "gcm_benchmark_summary.json")
    ctr_tamper = read_json(CTR / "raw" / "ctr_tamper_experiment.json")
    ctr_impl = parse_implementation(CTR)
    gcm_impl = parse_implementation(GCM)

    with (GCM / "raw" / "gcm_benchmark_runs.csv").open(newline="", encoding="utf-8-sig") as source:
        gcm_rows = list(csv.DictReader(source))
    dataset_rows = [row for row in gcm_rows if row["kind"] == "dataset"]
    transcript = (GCM / "raw" / "uart_transcript.txt").read_text(encoding="utf-8", errors="replace")

    def tick_summary(marker: str) -> dict[str, float]:
        ticks = [int(value) for value in re.findall(rf"^{marker} (\d+)$", transcript, re.M)]
        if len(ticks) != len(gcm_rows):
            raise RuntimeError(f"Expected {len(gcm_rows)} {marker} values, found {len(ticks)}")
        return {
            "count": len(ticks),
            "mean_ticks": statistics.fmean(ticks),
            "population_stdev_ticks": statistics.pstdev(ticks),
            "minimum_ticks": min(ticks),
            "maximum_ticks": max(ticks),
            "range_us_at_100mhz": (max(ticks) - min(ticks)) / 100.0,
        }

    tick_measurements = {
        "encryption": tick_summary("ENCRYPTION_GCM_DMA_COUNTER_TICKS"),
        "authenticated_decryption": tick_summary("DECRYPTION_GCM_DMA_COUNTER_TICKS"),
        "tampered_decryption": tick_summary("TAMPERED_DECRYPTION_GCM_DMA_COUNTER_TICKS"),
    }

    verification = {
        "gcm_transactions": len(gcm_rows),
        "gcm_dataset_images": len(dataset_rows),
        "unique_ivs": len({row["iv_hex"] for row in gcm_rows}),
        "all_ciphertexts_match_python": all(row["ciphertext_matches_python_aesgcm"] == "True" for row in gcm_rows),
        "all_tags_match_python": all(row["tag_matches_python_aesgcm"] == "True" for row in gcm_rows),
        "all_exact_recoveries": all(row["exact_recovery"] == "True" for row in gcm_rows),
        "all_tamper_rejections": all(row["board_rejects_modified_ciphertext"] == "True" for row in gcm_rows),
        "all_rejected_buffers_zeroized": all(row["rejected_buffer_zeroized"] == "True" for row in gcm_rows),
        "unauthenticated_plaintext_release_count": sum(row["unauthenticated_plaintext_released"] == "True" for row in gcm_rows),
    }

    manifest = {
        "board": gcm_summary["board"],
        "verified_gcm": verification,
        "ctr_dma": {"application": ctr_summary, "implementation": ctr_impl, "tamper_experiment": ctr_tamper},
        "gcm_dma": {"application": gcm_summary, "implementation": gcm_impl, "raw_counter_measurements": tick_measurements},
        "comparison": {
            "encryption_latency_increase_percent": percent_change(gcm_summary["encryption_time_us"]["mean"], ctr_summary["encryption_time_us"]["mean"]),
            "encryption_throughput_change_percent": percent_change(gcm_summary["encryption_throughput_kbps"]["mean"], ctr_summary["encryption_throughput_kbps"]["mean"]),
            "lut_change_percent": percent_change(gcm_impl["luts"], ctr_impl["luts"]),
            "flip_flop_change_percent": percent_change(gcm_impl["flip_flops"], ctr_impl["flip_flops"]),
            "estimated_power_change_percent": percent_change(gcm_impl["power_total_w"], ctr_impl["power_total_w"]),
        },
    }
    source_files = sorted(list((CTR / "raw").glob("*")) + list((CTR / "reports").glob("*")) + list((GCM / "raw").glob("*")) + list((GCM / "reports").glob("*")))
    manifest["source_sha256"] = {str(path.relative_to(ROOT)).replace("\\", "/"): sha256(path) for path in source_files}
    (OUT / "verified_summary.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    save_bar_chart(
        FIG / "dma_throughput_comparison.png",
        "ZCU104 AES DMA throughput",
        "Throughput (KB/s)",
        ["Encryption", "Decryption"],
        [[ctr_summary["encryption_throughput_kbps"]["mean"], ctr_summary["decryption_throughput_kbps"]["mean"]],
         [gcm_summary["encryption_throughput_kbps"]["mean"], gcm_summary["decryption_throughput_kbps"]["mean"]]],
        ["AES-CTR DMA", "AES-GCM DMA"],
        ["#277DA1", "#F8961E"],
    )
    save_bar_chart(
        FIG / "dma_latency_comparison.png",
        "ZCU104 AES DMA latency for 196,608 bytes",
        "Latency (us)",
        ["Encryption", "Decryption"],
        [[ctr_summary["encryption_time_us"]["mean"], ctr_summary["decryption_time_us"]["mean"]],
         [gcm_summary["encryption_time_us"]["mean"], gcm_summary["decryption_time_us"]["mean"]]],
        ["AES-CTR DMA", "AES-GCM DMA"],
        ["#277DA1", "#F8961E"],
    )

    fig, axes = plt.subplots(1, 2, figsize=(9.0, 4.2))
    labels = ["CTR-DMA", "GCM-DMA"]
    for ax, metric, values in [
        (axes[0], "LUTs", [ctr_impl["luts"], gcm_impl["luts"]]),
        (axes[1], "Flip-flops", [ctr_impl["flip_flops"], gcm_impl["flip_flops"]]),
    ]:
        bars = ax.bar(labels, values, color=["#277DA1", "#F8961E"])
        ax.bar_label(bars, fmt="%.0f", padding=3)
        ax.set_title(metric, weight="bold")
        ax.grid(axis="y", alpha=0.25)
        ax.spines[["top", "right"]].set_visible(False)
    fig.suptitle("Programmable-logic resource comparison", weight="bold")
    fig.tight_layout()
    fig.savefig(FIG / "dma_resource_comparison.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    security = np.array([[1, 0, 0], [1, 1, 1]], dtype=float)
    fig, ax = plt.subplots(figsize=(7.2, 3.1))
    image = ax.imshow(security, cmap=matplotlib.colors.ListedColormap(["#D9534F", "#2A9D8F"]), vmin=0, vmax=1, aspect="auto")
    ax.set_xticks(range(3), ["Confidentiality", "Tamper detection", "Release control"])
    ax.set_yticks(range(2), ["AES-CTR DMA", "AES-GCM DMA"])
    for row in range(2):
        for col in range(3):
            ax.text(col, row, "PASS" if security[row, col] else "NO", ha="center", va="center", color="white", weight="bold")
    ax.set_title("Experimentally demonstrated security properties", weight="bold")
    ax.tick_params(length=0)
    fig.tight_layout()
    fig.savefig(FIG / "security_property_comparison.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    entropy = [float(row["encrypted_entropy_all"]) for row in dataset_rows]
    hcorr = [float(row["encrypted_corr_horizontal"]) for row in dataset_rows]
    vcorr = [float(row["encrypted_corr_vertical"]) for row in dataset_rows]
    dcorr = [float(row["encrypted_corr_diagonal"]) for row in dataset_rows]
    fig, axes = plt.subplots(1, 2, figsize=(10.0, 4.2))
    x = np.arange(1, len(dataset_rows) + 1)
    axes[0].plot(x, entropy, marker="o", color="#F8961E")
    axes[0].axhline(8.0, color="#333333", linestyle="--", linewidth=1, label="8-bit maximum")
    axes[0].set_ylim(7.9987, 8.00005)
    axes[0].ticklabel_format(axis="y", style="plain", useOffset=False)
    axes[0].set_xlabel("Dataset image")
    axes[0].set_ylabel("Entropy (bits/byte)")
    axes[0].set_title("Ciphertext entropy", weight="bold")
    axes[0].legend(frameon=False)
    axes[0].grid(alpha=0.25)
    axes[1].plot(x, hcorr, marker="o", label="Horizontal")
    axes[1].plot(x, vcorr, marker="s", label="Vertical")
    axes[1].plot(x, dcorr, marker="^", label="Diagonal")
    axes[1].axhline(0.0, color="#333333", linestyle="--", linewidth=1)
    axes[1].set_xlabel("Dataset image")
    axes[1].set_ylabel("Adjacent-byte correlation")
    axes[1].set_title("Ciphertext spatial correlation", weight="bold")
    axes[1].legend(frameon=False, fontsize=8)
    axes[1].grid(alpha=0.25)
    fig.suptitle("AES-GCM statistical results across 10 images", weight="bold")
    fig.tight_layout()
    fig.savefig(FIG / "gcm_statistical_results.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    print(f"Wrote {OUT / 'verified_summary.json'}")
    print("Verification:", json.dumps(verification, sort_keys=True))


if __name__ == "__main__":
    main()
