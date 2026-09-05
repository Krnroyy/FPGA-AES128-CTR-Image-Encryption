# Viva and Interview Guide

## 30-second explanation

This project implements hardware-accelerated AES-128 CTR image encryption and decryption on a ZCU104. A bare-metal application on the ARM Cortex-A53 divides a 256 × 256 RGB image into 12,288 blocks and controls a custom Verilog AES accelerator over AXI4-Lite. The FPGA encrypts the counter and XORs the keystream with each input block. The same hardware decrypts the ciphertext. The board returns both images through PS UART, and a Python program reconstructs them and verifies exact byte-for-byte recovery.

## Why CTR mode?

CTR mode converts AES into a keystream generator. Encryption and decryption use the same forward AES core, so inverse AES modules are unnecessary. Blocks are independent when their counter values are different, making CTR suitable for future streaming and parallel implementations.

## Module explanation

- `AES_CTR_AXI_LITE`: processor-facing register interface, control/status, counter increment, and XOR.
- `AES_128_Core`: ten-round pipelined forward AES implementation.
- `KeyExpansion`: expands one 128-bit key into eleven round keys.
- `SubBytes`: sixteen parallel nonlinear S-box substitutions.
- `ShiftRows`: fixed byte permutation across AES rows.
- `MixColumns`: finite-field mixing for diffusion in rounds 1–9.
- `AddRoundKey`: XOR between the state and a round key.
- `main.c`: buffer management, register access, timing, recovery check, and UART framing.
- `receive_full_image.py`: binary reception, PNG creation, SHA-256, and host verification.

## Questions to expect

### Why use a ZCU104?

It combines ARM processors and FPGA logic in one device. Software handles orchestration and communication while programmable logic accelerates the cryptographic datapath.

### Why are encryption and decryption times almost equal?

CTR uses `data XOR AES(counter)` for both operations, so both passes perform the same work.

### How do you know AES ran in programmable logic?

The application accesses the custom accelerator at `0xA0000000`, waits for its hardware `DONE` flag, and reads its output registers. The implemented accelerator occupies 10,244 LUTs and 2,227 flip-flops in the Vivado hierarchy.

### Why are BRAM and DSP utilization zero?

The complete image resides in processor memory. The PL holds only one block and uses S-box, permutation, and XOR logic rather than DSP arithmetic.

### Why is throughput lower than the theoretical AES pipeline rate?

Each 16-byte block requires several AXI4-Lite writes, status reads, and output reads. Processor-controlled register traffic and polling dominate the measured time. AXI DMA and AXI4-Stream are the next performance upgrades.

### What does positive WNS mean?

The worst setup path arrives 0.342 ns before its deadline, so the implemented design meets the 75.002 MHz timing constraint.

### What are the security limitations?

CTR does not authenticate ciphertext. A fixed counter may only be used for a repeatable demonstration and must not be reused with the same key in deployment. A production design should use AES-GCM or a verified MAC, unique nonces, and secure key storage.

### Is this a complete medical-image system?

It is an image-security hardware/software proof of concept. The current test operates on RGB pixels and does not yet parse DICOM files or handle clinical metadata.

## Be precise about the claim

Say: “I implemented, integrated, and verified a ZCU104 AES-128 CTR image-encryption prototype.”

Do not claim that the current measured design includes AES-GCM, GHASH, DMA, dynamic image upload, or clinical DICOM support. Those are planned improvements or belonged to earlier experimental code.

