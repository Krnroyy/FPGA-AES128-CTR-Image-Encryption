# Security Model and Limitations

## Protected asset

The protected asset is the RGB image payload transferred between the laptop, Cortex-A53 memory and programmable-logic accelerator.

## Adversary considered

The experiments consider an attacker who can observe or modify ciphertext while it is stored or transmitted. The attacker does not know the 128-bit AES key and cannot modify the trusted FPGA configuration or running control software.

## Demonstrated guarantees

- **Confidentiality:** the image payload is encrypted with AES-128 in GCM mode using a fresh 96-bit IV.
- **Integrity and authenticity:** a 128-bit GCM tag is generated and checked.
- **Tamper rejection:** a one-bit ciphertext modification produced authentication failure in every tested transaction.
- **Release control:** the application transmits recovered plaintext only after successful authentication.
- **Failure cleanup:** the reserved rejected-output buffer is zeroized after authentication failure.
- **Independent reference:** FPGA ciphertext and tags match Python `AESGCM` byte-for-byte.

## Why CTR alone was insufficient

CTR mode encrypts by XORing plaintext with a generated keystream. A ciphertext bit flip therefore causes a predictable plaintext bit flip after decryption. The controlled ZCU104 CTR experiment changed one ciphertext byte and observed exactly one changed plaintext byte, with no authentication error. GCM retains CTR-like confidentiality while GHASH and the tag detect the modification.

## Trust boundaries

The Cortex-A53 software, PL bitstream, AES key-loading path and board are trusted. UART and ciphertext storage may be untrusted. The Python program is used as an independent experimental oracle, not as part of the deployed trust boundary.

## Limitations requiring careful claims

1. The project does not prove resistance against side-channel attacks, voltage/clock fault injection, bitstream replacement or malicious privileged software.
2. The demonstration key is not protected by a PUF, eFUSE, BBRAM or hardware security module.
3. Host-generated random IVs passed uniqueness checks in the experiment, but production systems require persistent IV allocation that prevents reuse under the same key.
4. No AAD is implemented. Image identifiers, dimensions and DICOM metadata are therefore not authenticated by the current core.
5. Unauthenticated bytes can transiently occupy a reserved DDR output buffer. They are not released and are zeroized, but a hardened design should quarantine output on-chip until tag verification.
6. Statistical image metrics do not establish cryptographic security. Standard conformance, reference agreement, nonce discipline and adversarial tests are the stronger evidence.
7. This is not a clinical workflow or regulatory validation.

## Safe publication language

Use: “The prototype experimentally demonstrated authenticated encryption, exact reference agreement and rejection of the tested ciphertext modifications on ZCU104.”

Avoid: “The system is unbreakable,” “clinically secure,” or “GCM prevents every possible attack.”
