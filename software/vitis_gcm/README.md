# Vitis AES-128-GCM Embedded Software Applications

This directory contains the Cortex-A53 bare-metal software applications for the ZCU104 AES-128-GCM hardware-software co-design.

## Subdirectories

- **`single_image/`**: Dynamic single-image authenticated AES-GCM application (`main_gcm_dma_dynamic.c` and `platform.h`).
- **`batch/`**: Multi-image AES-GCM benchmark application (`main_gcm_dma_batch.c` and `platform.h`).

## Setup and Build Instructions

1. **Target Platform**: Both applications target the standalone `psu_cortexa53_0` processor core on AMD/Xilinx ZCU104.
2. **Platform Generation**: Create the Vitis platform component using the XSA file exported after executing the hardware build scripts under `hardware/gcm_dma/scripts/`.
3. **Application Creation**: Create separate empty C application components in Vitis for single-image and batch modes using the created platform.
4. **Source Addition**: Add only the relevant C source (`main_gcm_dma_dynamic.c` or `main_gcm_dma_batch.c`) and `platform.h` to each application component.
5. **Single Main Rule**: Remove any default generated sources (such as `helloworld.c`) so that each application component contains exactly one `main()` function.
