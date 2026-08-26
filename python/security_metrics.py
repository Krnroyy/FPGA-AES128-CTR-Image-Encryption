import numpy as np
import matplotlib.pyplot as plt
from math import log2

WIDTH = 64
HEIGHT = 64

def read_hex_file(filename):
    values = []
    with open(filename, "r") as f:
        for line in f:
            line = line.strip()
            if line:
                values.append(int(line, 16))
    return np.array(values, dtype=np.uint8)

original = read_hex_file("image_input.hex").reshape(HEIGHT, WIDTH)
encrypted = read_hex_file("cipher_output.hex").reshape(HEIGHT, WIDTH)
recovered = read_hex_file("recovered_output.hex").reshape(HEIGHT, WIDTH)


# ============================================================
# ENTROPY
# ============================================================

def entropy(img):
    hist = np.bincount(img.flatten(), minlength=256)
    prob = hist / hist.sum()

    ent = 0.0
    for p in prob:
        if p > 0:
            ent -= p * log2(p)

    return ent


print("==============================================")
print("IMAGE ENTROPY")
print("==============================================")

print(f"Original  entropy : {entropy(original):.6f} bits/pixel")
print(f"Encrypted entropy : {entropy(encrypted):.6f} bits/pixel")
print(f"Recovered entropy : {entropy(recovered):.6f} bits/pixel")


# ============================================================
# ADJACENT PIXEL CORRELATION
# ============================================================

def correlation(x, y):
    x = x.astype(np.float64)
    y = y.astype(np.float64)

    if np.std(x) == 0 or np.std(y) == 0:
        return 0.0

    return np.corrcoef(x, y)[0, 1]


def image_correlations(img):

    horizontal_x = img[:, :-1].flatten()
    horizontal_y = img[:, 1:].flatten()

    vertical_x = img[:-1, :].flatten()
    vertical_y = img[1:, :].flatten()

    diagonal_x = img[:-1, :-1].flatten()
    diagonal_y = img[1:, 1:].flatten()

    return (
        correlation(horizontal_x, horizontal_y),
        correlation(vertical_x, vertical_y),
        correlation(diagonal_x, diagonal_y)
    )


orig_corr = image_correlations(original)
enc_corr = image_correlations(encrypted)


print("")
print("==============================================")
print("ADJACENT PIXEL CORRELATION")
print("==============================================")

print("")
print("Original Image")
print(f"Horizontal : {orig_corr[0]:.6f}")
print(f"Vertical   : {orig_corr[1]:.6f}")
print(f"Diagonal   : {orig_corr[2]:.6f}")

print("")
print("Encrypted Image")
print(f"Horizontal : {enc_corr[0]:.6f}")
print(f"Vertical   : {enc_corr[1]:.6f}")
print(f"Diagonal   : {enc_corr[2]:.6f}")


# ============================================================
# ORIGINAL VS RECOVERED CHECK
# ============================================================

mismatches = np.sum(original != recovered)

print("")
print("==============================================")
print("RECOVERY VERIFICATION")
print("==============================================")

print("Mismatching pixels :", mismatches)
print("Original == Recovered :", mismatches == 0)


# ============================================================
# HISTOGRAMS
# ============================================================

plt.figure(figsize=(8,5))
plt.hist(original.flatten(), bins=256)
plt.xlabel("Pixel Intensity")
plt.ylabel("Frequency")
plt.title("Original Image Histogram")
plt.tight_layout()
plt.savefig("hist_original.png", dpi=300)
plt.close()


plt.figure(figsize=(8,5))
plt.hist(encrypted.flatten(), bins=256)
plt.xlabel("Pixel Intensity")
plt.ylabel("Frequency")
plt.title("Encrypted Image Histogram")
plt.tight_layout()
plt.savefig("hist_encrypted.png", dpi=300)
plt.close()


print("")
print("Generated:")
print("hist_original.png")
print("hist_encrypted.png")