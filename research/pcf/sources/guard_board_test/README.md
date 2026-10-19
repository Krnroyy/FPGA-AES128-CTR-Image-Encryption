# Stage 2 direct release-guard board tests

This package adds a separate Vitis application. Keep receiver_stage2_app unchanged.
Use the EXISTING receiver_stage2_platform built from:

    C:\PCF\release_guard_stage2\scripts\zcu104_gcm_release_guard_stage2.xsa

No RTL changes, new Vivado project, bitstream rebuild, or new platform are needed.

## 1. Extract and build

Extract this ZIP into C:\PCF\guard_board_test, with README.md directly inside that folder.
In your current Vitis workspace, create an empty standalone application named
guard_board_test_app using receiver_stage2_platform and psu_cortexa53_0.
Add software\main_guard_board_test.c and software\platform.h to this application.
Remove any generated example main.c so the application contains exactly one main.
Check src\UserConfig.cmake lists main_guard_board_test.c exactly once. Build.

## 2. Start the UART evidence recorder

Close other COM6 terminals and stop the previous debug session. In PowerShell:

```powershell
cd C:\PCF\guard_board_test
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\monitor_guard_tests.py --self-test
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\monitor_guard_tests.py --port COM6
```

When it says "Port open", launch guard_board_test_app in Vitis using the Stage 2
bitstream and normal PS initialization. This program needs no image or UART input.
The recorder listens for up to 120 seconds, including time to launch the app.
If COM6 is missing, reconnect the board UART and list ports before retrying.

Expected final results:

    GUARD_BOARD_TESTS_PASSED 26 EXPECTED 26
    GUARD_BOARD_OVERALL PASS
    MONITOR OVERALL: PASS

Keep summary.json and uart_transcript.txt from the new guard_board_run_* folder.
If a test fails, return the complete transcript and build output before modifying code.

## What is checked

Two positive controls release the exact 21-byte plaintext. The other 24 checks
attempt release before authentication, repeated release, encryption/decryption mode
bypasses, changes to each of 17 configuration registers after authentication,
release after soft reset, release after recapture, and release after a bad tag.
Each negative check arms S2MM, checks the monitored 64-byte destination remains
0xA5, checks no DMA completion/error, checks the grant is revoked, and checks the
protected buffer reports idle and scrubbed. Configuration tests also check the
attempted write did not change the register value.

The fixed public test vector uses an all-zero AES-128 key and IV. These are test
inputs, not a production key/nonce policy. The receiver's normal key is untouched
in its source; relaunch receiver_stage2_app to restore its own configuration.

Evidence scope: software-observed status and a 64-byte DDR probe, not an independent
monitor of every DDR write. These tests do not establish full-system security,
key isolation, resistance to physical attacks, or reset-persistent replay prevention.
They are functional checks, not performance measurements.

## Validation before delivery

The C source passed syntax checks with mock BSP declarations for SDT and non-SDT.
The vector was checked independently with Python AESGCM. The UART monitor passed
seven parser cases. Compilation against your actual Vitis BSP and these 26 physical
board checks are still pending. Earlier Stage 2 receiver testing passed 11 cases;
that is separate evidence from this new application.
