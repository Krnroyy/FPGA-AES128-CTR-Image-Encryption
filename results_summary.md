# Final Results

## Functional Verification
- NIST AES-128 CTR: PASS
- Optimized CTR equivalence: PASS
- Full BRAM encryption/decryption: PASS
- Real-image recovery: 4096/4096 bytes correct

## FPGA Utilization
- LUTs: 1723 baseline
- FFs: 1580 baseline
- BRAM36: 3
- DSPs: 0

## Performance
- Baseline clock: 100 MHz
- Highest verified post-route clock: 185.185 MHz
- Encryption latency: 260 cycles
- Throughput @100 MHz: 196.92 Mbps
- Throughput @185.185 MHz: ~364.7 Mbps

## Power
- SAIF-based total power @100 MHz: 77 mW

## Image Security Metrics
- Original entropy: 7.403565 bits/pixel
- Encrypted entropy: 7.960175 bits/pixel
- Horizontal correlation: 0.847203 → 0.009830
- Vertical correlation: 0.758922 → 0.020345
- Diagonal correlation: 0.717050 → -0.020124
- Original == Recovered: YES