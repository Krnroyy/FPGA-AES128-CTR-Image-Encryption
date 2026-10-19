# Separate batch process; all paths stay inside this extracted candidate.
set pipeline_script_dir [file dirname [file normalize [info script]]]
if {[current_project -quiet] ne ""} { error "Run through Run-Candidate.ps1 in a separate batch process." }
source [file join $pipeline_script_dir 00_run_security_sim.tcl]
source [file join $pipeline_script_dir 01_create_protected_chunk_project_2026_1.tcl]
source [file join $pipeline_script_dir 02_build_protected_chunk_bitstream_2026_1.tcl]
source [file join $pipeline_script_dir 03_generate_protected_chunk_reports_2026_1.tcl]
puts "PASS: PCF CANDIDATE HARDWARE READY"
puts "XSA: [file join $pipeline_script_dir zcu104_gcm_cancel_candidate.xsa]"
puts "Next: return this log and reports for the Vitis platform update."
