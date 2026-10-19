# Combined Stage 2 security sweep and benchmark

Use your working Stage 2 hardware:

    C:\PCF\release_guard_stage2\scripts\zcu104_gcm_release_guard_stage2.xsa

This package supplies one new application and one passive UART recorder. Existing
RTL, bitstream, receiver application, and earlier evidence remain unchanged.

## One build, one board run

1. Extract this ZIP into C:\PCF\combined_stage2. README.md should be directly there.
2. In the current Vitis workspace, create an empty standalone application named
   combined_stage2_app using receiver_stage2_platform and psu_cortexa53_0.
3. Add software\main_combined_stage2.c, software\sweep_vectors.h, and
   software\platform.h. Keep them together. Remove any generated example main.c.
   Ensure src\UserConfig.cmake lists main_combined_stage2.c exactly once.
4. Build. Keep the current compiler flags for this first run; save the build log.
   The application records whether optimization is enabled. It cannot identify
   the exact optimization level, so retain the build output showing the flags.
5. Stop the earlier debug session and close any other COM6 terminal.
6. Run the following PowerShell commands, then launch combined_stage2_app in Vitis
   after "Port open". Use the existing Stage 2 bitstream and normal PS initialization.

```powershell
cd C:\PCF\combined_stage2
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" validation\check_fixtures.py
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\run_combined_stage2.py --self-test
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\run_combined_stage2.py --port COM6
```

No image file or UART input is required. The recorder has a 300-second timeout,
including application launch time. Full UART output is saved even though the
console only shows sweep progress every 50 cases. If the board port has changed,
list ports using your existing venv and substitute the observed UART port.

Expected final markers:

```text
SWEEP_TESTS_PASSED 640 EXPECTED 640
PERF_SAMPLES_PASSED 217 EXPECTED 217
COMBINED_OVERALL PASS
COMBINED MONITOR OVERALL: PASS
```

Return summary.json, uart_transcript.txt, samples.csv, statistics.csv, and the Vitis
build output. These files are written into one combined_run_* folder. A failure
preserves partial evidence; send the transcript before changing the working RTL.

## Functional coverage

The manifest lists 64 lengths: all 1 through 33, boundaries around larger powers
of two, the prior 969-byte case, 4095/4096, and ten deterministic random lengths.
Every fixture has independently varied public plaintext, key, IV, and AAD. The
public generation seed is 20261019; fixtures.json preserves the exact reference
bytes. These are fixed test fixtures, not deployment key or nonce generation.

Each length has ten checks:

- Valid release with exact plaintext comparison.
- Ciphertext changed at the first, middle, and last byte (three checks).
- Tag, IV, AAD, and key changed (four checks).
- Ciphertext changed at a deterministic random position.
- Valid release after the rejection group.

Total: 128 valid controls and 512 rejection checks. Coincident corruption positions
for tiny packets are repeated cases, not distinct attack sites. Invalid cases
attempt a release after failed authentication. Register checks and a probe spanning
payload length plus 64 trailing bytes must indicate rejection, no DMA completion,
no released plaintext, and protected-buffer idle/scrub status. Valid cases compare
all recovered bytes and the unchanged trailing sentinel.

This is raw payload/crypto/DMA testing, separate from the RGB UART header parser.
It does not test every length, every possible corruption, arbitrary hostile bus
masters, mid-transfer reset/backpressure, zero/oversized packet framing, or all DDR
traffic. Earlier RTL simulations provide some different stress coverage. Passing
these tests does not establish a formal security proof or production readiness.

## Benchmark method

Seven sizes: 16, 64, 256, 512, 1024, 2048, 4096 bytes. Each has three discarded warmup
transactions and 31 recorded transactions, for 217 retained samples. Every measured
transaction checks authentication, exact recovery, and destination sentinels. No
UART printing occurs between its first and last timestamp. Printing occurs between
samples, so this is isolated transaction latency, not a sustained stream benchmark.

The ARM physical counter supplies timestamps; its frequency is read from the CPU.
It is not assumed to equal the 75 MHz PL clock. The counter reads use DSB/ISB
barriers. The minimum of 32 back-to-back read intervals is recorded as timer
metadata; no overhead subtraction is applied. Actual BSP compilation and hardware
measurement must validate this code on your board.

| Field | Included work |
| --- | --- |
| capture | Buffer control/polling, input cache flush, MM2S transfer, captured-length checks |
| auth | GCM configuration/key/IV/AAD/tag writes, key setup, auth-only buffer replay, completion polling, status/tag/count checks |
| release | Arm S2MM, request authorized release, buffer replay, DMA/crypto completion polling, status/tag/count checks |
| cleanup | Protected-buffer scrub plus CPU zeroization/cache flush of both entire workspaces: 4096 and 4160 bytes |
| validation | Gaps used for destination cache invalidation and plaintext/probe comparisons |
| total | Wall interval from capture start through cleanup end, including the validation gaps |

Fixture copying, soft reset, DMA reset, initial destination fill/cache flush, and
initialization occur before the measured interval and are excluded. No encryption
or UART transfer is included. The four phase durations plus validation equal total.

Statistics include per-phase minimum, p5, median, p95, maximum, and two separately
labelled throughput calculations. MB/s means decimal 1,000,000 bytes/s; the numerator
is one payload length, not double-counted for the two crypto passes:

- capture_auth_release_median_MBps excludes cleanup and validation gaps.
- total_including_cleanup_and_validation_median_MBps uses the complete timed interval.

These are CPU-observed orchestration timings, not pure AES/GHASH throughput. Software
polling, cache operations, the compiler flags, and fixed-size cleanup affect results.
Keep CPU/BSP configuration and build flags when comparing runs. p5/p95 show sample
spread, not confidence intervals. No speedup versus Stage 1 or power savings can
be inferred from this run alone. The old debug-print Stage 1 timings are unsuitable
as a comparative benchmark.

## Files and offline validation

software/ contains the app and reference vectors. host/ contains the UART recorder,
parser, statistics generation, and manifest. validation/ contains fixture references,
the independent AESGCM corruption checker, and validation status/source hashes.

Before delivery, the actual serialized C vector values were checked against the
reference JSON and Python AESGCM (64 valid plus 512 corrupted cases). C syntax was
checked using mock BSP declarations for both SDT/non-SDT. The recorder passed parser
and statistics checks, including missing/duplicate results, malformed timing sums,
negative-test DMA completion, and missing completion markers. These offline checks
do not substitute for your actual Vitis build or physical board run.

To regenerate statistics from a saved transcript without touching the board:

```powershell
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\run_combined_stage2.py --analyze "C:\path\uart_transcript.txt"
```
