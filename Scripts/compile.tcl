#*******************************************************************************
# compile.tcl - Synthesis, implementation, bitstream and XSA export
#
# Usage, from the Vivado Tcl console or in batch mode:
#   source <repo>/Scripts/compile.tcl
#   vivado -mode batch -source Scripts/compile.tcl
#
# Opens build/vivado_project.xpr (running build.tcl first if the project does
# not exist yet), runs everything with parallel jobs, checks timing, and writes
# build/design_1_wrapper.xsa with the bitstream included.
#*******************************************************************************

set script_dir [file dirname [file normalize [info script]]]
set base_dir [file dirname $script_dir]
set xpr [file join $base_dir build vivado_project.xpr]

if {[catch {current_project}]} {
    if {[file exists $xpr]} {
        open_project $xpr
    } else {
        source [file join $script_dir build.tcl]
    }
}
source [file join $base_dir Sources Scripts max_threads.tcl]

# Parallel runs: the 14 out-of-context IP runs dominate a first build (later
# builds take most of them from the IP cache). Each run needs about 1 GB of
# RAM, so cap at 8 jobs.
set jobs [expr {min([get_param general.maxThreads], 8)}]
set t0 [clock seconds]

# Synthesis (IP runs come from the IP cache when it has a match)
if {[get_property NEEDS_REFRESH [get_runs synth_1]] || [get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    reset_run synth_1
    launch_runs synth_1 -jobs $jobs
    wait_on_run synth_1
}
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synth_1 failed: [get_property STATUS [get_runs synth_1]]"
}
set t1 [clock seconds]

# Implementation through bitstream
if {[get_property NEEDS_REFRESH [get_runs impl_1]] || [get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    reset_run impl_1
    launch_runs impl_1 -to_step write_bitstream -jobs $jobs
    wait_on_run impl_1
}
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    error "impl_1 failed: [get_property STATUS [get_runs impl_1]]"
}
set t2 [clock seconds]

# Timing check
set impl [get_runs impl_1]
set wns [get_property STATS.WNS $impl]
set whs [get_property STATS.WHS $impl]
set tpws [get_property STATS.TPWS $impl]
if {$wns < 0 || $whs < 0 || $tpws < 0} {
    error "Timing not met: WNS=$wns WHS=$whs TPWS=$tpws"
}

# Hardware platform for Vitis / PYNQ
set xsa [file join $base_dir build design_1_wrapper.xsa]
write_hw_platform -fixed -include_bit -force -file $xsa

puts "compile.tcl: synthesis [expr {$t1 - $t0}] s, implementation [expr {$t2 - $t1}] s"
puts "compile.tcl: timing met (WNS $wns ns, WHS $whs ns), wrote $xsa"
