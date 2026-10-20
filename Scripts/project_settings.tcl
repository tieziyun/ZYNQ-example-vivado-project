################################################################################
# project_settings.tcl - Captured Project Configuration
# Generated: Mon Oct 19 15:55:39 2026
# Project: vivado_project
# Device: xc7z020clg400-1
################################################################################

# Derive base_dir for referencing exported files (e.g., hook scripts)
set base_dir [file dirname [file dirname [file normalize [info script]]]]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROJECT SETTINGS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set_property PART xc7z020clg400-1 [current_project]
set_property BOARD_PART {tul.com.tw:pynq-z2:part0:1.0} [current_project]
set_property TARGET_LANGUAGE {Verilog} [current_project]
set_property IP_CACHE_PERMISSIONS {read write} [current_project]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FILESET SETTINGS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set_property TOP {design_1_wrapper} [get_filesets sources_1]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SYNTHESIS SETTINGS (non-default only)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]

# Compile time: the top level is only the block design wrapper, so synth_1
# uses the fastest flow. Applying a strategy resets the step arguments, so set
# these two after it.
# The out-of-context IP runs keep the default strategy: v_frmbuf_rd misses
# timing (WNS -0.19 ns) when synthesized with Flow_RuntimeOptimized, and the
# IP cache means each IP is synthesized only once anyway.
set_property STRATEGY {Flow_RuntimeOptimized} [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.SHREG_MIN_SIZE {3} [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.CONTROL_SET_OPT_THRESHOLD {auto} [get_runs synth_1]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# IMPLEMENTATION SETTINGS (non-default only)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Default directives: the cheapest strategy that meets timing. Measured on
# Vivado 2026.1 (post-route WNS): Flow_RuntimeOptimized -0.29 ns (fails),
# Defaults +0.08 ns, Performance_Explore +0.21 ns. The original
# Performance_ExplorePostRoutePhysOpt took about twice as long to place/route.
# If a design change breaks timing, try Performance_Explore first.
set_property STRATEGY {Vivado Implementation Defaults} [get_runs impl_1]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TCL HOOK SCRIPTS (pre/post hooks)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Runs are separate Vivado processes that start with 2 threads on Windows.
# build.tcl imports Sources/Scripts/*.tcl into utils_1; raise the thread count
# before the first implementation step.
set max_threads_hook [get_files -quiet -of_objects [get_filesets utils_1] *max_threads.tcl]
if {$max_threads_hook ne ""} {
    set_property STEPS.INIT_DESIGN.TCL.PRE $max_threads_hook [get_runs impl_1]
}

puts "Project settings restored from saved configuration"
