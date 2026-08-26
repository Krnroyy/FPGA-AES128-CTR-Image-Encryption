# FPGA-Based AES-128 CTR Image Encryption and Decryption

An FPGA-oriented hardware implementation of AES-128 in Counter (CTR) mode for grayscale image encryption and decryption, developed in Verilog and implemented using AMD Vivado.

The project includes NIST-standard cryptographic verification, BRAM-based image storage, real-image encryption/decryption, post-route timing analysis, SAIF-based power estimation, and RTL critical-path optimization.

---

## Project Overview

The system encrypts and decrypts image data using AES-128 CTR mode.

In CTR mode:

```text
Ciphertext = Plaintext XOR AES(Key, Counter)
Plaintext  = Ciphertext XOR AES(Key, Counter)