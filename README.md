# FPGA AES-128-GCM Authenticated Image Security on ZCU104

Hardware/software co-design for authenticated image encryption on the AMD/Xilinx ZCU104 Zynq UltraScale+ MPSoC. A Cortex-A53 application transfers 256 × 256 RGB888 images through AXI DMA to a custom 128-bit AES-GCM AXI4-Stream accelerator in programmable logic.

The final implementation provides confidentiality, a 128-bit authentication tag, ciphertext-tamper detection, and controlled plaintext release. FPGA ciphertext and tags were independently checked against Python's `AESGCM` implementation.

## Verified outcome

| Test | Measured result |
|---|---:|
| Physical board | ZCU104 (`xczu7ev-ffvc1156-2-e`) |
| Toolchain | Vivado and Vitis Embedded 2026.1 |
| PL clock | 75.002 MHz |
| Image format | 256 × 256 RGB888, 196,608 bytes |
| Dataset | 10 images + 1 same-image/new-IV transaction |
| Unique 96-bit IVs | 11/11 |
| FPGA ciphertext matched Python AESGCM | 11/11 PASS |
| FPGA 128-bit tag matched Python AESGCM | 11/11 PASS |
| Exact recovery | 11/11 PASS |
| Modified ciphertext rejected | 11/11 PASS |
| Rejected output buffer zeroized | 11/11 PASS |
| Unauthenticated plaintext released | 0/11 |

## Architecture

```mermaid
flowchart LR
    Host["Laptop: image, IV, verification"] -->|UART| A53["Cortex-A53 bare-metal app"]
    A53 <--> DDR["PS DDR buffers"]
    DDR -->|AXI DMA MM2S, 128-bit| GCM["AES-128-GCM AXI4-Stream RTL"]
    GCM -->|AXI DMA S2MM, 128-bit| DDR
    A53 -->|AXI4-Lite control| GCM
```

Data path: PS DDR → AXI DMA → AES-GCM → AXI DMA → PS DDR. The processor supplies the key, 96-bit IV, direction and length through AXI4-Lite registers. On decryption, software checks the hardware authentication decision before transmitting plaintext. A rejected output buffer is zeroized.

## Measured CTR-DMA versus GCM-DMA

| Metric | AES-CTR DMA | AES-GCM DMA | GCM change |
|---|---:|---:|---:|
| Encryption latency | 2,186 µs | 3,010 µs | +37.7% |
| Encryption throughput | 89,939 KB/s | 65,318 KB/s | −27.4% |
| Decryption latency | 2,175 µs | 2,999 µs | +37.9% |
| Decryption throughput | 90,394 KB/s | 65,557 KB/s | −27.5% |
| LUTs | 17,016 | 19,593 | +15.1% |
| Flip-flops | 11,129 | 12,587 | +13.1% |
| BRAM equivalent | 5 × 36K | 5 × 36K | 0% |
| DSPs | 0 | 0 | 0 |
| WNS at 75.002 MHz | +1.304 ns | +0.187 ns | Timing met |
| Vivado estimated power | 3.539 W | 3.625 W | +2.4% |
| Ciphertext tamper detection | No | Yes | Security gain |

![DMA throughput comparison](docs/images/dma_throughput_comparison.png)

![Security-property comparison](docs/images/security_property_comparison.png)

## Image-security measurements

Across the 10-image AES-GCM dataset:

- mean combined ciphertext entropy: **7.999052 bits/byte**;
- mean horizontal, vertical and diagonal correlations: **−0.000839**, **−0.001305**, and **+0.001588**;
- same preprocessed image with two fresh IVs: **NPCR 99.593099%**, **UACI 33.458699%**;
- all 11 IVs, tags and ciphertext hashes were unique.

These image statistics describe the measured ciphertext. Cryptographic correctness is supported more strongly by the standard RTL tests, exact Python AESGCM agreement, unique-IV checks, and authenticated tamper-rejection experiment.

![GCM statistical results](docs/images/gcm_statistical_results.png)

## Repository layout

```text
hardware/
  rtl/                         Original AXI4-Lite CTR baseline
  gcm_dma/rtl/                 AES, GHASH and AES-GCM AXI4-Stream RTL
  gcm_dma/sim/                 NIST/reference RTL testbenches
  gcm_dma/scripts/             Self-contained Vivado 2026.1 flow
software/
  vitis/                       Original fixed-image baseline
  vitis_gcm/single_image/      Dynamic authenticated-image application
  vitis_gcm/batch/             Multi-image benchmark application
host/gcm/                      Python single-image and batch tools
results/
  ctr_dma_run1/                Preserved CTR-DMA evidence
  gcm_batch_run1/              Preserved GCM evidence and reports
  comparison/                  Recomputed JSON summary and evidence hashes
docs/                          Security model and paper experiment plan
tools/analyze_results.py       Reproduces tables, hashes and figures
```

## Reproduce the analysis

```powershell
py -m pip install -r requirements-analysis.txt
py tools\analyze_results.py
```

The script reads the preserved raw files, recomputes the comparison, creates SHA-256 checksums for the evidence, and regenerates the figures. It does not alter the raw measurements.

## Build and run

Follow [BUILD_AND_RUN.md](BUILD_AND_RUN.md). The short sequence is:

1. Run the RTL validation testbench.
2. Run the three Vivado scripts under `hardware/gcm_dma/scripts`.
3. Create a Vitis platform from the exported XSA.
4. Build either the single-image or batch Cortex-A53 application.
5. Start the matching Python host tool before launching the Vitis application.
6. Require `OVERALL: PASS` before accepting a run.

## Documentation

- [Detailed measured results](RESULTS.md)
- [Build and run guide](BUILD_AND_RUN.md)
- [Security model and limitations](docs/SECURITY_MODEL.md)
- [Paper experiment roadmap](docs/PAPER_EXPERIMENT_PLAN.md)
- [Machine-readable verified summary](results/comparison/verified_summary.json)

## Current limitations

- The proof of concept supports 256 × 256 RGB888 payloads; it is not a DICOM parser.
- No additional authenticated data (AAD) is implemented yet.
- IVs are randomly generated by the host; production use needs persistent uniqueness enforcement for every key.
- The demonstration key is not stored in a secure hardware key vault.
- Rejected plaintext can transiently enter a reserved DDR buffer before tag verification; it is never released and is zeroized after rejection.
- Power values are vectorless Vivado estimates with medium confidence, not physical rail measurements.
- The present dataset has 10 images; a publication study should use a larger, licensed medical-image dataset and repeated trials.

## Academic scope

This repository is a verified engineering research prototype, not a clinical security product. The included NIST/demo key is intentionally public and must never be used as a production secret. Do not publish private patient images, real secret keys, generated Vivado workspaces, bitstreams, XSA files, or unrelated local logs. Only redistribute sample images whose licensing permits public use.

## License

See [LICENSE](LICENSE).
