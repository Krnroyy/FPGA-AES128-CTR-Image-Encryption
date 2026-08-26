from PIL import Image
import numpy as np

# ============================================================
# SETTINGS
# ============================================================

INPUT_IMAGE = "input_image.jpg"

OUTPUT_IMAGE = "original_64x64.png"

HEX_FILE = "image_input.hex"

WIDTH = 64
HEIGHT = 64


# ============================================================
# LOAD IMAGE
# ============================================================

try:
    img = Image.open(INPUT_IMAGE)
except FileNotFoundError:
    print(f"Input file not found: {INPUT_IMAGE}")
    raise
except OSError:
    print(f"Failed to open image (unsupported or corrupted): {INPUT_IMAGE}")
    raise

# Convert to grayscale
img = img.convert("L")

# Resize to exactly 64 x 64 pixels
img = img.resize((WIDTH, HEIGHT))

# Save resized grayscale image
img.save(OUTPUT_IMAGE)


# ============================================================
# CONVERT IMAGE TO BYTE ARRAY
# ============================================================

pixels = np.array(img, dtype=np.uint8)

flat_pixels = pixels.flatten()


print("Image size       :", pixels.shape)
print("Total pixels     :", len(flat_pixels))
print("Total bytes      :", len(flat_pixels))
print("AES blocks       :", len(flat_pixels) // 16)


# ============================================================
# WRITE HEX FILE
#
# One byte per line:
#
# 10
# A5
# FF
# ...
#
# Vivado can read this using $readmemh
# ============================================================

with open(HEX_FILE, "w") as f:

    for value in flat_pixels:

        f.write(f"{value:02X}\n")


print("")
print("Generated:")
print("1.", OUTPUT_IMAGE)
print("2.", HEX_FILE)

print("")
print("Ready for Vivado BRAM loading.")