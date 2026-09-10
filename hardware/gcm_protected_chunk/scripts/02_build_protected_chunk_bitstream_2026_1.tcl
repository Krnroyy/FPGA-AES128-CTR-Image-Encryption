puts "========== BUILD ZCU104 GCM PROTECTED-CHUNK BITSTREAM =========="
set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir vivado_project \
    zcu104_gcm_protected_chunk.xpr]
if {![file exists $project_file]} {
    error "Project not found. Run 01_create_protected_chunk_project_2026_1.tcl first."
}
if {[current_project -quiet] eq ""} {
    open_project $project_file
}
set synth_run [get_runs synth_1]
set impl_run [get_runs impl_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 $synth_run
catch {reset_property INCREMENTAL_CHECKPOINT $synth_run}
set_property AUTO_INCREMENTAL_CHECKPOINT 0 $impl_run
catch {reset_property INCREMENTAL_CHECKPOINT $impl_run}
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![regexp -nocase {complete} [get_property STATUS $synth_run]]} {
    error "Synthesis failed. Inspect synth_1/runme.log."
}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![regexp -nocase {complete} [get_property STATUS $impl_run]]} {
    error "Implementation failed. Inspect impl_1/runme.log."
}
open_run impl_1
set timing_wns [get_property SLACK \
    [get_timing_paths -delay_type max -max_paths 1]]
if {$timing_wns < 0.0} {
    error "Timing failed with WNS=$timing_wns ns. Do not export this hardware."
}
set xsa_file [file join $script_dir zcu104_gcm_protected_chunk.xsa]
write_hw_platform -fixed -include_bit -force -file $xsa_file
puts "========== PROTECTED-CHUNK HARDWARE BUILD COMPLETE =========="
puts "Timing WNS: $timing_wns ns"
puts "XSA: $xsa_file"
puts "NEXT: source [file join $script_dir 03_generate_protected_chunk_reports_2026_1.tcl]"
