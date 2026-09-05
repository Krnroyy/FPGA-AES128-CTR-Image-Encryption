# Measured Results

## Hardware demonstration

The ZCU104 processed a 256 × 256 RGB888 image containing 196,608 bytes or 12,288 AES blocks. Encryption and decryption both completed on the physical board, and the recovered buffer matched the original buffer byte-for-byte.

```text
ZCU104_AES_CTR_START
IMAGE 256 256 RGB888 196608
AES_BLOCKS 12288
ENCRYPTION_TIME_US 34766
ENCRYPTION_THROUGHPUT_KBPS 5655
DECRYPTION_TIME_US 34747
DECRYPTION_THROUGHPUT_KBPS 5658
RECOVERY_PASS
ZCU104_AES_CTR_DONE
Original == recovered: PASS
```

## Implementation

| Measurement | Result |
|---|---:|
| Clock | 75.002 MHz |
| Period | 13.333 ns |
| Worst slack | +0.342 ns |
| Total negative slack | 0 ns |
| Failing endpoints | 0 |
| Complete-system LUTs | 10,779 / 230,400 (4.68%) |
| Complete-system flip-flops | 2,866 / 460,800 (0.62%) |
| AES-accelerator LUTs | 10,244 |
| AES-accelerator flip-flops | 2,227 |
| BRAM / URAM / DSP | 0 / 0 / 0 |

The measured application throughput includes AXI4-Lite register writes, status polling, and register reads. It is not the theoretical one-block-per-cycle throughput of the internal AES pipeline.

## Power estimate

| Component | Estimate |
|---|---:|
| Total on-chip power | 3.872 W |
| Dynamic power | 3.177 W |
| Static power | 0.695 W |
| AES hierarchy dynamic power | approximately 0.491 W |

Vivado reported medium confidence because internal activity came from vectorless propagation. These values are implementation estimates and not physical board measurements.

## Image-security analysis

| Metric | Measured value |
|---|---:|
| Ciphertext combined entropy | 7.9991 bits/byte |
| Counter-change byte NPCR | 99.6262% |
| Counter-change UACI | 33.5052% |
| Counter-change bit-change rate | 49.9736% |
| Different RGB pixels | 65,536 / 65,536 |

The original and recovered images have zero differing bytes. Statistical image metrics describe the demonstrated ciphertext; standardized AES test vectors and correct nonce management remain the basis of cryptographic assurance.

