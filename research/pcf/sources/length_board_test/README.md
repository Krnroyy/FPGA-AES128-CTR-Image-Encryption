# Stage 2 payload-length board tests

Use the existing receiver_stage2_platform and Stage 2 bitstream. This package adds
one separate Vitis application; it does not change RTL or the existing receiver.

## Build

1. Extract into C:\PCF\length_board_test (README.md directly inside that folder).
2. In your current Vitis workspace, create an empty standalone application named
   length_board_test_app using receiver_stage2_platform and psu_cortexa53_0.
3. Add all three files in software: main_length_board_test.c, platform.h, and
   length_vectors.h. Keep these files together so the header can be found.
4. Remove any generated example main.c. List main_length_board_test.c exactly once
   in src\UserConfig.cmake. The two headers are not separate compilation units.
5. Build. Keep receiver_stage2_app and guard_board_test_app unchanged.

No new platform, Vivado project, XSA, or bitstream build is needed.

## Run

Stop the previous debug session and close any COM6 terminal. Start PowerShell:

```powershell
cd C:\PCF\length_board_test
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\monitor_length_tests.py --self-test
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\monitor_length_tests.py --port COM6
```

After "Port open", launch length_board_test_app in Vitis using your Stage 2
bitstream and normal PS initialization. No UART input or image file is needed.
The 120-second timeout includes time to launch the application.

Expected ending:

```text
LENGTH_BOARD_TESTS_PASSED 36 EXPECTED 36
LENGTH_BOARD_OVERALL PASS
MONITOR OVERALL: PASS
```

Return summary.json and uart_transcript.txt from the new length_board_run_* folder.
If a test fails, return the complete transcript before modifying the working RTL.

## Test matrix

Each of 1, 15, 16, 17, 4095, and 4096 bytes receives six checks:

- Valid authentication and exact plaintext recovery.
- First ciphertext byte changed.
- Middle ciphertext byte changed.
- Last ciphertext byte changed.
- Authentication tag changed.
- Valid authentication/recovery after the rejections.

That is 12 positive controls and 24 rejection tests. For length 1, first/middle/last
positions coincide; those are repeated checks, not three distinct corruption sites.
Every negative case explicitly attempts release after failed authentication.

The destination probe covers the full payload length PLUS a 64-byte trailing
sentinel. Authentication must leave it unchanged. Valid release must recover all
plaintext bytes and leave the trailing sentinel unchanged. Rejection checks require
no output DMA completion/error, no release grant, and buffer idle/scrub status.

The tests exercise raw payloads through the protected buffer, AES-GCM, release
interlock, and DMA. They bypass the receiver's RGB header parser; they do not claim
that every arbitrary byte length forms a valid RGB image. Zero-length and oversized
requests, reset timing stress, and full-image protocol tests are outside this suite.

## Fixture and evidence scope

Fixtures use a public zero AES-128 key and distinct fixed 96-bit IVs for each length.
Python AESGCM generated the expected ciphertext/tag. Repeated use here is confined
to fixed test vectors; it is not a production nonce-management policy.
Plaintext byte i is (29*i + 7) modulo 256. AAD has four big-endian words:
0x01010300, 0x00010001, payload length, 1. Crypto hardware processes this AAD as
bytes; no image-header validation is asserted by this application.

These are firmware-observed register and destination-memory checks, not independent
monitoring of all DDR traffic or a formal security proof. Timings from this app
are not performance benchmarks.

Before delivery: the fixtures and four corruptions per length were checked with
Python AESGCM; C syntax was checked with mock BSP declarations for SDT and non-SDT;
the passive monitor passed seven parser cases. Your actual Vitis build and all
36 physical board cases remain pending.
