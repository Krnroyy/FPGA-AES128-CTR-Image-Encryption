set script_dir [file dirname [file normalize [info script]]]
set rtl_dir [file normalize [file join $script_dir .. rtl]]
set project_dir [file join $script_dir vivado_protected_chunk_sim]

create_project -force gcm_protected_chunk_sim $project_dir \
    -part xczu7ev-ffvc1156-2-e
set_property target_language Verilog [current_project]

add_files -norecurse [list \
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
add_files -fileset sim_1 -norecurse [list \
    [file join $script_dir tb_ProtectedChunkBuffer_AXIS.v] \
    [file join $script_dir tb_AES_GCM_ProtectedChunk.v]]

set_property top tb_ProtectedChunkBuffer_AXIS [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
launch_simulation
# Keep the unit simulation bounded even if a DUT/testbench wait is stuck.
# The testbench has its own watchdog; this Tcl bound is a second safeguard.
run 1000000ns
close_sim

set_property top tb_AES_GCM_ProtectedChunk [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
# Bound the integration simulation as well; its Verilog watchdog is 2 ms.
run 2000000ns
close_sim

puts "Expected final lines:"
puts "  PASS: PROTECTED CHUNK BUFFER RTL MILESTONE"
puts "  PASS: AES-GCM PROTECTED CHUNK INTEGRATION MILESTONE"
