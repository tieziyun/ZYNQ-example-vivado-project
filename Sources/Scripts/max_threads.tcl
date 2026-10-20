# max_threads.tcl - Use every logical CPU for multi-threaded Vivado steps.
# Vivado defaults to 2 threads on Windows and accepts up to 32.
# Sourced by build.tcl for the interactive session, and set as the impl_1
# STEPS.INIT_DESIGN.TCL.PRE hook so opt/place/route in the run process get it too.
set _cpus 8
if {[info exists ::env(NUMBER_OF_PROCESSORS)]} {
    set _cpus $::env(NUMBER_OF_PROCESSORS)
} else {
    catch {set _cpus [exec nproc]}
}
set_param general.maxThreads [expr {min(max($_cpus, 1), 32)}]
