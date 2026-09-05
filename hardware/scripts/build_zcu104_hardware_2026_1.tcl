puts "========== ZCU104 REAL-IMAGE AES-CTR HARDWARE =========="

set script_dir [file dirname [file normalize [info script]]]
set project_dir [file join $script_dir vivado_project]
set rtl_dir [file normalize [file join $script_dir .. rtl]]
set project_name zcu104_real_image_aes_ctr
set expected_part xczu7ev-ffvc1156-2-e

if {[current_project -quiet] ne ""} {
    close_project
}

create_project -force $project_name $project_dir -part $expected_part
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]
set_property target_language Verilog [current_project]

add_files -fileset sources_1 -norecurse [list \
    [file join $rtl_dir AES_CTR_AXI_LITE.v] \
    [file join $rtl_dir AES_128_Core.v] \
    [file join $rtl_dir KeyExpansion.v] \
    [file join $rtl_dir AddRoundKey.v] \
    [file join $rtl_dir SubBytes.v] \
    [file join $rtl_dir ShiftRows.v] \
    [file join $rtl_dir MixColumns.v]]

update_compile_order -fileset sources_1

create_bd_design system

set ps_vlnv [lindex [get_ipdefs -all xilinx.com:ip:zynq_ultra_ps_e:*] end]
set smc_vlnv [lindex [get_ipdefs -all xilinx.com:ip:smartconnect:*] end]

if {$ps_vlnv eq "" || $smc_vlnv eq ""} {
    error "Required Zynq UltraScale+ PS or SmartConnect IP is unavailable. Check the Vivado device installation."
}

set ps [create_bd_cell -type ip -vlnv $ps_vlnv zynq_ultra_ps_e_0]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} $ps

set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {75}] $ps

set smc [create_bd_cell -type ip -vlnv $smc_vlnv axi_smc]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $smc

set aes [create_bd_cell -type module -reference AES_CTR_AXI_LITE aes_ctr_axi_lite_0]

connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
                    [get_bd_intf_pins aes_ctr_axi_lite_0/S_AXI]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] \
               [get_bd_pins axi_smc/aclk] \
               [get_bd_pins aes_ctr_axi_lite_0/s_axi_aclk]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
               [get_bd_pins axi_smc/aresetn] \
               [get_bd_pins aes_ctr_axi_lite_0/s_axi_aresetn]

set slave_segs [get_bd_addr_segs -of_objects [get_bd_intf_pins aes_ctr_axi_lite_0/S_AXI]]
if {[llength $slave_segs] == 0} {
    error "Vivado did not infer the AES AXI4-Lite address segment."
}

assign_bd_address -offset 0xA0000000 -range 64K \
    -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] \
    [lindex $slave_segs 0] -force

validate_bd_design
save_bd_design

set bd_file [get_files system.bd]
generate_target all $bd_file
set wrapper_file [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper_file
set_property top system_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

set synth_run [get_runs synth_1]
set impl_run [get_runs impl_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 $synth_run
catch {reset_property INCREMENTAL_CHECKPOINT $synth_run}
set_property AUTO_INCREMENTAL_CHECKPOINT 0 $impl_run
catch {reset_property INCREMENTAL_CHECKPOINT $impl_run}

puts "Launching synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![regexp -nocase {complete} [get_property STATUS $synth_run]]} {
    error "Synthesis failed. Open synth_1/runme.log."
}

puts "Launching implementation and bitstream generation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![regexp -nocase {complete} [get_property STATUS $impl_run]]} {
    error "Implementation or bitstream generation failed. Open impl_1/runme.log."
}

set xsa_file [file join $script_dir zcu104_real_image_aes_ctr.xsa]
write_hw_platform -fixed -include_bit -force -file $xsa_file

puts "========== HARDWARE BUILD COMPLETE =========="
puts "XSA for Vitis: $xsa_file"
puts "AXI accelerator base address: 0xA0000000"
