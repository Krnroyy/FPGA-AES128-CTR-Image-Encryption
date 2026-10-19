set guard_check_root [file normalize [file join [file dirname [info script]] ..]]
set guard_stamp [file join $guard_check_root sim validated_sources.txt]
if {![file exists $guard_stamp]} {
    error "Run scripts/00_run_security_sim.tcl successfully before creating/building hardware."
}
set guard_f [open $guard_stamp r]
set guard_expected [string trim [read $guard_f]]
close $guard_f
set guard_actual {}
foreach guard_file [lsort [concat \
    [glob -directory [file join $guard_check_root rtl] *.v] \
    [glob -directory [file join $guard_check_root sim] tb_*.v]]] {
    set guard_f [open $guard_file rb]
    set guard_crc [zlib crc32 [read $guard_f]]
    close $guard_f
    lappend guard_actual [list [file tail $guard_file] $guard_crc]
}
if {$guard_actual ne $guard_expected} {
    error "RTL/testbench changed since simulation PASS. Rerun 00_run_security_sim.tcl."
}
