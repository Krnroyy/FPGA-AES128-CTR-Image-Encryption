# PCF stage 2: receiver-only RTL release interlock

This is an isolated experiment based ONLY on the PCF project in this chat.
Your stage-1 receiver passed its physical ZCU104 suite. Its uploaded firmware,
summary and transcript are preserved unchanged in baseline_stage1/. Do not
replace that working application or its Vivado project with these files.

## First action: Vivado simulation only

Extract the contents of this ZIP directly to C:/PCF/release_guard_stage2.
In Vivado 2026.1 Tcl Console run:

```tcl
source {C:/PCF/release_guard_stage2/scripts/00_run_security_sim.tcl}
```

This closes the current project and creates disposable RTL simulation projects
inside the NEW folder. Save any unrelated unsaved GUI edits before running.
It does not synthesize or program the FPGA. Require:

PASS: PROTECTED CHUNK BUFFER RTL MILESTONE
PASS: RTL RELEASE INTERLOCK MILESTONE
PASS: STAGE2 SECURITY SIMULATIONS VERIFIED

Return the Tcl transcript. Do not build hardware if either test fails. The
script verifies the simulator log rather than printing expected PASS lines as
proof. Successful validation records source CRCs; later source changes require
rerunning simulation. CRCs are change detection, not security hashes.

## What changed

AES_GCM_AXIS now implements receiver-only authenticated release. Software
cannot stream payloads in encrypt mode or directly select decrypt mode. A
successful auth-only pass grants permission for one release operation, bound
to the continuously locked buffer and unchanged key/IV/tag/AAD configuration.

New hardwired sidebands:
- buffer -> GCM: protected_locked and protected_bytes;
- GCM -> buffer: security_abort.

The project creation script connects these signals directly. Do not tie them
to constants, expose them as software-controlled values, or connect the GCM
input stream to another source. The data path is still DMA -> protected buffer
-> GCM -> DMA. Buffer validity includes complete capture and no length errors.

Hardware phases: IDLE -> AUTH -> AUTHORIZED -> RELEASE -> SPENT.
- A successful auth-only tag check AND matching captured byte count grants
  authorization. A failure goes to SPENT.
- CONTROL=0x11 consumes authorization and starts decryption with the existing
  locked configuration. No soft reset or register reload occurs between passes.
- Key/IV/expected-tag/AAD/mode configuration writes during an active transaction
  are blocked and revoke authorization. The fault is sticky in the guard status.
- Invalid release/setup requests revoke authorization and initiate scrubbing.
- Soft reset during an active transaction cancels it and scrubs the buffer.
- Loss of the locked window invalidates the crypto pipeline and permission.
- A completed release consumes the grant; a second release is denied.
- Normal authorized backpressure holds TVALID/data/keep/last stable.
- Explicit reset/security abort cancels the stream; a pending beat can be
  withdrawn. The receiver must treat that DMA transaction as aborted and reset
  its DMA channel before retry. This is not transparent resumption mid-packet.

## Register interface

Existing register addresses stay the same. New read-only REG_GUARD at 0x68:

| Bits | Meaning |
| --- | --- |
| 31:16 | Signature 0x5247 |
| 0 | Protected buffer locked and valid |
| 1 | Authentication active |
| 2 | One-use release grant available |
| 3 | Release active |
| 4 | Spent/failed transaction |
| 8 | Sticky denied operation; cleared by soft reset or hardware reset |

CONTROL bit 4 is the release request and must be used with bit 0 ENABLE,
without LOAD_IV/CLEAR_DONE/RESET. Other CONTROL bits retain their meanings.
MODE accepts AUTH_ONLY (2). Direct ENCRYPT (0) or DECRYPT (1) writes are denied.
The firmware tests the guard signature and grant before requesting release.

## After simulation review: create and build NEW hardware

```tcl
source {C:/PCF/release_guard_stage2/scripts/01_create_protected_chunk_project_2026_1.tcl}
source {C:/PCF/release_guard_stage2/scripts/02_build_protected_chunk_bitstream_2026_1.tcl}
source {C:/PCF/release_guard_stage2/scripts/03_generate_protected_chunk_reports_2026_1.tcl}
```

The new project is zcu104_gcm_release_guard_stage2. Synthesis/implementation,
bitstream and XSA are produced only in this package's scripts folder. The
build checks both setup and hold slack before XSA export. Compare utilization,
routing and timing to the preserved baseline; do not reuse the old numbers.

## After hardware review: separate Vitis application

Create a NEW platform/application from:
C:/PCF/release_guard_stage2/scripts/zcu104_gcm_release_guard_stage2.xsa
Use Cortex-A53 #0, standalone, 64-bit, matching the working setup.
Application sources are software/main_gcm_receiver.c and software/platform.h.
Only one main() should be compiled. Stage-1 firmware is NOT compatible with this
receiver-only RTL because its release path resets/reloads GCM configuration.
Stage-2 firmware expects the new hardware guard and fails if its signature or
grant is missing. Both SDT and non-SDT C branches passed host syntax checks;
actual Vitis build/link remains required.

Debug prints have been removed from stage-2 timed regions. This does NOT make
these timings directly comparable with the heavily instrumented stage-1 board
run. A clean stage-1 performance run with the same compiler settings and timing
boundary is required for a performance comparison.

## Functional board suite after the new firmware builds

Use the existing Python environment if desired:

```powershell
cd C:\PCF\release_guard_stage2
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\test_external_receiver.py --self-test
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\test_external_receiver.py --port COM6
```

COM6 was confirmed for this project's board in this chat; recheck if Windows
changes it. Close serial terminals. After Port open, program the MATCHING stage-2
bitstream, initialize the PS and launch the NEW stage-2 application in Vitis.
The host expects PCF_EXTERNAL_RECEIVER_STAGE2. Require all 11 cases and
BOARD OVERALL: PASS. Reset/relaunch before each run to clear volatile freshness.
The host saves summary.json and uart_transcript.txt in a timestamped folder.

## Validation performed here

- Icarus Verilog 12.0: protected-buffer unit test PASS.
- Icarus Verilog 12.0: interlock integration suite PASS, including direct release
  denial, encrypt/decrypt bypass attempts, all 17 configuration-register writes,
  configuration violations during authentication and stalled release, hardware
  reset, soft reset, scrub/recapture, valid authenticated release, output
  backpressure, repeat release denial, tampered ciphertext, and failure scrub.
- The integration monitor checks that output TVALID is never asserted without
  a locked buffer and RELEASE phase. These are simulation checks, not a formal
  proof or exhaustive verification.
- Matching Python fixture suite: 11 cases PASS offline.
- Matching C firmware: SDT and non-SDT syntax checks PASS using mocked BSP headers.
- Logs are in validation/. No Vivado synthesis, XSim, Vitis build or physical
  stage-2 board execution has been performed here.

## Scope and limitations

This protects release sequencing under the fixed trusted hardware wiring and
configured key. It does not make an untrusted Cortex-A53 safe: privileged
software can read key registers and access system memory. Key confidentiality,
secure boot, malicious bitstream replacement, physical fault injection and
side-channel resistance are outside this experiment. Key registers are not
zeroized by a soft reset; memory scrubbing must not be described as secure key
removal. The supplied AES key is public demonstration data.

Replay protection is still volatile software session state. This suite uses
one 969-byte chunk; whole-image atomic release, persistent replay prevention,
large-payload performance and repeated board trials are not yet validated.
The firmware still uses blocking UART receive; a truncated body needs a
reset/relaunch. Hardware errors halt the application. Full timeout/abort
recovery and independent monitoring of DMA writes remain further work.
Power values require fresh analysis and appropriate activity assumptions.
