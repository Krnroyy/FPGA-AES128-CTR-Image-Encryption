puts "========== BUILD ZCU104 AES-GCM AXI-DMA BITSTREAM =========="

set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir vivado_project zcu104_aes_gcm_axi_dma.xpr]
if {![file exists $project_file]} {
    error "Project not found. Run 01_create_gcm_dma_project_2026_1.tcl first."
}
if {[current_project -quiet] eq ""} {
    open_project $project_file
} elseif {[file normalize [get_property DIRECTORY [current_project]]] ne
          [file normalize [file join $script_dir vivado_project]]} {
    close_project
    open_project $project_file
}

set synth_run [get_runs synth_1]
set impl_run [get_runs impl_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 $synth_run
catch {reset_property INCREMENTAL_CHECKPOINT $synth_run}
set_property AUTO_INCREMENTAL_CHECKPOINT 0 $impl_run
catch {reset_property INCREMENTAL_CHECKPOINT $impl_run}

if {![regexp -nocase {complete} [get_property STATUS $synth_run]]} {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
}
if {![regexp -nocase {complete} [get_property STATUS $synth_run]]} {
    error "Synthesis failed. Open vivado_project/zcu104_aes_gcm_axi_dma.runs/synth_1/runme.log."
}

set bit_file [file join [get_property DIRECTORY $impl_run] system_wrapper.bit]
if {![regexp -nocase {complete} [get_property STATUS $impl_run]] ||
    ![file exists $bit_file]} {
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
}
if {![regexp -nocase {complete} [get_property STATUS $impl_run]] ||
    ![file exists $bit_file]} {
    error "Implementation/bitstream failed. Open vivado_project/zcu104_aes_gcm_axi_dma.runs/impl_1/runme.log."
}

open_run impl_1
set timing_wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
if {$timing_wns < 0.0} {
    error "Bitstream exists, but timing failed with WNS=$timing_wns ns. Do not export this hardware until timing is fixed."
}

set xsa_file [file join $script_dir zcu104_aes_gcm_axi_dma.xsa]
write_hw_platform -fixed -include_bit -force -file $xsa_file

puts "========== GCM-DMA HARDWARE BUILD COMPLETE =========="
puts "Timing WNS: $timing_wns ns"
puts "Bitstream:  $bit_file"
puts "XSA:        $xsa_file"
puts "NEXT: source [file join $script_dir 03_generate_gcm_reports_2026_1.tcl]"
