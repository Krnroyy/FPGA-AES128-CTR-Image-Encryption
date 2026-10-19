puts "========== CREATE ZCU104 GCM PROTECTED-CHUNK PROJECT =========="

set script_dir [file dirname [file normalize [info script]]]
set project_dir [file join $script_dir vivado_project]
set project_name zcu104_gcm_protected_chunk
set expected_part xczu7ev-ffvc1156-2-e
set rtl_dir [file normalize [file join $script_dir .. rtl]]

set source_files [list \
    [file join $rtl_dir ProtectedChunkMemory_BRAM.v] \
    [file join $rtl_dir ProtectedChunkBuffer_AXIS.v] \
    [file join $rtl_dir AES_GCM_AXIS.v] \
    [file join $rtl_dir GHASH_Mult32.v] \
    [file join $rtl_dir AES_128_Core.v] \
    [file join $rtl_dir KeyExpansion.v] \
    [file join $rtl_dir AddRoundKey.v] \
    [file join $rtl_dir SubBytes.v] \
    [file join $rtl_dir ShiftRows.v] \
    [file join $rtl_dir MixColumns.v]]
foreach source_file $source_files {
    if {![file exists $source_file]} {
        error "Required RTL file was not found: $source_file"
    }
}

if {[current_project -quiet] ne ""} { close_project }
create_project -force $project_name $project_dir -part $expected_part
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]
set_property target_language Verilog [current_project]
add_files -fileset sources_1 -norecurse $source_files
update_compile_order -fileset sources_1

create_bd_design system
set ps_vlnv [lindex [get_ipdefs -all xilinx.com:ip:zynq_ultra_ps_e:*] end]
set smc_vlnv [lindex [get_ipdefs -all xilinx.com:ip:smartconnect:*] end]
set dma_vlnv [lindex [get_ipdefs -all xilinx.com:ip:axi_dma:*] end]
set rst_vlnv [lindex [get_ipdefs -all xilinx.com:ip:proc_sys_reset:*] end]
set logic_vlnv [lindex [get_ipdefs -all xilinx.com:ip:util_vector_logic:*] end]
if {$ps_vlnv eq "" || $smc_vlnv eq "" || $dma_vlnv eq "" ||
    $rst_vlnv eq "" || $logic_vlnv eq ""} {
    error "Required PS, SmartConnect, AXI DMA, reset, or vector-logic IP is missing."
}

set ps [create_bd_cell -type ip -vlnv $ps_vlnv zynq_ultra_ps_e_0]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} $ps
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {75}] $ps

set ctrl_smc [create_bd_cell -type ip -vlnv $smc_vlnv ctrl_smc]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {3}] $ctrl_smc
set mem_smc [create_bd_cell -type ip -vlnv $smc_vlnv mem_smc]
set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1}] $mem_smc
set dma [create_bd_cell -type ip -vlnv $dma_vlnv axi_dma_0]
set_property -dict [list \
    CONFIG.c_include_sg {0} CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_m_axis_mm2s_tdata_width {128} \
    CONFIG.c_s_axis_s2mm_tdata_width {128} \
    CONFIG.c_include_mm2s_dre {1} CONFIG.c_include_s2mm_dre {1} \
    CONFIG.c_sg_length_width {26} \
    CONFIG.c_mm2s_burst_size {64} CONFIG.c_s2mm_burst_size {64}] $dma
set reset_block [create_bd_cell -type ip -vlnv $rst_vlnv proc_sys_reset_0]
set reset_inverter [create_bd_cell -type ip -vlnv $logic_vlnv reset_inverter]
set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {1}] $reset_inverter
set gcm [create_bd_cell -type module -reference AES_GCM_AXIS aes_gcm_axis_0]
set protected_buffer [create_bd_cell -type module \
    -reference ProtectedChunkBuffer_AXIS protected_chunk_buffer_0]

connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins ctrl_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins ctrl_smc/M00_AXI] \
                    [get_bd_intf_pins aes_gcm_axis_0/S_AXI_CTRL]
connect_bd_intf_net [get_bd_intf_pins ctrl_smc/M01_AXI] \
                    [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins ctrl_smc/M02_AXI] \
                    [get_bd_intf_pins protected_chunk_buffer_0/S_AXI_CTRL]

connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] \
                    [get_bd_intf_pins mem_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] \
                    [get_bd_intf_pins mem_smc/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins mem_smc/M00_AXI] \
                    [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]

# Security data path: DDR -> DMA -> locked BRAM -> AES-GCM -> DMA -> DDR.
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] \
                    [get_bd_intf_pins protected_chunk_buffer_0/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins protected_chunk_buffer_0/M_AXIS] \
                    [get_bd_intf_pins aes_gcm_axis_0/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins aes_gcm_axis_0/M_AXIS] \
                    [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

set pl_clk [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]
foreach pin_path [list \
    zynq_ultra_ps_e_0/maxihpm0_fpd_aclk \
    zynq_ultra_ps_e_0/saxihp0_fpd_aclk \
    ctrl_smc/aclk mem_smc/aclk \
    axi_dma_0/s_axi_lite_aclk axi_dma_0/m_axi_mm2s_aclk \
    axi_dma_0/m_axi_s2mm_aclk proc_sys_reset_0/slowest_sync_clk \
    aes_gcm_axis_0/aclk protected_chunk_buffer_0/aclk] {
    set target_pin [get_bd_pins -quiet $pin_path]
    if {[llength $target_pin] != 1} { error "Clock pin not found: $pin_path" }
    connect_bd_net $pl_clk $target_pin
}

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
               [get_bd_pins reset_inverter/Op1]
connect_bd_net [get_bd_pins reset_inverter/Res] \
               [get_bd_pins proc_sys_reset_0/ext_reset_in]
set peripheral_resetn [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
foreach pin_path [list ctrl_smc/aresetn mem_smc/aresetn \
    axi_dma_0/axi_resetn aes_gcm_axis_0/aresetn \
    protected_chunk_buffer_0/aresetn] {
    set target_pin [get_bd_pins -quiet $pin_path]
    if {[llength $target_pin] != 1} { error "Reset pin not found: $pin_path" }
    connect_bd_net $peripheral_resetn $target_pin
}

assign_bd_address
set ps_data [get_bd_addr_spaces zynq_ultra_ps_e_0/Data]
set gcm_seg [get_bd_addr_segs -of_objects \
    [get_bd_intf_pins aes_gcm_axis_0/S_AXI_CTRL]]
set dma_seg [get_bd_addr_segs -of_objects \
    [get_bd_intf_pins axi_dma_0/S_AXI_LITE]]
set buffer_seg [get_bd_addr_segs -of_objects \
    [get_bd_intf_pins protected_chunk_buffer_0/S_AXI_CTRL]]
if {[llength $gcm_seg] != 1 || [llength $dma_seg] != 1 ||
    [llength $buffer_seg] != 1} {
    error "Vivado did not infer all three control segments."
}
assign_bd_address -offset 0xA0000000 -range 64K \
    -target_address_space $ps_data [lindex $gcm_seg 0] -force
assign_bd_address -offset 0xA0010000 -range 64K \
    -target_address_space $ps_data [lindex $dma_seg 0] -force
assign_bd_address -offset 0xA0020000 -range 64K \
    -target_address_space $ps_data [lindex $buffer_seg 0] -force

validate_bd_design
save_bd_design
set bd_file [get_files system.bd]
generate_target all $bd_file
set wrapper_file [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper_file
set_property top system_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "========== PROTECTED-CHUNK PROJECT CREATION COMPLETE =========="
puts "Project:       [file join $project_dir ${project_name}.xpr]"
puts "AES-GCM base:  0xA0000000"
puts "AXI DMA base:  0xA0010000"
puts "Buffer base:   0xA0020000"
puts "NEXT: source [file join $script_dir 02_build_protected_chunk_bitstream_2026_1.tcl]"
