# Vitis Application

Create a standalone application for `psu_cortexa53_0` using the XSA exported by the Vivado build.

Add all files under `src` exactly once. `main.c` contains the final hardware-tested performance counters and does not depend on `xtime_l.h`; it reads the ARMv8 physical counter directly.

The image is compiled into `car_256_rgb.h`. Changing only the image requires rebuilding the Vitis application, not the Vivado bitstream.

