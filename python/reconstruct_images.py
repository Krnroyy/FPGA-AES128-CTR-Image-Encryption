from PIL import Image
import numpy as np
import os

# ============================================================
# SETTINGS
# ============================================================

WIDTH = 64
HEIGHT = 64

ORIGINAL_HEX = "image_input.hex"
CIPHER_HEX = "cipher_output.hex"
RECOVERED_HEX = "recovered_output.hex"


# ============================================================
# READ HEX FILE
# ============================================================

def read_hex_file(filename):

    values = []

    with open(filename, "r") as f:

        for line in f:

            line = line.strip()

            if line:
                values.append(int(line, 16))

    return np.array(values, dtype=np.uint8)


# ============================================================
# LOAD DATA
# ============================================================

original = read_hex_file(ORIGINAL_HEX)
cipher = read_hex_file(CIPHER_HEX)
recovered = read_hex_file(RECOVERED_HEX)


print("Original bytes  :", len(original))
print("Cipher bytes    :", len(cipher))
print("Recovered bytes :", len(recovered))


# ============================================================
# CHECK SIZE
# ============================================================

expected_size = WIDTH * HEIGHT

if len(original) != expected_size:
    raise ValueError("Original image does not contain 4096 bytes.")

if len(cipher) != expected_size:
    raise ValueError("Cipher image does not contain 4096 bytes.")

if len(recovered) != expected_size:
    raise ValueError("Recovered image does not contain 4096 bytes.")


# ============================================================
# RESHAPE TO 64 x 64
# ============================================================

original_img = original.reshape((HEIGHT, WIDTH))

cipher_img = cipher.reshape((HEIGHT, WIDTH))

recovered_img = recovered.reshape((HEIGHT, WIDTH))


# ============================================================
# CREATE PNG FILES
# ============================================================

Image.fromarray(original_img).save(
    "original_from_hex.png"
)

Image.fromarray(cipher_img).save(
    "encrypted_64x64.png"
)

Image.fromarray(recovered_img).save(
    "recovered_64x64.png"
)


# ============================================================
# BYTE-BY-BYTE VERIFICATION
# ============================================================

if np.array_equal(original, recovered):

    print("")
    print("==============================================")
    print(" ORIGINAL == RECOVERED : YES")
    print(" All 4096 bytes match.")
    print("==============================================")

else:

    mismatches = np.sum(original != recovered)

    print("")
    print("ORIGINAL == RECOVERED : NO")
    print("Mismatching bytes:", mismatches)


# ============================================================
# CHECK WHETHER ENCRYPTION CHANGED DATA
# ============================================================

changed_pixels = np.sum(original != cipher)

change_percentage = (
    changed_pixels / expected_size
) * 100


print("")
print("Changed encrypted pixels :", changed_pixels)

print(
    "Changed pixel percentage :",
    f"{change_percentage:.2f}%"
)


print("")
print("Generated images:")

print("1. original_from_hex.png")
print("2. encrypted_64x64.png")
print("3. recovered_64x64.png")