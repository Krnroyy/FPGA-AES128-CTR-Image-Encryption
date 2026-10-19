# Matched original Stage 1 comparison

This is a benchmark of the ORIGINAL trusted-firmware design, to compare against
your saved optimized Stage 2 result. It does not modify Stage 2 RTL or applications.
No new bitstream is needed if the original BRAM-baseline bitstream/XSA are intact.

## 1. Record the working setup

Extract into C:\PCF\stage1_comparison and run in PowerShell:

```powershell
cd C:\PCF\stage1_comparison
powershell -NoProfile -ExecutionPolicy Bypass -File .\Record-Inputs.ps1
```

This reads and hashes the expected original/Stage 2 files and copies the Stage 2
source, UserConfig.cmake, and build log into a new provenance_* folder. Existing
files are not changed. Check that stage1_xsa exists. If the original XSA is missing,
return inputs.json before choosing another hardware package.

The original BRAM-baseline XSA is:

    C:\PCF\bram_baseline_20261018_200837\scripts\zcu104_gcm_protected_chunk.xsa

The corresponding Stage 1 platform used earlier was receiver_platform under
C:\PCF\receiver_stage1. Confirm that its hardware specification refers to the
original BRAM-baseline XSA above. Do not use the separate hardware/scripts LUT
baseline or a Stage 2 XSA for this comparison.

## 2. Build the application against the original platform

In Vitis create an empty application named stage1_compare_app using the original
receiver_platform, standalone psu_cortexa53_0. If the platform is not listed, import
the existing component C:\PCF\receiver_stage1\receiver_platform. Verify its XSA
reference before building. Keep receiver_stage2_platform and its applications.

Add software\main_stage1_compare.c, software\sweep_vectors.h, software\platform.h.
Remove any example main.c. Ensure the C source appears exactly once in
src\UserConfig.cmake. Set optimization to -O2 and retain -g3. The supplied Set-O2.ps1
performs that one configuration change, with a backup, for the default app location:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Set-O2.ps1
```

If Vitis created the app elsewhere, pass its actual file as -ConfigPath.
Build and retain the complete compiler flags/build output. Both comparisons require
-O2; the UART's optimization boolean alone does not establish the exact level.

## 3. One original-hardware benchmark run

Stop the previous debug session and close other COM6 terminals. Start:

```powershell
cd C:\PCF\stage1_comparison
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\run_stage1_compare.py --self-test
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\run_stage1_compare.py --port COM6
```

After "Port open", launch stage1_compare_app using ORIGINAL STAGE 1 hardware and
normal PS initialization. Ensure the launch configuration programs the ORIGINAL
BRAM-baseline bitstream, not the currently loaded Stage 2 bitstream. Simply loading
the ELF while Stage 2 hardware remains programmed will fail the identity check.

The application reads reserved register 0x68. Stage 1 returns zero; Stage 2's 0x5247
signature is rejected. Zero is NOT a unique hardware identity; the XSA/bitstream
record and launch configuration must establish which original image is programmed.

Expected ending:

    PERF_SAMPLES_PASSED 217 EXPECTED 217
    BASELINE_OVERALL PASS
    BASELINE MONITOR OVERALL: PASS

No 640-case sweep runs here: Stage 1 deliberately lacks the hardware interlock.
This benchmark performs only valid two-pass transactions, three warmups then 31
retained samples at each of seven sizes. Every transaction verifies authentication,
plaintext, and destination sentinels. No image input or UART transmission is needed.

## 4. Generate the comparison

Substitute the new run folder printed by the recorder:

```powershell
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\compare_results.py .\stage1_compare_run_YYYYMMDD_HHMMSS_microseconds
```

The result is stage1_vs_stage2.csv in that run folder. Return it, summary.json,
uart_transcript.txt, samples.csv, statistics.csv, inputs.json, and build output.
The bundled reference_stage2 files are copies of your saved optimized run
combined_run_20261019_101939_994887, not newly generated measurements.

When returning to Stage 2 work, launch the existing Stage 2 application/platform
and program its Stage 2 bitstream. Do not replace the Stage 2 platform with Stage 1.

## What this comparison means

Fixtures, payload sizes, cache operations, full-workspace cleanup, timestamps,
validation boundaries, and CPU counter handling match the Stage 2 benchmark.
The Stage 1 application faithfully follows its original release procedure:
firmware first verifies authentication, then configures MODE_DECRYPT/key/IV/AAD/tag
again before replaying the SAME captured ciphertext. Stage 2 uses a hardware grant
and a release command instead. No debug UART printing occurs inside timed regions.

The measured difference is the NET architectural/software processing difference.
It includes Stage 1's extra release configuration and Stage 2's guard status reads,
as well as physical implementation effects. It does not isolate the combinational
latency or timing impact of inserting just the RTL guard. Keep clock settings,
CPU/BSP initialization, cache configuration, and -O2 flags comparable.

Capture/auth/release rates exclude cleanup/validation; total includes both. Source
preparation and DMA reset remain outside the total interval. Cleanup clears all
4096+4160 bytes, regardless of payload size, as in the Stage 2 test. These are
isolated CPU-observed latencies, not sustained UART/image or pure crypto throughput.

Do not claim that Stage 1 provides hardware-enforced authentication-before-release.
It depends on trusted firmware. Functional baseline timing measurements do not
provide evidence that unauthorized register accesses are blocked on Stage 1.

## Offline checks and pending work

The app shares fixture bytes and driver helpers with the tested Stage 2 benchmark;
its release sequence was checked against the actual Stage 1 receiver source.
C syntax checks with mock BSP declarations passed for SDT/non-SDT at -O2.
The monitor parser passed positive/missing/duplicate/wrong-image/bad-timing checks.
Your real Vitis build, original-bitstream identity, and physical baseline run are
still pending. If a test fails, preserve the transcript before changing the code.
