puts "========== CREATE AES-GCM RTL VALIDATION PROJECT =========="

set script_dir [file dirname [file normalize [info script]]]
set project_dir [file join $script_dir vivado_project]
set rtl_dir [file normalize [file join $script_dir .. rtl]]
set sim_dir $script_dir
set project_name zcu104_aes_gcm_rtl_validation
set expected_part xczu7ev-ffvc1156-2-e

if {[current_project -quiet] ne ""} {
    close_project
}

create_project -force $project_name $project_dir -part $expected_part
set_property target_language Verilog [current_project]

add_files -fileset sources_1 -norecurse [list \
    [file join $rtl_dir AES_GCM_OneBlock.v] \
    [file join $rtl_dir GHASH_Mult32.v] \
    [file join $rtl_dir AES_128_Core.v] \
    [file join $rtl_dir KeyExpansion.v] \
    [file join $rtl_dir AddRoundKey.v] \
    [file join $rtl_dir SubBytes.v] \
    [file join $rtl_dir ShiftRows.v] \
    [file join $rtl_dir MixColumns.v]]
add_files -fileset sim_1 -norecurse \
    [file join $sim_dir tb_AES_GCM_OneBlock.v]

set_property top AES_GCM_OneBlock [get_filesets sources_1]
set_property top tb_AES_GCM_OneBlock [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation
run all

puts "========== CHECK TCL CONSOLE =========="
puts "Required final line: PASS: AES_GCM_OneBlock all validation tests"
puts "Do not create the DMA hardware project until every GCM test passes."
