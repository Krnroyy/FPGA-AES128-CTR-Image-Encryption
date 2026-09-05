# Build and Run Guide

## Requirements

- AMD/Xilinx ZCU104 board
- Vivado 2026.1 with Zynq UltraScale+ device support and the ZCU104 board definition
- Vitis Embedded Development 2026.1
- USB/JTAG-UART cable and ZCU104 power supply
- Python 3 with `pyserial` and `Pillow`

Use a short Windows directory without spaces or parentheses, for example `C:\ZCU104_AES_CTR`.

## 1. Build the Vivado hardware

Open Vivado 2026.1 without opening an old project. In the Tcl Console, run:

```tcl
source {C:/ZCU104_AES_CTR/hardware/scripts/build_zcu104_hardware_2026_1.tcl}
```

The script creates a new project, integrates the Zynq processing system, AXI SmartConnect, and custom AES RTL, generates the bitstream, and exports:

```text
zcu104_real_image_aes_ctr.xsa
```

## 2. Create the Vitis platform

1. Open Vitis Unified IDE 2026.1.
2. Set a new workspace outside the source repository.
3. Create a Platform Component from the exported XSA.
4. Select `standalone` and `psu_cortexa53_0`.
5. Build the platform.

## 3. Create the Cortex-A53 application

1. Create an Empty Application Component using the platform.
2. Add `main.c`, `car_256_rgb.h`, and `platform.h` from `software/vitis/src`.
3. Ensure each source is listed only once in the application configuration.
4. Build the application.

If Vitis reports a missing `platform.h`, use the supplied header. If it refers to `main (1).c`, remove the duplicate entry from `UserConfig.cmake` and retain only the real `main.c` path.

## 4. Connect the board

1. Connect the ZCU104 power supply.
2. Connect the USB/JTAG-UART cable.
3. Power on the board.
4. Use the JTAG boot-mode setting used during the verified test.
5. Confirm the board is visible to Vivado/Vitis hardware tools.

## 5. Start the laptop receiver

Install the dependencies once:

```powershell
py -m pip install pyserial pillow
```

Open PowerShell in the repository and run:

```powershell
py host\receive_full_image.py COM11
```

If the PS UART is assigned to another port, try COM13. COM12 was used by the earlier PL-UART test and may not be the correct port for this application.

## 6. Launch the application

Keep the Python receiver waiting, then use Vitis Run or Debug to program the hardware and launch the application on `psu_cortexa53_0`.

Successful output contains:

```text
RECOVERY_PASS
ZCU104_AES_CTR_DONE
Original == recovered: PASS
```

The Python script saves encrypted and recovered PNG and BIN files under `full_image_output`.

## Change the input image

The current application contains a compiled RGB image. To use another image:

1. Put an image at the input path expected by `tools/prepare_real_image_assets.py` or update the `SOURCE` value.
2. Run the preparation script.
3. Replace `software/vitis/src/car_256_rgb.h` with the generated header.
4. Clean and rebuild only the Vitis application.
5. The Vivado bitstream does not need to be regenerated because the image is stored in processor software, not PL logic.

