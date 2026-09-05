# FPGA-Based AES-128 CTR Image Encryption and Decryption

This project implements AES-128 in Counter (CTR) mode on FPGA for grayscale image encryption and decryption.

The design is written in Verilog and implemented using AMD Vivado 2026.1. The project covers AES-128 hardware design, NIST verification, BRAM-based image storage, real-image encryption and recovery, timing analysis, power estimation, and RTL critical-path optimization.

## Real-Image Encryption Demo

| Original Image | Encrypted Image | Recovered Image |
|---|---|---|
| ![Original](results/images/original_64x64.png) | ![Encrypted](results/images/encrypted_64x64.png) | ![Recovered](results/images/recovered_64x64.png) |

Result:

```text
Image size              : 64 x 64
Total bytes             : 4096
Recovered bytes         : 4096 / 4096
Recovered mismatches    : 0
Original == Recovered   : YES
```

## Project Overview

AES-128 CTR mode generates a keystream by encrypting a counter value.

```text
Keystream  = AES-128(Key, Counter)

Ciphertext = Plaintext XOR Keystream

Plaintext  = Ciphertext XOR Keystream
```

CTR mode does not require an inverse AES datapath for decryption. The same AES encryption core and XOR operation can be used for both encryption and decryption.

The final design uses one AES-128 core along with three BRAM memories for original image data, ciphertext data, and recovered image data.

## System Architecture

```text
                       AES-128 Key
                            |
                            v
                     +--------------+
Counter ------------>| AES-128 Core |
                     +------+-------+
                            |
                         Keystream
                            |
                            v
Image BRAM ---------> XOR ----------> Cipher BRAM


Decryption:

                       AES-128 Key
                            |
                            v
                     +--------------+
Counter ------------>| AES-128 Core |
                     +------+-------+
                            |
                         Keystream
                            |
                            v
Cipher BRAM --------> XOR ----------> Recovered BRAM
```

The system contains:

- AES-128 encryption core
- AES round modules
- AES key expansion
- CTR counter logic
- BRAM-based image storage
- Encryption/decryption control FSM
- Ciphertext memory
- Recovered-image memory

## FPGA and Design Parameters

| Parameter | Value |
|---|---|
| FPGA Family | Xilinx Artix-7 |
| Device | xc7a12ticsg325-1L |
| Tool | AMD Vivado 2026.1 |
| HDL | Verilog |
| Algorithm | AES-128 CTR |
| Key Size | 128 bits |
| AES Block Size | 128 bits |
| Image Type | 8-bit grayscale |
| Image Resolution | 64 x 64 |
| Image Size | 4096 bytes |
| AES Blocks per Image | 256 |

## Repository Structure

```text
FPGA-AES128-CTR-Image-Encryption/
|
|-- rtl/
|   |-- aes128_core.v
|   |-- aes128_ctr.v
|   |-- aes128_ctr_opt.v
|   |-- aes_round.v
|   |-- aes_final_round.v
|   |-- add_round_key.v
|   |-- sub_bytes.v
|   |-- shift_rows.v
|   |-- mix_columns.v
|   |-- sbox.v
|   |-- key_expension_128.v
|   |-- bram_8x4096.v
|   `-- image_aes_bram_encdec_top.v
|
|-- testbench/
|   |-- aes128_ctr_nist_tb.v
|   |-- tb_aes128_ctr_opt_nist.v
|   |-- tb_aes128_ctr_equivalence.v
|   |-- image_aes_bram_encdec_tb.v
|   |-- image_aes_real_image_tb.v
|   `-- image_aes_bram_encdec_power_tb.v
|
|-- constraints/
|   `-- aes128_fpga.xdc
|
|-- python/
|   |-- prepare_image.py
|   |-- reconstruct_images.py
|   `-- security_metrics.py
|
|-- results/
|   |-- images/
|   |-- data/
|   |-- reports/
|   `-- results_summary.md
|
|-- .gitignore
|-- LICENSE
`-- README.md
```

## AES-128 CTR Verification

The CTR implementation was verified using NIST SP 800-38A test vectors.

AES-128 key:

```text
2B7E151628AED2A6ABF7158809CF4F3C
```

Initial counter:

```text
F0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF
```

Test results:

| Block | Expected Ciphertext | Result |
|---|---|---|
| 0 | 874D6191B620E3261BEF6864990DB6CE | PASS |
| 1 | 9806F66B7970FDFF8617187BB9FFFDFF | PASS |
| 2 | 5AE4DF3EDBD5D35E5B4F09020DB03EAB | PASS |
| 3 | 1E031DDA2FBE03D1792170A0F3009CEE | PASS |

All four ciphertext blocks and counter checks passed.

```text
PASS checks : 8
FAIL checks : 0
```

## BRAM-Based Image Storage

Three BRAM memories are used in the complete system.

```text
Original Image BRAM
        |
        v
   AES-128 CTR
        |
        v
  Cipher BRAM
        |
        v
   AES-128 CTR
        |
        v
 Recovered BRAM
```

Each BRAM stores 4096 8-bit values.

```text
Memory size = 4096 x 8 bits
```

This is sufficient for one 64 x 64 grayscale image.

Block RAM inference is requested using:

```verilog
(* ram_style = "block" *)
```

## Real-Image Processing

The image processing flow used for simulation is:

```text
Input image
     |
     v
Convert to grayscale
     |
     v
Resize to 64 x 64
     |
     v
Generate image_input.hex
     |
     v
Load into image BRAM
     |
     v
AES-128 CTR encryption
     |
     v
cipher_output.hex
     |
     v
AES-128 CTR decryption
     |
     v
recovered_output.hex
     |
     v
Reconstruct recovered image
```

The complete 4096-byte image was compared after decryption.

```text
Recovered byte mismatches : 0
Original Image == Recovered Image : YES
REAL IMAGE AES-128 CTR TEST : PASS
```

## Latency

A 64-byte test containing four AES blocks required:

```text
Encryption : 260 cycles
Decryption : 260 cycles
```

This gives:

```text
65 cycles per 128-bit block
```

At 100 MHz:

```text
Encryption latency : 2.60 us
Decryption latency : 2.60 us
```

## Throughput

For 512 bits processed in 260 cycles:

At 100 MHz:

```text
Throughput : 196.92 Mbps
Data rate  : 24.62 MB/s
```

At 185.185 MHz:

```text
Throughput : approximately 364.7 Mbps
Data rate  : approximately 45.59 MB/s
```

## Resource Utilization

Baseline implementation:

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| LUT | 1723 | 8000 | 21.54% |
| Flip-Flop | 1580 | 16000 | 9.88% |
| Slice | 641 | 3650 | 17.56% |
| BRAM36 | 3 | 20 | 15% |
| DSP | 0 | - | 0% |
| BUFG | 1 | - | - |

The three BRAM blocks are used for original image, encrypted image, and recovered image storage.

No DSP blocks are used.

## Timing at 100 MHz

The 100 MHz implementation uses a 10 ns clock period.

Post-route timing results:

```text
WNS = +2.655 ns
TNS = 0 ns

WHS = +0.026 ns
THS = 0 ns
```

The design meets internal setup and hold timing requirements at 100 MHz.

## High-Frequency Timing Characterization

The design was also implemented using progressively tighter clock constraints.

The highest clock frequency successfully verified in the current post-route implementation was:

```text
Clock period : 5.400 ns
Frequency    : 185.185 MHz
```

At this frequency, the 260-cycle operation requires approximately:

```text
1.404 us
```

This represents an approximately 85.19 percent increase in operating frequency compared with the 100 MHz baseline.

## Critical Path Analysis

Timing analysis of the original design identified the 128-bit CTR increment operation as the critical path.

Original counter operation:

```verilog
counter_out <= counter_reg + 128'd1;
```

The corresponding implementation contained a long carry chain.

Original critical-path characteristics at the 5.400 ns constraint:

```text
Data path delay : 5.213 ns
Logic delay     : 4.928 ns
Routing delay   : 0.285 ns
```

Approximately 94.53 percent of the delay was caused by logic and 5.47 percent by routing.

## CTR Counter Optimization

A separate optimized module named:

```text
aes128_ctr_opt.v
```

was created for the timing experiment.

The original 128-bit increment was divided into four 32-bit sections.

```text
[127:96] [95:64] [63:32] [31:0]
    |        |       |       |
  32-bit   32-bit  32-bit  32-bit
 section   section  section  section
```

Each section computes its increment locally and carry propagation between sections is handled using selection logic.

The optimization preserves the behavior of a complete 128-bit counter increment.

## Counter Equivalence Verification

The original and optimized CTR implementations were compared using the same inputs.

The testbench checked:

- Normal counter increments
- 32-bit rollover
- 64-bit rollover
- 96-bit rollover
- Full 128-bit rollover
- AES output equality
- Counter output equality

All tests passed.

```text
Original CTR == Optimized CTR : PASS
```

The optimized CTR implementation was also tested separately using the NIST SP 800-38A vectors.

## Result of Counter Optimization

After optimization, the CTR counter was no longer the critical timing path.

The new critical path moved into the AES datapath.

Optimized critical-path characteristics:

```text
Data path delay : 5.199 ns
Logic delay     : 1.672 ns
Routing delay   : 3.527 ns
```

The new path consisted of approximately:

```text
32.16 percent logic
67.84 percent routing
```

The optimization therefore changed the system bottleneck from the long counter carry chain to the AES datapath.

## Baseline and Optimized Area Comparison

| Resource | Baseline | Optimized | Difference |
|---|---:|---:|---:|
| LUT | 1723 | 1770 | +47 |
| Flip-Flop | 1580 | 1583 | +3 |
| Slice | 641 | 649 | +8 |
| BRAM36 | 3 | 3 | 0 |
| DSP | 0 | 0 | 0 |

The optimized counter requires slightly more FPGA resources.

The highest verified system frequency remained 185.185 MHz because, after removing the counter bottleneck, the AES datapath became the limiting path.

The baseline version is therefore slightly more area-efficient, while the optimized version is retained as a timing-optimization experiment.

## Power Analysis

SAIF-based post-implementation power estimation was performed at 100 MHz.

| Power Component | Value |
|---|---:|
| Total On-Chip Power | 0.077 W |
| Dynamic Power | 0.018 W |
| Static Power | 0.059 W |

SAIF activity coverage:

```text
Matched nets : 3911 / 4416
Coverage     : approximately 89%
```

Vivado reported high confidence for the power estimate.

The power values are simulation-based estimates and are not physical board measurements.

## Image Security Analysis

Statistical analysis was performed on the original and encrypted grayscale images using Python.

### Entropy

| Image | Entropy |
|---|---:|
| Original | 7.403565 bits/pixel |
| Encrypted | 7.960175 bits/pixel |
| Recovered | 7.403565 bits/pixel |

The encrypted image entropy is close to the maximum theoretical entropy of 8 bits per pixel for an 8-bit grayscale image.

### Adjacent Pixel Correlation

| Direction | Original | Encrypted |
|---|---:|---:|
| Horizontal | 0.847203 | 0.009830 |
| Vertical | 0.758922 | 0.020345 |
| Diagonal | 0.717050 | -0.020124 |

The encrypted image shows near-zero adjacent-pixel correlation compared with the original image.

### Histogram Comparison

| Original Histogram | Encrypted Histogram |
|---|---|
| ![Original Histogram](results/images/hist_original.png) | ![Encrypted Histogram](results/images/hist_encrypted.png) |

### Plaintext and Ciphertext Pixel Difference

```text
Changed pixels : 4081 / 4096
Percentage     : 99.63%
```

This value represents the percentage of ciphertext pixels that differ from the corresponding plaintext pixels.

It is not reported as NPCR because conventional NPCR analysis requires two plaintext images differing by a controlled pixel change and comparison of their resulting ciphertext images.

## Verification Flow

```text
S-Box
  |
  v
AES transformations
  |
  v
AES round
  |
  v
AES-128 core
  |
  v
AES-128 CTR
  |
  v
NIST verification
  |
  v
BRAM integration
  |
  v
Full encryption/decryption test
  |
  v
Counter optimization
  |
  v
Equivalence verification
  |
  v
Real-image encryption
  |
  v
Timing analysis
  |
  v
Power analysis
  |
  v
Image statistical analysis
```

## Final Results

| Metric | Result |
|---|---|
| Algorithm | AES-128 CTR |
| NIST Verification | PASS |
| Real-Image Verification | PASS |
| Image Resolution | 64 x 64 |
| Image Size | 4096 bytes |
| AES Blocks | 256 |
| Recovered Bytes | 4096 / 4096 |
| Recovery Mismatches | 0 |
| Baseline LUTs | 1723 |
| Baseline Flip-Flops | 1580 |
| BRAM36 | 3 |
| DSP | 0 |
| Latency at 100 MHz | 2.60 us per 64 bytes |
| Throughput at 100 MHz | 196.92 Mbps |
| Highest Verified Post-Route Frequency | 185.185 MHz |
| Latency at 185.185 MHz | approximately 1.404 us per 64 bytes |
| Throughput at 185.185 MHz | approximately 364.7 Mbps |
| Estimated Power at 100 MHz | 77 mW |
| Encrypted Image Entropy | 7.960175 bits/pixel |
| Real-Image Recovery | Exact |

## Running the Project

### RTL sources

Add the Verilog files from:

```text
rtl/
```

to Vivado Design Sources.

Set:

```text
image_aes_bram_encdec_top
```

as the design top.

### Simulation

Use the relevant testbench depending on the experiment.

NIST verification:

```text
tb_aes128_ctr_opt_nist.v
```

Original and optimized CTR comparison:

```text
tb_aes128_ctr_equivalence.v
```

Full BRAM encryption/decryption:

```text
image_aes_bram_encdec_tb.v
```

Real-image test:

```text
image_aes_real_image_tb.v
```

### Clock constraint

The constraint file is located in:

```text
constraints/aes128_fpga.xdc
```

For the 100 MHz baseline:

```tcl
create_clock -period 10.000 [get_ports clk]
```

For the high-frequency experiment:

```tcl
create_clock -period 5.400 [get_ports clk]
```

### Image preparation

Run:

```bash
python prepare_image.py
```

The script converts the selected image to a 64 x 64 grayscale image and creates:

```text
image_input.hex
```

### Image reconstruction

After the Vivado simulation creates the encrypted and recovered HEX files, run:

```bash
python reconstruct_images.py
```

This generates the original, encrypted, and recovered image files.

### Statistical analysis

Run:

```bash
python security_metrics.py
```

The script calculates entropy, adjacent-pixel correlation, recovery accuracy, and histogram data.

## Implementation Limitation

The current project is a board-independent Vivado implementation and simulation study.

No physical FPGA board was used.

Only the internal clock constraint is applied. Board-specific constraints such as the following are therefore not included:

```text
PACKAGE_PIN
IOSTANDARD
Input delay
Output delay
External interface timing
```

The reported value of 185.185 MHz should be interpreted as the highest experimentally verified post-route clock frequency under the current internal timing constraints.

It is not claimed as a hardware-validated FPGA board frequency.

A physical implementation would require the appropriate FPGA board, pin assignments, electrical standards, interface timing constraints, and hardware testing.

## Tools

- Verilog HDL
- AMD Vivado 2026.1
- XSim
- Xilinx Artix-7
- Python
- NumPy
- Pillow
- Matplotlib
- Git
- GitHub

## Future Work

Possible extensions include:

- FPGA board implementation and validation
- UART, SPI, or AXI communication interface
- Streaming image encryption
- Larger image support
- AES pipelining
- Multiple parallel AES cores
- Throughput-per-area optimization
- Hardware/software co-design
- Real-time video encryption
- Side-channel-resistant AES architectures

## License

This project is available under the MIT License.

See the `LICENSE` file for details.

## Author

Karan Kumar

B.Tech in Electronics and Communication Engineering  
Indian Institute of Information Technology Bhagalpur

Areas of interest: VLSI Design, FPGA, RTL Design, Digital Hardware, Hardware Security, ASIC and SoC Design
