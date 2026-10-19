# PCF cancellation candidate — committed authenticated packets

This is an isolated candidate for the C:\PCF AES-GCM release-guard project. It does not replace the existing Stage 2 baseline. All generated Vivado projects and exports stay inside this package.

## One next action

Extract this archive into a new folder `C:\PCF\cancel_fix`. The archive contains its files directly, so `Run-Candidate.ps1` should be directly inside that folder.

Save your current work and close idle Vivado/Vitis windows to make memory available. In PowerShell:

```powershell
cd C:\PCF\cancel_fix
powershell -NoProfile -ExecutionPolicy Bypass -File .\Run-Candidate.ps1
```

The launcher uses `C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat`. If needed, pass your actual launcher path with `-Vivado`. It checks source hashes, starts a separate Vivado batch process, runs four simulations, creates the candidate hardware project, builds the bitstream, checks setup/hold slack, exports the XSA, and generates reports. Failure stops the pipeline. It does not program the board or change a Vitis platform/application.

Expected completion marker:

```text
PASS: PCF CANDIDATE HARDWARE READY
```

The launcher then prints a `candidate_build_evidence.zip` path. Return that ZIP for review. It contains the build log, source hashes, and implementation reports. The candidate XSA will be `scripts\zcu104_gcm_cancel_candidate.xsa`; retain it for the subsequent Vitis platform update. Do not substitute the old Stage 2 XSA for this candidate.

For simulation alone, `Run-Verification.ps1` is provided, but it is not an additional required step when using the pipeline above. Do not source the simulation Tcl into your existing GUI project. The launcher handles the separate process.

## Why the behavior changes

The baseline dropped an offered output beat when software requested cancellation during a stall. The receiving AXI stream had not accepted that beat and had not been reset. Arm IHI 0051B section 2.2 requires valid data to remain offered until acceptance. The reproduced baseline violation and its tests are preserved separately in PCF-Controller-Timing-Review.zip.

This candidate defines the release command as the commitment point for an already authenticated packet:

- Before a valid release command is accepted, a reset or prohibited configuration/control operation still revokes the grant and blocks release.
- After the valid release command is accepted, the ciphertext and authentication context remain frozen until the packet's final output handshake. A late configuration, disable, soft-reset, repeated-release, or buffer-control request is denied/deferred; it cannot alter or truncate that authenticated packet.
- A deferred cancellation is recorded. Once the final beat is accepted, the buffer is scrubbed and the crypto datapath is reset. A later transaction cannot reuse the permission.
- A real shared hardware reset can still terminate the transfer. A stalled receiver can delay completion indefinitely; availability under permanent backpressure is not promised.

This is a deliberate security-contract refinement, not simply a relaxed checker. The pending output remains checked for exact data, byte mask, last flag, and stability. The previous claim that a software cancellation suppresses all output immediately during RELEASE does not apply to this candidate. Only the previously authenticated packet may finish; the cancellation grants no new release authority.

There is no one-beat truncation workaround: the entire committed packet finishes, preserving its final TLAST. Completion still requires firmware to issue the permitted first buffer replay and the downstream receiver eventually to accept data. If either never occurs, recovery requires the real shared reset and application/DMA recovery.

## RTL changes

`AES_GCM_AXIS.v` freezes all configuration/control effects in the RELEASE phase, records deferred cancellation, and scrubs after the last handshake. It exports `release_committed`, including the combinational acceptance of the release command, so a simultaneous buffer scrub cannot destroy the newly committed capture.

`ProtectedChunkBuffer_AXIS.v` protects capture metadata and payload while committed. It accepts exactly the first replay command for that release, reports other buffer writes through `release_cancel_request`, and blocks replacement capture traffic. Both new sidebands are connected in the included block-design creation script.

The existing register map remains, with:

- Guard register `0x68`, bit 9: cancellation pending while a committed packet drains. Bit 8 records denial.
- Read-only policy register `0x6C`: `0x00030001`, identifying this policy revision.
- New candidate project/export name: `zcu104_gcm_cancel_candidate`.

No application source change is included at this point. Normal authenticated receive/release follows the previous command sequence. The final hardware and firmware combination still needs board validation before it replaces the baseline.

## Completed local validation

Icarus Verilog 12.0 ran the actual AES/GHASH and protected-buffer RTL. All four suites passed; exact logs and tool version are in `validation/`:

| Suite | Scope |
|---|---|
| Protected buffer regression | Capture, immutable replay, malformed input, backpressure, and scrub |
| Release-interlock regression | Previous pre-commit security checks; the changed in-release case now requires exact packet completion followed by scrub |
| 16 timing scenarios | Nine pending-tag/write overlaps with three AXI-Lite channel orders; five final-beat reset/cancellation cases; simultaneous release/scrub; valid stalled release and one-use permission |
| 45 packet scenarios | Nine cancellation types at each of 1, 16, 17, 21, and 4096 bytes; strict output stability, exact plaintext, final-byte masks, deterministic varying backpressure, attempted capture overwrite, and checking all 256 scrubbed memory words |

The output stream stability checks reported zero violations. Fixtures for the packet suite were generated with Python cryptography AESGCM using a zero test key/IV, a fixed 16-byte AAD, and deterministic plaintext. These are public test vectors, not operational keys. Behavioral simulation clock timing is not a measured FPGA timing result.

Scope limits: directed simulation, not formal proof; no Vivado/XSim or new FPGA implementation results have been produced in this assistant environment. The included pipeline obtains those tool/build results on your computer. The AXI checker covers the external plaintext output; it is not a complete AXI-Lite/DMA/SoC protocol verification. The private buffer-to-crypto link still has abort semantics before release; no blanket standards-compliance claim is made for every internal signal. Trusted key provisioning and the previous threat-model limits remain.

To reproduce the local suite with Python and Icarus on PATH, run `python3 run_checks.py` (or `py run_checks.py` on Windows). This is optional when using Vivado.

Source reference: Arm AMBA AXI-Stream Protocol Specification IHI 0051B, section 2.2, https://documentation-service.arm.com/static/64819f1516f0f201aa6b963c .
