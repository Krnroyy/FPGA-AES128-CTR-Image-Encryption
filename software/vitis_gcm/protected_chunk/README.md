# Vitis AES-GCM Protected-Chunk Firmware

This directory contains the Cortex-A53 bare-metal firmware application for the AES-GCM protected-chunk co-design milestone.

## Application Structure

- `main_gcm_dma_protected_chunk.c`: Core Cortex-A53 application managing UART communication, CHK3 32-byte header parsing, AXI DMA transfers, authentication tag verification, and protected buffer release.
- `platform.h`: Platform setup and cleanup declarations for standalone ARM Cortex-A53 (`psu_cortexa53_0`).

## Protected-Chunk Execution Flow

1. **Header Parsing & Buffer Locking**: Software parses the 32-byte CHK3 header received via UART, verifies chunk ordering and session freshness, configures AXI4-Lite registers, and loads the chunk into the hardware buffer (`ProtectedChunkMemory_BRAM.v`), which locks upon completion.
2. **Pass 1 (Authentication-Only)**: The hardware streams the locked chunk through the AES-GCM engine for authentication tag calculation while the AXI DMA S2MM channel remains disarmed. Plaintext cannot reach DDR memory during Pass 1.
3. **Pass 2 (Plaintext Release)**: Software checks the 128-bit authentication tag against expected tag.
   - If the tag is **valid**, software arms the AXI DMA S2MM channel and triggers a second hardware replay pass to decrypt and release plaintext into DDR memory.
   - If the tag is **invalid**, decryption is aborted and the hardware protected buffer and software staging memory are zeroized immediately.

## Vitis Build Requirements

1. Open Vitis Unified IDE 2026.1.
2. Create a Platform Component from the exported XSA (`hardware/gcm_protected_chunk`) targeting `psu_cortexa53_0` with standalone OS.
3. Create an Empty Application Component referencing the platform.
4. Add `main_gcm_dma_protected_chunk.c` and `platform.h` to the application source directory.
5. Build the application (`Build Finished successfully`).