# Paper Experiment Roadmap

The implemented system is a strong engineering prototype. The remaining work is primarily experimental depth, threat-model coverage and comparison—not another complete architecture rewrite.

## Completed evidence

- NIST/reference RTL validation for AES and GCM building blocks
- 128-bit AXI4-Stream AES-GCM integrated with AXI DMA and PS DDR
- Physical ZCU104 implementation meeting 75.002 MHz timing
- Exact FPGA ciphertext and tag agreement with Python AESGCM
- Dynamic host-supplied image operation
- Multi-image batch testing with fresh 96-bit IVs
- Exact authenticated recovery and one-bit tamper rejection
- CTR-DMA versus GCM-DMA latency, throughput, utilization and estimated-power comparison
- Entropy, spatial-correlation, histogram and IV-sensitivity measurements

## Minimum work for a credible paper submission

### 1. Dataset expansion

- Select a public, citable and redistributable medical-image dataset.
- Use at least 50–100 images covering different modalities or image characteristics.
- Record original format, preprocessing, resize method and RGB conversion.
- Keep patient-identifying information out of the repository.

### 2. Repeated measurements

- Run at least three independent board passes per image.
- Use fresh, recorded IVs for every transaction.
- Store raw 100 MHz counter ticks instead of only rounded microseconds.
- Report mean, standard deviation, minimum, maximum and 95% confidence intervals.

### 3. Comparable baselines

Measure the same payload and timing boundary for:

1. ARM Cortex-A53 software AES-GCM;
2. FPGA AES-CTR with AXI DMA;
3. FPGA AES-GCM with AXI DMA;
4. optionally, the earlier AXI4-Lite accelerator.

State clearly whether timing includes cache maintenance, DMA setup, tag calculation and tag verification.

### 4. Power and energy

- Capture physical board-rail power if laboratory equipment is available.
- Otherwise keep Vivado power explicitly labelled as vectorless estimated power.
- Report energy per image and energy per byte using the same measurement boundary.

### 5. Authentication coverage

Add and test AAD for dimensions and metadata, ciphertext changes at multiple positions, tag changes, IV changes, wrong-key decryption, malformed packets and replay/IV reuse.

### 6. Hardened release policy

Improve the design so unauthenticated plaintext is held in on-chip quarantine memory or a protected destination until tag verification. Compare its resource cost with the current DDR-buffer-and-zeroize policy.

## Recommended paper contribution statement

“A reproducible ZCU104 hardware/software architecture for DMA-streamed AES-128-GCM image protection, evaluated through independent software-reference agreement, authenticated tamper rejection and quantified performance/resource trade-offs against an AES-CTR DMA baseline.”

## Suggested paper structure

1. Introduction and motivation
2. Related authenticated-encryption accelerators
3. Threat model and security requirements
4. ZCU104 hardware/software architecture
5. AES-GCM RTL and AXI DMA integration
6. Experimental methodology
7. Functional, performance, resource and security results
8. Limitations and future hardening
9. Conclusion

## Publication gate

Do not submit until the repository contains the dataset citation, repeated-run raw data, software baseline, timing-boundary definition and a clear security model. The current 10-image run is valid pilot evidence but is too small to be the only dataset experiment in the final paper.
