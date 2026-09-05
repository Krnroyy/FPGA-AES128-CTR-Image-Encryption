# Vivado Hardware

The generated top is `system_wrapper`. The `system` block design contains:

- Zynq UltraScale+ Processing System: `zynq_ultra_ps_e_0`
- AXI SmartConnect: `axi_smc`
- Custom accelerator: `aes_ctr_axi_lite_0`

The processor accesses the accelerator through `M_AXI_HPM0_FPD` at base address `0xA0000000`. The second HPM master is disabled by the build script to avoid an unused-clock validation error.

