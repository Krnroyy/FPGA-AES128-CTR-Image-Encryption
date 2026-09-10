# Hardware

## Final GCM-DMA architecture

`gcm_dma/rtl` contains the self-contained RTL used by the authenticated-encryption design.

| Module | Responsibility |
|---|---|
| `AES_GCM_AXIS` | AXI4-Lite control, 128-bit AXI4-Stream data path, CTR processing, GHASH sequencing and tag decision |
| `AES_GCM_OneBlock` | Standalone single-block GCM validation wrapper |
| `GHASH_Mult32` | GF(2^128) authentication multiplication implementation |
| `AES_128_Core` | AES-128 forward cipher |
| `KeyExpansion` | AES round-key generation |
| `SubBytes` | AES S-box substitution |
| `ShiftRows` | AES row permutation |
| `MixColumns` | AES finite-field column mixing |
| `AddRoundKey` | State and round-key XOR |

The Vivado block design adds Zynq UltraScale+ PS, AXI DMA, control and memory SmartConnect instances, reset logic and a 75.002 MHz PL clock. The GCM register block is mapped at `0xA0000000`; AXI DMA control is mapped at `0xA0010000`.

Use the test scripts under `gcm_dma/sim` before running the implementation scripts under `gcm_dma/scripts`.

Note: `gcm_dma` remains the original baseline AES-GCM DMA architecture.

## Protected-chunk BRAM architecture

`gcm_protected_chunk/rtl` contains the protected-chunk AES-GCM design with on-chip ciphertext buffer locking.

| Module | Responsibility |
|---|---|
| `ProtectedChunkBuffer_AXIS.v` | AXI4-Stream interface, chunk locking controller, 2-pass replay control, and zeroization logic |
| `ProtectedChunkMemory_BRAM.v` | Synchronous simple-dual-port BRAM primitive storing up to 4096 bytes of chunk ciphertext |

The BRAM implementation refactors protected ciphertext storage to enable block-RAM inference, utilizing **86 LUTs** and **2 RAMB36 blocks** (compared to 58,392 LUTs in the pre-optimization baseline).

Use the validation script `hardware/gcm_protected_chunk/sim/run_protected_chunk_validation_2026_1.tcl` before executing the build scripts under `hardware/gcm_protected_chunk/scripts/`.

## Historical baseline

The top-level `rtl` and `scripts` directories retain the earlier AXI4-Lite AES-CTR design as a development baseline. The final measured comparison uses the separate AXI-DMA CTR evidence under `results/ctr_dma_run1`.