#!/usr/bin/env python3
"""Dependency-free verification of the GHASH convention used by the RTL."""

REDUCTION = 0xE1000000000000000000000000000000
MASK128 = (1 << 128) - 1


def gf_multiply(x: int, h: int) -> int:
    z = 0
    v = h
    for bit in range(128):
        if (x >> (127 - bit)) & 1:
            z ^= v
        if v & 1:
            v = (v >> 1) ^ REDUCTION
        else:
            v >>= 1
    return z & MASK128


def main() -> None:
    # NIST SP 800-38D one-block zero-key/zero-IV example.
    h = int("66e94bd4ef8a2c3b884cfa59ca342b2e", 16)
    ciphertext = int("0388dace60b6a392f328c2b971b2fe78", 16)
    length_block = 128
    tag_mask = int("58e2fccefa7e3061367f1d57a4e7455a", 16)
    expected_ghash = int("f38cbb1ad69223dcc3457ae5b6b0f885", 16)
    expected_tag = int("ab6e47d42cec13bdf53a67b21257bddf", 16)

    after_ciphertext = gf_multiply(ciphertext, h)
    ghash = gf_multiply(after_ciphertext ^ length_block, h)
    tag = tag_mask ^ ghash

    assert ghash == expected_ghash
    assert tag == expected_tag
    print("PASS: GHASH reference value", f"{ghash:032x}")
    print("PASS: AES-GCM reference tag", f"{tag:032x}")


if __name__ == "__main__":
    main()
