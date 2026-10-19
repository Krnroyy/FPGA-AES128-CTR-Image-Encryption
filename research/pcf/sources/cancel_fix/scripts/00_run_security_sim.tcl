# Run through Run-Verification.ps1 in a separate Vivado batch process.
# Simulation projects only: no synthesis, programming, or existing-project edits.
if {[current_project -quiet] ne ""} { error "Use the batch launcher; do not source this in an open project." }
set guard_root [file normalize [file join [file dirname [info script]] ..]]
set guard_rtl [glob -directory [file join $guard_root rtl] *.v]
set guard_checks [list \
    [list tb_ProtectedChunkBuffer_AXIS "PASS: PROTECTED CHUNK BUFFER RTL MILESTONE"] \
    [list tb_ReleaseInterlock "PASS: RTL RELEASE INTERLOCK MILESTONE"] \
    [list tb_ControllerRaces "CANDIDATE_RACES_PASS scenarios=16 pending_completion_collisions=9"] \
    [list tb_CommittedPacket "COMMITTED_PACKET_PASS cases=45 strict_axis_violations=0"]]
set guard_stamp [file join $guard_root sim validated_sources.txt]
file delete -force $guard_stamp
foreach guard_check $guard_checks {
    set guard_top [lindex $guard_check 0]
    set guard_marker [lindex $guard_check 1]
    if {[current_project -quiet] ne ""} { close_project }
    set guard_project_dir [file join $guard_root sim verification_projects $guard_top]
    create_project -force $guard_top $guard_project_dir -part xczu7ev-ffvc1156-2-e
    set_property target_language Verilog [current_project]
    add_files -norecurse $guard_rtl
    add_files -fileset sim_1 -norecurse [file join $guard_root sim ${guard_top}.v]
    set_property top $guard_top [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
    launch_simulation -mode behavioral
    run 3000000ns
    close_sim
    set guard_log [file join $guard_project_dir ${guard_top}.sim sim_1 behav xsim simulate.log]
    # GUI XSim versions commonly use simulate.log; retain xsim.log fallback.
    if {![file exists $guard_log]} {
        set guard_log [file join $guard_project_dir ${guard_top}.sim sim_1 behav xsim xsim.log]
    }
    if {![file exists $guard_log]} { error "Simulation log missing; no PASS recorded." }
    set guard_f [open $guard_log r]
    set guard_text [read $guard_f]
    close $guard_f
    if {[regexp -line {^(FAIL:|FATAL:|ERROR:|Fatal:)} $guard_text] ||
        [string first $guard_marker $guard_text] < 0} {
        error "Security simulation did not pass. Review $guard_log"
    }
    puts "VERIFIED $guard_marker"
}
# CRCs detect accidental changes after validation; they are not security hashes.
set guard_fingerprints {}
foreach guard_file [lsort [concat $guard_rtl [glob -directory [file join $guard_root sim] tb_*.v]]] {
    set guard_f [open $guard_file rb]
    set guard_crc [zlib crc32 [read $guard_f]]
    close $guard_f
    lappend guard_fingerprints [list [file tail $guard_file] $guard_crc]
}
set guard_f [open $guard_stamp w]
puts $guard_f $guard_fingerprints
close $guard_f
puts "PASS: PCF CANCELLATION CANDIDATE SIMULATIONS"
puts "NEXT: Return the simulation log for review before creating candidate hardware."
