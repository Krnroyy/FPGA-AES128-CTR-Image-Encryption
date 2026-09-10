# AES-GCM protected-chunk milestone

The protected-chunk milestone removes the external-memory time-of-check/time-of-use assumption from the two-pass AES-GCM release path. Each CHK3 transaction is captured once into a 4096-byte on-chip buffer. Capture then locks; the same bytes are replayed for authentication-only mode and, only after a valid tag, replayed again for decryption and plaintext release.

## Security behavior

1. The host sends a 32-byte canonical CHK3 header and RGB888 chunk payload (`host/gcm/protected_chunk/chk3_protocol.py`).
2. The firmware (`software/vitis_gcm/protected_chunk/main_gcm_dma_protected_chunk.c`, `software/vitis_gcm/protected_chunk/platform.h`) captures the chunk and checks the locked-buffer state.
3. Authentication-only GCM runs with S2MM unarmed, so no plaintext destination exists while the tag is checked.
4. A valid tag permits a second replay and plaintext DMA release.
5. Modified ciphertext or AAD is rejected before decryption; rejected data and the protected buffer are zeroized.
6. A fresh session nonce and monotonically ordered chunk index provide unique per-chunk IVs within the volatile session.

## Board evidence

The physical ZCU104 runs passed at all three tested sizes:

| Size | Chunks | Recovery | Tamper rejection | Overall |
|---|---:|---|---|---|
| 17×19 | 1 | PASS | PASS | PASS |
| 256×256 | 48 | PASS | PASS | PASS |
| 512×512 | 192 | PASS | PASS | PASS |

The 512×512 run accepted all 192 chunks and ended with `ZCU104_AES_GCM_PROTECTED_CHUNK_DONE ACCEPTED 192`.

## Reproduction

Run the RTL validation script under `hardware/gcm_protected_chunk/sim/`, build the ZCU104 project with the three scripts under `hardware/gcm_protected_chunk/scripts/`, then build the Vitis application from the exported XSA (`software/vitis_gcm/protected_chunk/`). Start the host script before launching the application:

```powershell
py host/gcm/protected_chunk/test_chunk_protocol_offline.py
py host/gcm/protected_chunk/run_gcm_protected_chunk.py `
  "C:/path/to/dataset/image.png" COM11 `
  --size 256x256 --sequence 101 --output protected_chunk_256_run1
```

## BRAM optimization validation

The protected ciphertext storage was refactored from the LUT-based pre-optimization baseline into a synchronous simple-dual-port memory (`ProtectedChunkMemory_BRAM.v`) to enable block-RAM inference.

| Metric | LUT baseline | BRAM optimized |
|---|---:|---:|
| Protected memory LUTs | 58,392 | 86 |
| RAMB36 | 0 | 2 |
| RAMB18 | 0 | 0 |
| WNS | +0.313 ns | +0.975 ns |
| WHS | +0.013 ns | +0.002 ns |
| Total power | 4.000 W | 3.602 W |
| Dynamic power | 3.305 W | 2.909 W |
| Static power | 0.696 W | 0.693 W |

The optimized bitstream passed physical ZCU104 validation for:

- 17x19 image: 1/1 chunk PASS
- 256x256 image: 48/48 chunks PASS
- 512x512 image: 192/192 chunks PASS

Ciphertext tampering and AAD tampering were rejected before plaintext release, and rejected buffers were zeroized.

## Resource and scope notes

The routed report met timing at 75.002 MHz, with WNS +0.975 ns and WHS +0.002 ns. Power values are vectorless Vivado estimates with medium confidence, not physical board rail measurements.

The prototype uses a demonstration AES key, volatile session freshness state, RGB888 input only, and a 4096-byte chunk limit. It does not claim resistance to side-channel or fault-injection attacks and is not a clinical product.