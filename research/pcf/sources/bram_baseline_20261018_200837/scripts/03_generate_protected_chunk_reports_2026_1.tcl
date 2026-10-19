puts "========== GENERATE PROTECTED-CHUNK REPORTS =========="
set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir vivado_project \
    zcu104_gcm_protected_chunk.xpr]
set report_dir [file join $script_dir protected_chunk_reports]
file mkdir $report_dir
if {![file exists $project_file]} {
    error "Project not found. Run project creation and bitstream scripts first."
}
if {[current_project -quiet] eq ""} { open_project $project_file }
set impl_run [get_runs impl_1]
if {![regexp -nocase {complete} [get_property STATUS $impl_run]]} {
    error "impl_1 is not complete. Generate the bitstream first."
}
open_run impl_1
report_utilization -hierarchical -hierarchical_depth 4 \
    -file [file join $report_dir protected_chunk_utilization.rpt]
report_timing_summary -delay_type min_max -max_paths 10 \
    -report_unconstrained \
    -file [file join $report_dir protected_chunk_timing_summary.rpt]
report_power -file [file join $report_dir protected_chunk_power.rpt]
report_route_status \
    -file [file join $report_dir protected_chunk_route_status.rpt]
puts "========== PROTECTED-CHUNK REPORTS COMPLETE =========="
puts "Reports folder: $report_dir"
