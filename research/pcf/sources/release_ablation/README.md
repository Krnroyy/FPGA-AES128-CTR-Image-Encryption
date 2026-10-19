# Paired release-policy experiment — PCF only

Purpose: compare the same raw-decrypt command sequence on original Stage 1 and
hardware-interlocked Stage 2. This is a small causal experiment, not another random
sweep or a new cryptographic algorithm. Existing bitstreams/platforms are reused.

## Build two applications from the SAME source

Extract into C:\PCF\release_ablation.

In Vitis create two empty standalone psu_cortexa53_0 applications:

| App name | Existing platform | Hardware programmed at launch |
| --- | --- | --- |
| ablation_stage1_app | receiver_platform | Original BRAM-baseline Stage 1 |
| ablation_stage2_app | receiver_stage2_platform | Stage 2 release guard |

For BOTH apps, add software\main_release_ablation.c and software\platform.h.
Remove any generated example main.c. Each app must have exactly one main source.
Keep the same source content in both apps. Use -O2 -g3 and retain both build logs.
This test is not a timing benchmark; optimization is recorded only for provenance.
Do not overwrite existing receiver or benchmark sources/applications.

## First run: original Stage 1 (currently loaded)

Close other COM6 terminals and stop the old debug session. In PowerShell:

```powershell
cd C:\PCF\release_ablation
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\run_release_ablation.py --self-test
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\run_release_ablation.py --port COM6 --expect stage1
```

After "Port open", launch ablation_stage1_app with the original platform/bitstream
and PS initialization. Expected identity: STAGE1_TRUSTED_FIRMWARE. Expected results:

```text
ABLATION_RESULT AUTHENTICATED_CONTROL EXACT_21_BYTES
ABLATION_RESULT RAW_DECRYPT_VALID_TAG EXPOSED_EXACT_21_BYTES TAG_MATCH
ABLATION_RESULT RAW_DECRYPT_BAD_TAG EXPOSED_EXACT_21_BYTES AUTH_FAIL
ABLATION_OVERALL PASS
ABLATION MONITOR OVERALL: PASS
```

Here PASS means the experiment observed its expected baseline behavior. It does
NOT mean Stage 1 prevents the bypass. If this expected behavior is not observed,
return the transcript; do not modify the app just to obtain an expected result.

## Second run: Stage 2

Stop the Stage 1 debug session. Start the recorder again:

```powershell
& "C:\PCF\receiver_stage1\.venv\Scripts\python.exe" host\run_release_ablation.py --port COM6 --expect stage2
```

After "Port open", launch ablation_stage2_app using receiver_stage2_platform and
PROGRAM THE STAGE 2 BITSTREAM, with PS initialization. Loading only the ELF while
Stage 1 hardware remains programmed is insufficient. Expected identity: STAGE2_GUARD.

```text
ABLATION_RESULT AUTHENTICATED_CONTROL EXACT_21_BYTES
ABLATION_RESULT RAW_DECRYPT_VALID_TAG BLOCKED_PROBE_UNCHANGED
ABLATION_RESULT RAW_DECRYPT_BAD_TAG BLOCKED_PROBE_UNCHANGED
ABLATION_OVERALL PASS
ABLATION MONITOR OVERALL: PASS
```

The recorder creates separate release_ablation_stage1_run_* and stage2_run_* folders.
Return summary.json and uart_transcript.txt from BOTH folders plus build output.
No input image or UART data is required. All test keys/data are public fixtures.

## What the experiment actually does

Both runs first establish a working normal authenticated two-pass release of the
same fixed 21-byte plaintext (00 through 14 in hex). The positive control uses the
correct hardware-specific release procedure; it is deliberately not an attack.

Each raw attempt then resets state, captures the fixed ciphertext, and provisions
the legitimate fixed key/IV/AAD/expected tag. No auth-only replay occurs. S2MM is
armed with a 64-byte 0xA5 destination probe. Both runs issue exactly these writes:

1. MODE = DECRYPT (1).
2. CONTROL = LOAD_IV (2).
3. Wait 100 microseconds for setup.
4. CONTROL = ENABLE | CLEAR_DONE (9).
5. Protected buffer CONTROL = REPLAY (2).
6. Wait 2 milliseconds, then inspect status and probe bytes.

The bad-tag case changes only the expected tag's final bit. It uses the same
ciphertext/key/IV/AAD, so any observed plaintext has the same exact expected bytes.
On Stage 1, exposure is accepted as an experimental observation only if DMA
completion occurs without error, all 21 plaintext bytes are exact, trailing bytes
are unchanged, and the crypto verdict is correct (AUTH_FAIL for the bad tag).
On Stage 2, acceptance requires no DMA completion/error, the entire probe unchanged,
no grant/release bits, denied status, and protected-buffer idle/scrub status.

Hardware selection is checked using reserved register 0x68: Stage 1 returns zero,
Stage 2 returns the 0x5247 signature. Zero is not a globally unique identity; retain
the known platform/XSA/bitstream provenance and launch configuration. The host
requires an explicit --expect profile so a wrong hardware launch cannot silently
count as the requested comparison.

## Interpretation and limits

Stage 1 is a trusted-firmware design. Its raw decryption capability is not itself
an AES-GCM algorithm flaw; legitimate firmware is responsible for not exposing
invalid plaintext. This experiment intentionally bypasses that responsibility.
Stage 2 should enforce the narrower command policy in hardware.

A positive result supports a causal comparison of these particular interfaces and
commands under a trusted provisioned context. It does not establish isolation from
privileged software that can read or replace keys, all-DDR noninterference,
side-channel resistance, or formal security. It does not timestamp plaintext's
first appearance relative to the final tag verdict: status and destination bytes
are sampled after processing. The bad-tag case directly tests the observable
presence/absence of plaintext despite invalid authentication.

Prior literature already establishes the dangers of unverified plaintext and
buffering until authentication. This experiment is evidence for the implementation's
specific hardware-versus-software enforcement distinction, not proof of novelty.
Related-work pointers remain in PCF-Research-Foundation.md and the comparison kit.

## Validation status

C syntax checks passed for SDT/non-SDT using mock BSP headers at -O2 with warnings
as errors. The passive monitor passed ten synthetic parser checks. The public
AESGCM vector is the same independently checked vector used by the previous guard
board app. Actual Vitis builds and BOTH physical ablation runs are PENDING.
