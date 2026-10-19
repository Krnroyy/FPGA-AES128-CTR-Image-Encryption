# Research status — PCF project only

Reviewed 19 October 2026. This is a scoped first literature check, not an exhaustive
novelty review. Literature and the specific implementation contribution must be
reassessed at major experiment milestones. No numerical publication-readiness
percentage or acceptance prediction is justified.

## Verified prior art and implications

1. Andreeva et al., "How to Securely Release Unverified Plaintext in Authenticated
   Encryption," ASIACRYPT 2014, pp. 105–125. Institutional publication record and
   abstract reviewed: https://orbit.dtu.dk/en/publications/how-to-securely-release-unverified-plaintext-in-authenticated-enc/
   The RUP security problem is established. Our output suppression tests do not
   constitute a proof of their formal notions, and the problem itself is not new.

2. Unterstein et al., "SCA secure and updatable crypto engines for FPGA SoC bitstream
   decryption: extended version," Journal of Cryptographic Engineering 11, 257–272
   (2021), online 24 December 2020. Full publisher text reviewed, particularly
   sections 4.2 and 8.1: https://doi.org/10.1007/s13389-020-00247-2
   The paper describes authenticated on-chip plaintext buffering and a later
   authenticate-before-decrypt construction. Buffering until authentication cannot
   be claimed as a new concept. Its leakage-resilient cryptography, PUFs, and
   bitstream deployment differ from this AXI-DMA runtime payload implementation.

3. AMD XAPP1098, "Invalid/Random Bitstream Data," revision 1.6, 1 October 2026.
   This is vendor documentation, not a research paper. The text explicitly describes
   holding ciphertext in configuration memory during RSA authentication, then
   decrypting it in place:
   https://docs.amd.com/r/en-US/xapp1098-tamper-resist-designs/Invalid/Random-Bitstream-Data
   Therefore storing ciphertext until verification is also not new in general.
   That configuration/RSA mechanism is not equivalent to this runtime AES-GCM guard.

4. "The Design of a High-Throughput Hardware Architecture for the AES-GCM Algorithm,"
   IEEE Transactions on Consumer Electronics 70(1), February 2024:
   https://ieeexplore.ieee.org/document/10318194/
   Publisher-indexed abstract screened, full text blocked by access verification.
   It describes pipelined AES-GCM architecture. It is a candidate performance
   reference, not evidence that our implementation is faster or its release policy
   is different. A direct numerical comparison requires the full evaluation scope,
   FPGA family, clocks, resource boundaries, and encryption/decryption policy.

Do not rank our CPU-observed capture/auth/release MB/s against a paper's fully
pipelined core Gbit/s without normalizing what each metric measures.

## Candidate contribution, not yet a novelty claim

Evaluate a transaction-bound hardware release interlock for an AXI-DMA AES-GCM
receiver: immutable captured ciphertext, configuration binding, single-use release
permission, and revocation on misuse/reset/recapture. The novelty question is
whether this particular mechanism and its documented threat model/evaluation add
something beyond prior protected-buffer and authorization architectures.

Describe existing AES-GCM, protected buffering, two-pass processing, and the RUP
problem with citations. Do not claim a new cipher, first authenticate-before-release
FPGA, protection against all compromised software, or side-channel resistance.

## Current evidence and remaining gates

- Working ZCU104 implementation: established by saved implementation reports and
  board test transcripts.
- Directed guard and boundary tests: saved, passing. These are finite functional
  tests, not exhaustive proofs.
- Wider campaign: 640 cases across 64 lengths, passing at unoptimized and optimized
  builds; repeated locations in tiny packets are not independent attack sites.
- Timings: 217 retained samples per build, with matching raw records. These measure
  software-visible orchestration, with explicit cleanup/validation boundaries.
- Matched Stage 1/Stage 2 comparison: prepared, board run still pending.
- Precise threat model: must be written. Trusted provisioning, key access, host and
  firmware privileges, reset behavior, and the observer boundary need explicit
  treatment. Current readable/writable key configuration does not establish key
  isolation from arbitrary malicious privileged software.
- Stronger invariants: consider assertions/proofs for output authorization, capture
  binding, frozen configuration, and one-use grant consumption, scoped to the
  actual trusted hardware/environment assumptions.
- Novelty review: incomplete. Search for close transaction-bound release guards,
  immutable-buffer TOCTOU protection, and AXI/SoC authenticated DMA architectures.
- Final full-image evidence on Stage 2, reproducibility package, related-work table,
  figures, and manuscript: still needed according to the chosen paper scope.

## How to decide the next experiments

Complete the matched baseline comparison to measure architectural cost. Then
choose additional experiments from actual literature gaps and unproven claims,
rather than accumulating arbitrary test counts. A matched bypass demonstration
on trusted-firmware versus hardware-interlocked designs and scoped invariant
verification may provide more useful evidence than another large random sweep.

Write all explanation/figures from our actual design and measured results. Cite
borrowed ideas and identify reused code/IP and licenses. Do not copy wording,
figures, data, or architecture claims from another paper. Keep a claim-to-evidence
list: each claim must have a local artifact or a cited prior source, and its limits.
