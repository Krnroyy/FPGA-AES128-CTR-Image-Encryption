# PCF protected-chunk security research checkpoint

This directory preserves selected source snapshots and experimental evidence
for the ZCU104 AES-GCM protected-chunk receiver.

## Layout

- sources/: development stages and application sources.
- evidence/: selected board transcripts, summaries, benchmark samples,
  and candidate implementation reports.

Some reusable sources also appear inside Vitis application snapshots.
Generated projects, platforms, binaries, and Python environments are excluded.
These are research snapshots, not a portable one-command build distribution.
Paths in scripts and application configurations may need adjustment.

## Confirmed earlier board results

- Stage 1 receiver: 11 cases passed.
- Stage 2 receiver: 11 cases passed.
- Hardware release guard: 26 cases passed.
- Length checks: 36 cases passed.
- Combined sweep: 640 cases passed with both O0 and O2 application builds.
- Matched Stage 1 benchmark: passed.
- Paired release-policy ablation: expected outcomes passed on both stages.

In the paired experiment, Stage 1 raw decryption exposed the tested plaintext
even with a bad tag when firmware sequencing was bypassed. Stage 2 blocked
the same unauthorized command sequence. Normal authenticated release worked
on both. This is a release-policy comparison, not a cryptographic break.

## Cancellation candidate

An accepted authorized release command commits the authenticated packet.
Subsequent software cancellation requests are deferred until packet completion,
then cleanup occurs. This differs from immediate cancellation during release.

Candidate policy register: 0xA000006C; expected value: 0x00030001.

Confirmed candidate results:
- Four simulation suites passed.
- Vivado implementation and bitstream generation completed.
- 75 MHz: setup slack +0.846 ns; hold slack +0.010 ns.
- Zero reported routing errors and unconstrained internal endpoints.
- 20,249 LUTs; 12,972 registers; 6 RAMB36 and 2 RAMB18.
- Matching Vitis platform built successfully.

Candidate board validation is not established by the evidence in this snapshot.
Earlier Stage 2 board passes must not be attributed to this candidate.
Power reports are tool estimates, not physical power measurements.

## Scope and limitations

Withholding plaintext until authentication is established prior work.
Novelty of the specific controller and evaluation remains under investigation.

Board observations use firmware, DMA status, and destination probes.
They are not independent DDR-bus monitoring or direct BRAM-erasure proof.
No formal proof, persistent replay protection across resets, or protection
against arbitrary privileged software with key access is claimed.

Cryptographic fixtures contain public test keys and nonces, not production
key-management examples. Do not reuse their fixed nonces in deployment.

## Reproducibility notes

Generated bitstreams, XSAs, ELFs and build directories are not included.
The candidate source manifest describes its original package; intentionally
excluded files such as its PowerShell launchers may be named in that manifest.
The previously antivirus-flagged board-test ZIP is excluded.