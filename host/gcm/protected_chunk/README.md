# Host Protected-Chunk Python Tools

This directory contains the host-side Python software for the AES-GCM protected-chunk milestone.

## Requirements and Dependencies

Python 3.10+ is required with dependencies specified in `requirements.txt`:

```text
cryptography>=42.0
Pillow>=10.0
pyserial>=3.5
```

Install dependencies using:

```powershell
py -m pip install -r host/gcm/protected_chunk/requirements.txt
```

## Protocol Architecture

The CHK3 protocol splits image payloads into canonical chunks (maximum 4096 bytes per chunk).

- **CHK3 Framing**: Each transaction starts with a 32-byte canonical header (`chk3_protocol.py`), followed by the chunk payload. The 16-byte AAD is derived from the header metadata.
- **Maximum Chunk Size**: 4096 bytes.
- **Authenticate-then-Release (2-Pass Flow)**:
  - **Pass 1**: The chunk ciphertext is transferred and locked in the on-chip BRAM buffer (`ProtectedChunkMemory_BRAM.v`). Authentication-only GCM runs while the output DMA is unarmed, preventing unauthenticated plaintext release to DDR memory.
  - **Pass 2**: If the 128-bit authentication tag matches, the locked buffer is replayed for decryption and plaintext release over AXI DMA. If authentication fails, the protected buffer is zeroized immediately.

## Offline Protocol Test

Verify framing, ordering, AAD construction, unique IV generation, and tamper-rejection logic offline:

```powershell
py host/gcm/protected_chunk/test_chunk_protocol_offline.py
```

Expected output ends with:

```text
PASS: CHK3 PROTOCOL OFFLINE MILESTONE
```

## Board Verification Command

Run the protected-chunk host client against the ZCU104 hardware running `main_gcm_dma_protected_chunk.c`:

```powershell
py host/gcm/protected_chunk/run_gcm_protected_chunk.py "C:/path/to/image.png" COM11 --size 256x256 --sequence 101 --output protected_chunk_256_run1
```

Expected result:

```text
OVERALL: PASS
```