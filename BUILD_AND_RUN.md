# Build and Run Guide

## Requirements

- AMD/Xilinx ZCU104 board and power supply
- Micro-USB JTAG/UART connection
- Vivado 2026.1 with Zynq UltraScale+ devices and ZCU104 board files
- Vitis Embedded Development 2026.1
- Python 3 with packages from `host/gcm/requirements.txt`

Use a short Windows path without spaces, for example `C:\ZCU104_AES_GCM`.

## 1. Optional RTL validation

Open Vivado 2026.1 and use **Window > Tcl Console**.

```tcl
source {C:/ZCU104_AES_GCM/hardware/gcm_dma/sim/run_oneblock_validation_2026_1.tcl}
```

Required ending: `PASS: AES_GCM_OneBlock all validation tests`.

Then run:

```tcl
source {C:/ZCU104_AES_GCM/hardware/gcm_dma/sim/run_axis_validation_2026_1.tcl}
```

Required ending: `PASS: AES_GCM_AXIS all validation tests`.

## 2. Build the GCM-DMA hardware

Run these commands in the Vivado Tcl console:

```tcl
source {C:/ZCU104_AES_GCM/hardware/gcm_dma/scripts/01_create_gcm_dma_project_2026_1.tcl}
source {C:/ZCU104_AES_GCM/hardware/gcm_dma/scripts/02_build_gcm_bitstream_2026_1.tcl}
source {C:/ZCU104_AES_GCM/hardware/gcm_dma/scripts/03_generate_gcm_reports_2026_1.tcl}
```

The second command can take a long time. Do not stop it while synthesis or implementation is active. Accept the build only if implementation completes, the bitstream is generated and WNS is nonnegative.

## 3. Create the Vitis platform

1. Open Vitis Unified IDE 2026.1.
2. Select a workspace outside the Git repository.
3. Create a Platform Component from the exported XSA.
4. Select `psu_cortexa53_0` and standalone OS.
5. Build the platform.

## 4. Create the applications

Create two separate Empty Application components using the same platform.

Single-image sources:

```text
software/vitis_gcm/single_image/main_gcm_dma_dynamic.c
software/vitis_gcm/single_image/platform.h
```

Batch sources:

```text
software/vitis_gcm/batch/main_gcm_dma_batch.c
software/vitis_gcm/batch/platform.h
```

Remove generated Hello World sources so each component contains only one `main()`. Build must end with `Build Finished successfully`.

## 5. Connect and program the board

1. Set the ZCU104 to the JTAG boot setting used for the verified experiments.
2. Connect board power and the JTAG/UART USB cable.
3. Power on the board.
4. Open the matching Python host command first.
5. Launch the desired Vitis application once.

After every power cycle, the volatile PL bitstream and bare-metal application must be programmed again. Persistent boot requires a separately prepared boot image.

## 6. Single-image authenticated test

```powershell
cd C:\ZCU104_AES_GCM\host\gcm
py -m pip install -r requirements.txt
py send_receive_gcm_image.py "C:\path\to\image.png" COM11 --output gcm_output_run1
```

Keep PowerShell waiting and launch the single-image Vitis application. If COM11 is wrong, terminate the running Vitis session and retry with COM13.

Required final line: `OVERALL: PASS`.

## 7. Multi-image benchmark

```powershell
cd C:\ZCU104_AES_GCM\host\gcm
py benchmark_gcm_images.py "C:\path\to\dataset" COM11 --limit 10 --output gcm_benchmark_output_run1
```

Launch the batch Vitis application once. The default experiment sends the selected dataset images and repeats the first image with a new IV.

Required ending:

```text
All unique IVs: PASS
All FPGA ciphertexts match Python: PASS
All FPGA tags match Python: PASS
All recoveries: PASS
All board tamper rejections: PASS
All rejected buffers zeroized: PASS
OVERALL: PASS
```

## 8. Recompute repository figures

```powershell
py -m pip install -r requirements-analysis.txt
py tools\analyze_results.py
```
