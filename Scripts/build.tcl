#*******************************************************************************
# build.tcl - Project Recreation Script
# Generated: Mon Oct 19 15:55:41 2026
# Original Project: vivado_project
#*******************************************************************************

set script_dir [file dirname [file normalize [info script]]]
set base_dir [file dirname $script_dir]
set proj_name vivado_project

#─────────────────────────────────────────────────────────────────────────────────
# Step 1: Create Project
#─────────────────────────────────────────────────────────────────────────────────
# The project is created in <repo>/build/ (git-ignored), whatever directory
# Vivado was started from. The rest of this script uses paths relative to it.
set proj_dir [file join $base_dir build]
file mkdir $proj_dir
cd $proj_dir

# PYNQ-Z2 board files: install them from Vivado's board store, or point the
# PYNQZ2_BOARD_DIR environment variable at a folder that contains them.
if {[info exists ::env(PYNQZ2_BOARD_DIR)]} {
    set_param board.repoPaths [list $::env(PYNQZ2_BOARD_DIR)]
}

create_project $proj_name . -part xc7z020clg400-1 -force
if {[llength [get_board_parts -quiet tul.com.tw:pynq-z2:part0:*]] == 0} {
    error "PYNQ-Z2 board files not found. Install them from Vivado's board store\
           (Tools > Vivado Store > Boards, search 'pynq-z2'), or set PYNQZ2_BOARD_DIR\
           to a folder containing them, then run build.tcl again."
}
set_property BOARD_PART {tul.com.tw:pynq-z2:part0:1.0} [current_project]

#─────────────────────────────────────────────────────────────────────────────────
# Step 1b: Set Custom IP Repository Paths (required before BD recreation)
# Digilent IP (rgb2dvi, axi_dynclk) comes from the vivado-library git submodule.
#─────────────────────────────────────────────────────────────────────────────────
if {![file exists [file join $base_dir vivado-library ip rgb2dvi]]} {
    error "vivado-library submodule is empty. Run: git submodule update --init"
}
set_property IP_REPO_PATHS [list \
    [file normalize $base_dir/vivado-library/ip] \
    [file normalize $base_dir/vivado-library/if] \
] [current_project]
update_ip_catalog

#─────────────────────────────────────────────────────────────────────────────────
# Step 2: Add RTL Sources
#─────────────────────────────────────────────────────────────────────────────────
# Local sources — import into project for full portability
set rtl_files {}
catch {set rtl_files [glob $base_dir/Sources/RTL/*]}
if {[llength $rtl_files] > 0} {
    import_files $rtl_files
}

#─────────────────────────────────────────────────────────────────────────────────
# Step 3: Add Constraint Files
#─────────────────────────────────────────────────────────────────────────────────
set _constrs_files_constrs_1 [list \
    [file join $base_dir Sources Constraints {pynq_z2.xdc}] \
]
if {[llength [set _constrs_files_constrs_1]] > 0} {
    import_files -fileset constrs_1 [set _constrs_files_constrs_1]
}
catch {set_property TARGET_CONSTRS_FILE [file join $base_dir Sources Constraints {pynq_z2.xdc}] [get_filesets constrs_1]}
# Include NoC constraints if present (attached to the primary constrs_1 set)
catch {
    set _noc_xdc [glob $base_dir/Sources/NoC/*.xdc]
    if {[llength $_noc_xdc] > 0} { import_files -fileset constrs_1 $_noc_xdc }
}

#─────────────────────────────────────────────────────────────────────────────────
# Step 4: Add Simulation Files
#─────────────────────────────────────────────────────────────────────────────────
set sim_files {}
catch {set sim_files [glob $base_dir/Sources/Simulation/*]}
if {[llength $sim_files] > 0} {
    import_files -fileset sim_1 $sim_files
}

#─────────────────────────────────────────────────────────────────────────────────
# Step 5: Add Data Files (Memory init, config, etc.)
#─────────────────────────────────────────────────────────────────────────────────
set data_files {}
catch {set data_files [glob $base_dir/Sources/Data/*]}
if {[llength $data_files] > 0} {
    import_files $data_files
}

#─────────────────────────────────────────────────────────────────────────────────
# Step 6: Recreate IP Cores
#─────────────────────────────────────────────────────────────────────────────────
set ip_tcls {}
catch {set ip_tcls [glob $base_dir/Sources/IP/*.tcl]}
foreach ip_tcl $ip_tcls {
    source $ip_tcl
}

# Create OOC synthesis runs for standalone IPs (outside Block Designs)
set standalone_ips [get_ips]
foreach ip $standalone_ips {
    set is_bd [get_property IS_BD_CONTEXT $ip]
    if {$is_bd ne "1" && $is_bd ne "true"} {
        catch {create_ip_run [get_ips [get_property NAME $ip]]}
    }
}

#─────────────────────────────────────────────────────────────────────────────────
# Step 7: Recreate Block Designs
# CRITICAL: BDC child BDs must be sourced BEFORE parent BDs that instantiate them.
# For DFX: RM Block Designs are skipped here — they are added to RM filesets in
#          Step 12 (dfx_define_partition) to prevent them from becoming independent BDs.
#─────────────────────────────────────────────────────────────────────────────────
set bd_is_rm_owned 0
if {[info exists _rm_owned_bd_names]} {
    set bd_is_rm_owned [expr {[lsearch $_rm_owned_bd_names "design_1"] >= 0}]
}
if {$bd_is_rm_owned} {
    puts "  Skipping BD (RM-owned): design_1 — will be added to RM fileset in Step 12"
} elseif {0} {
    # Preserved BD (remote cache mode): add_files the .bd restored from the
    # cache in Step 1c, and rely on the .gen restored there too to avoid
    # regeneration. Non-preserved BDs use the standard Tcl-regeneration path
    # below -- this branch is per-BD, not global. Step 1c already guarantees
    # this source exists (it errors out the whole build otherwise).
    add_files -norecurse [file join ${proj_name}.srcs {} {design_1.bd}]
    if {[catch {generate_target all [get_files design_1.bd]} _gt_pres_err]} {
        puts "  WARNING: generate_target failed for preserved BD design_1: $_gt_pres_err"
    }
    # add_files alone does not open the BD as a live design -- validate_bd_design
    # / save_bd_design / get_bd_designs need open_bd_design first, or they fail
    # with 'Cannot find design named ...' / 'A block design must be open'.
    catch {open_bd_design [get_files design_1.bd]}
    catch {validate_bd_design -force -design design_1}
    catch {save_bd_design [get_bd_designs -quiet design_1]}
} else {
    set bd_tcl $base_dir/Sources/BD/design_1.tcl
    if {[file exists $bd_tcl]} {
        puts "  Sourcing BD: design_1"
        source $bd_tcl
        # Validate immediately: BDC parents that reference this BD as a
        # container (create_bd_cell -type container -reference) require it
        # to be validated first, otherwise cell creation fails.
        if {[catch {validate_bd_design -force -design design_1} _vbd_err]} {
            puts "  WARNING: validate_bd_design reported an error for design_1: $_vbd_err"
            puts "  This is usually caused by locked/out-of-date IPs in the BD."
            puts "  On the ORIGINAL project: open_bd_design design_1.bd; report_ip_status"
            puts "  then upgrade_ip the flagged IPs and re-run this export."
            puts "  NOTE: Vivado now treats this session as having a logged error --"
            puts "  later commands (e.g. make_wrapper) may fail with 'failed due to"
            puts "  earlier errors' even though THIS is the real root cause."
        }
        # Persist the validated state — without this, a sibling BD sourced
        # later that references this BD as a BDC container may see it as
        # not validated (validate_bd_design alone is not enough).
        catch {save_bd_design [get_bd_designs -quiet design_1]}
    } else {
        puts "  WARNING: BD tcl not exported, skipping: design_1"
    }
}


#─────────────────────────────────────────────────────────────────────────────────
# Step 8: Recreate Block Design wrappers (only if wrapper was present in project)
#─────────────────────────────────────────────────────────────────────────────────
# Create and add wrapper for BD: design_1
set bd_obj [get_files -quiet design_1.bd]
if {[llength $bd_obj] > 0} {
    if {[catch {set wrapper_path [make_wrapper -files $bd_obj -top]} _mw_err]} {
        puts "  ERROR: make_wrapper failed for design_1: $_mw_err"
        puts "  This almost always means an EARLIER step already logged an error"
        puts "  for this BD (search this log above for WARNING/ERROR mentioning"
        puts "  design_1 -- commonly locked/out-of-date IPs from Step 7)."
        puts "  Fix on the ORIGINAL project (report_ip_status / upgrade_ip), then"
        puts "  re-run the export/build pipeline."
    } else {
        import_files $wrapper_path
    }
}


#─────────────────────────────────────────────────────────────────────────────────
# Step 9: Generate BD Targets and Create BD IP OOC Runs
# NOTE: Only operate on top-level user BDs from sources_1 fileset.
#       Nested sub-designs (e.g., inside Versal CIPS) are auto-generated by
#       their parent IP and MUST NOT be generated independently.
#       Using FILE_TYPE filter + .srcs path check to exclude them.
#─────────────────────────────────────────────────────────────────────────────────
set bd_files {}
catch {set bd_files [get_files -filter {FILE_TYPE == "Block Designs"} -of_objects [get_filesets sources_1]]}
foreach bd $bd_files {
    set bd_norm [file normalize $bd]
    # Skip nested sub-designs in .gen/ (auto-generated by parent IPs like Versal CIPS)
    if {[string match "*/.gen/*" $bd_norm]} {
        puts "  Skipping nested sub-design: [file tail $bd]"
        continue
    }
    # Skip generated BDs
    if {[get_property IS_GENERATED $bd] eq "1"} {
        puts "  Skipping generated BD: [file tail $bd]"
        continue
    }
    puts "  Generating targets for: [file tail $bd]"
    if {[catch {generate_target all $bd} _gt_err]} {
        puts "  ERROR: generate_target failed for [file tail $bd]: $_gt_err"
        puts "  Check the ERROR/CRITICAL WARNING lines just above for the real root"
        puts "  cause. Two known classes seen in this skill's own validation:"
        puts "    1) Debug-net (mark_debug/ILA) connections routed through a Block"
        puts "       Design Container failing to resolve on a freshly recreated"
        puts "       design ('Could not find the cell' errors) -- not an export"
        puts "       issue. Workaround: remove debug cores from the BD before"
        puts "       export, or manually regenerate targets for [file tail $bd]"
        puts "       in the GUI."
        puts "    2) A NoC memory-controller PHY IP (e.g. noc_mc_ddr5_phy_v1_0)"
        puts "       failing to generate simulation BFM outputs due to a missing"
        puts "       file under this Vivado install's own"
        puts "       data/ip/xilinx/<ip>/hdl/bfm/ tree ('Failed to copy file ..."
        puts "       it does not exist' CRITICAL WARNING) -- a Vivado installation"
        puts "       gap, not something export/rebuild can fix; report it to your"
        puts "       Vivado install owner."
    }
}

# Create OOC runs for IPs within top-level Block Designs only
foreach bd $bd_files {
    set bd_norm [file normalize $bd]
    if {[string match "*/.gen/*" $bd_norm]} { continue }
    if {[get_property IS_GENERATED $bd] eq "1"} { continue }
    catch {create_ip_run [get_ips -of_objects [get_files $bd]]}
}

#─────────────────────────────────────────────────────────────────────────────────
# Step 10: Add Hook Scripts to utils_1 fileset
#─────────────────────────────────────────────────────────────────────────────────
set hook_scripts {}
catch {set hook_scripts [glob $base_dir/Sources/Scripts/*.tcl]}
if {[llength $hook_scripts] > 0} {
    import_files -fileset utils_1 $hook_scripts
}

#─────────────────────────────────────────────────────────────────────────────────
# Step 11: Apply Captured Project Settings
#─────────────────────────────────────────────────────────────────────────────────
source $script_dir/project_settings.tcl
update_compile_order -fileset sources_1

#─────────────────────────────────────────────────────────────────────────────────
# Step 11b: Restore fileset source ordering (if captured)
#─────────────────────────────────────────────────────────────────────────────────
proc _rc_restore_fileset_order {fileset_name ordered_tails} {
    if {[llength [get_filesets -quiet $fileset_name]] == 0} { return }
    set last_file ""
    foreach tail $ordered_tails {
        set match {}
        catch {set match [get_files -quiet -of_objects [get_filesets $fileset_name] -filter "NAME =~ *${tail}"]}
        if {[llength $match] == 0} { continue }
        set f [lindex $match 0]
        if {$last_file eq ""} {
            catch {reorder_files -fileset $fileset_name -front $f}
        } else {
            catch {reorder_files -fileset $fileset_name -after $last_file $f}
        }
        set last_file $f
    }
    catch {update_compile_order -fileset $fileset_name}
}

_rc_restore_fileset_order constrs_1 pynq_z2.xdc
_rc_restore_fileset_order design_1_axi_dynclk_0_0 {design_1_axi_dynclk_0_0.xci axi_dynclk.xdc mmcme2_drp.v SyncAsync.vhd axi_dynclk_S00_AXI.vhd axi_dynclk.vhd design_1_axi_dynclk_0_0.vhd design_1_axi_dynclk_0_0.dcp design_1_axi_dynclk_0_0_stub.v design_1_axi_dynclk_0_0_stub.vhdl design_1_axi_dynclk_0_0_sim_netlist.v design_1_axi_dynclk_0_0_sim_netlist.vhdl dynclk.mdd dynclk.tcl Makefile ddynclk.h ddynclk.c ddynclk_selftest.c ddynclk_g.c ddynclk_sinit.c design_1_axi_dynclk_0_0.vhd}
_rc_restore_fileset_order design_1_axi_gpio_0_0 {design_1_axi_gpio_0_0.xci design_1_axi_gpio_0_0_board.xdc axi_lite_ipif_v3_1_rfs.vhd interrupt_control_v3_2_rfs.vhd design_1_axi_gpio_0_0_ooc.xdc axi_gpio_v2_0_rfs.vhd design_1_axi_gpio_0_0.vhd design_1_axi_gpio_0_0.dcp design_1_axi_gpio_0_0_stub.v design_1_axi_gpio_0_0_stub.vhdl design_1_axi_gpio_0_0_sim_netlist.v design_1_axi_gpio_0_0_sim_netlist.vhdl design_1_axi_gpio_0_0.vhd}
_rc_restore_fileset_order design_1_proc_sys_reset_0_0 {design_1_proc_sys_reset_0_0.xci design_1_proc_sys_reset_0_0_board.xdc proc_sys_reset_v5_0_rfs.vhd design_1_proc_sys_reset_0_0.vhd design_1_proc_sys_reset_0_0.dcp design_1_proc_sys_reset_0_0_stub.v design_1_proc_sys_reset_0_0_stub.vhdl design_1_proc_sys_reset_0_0_sim_netlist.v design_1_proc_sys_reset_0_0_sim_netlist.vhdl design_1_proc_sys_reset_0_0.vhd design_1_proc_sys_reset_0_0_ooc.xdc}
_rc_restore_fileset_order design_1_proc_sys_reset_1_0 {design_1_proc_sys_reset_1_0.xci design_1_proc_sys_reset_1_0_board.xdc proc_sys_reset_v5_0_rfs.vhd design_1_proc_sys_reset_1_0.vhd design_1_proc_sys_reset_1_0.dcp design_1_proc_sys_reset_1_0_stub.v design_1_proc_sys_reset_1_0_stub.vhdl design_1_proc_sys_reset_1_0_sim_netlist.v design_1_proc_sys_reset_1_0_sim_netlist.vhdl design_1_proc_sys_reset_1_0.vhd design_1_proc_sys_reset_1_0_ooc.xdc}
_rc_restore_fileset_order design_1_proc_sys_reset_2_0 {design_1_proc_sys_reset_2_0.xci design_1_proc_sys_reset_2_0_board.xdc proc_sys_reset_v5_0_rfs.vhd design_1_proc_sys_reset_2_0.vhd design_1_proc_sys_reset_2_0.dcp design_1_proc_sys_reset_2_0_stub.v design_1_proc_sys_reset_2_0_stub.vhdl design_1_proc_sys_reset_2_0_sim_netlist.v design_1_proc_sys_reset_2_0_sim_netlist.vhdl design_1_proc_sys_reset_2_0.vhd design_1_proc_sys_reset_2_0_ooc.xdc}
_rc_restore_fileset_order design_1_processing_system7_0_0 {design_1_processing_system7_0_0.xci axi_infrastructure_v1_1_0.vh axi_infrastructure_v1_1_vl_rfs.v axi_vip_v1_1_vl_rfs.sv processing_system7_vip_v1_0_25_local_params.v processing_system7_vip_v1_0_vl_rfs.sv processing_system7_vip_v1_0_25_reg_params.v processing_system7_vip_v1_0_25_reg_init.v processing_system7_vip_v1_0_25_apis.v processing_system7_vip_v1_0_25_unused_ports.v processing_system7_vip_v1_0_25_axi_gp.v processing_system7_vip_v1_0_25_axi_acp.v processing_system7_vip_v1_0_25_axi_hp.v design_1_processing_system7_0_0.v design_1_processing_system7_0_0.dcp design_1_processing_system7_0_0_stub.v design_1_processing_system7_0_0_stub.vhdl design_1_processing_system7_0_0_sim_netlist.v design_1_processing_system7_0_0_sim_netlist.vhdl design_1_processing_system7_0_0.xdc design_1_processing_system7_0_0.hwdef ps7_init.c ps7_init.h ps7_init_gpl.c ps7_init_gpl.h ps7_init.tcl ps7_init.html processing_system7_v5_5_aw_atc.v processing_system7_v5_5_b_atc.v processing_system7_v5_5_w_atc.v processing_system7_v5_5_atc.v processing_system7_v5_5_trace_buffer.v processing_system7_v5_5_processing_system7.v design_1_processing_system7_0_0.v}
_rc_restore_fileset_order design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0 {design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0.xci generic_baseblocks_v2_1_rfs.v axi_infrastructure_v1_1_0.vh axi_infrastructure_v1_1_vl_rfs.v axi_register_slice_v2_1_rfs.v fifo_generator_vlog_beh.v axi_data_fifo_v2_1_vl_rfs.v axi_crossbar_v2_1_vl_rfs.v design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0.v design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0.dcp design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0_stub.v design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0_stub.vhdl design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0_sim_netlist.v design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0_sim_netlist.vhdl design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0.v design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0_ooc.xdc}
_rc_restore_fileset_order design_1_rgb2dvi_0_0 {design_1_rgb2dvi_0_0.xci rgb2dvi.xdc rgb2dvi_ooc.xdc rgb2dvi_clocks.xdc ClockGen.vhd SyncAsync.vhd SyncAsyncReset.vhd DVI_Constants.vhd OutputSERDES.vhd TMDS_Encoder.vhd rgb2dvi.vhd design_1_rgb2dvi_0_0.vhd design_1_rgb2dvi_0_0.dcp design_1_rgb2dvi_0_0_stub.v design_1_rgb2dvi_0_0_stub.vhdl design_1_rgb2dvi_0_0_sim_netlist.v design_1_rgb2dvi_0_0_sim_netlist.vhdl design_1_rgb2dvi_0_0.vhd}
_rc_restore_fileset_order design_1_v_axi4s_vid_out_0_0 {design_1_v_axi4s_vid_out_0_0.xci axi_lite_ipif_v3_0_vh_rfs.vhd v_vid_in_axi4s_v5_0_rfs.v design_1_v_axi4s_vid_out_0_0_clocks.xdc v_axi4s_vid_out_v4_0_rfs.v design_1_v_axi4s_vid_out_0_0.v design_1_v_axi4s_vid_out_0_0.dcp design_1_v_axi4s_vid_out_0_0_stub.v design_1_v_axi4s_vid_out_0_0_stub.vhdl design_1_v_axi4s_vid_out_0_0_sim_netlist.v design_1_v_axi4s_vid_out_0_0_sim_netlist.vhdl design_1_v_axi4s_vid_out_0_0.v design_1_v_axi4s_vid_out_0_0_ooc.xdc}
_rc_restore_fileset_order design_1_v_frmbuf_rd_0_0 {design_1_v_frmbuf_rd_0_0.xci design_1_v_frmbuf_rd_0_0_AXIMMvideo2Bytes.v design_1_v_frmbuf_rd_0_0_AXIMMvideo2Bytes_Pipeline_VITIS_LOOP_557_1.v design_1_v_frmbuf_rd_0_0_Bytes2MultiPixStream.v design_1_v_frmbuf_rd_0_0_Bytes2MultiPixStream_Pipeline_VITIS_LOOP_1627_1.v design_1_v_frmbuf_rd_0_0_Bytes2MultiPixStream_Pipeline_VITIS_LOOP_2307_4.v design_1_v_frmbuf_rd_0_0_BYTES_PER_PIXEL_ROM_AUTO_1R.dat design_1_v_frmbuf_rd_0_0_BYTES_PER_PIXEL_ROM_AUTO_1R.v design_1_v_frmbuf_rd_0_0_CTRL_s_axi.v design_1_v_frmbuf_rd_0_0_fifo_w24_d2_S.v design_1_v_frmbuf_rd_0_0_fifo_w64_d961_B.v design_1_v_frmbuf_rd_0_0_flow_control_loop_pipe_sequential_init.v design_1_v_frmbuf_rd_0_0_FrmbufRdHlsDataFlow.v design_1_v_frmbuf_rd_0_0_hls_deadlock_detection_unit.v design_1_v_frmbuf_rd_0_0_hls_deadlock_detector.vh design_1_v_frmbuf_rd_0_0_hls_deadlock_idx0_monitor.v design_1_v_frmbuf_rd_0_0_hls_deadlock_kernel_monitor_top.vh design_1_v_frmbuf_rd_0_0_hls_deadlock_report_unit.vh design_1_v_frmbuf_rd_0_0_MEMORY2LIVE_ROM_AUTO_1R.dat design_1_v_frmbuf_rd_0_0_MEMORY2LIVE_ROM_AUTO_1R.v design_1_v_frmbuf_rd_0_0_mm_video_m_axi.v design_1_v_frmbuf_rd_0_0_mul_12ns_14ns_25_2_1.v design_1_v_frmbuf_rd_0_0_mul_15s_3ns_15_2_1.v design_1_v_frmbuf_rd_0_0_MultiPixStream2AXIvideo.v design_1_v_frmbuf_rd_0_0_MultiPixStream2AXIvideo_Pipeline_VITIS_LOOP_405_1.v design_1_v_frmbuf_rd_0_0_MultiPixStream2AXIvideo_Pipeline_VITIS_LOOP_405_1_mapComp_ROM_AUTO_1R.dat design_1_v_frmbuf_rd_0_0_MultiPixStream2AXIvideo_Pipeline_VITIS_LOOP_405_1_mapComp_ROM_AUTO_1R.v design_1_v_frmbuf_rd_0_0_MultiPixStream2AXIvideo_Pipeline_VITIS_LOOP_414_3.v design_1_v_frmbuf_rd_0_0_reg_unsigned_short_s.v design_1_v_frmbuf_rd_0_0_regslice_both.v design_1_v_frmbuf_rd_0_0_sparsemux_7_2_8_1_1.v design_1_v_frmbuf_rd_0_0_start_for_Bytes2MultiPixStream_U0.v design_1_v_frmbuf_rd_0_0_start_for_MultiPixStream2AXIvideo_U0.v design_1_v_frmbuf_rd_0_0_urem_12ns_3ns_2_16_seq_1.v design_1_v_frmbuf_rd_0_0_v_frmbuf_rd.v design_1_v_frmbuf_rd_0_0.xdc design_1_v_frmbuf_rd_0_0.v design_1_v_frmbuf_rd_0_0.dcp design_1_v_frmbuf_rd_0_0_stub.v design_1_v_frmbuf_rd_0_0_stub.vhdl design_1_v_frmbuf_rd_0_0_sim_netlist.v design_1_v_frmbuf_rd_0_0_sim_netlist.vhdl design_1_v_frmbuf_rd_0_0.v design_1_v_frmbuf_rd_0_0_ooc.xdc hls_commands.txt v_frmbuf_rd_config.h v_frmbuf_rd.h hls_video.h hls_opencv.h hls_axi_io.h hls_video_arithm.h hls_video_core.h hls_video_fast.h hls_video_haar.h hls_video_harris.h hls_video_histogram.h hls_video_hough.h hls_video_imgbase.h hls_video_imgproc.h hls_video_io.h hls_video_mem.h hls_video_stereobm.h hls_video_types.h hls_video_undistort.h}
_rc_restore_fileset_order design_1_v_tc_0_0 {design_1_v_tc_0_0.xci axi_lite_ipif_v3_0_vh_rfs.vhd design_1_v_tc_0_0_clocks.xdc design_1_v_tc_0_0.vhd design_1_v_tc_0_0.dcp design_1_v_tc_0_0_stub.v design_1_v_tc_0_0_stub.vhdl design_1_v_tc_0_0.vhd design_1_v_tc_0_0_ooc.xdc}
_rc_restore_fileset_order sources_1 {design_1.bd design_1_processing_system7_0_0.xci axi_infrastructure_v1_1_0.vh axi_infrastructure_v1_1_vl_rfs.v axi_vip_v1_1_vl_rfs.sv processing_system7_vip_v1_0_25_local_params.v processing_system7_vip_v1_0_vl_rfs.sv processing_system7_vip_v1_0_25_reg_params.v processing_system7_vip_v1_0_25_reg_init.v processing_system7_vip_v1_0_25_apis.v processing_system7_vip_v1_0_25_unused_ports.v processing_system7_vip_v1_0_25_axi_gp.v processing_system7_vip_v1_0_25_axi_acp.v processing_system7_vip_v1_0_25_axi_hp.v design_1_processing_system7_0_0.v design_1_processing_system7_0_0.dcp design_1_processing_system7_0_0_stub.v design_1_processing_system7_0_0_stub.vhdl design_1_processing_system7_0_0_sim_netlist.v design_1_processing_system7_0_0_sim_netlist.vhdl design_1_processing_system7_0_0.xdc design_1_processing_system7_0_0.hwdef ps7_init.c ps7_init.h ps7_init_gpl.c ps7_init_gpl.h ps7_init.tcl ps7_init.html processing_system7_v5_5_aw_atc.v processing_system7_v5_5_b_atc.v processing_system7_v5_5_w_atc.v processing_system7_v5_5_atc.v processing_system7_v5_5_trace_buffer.v processing_system7_v5_5_processing_system7.v design_1_processing_system7_0_0.v design_1_xlconcat_0_0.xci xlconcat_v2_1_rfs.v design_1_xlconcat_0_0.v design_1_xlconcat_0_0.v design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0.xci generic_baseblocks_v2_1_rfs.v axi_infrastructure_v1_1_0.vh axi_infrastructure_v1_1_vl_rfs.v axi_register_slice_v2_1_rfs.v fifo_generator_vlog_beh.v axi_data_fifo_v2_1_vl_rfs.v axi_crossbar_v2_1_vl_rfs.v design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0.v design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0.dcp design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0_stub.v design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0_stub.vhdl design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0_sim_netlist.v design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0_sim_netlist.vhdl design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0.v design_1_ps7_0_axi_periph_upgraded_ipi_imp_xbar_0_ooc.xdc design_1_ps7_0_axi_periph_imp_auto_pc_0.xci generic_baseblocks_v2_1_rfs.v fifo_generator_vlog_beh.v axi_data_fifo_v2_1_vl_rfs.v axi_infrastructure_v1_1_0.vh axi_infrastructure_v1_1_vl_rfs.v axi_register_slice_v2_1_rfs.v axi_protocol_converter_v2_1_vl_rfs.v design_1_ps7_0_axi_periph_imp_auto_pc_0.v design_1_ps7_0_axi_periph_imp_auto_pc_0.dcp design_1_ps7_0_axi_periph_imp_auto_pc_0_sim_netlist.v design_1_ps7_0_axi_periph_imp_auto_pc_0_sim_netlist.vhdl design_1_ps7_0_axi_periph_imp_auto_pc_0_stub.v design_1_ps7_0_axi_periph_imp_auto_pc_0_stub.vhdl design_1_ps7_0_axi_periph_imp_auto_pc_0_ooc.xdc design_1_ps7_0_axi_periph_imp_auto_pc_0.v design_1_ps7_0_axi_periph_imp_auto_cc_0.xci design_1_ps7_0_axi_periph_imp_auto_cc_0_clocks.xdc axi_infrastructure_v1_1_0.vh axi_infrastructure_v1_1_vl_rfs.v fifo_generator_vlog_beh.v design_1_ps7_0_axi_periph_imp_auto_cc_0_ooc.xdc axi_clock_converter_v2_1_vl_rfs.v design_1_ps7_0_axi_periph_imp_auto_cc_0.v design_1_ps7_0_axi_periph_imp_auto_cc_0.dcp design_1_ps7_0_axi_periph_imp_auto_cc_0_sim_netlist.v design_1_ps7_0_axi_periph_imp_auto_cc_0_sim_netlist.vhdl design_1_ps7_0_axi_periph_imp_auto_cc_0_stub.v design_1_ps7_0_axi_periph_imp_auto_cc_0_stub.vhdl design_1_ps7_0_axi_periph_imp_auto_cc_0.v design_1_axi_mem_intercon_imp_auto_pc_0.xci generic_baseblocks_v2_1_rfs.v fifo_generator_vlog_beh.v axi_data_fifo_v2_1_vl_rfs.v axi_infrastructure_v1_1_0.vh axi_infrastructure_v1_1_vl_rfs.v axi_register_slice_v2_1_rfs.v axi_protocol_converter_v2_1_vl_rfs.v design_1_axi_mem_intercon_imp_auto_pc_0.v design_1_axi_mem_intercon_imp_auto_pc_0.dcp design_1_axi_mem_intercon_imp_auto_pc_0_stub.v design_1_axi_mem_intercon_imp_auto_pc_0_stub.vhdl design_1_axi_mem_intercon_imp_auto_pc_0_ooc.xdc design_1_axi_mem_intercon_imp_auto_pc_0.v design_1_v_frmbuf_rd_0_0.xci design_1_v_frmbuf_rd_0_0_AXIMMvideo2Bytes.v design_1_v_frmbuf_rd_0_0_AXIMMvideo2Bytes_Pipeline_VITIS_LOOP_557_1.v design_1_v_frmbuf_rd_0_0_Bytes2MultiPixStream.v design_1_v_frmbuf_rd_0_0_Bytes2MultiPixStream_Pipeline_VITIS_LOOP_1627_1.v design_1_v_frmbuf_rd_0_0_Bytes2MultiPixStream_Pipeline_VITIS_LOOP_2307_4.v design_1_v_frmbuf_rd_0_0_BYTES_PER_PIXEL_ROM_AUTO_1R.dat design_1_v_frmbuf_rd_0_0_BYTES_PER_PIXEL_ROM_AUTO_1R.v design_1_v_frmbuf_rd_0_0_CTRL_s_axi.v design_1_v_frmbuf_rd_0_0_fifo_w24_d2_S.v design_1_v_frmbuf_rd_0_0_fifo_w64_d961_B.v design_1_v_frmbuf_rd_0_0_flow_control_loop_pipe_sequential_init.v design_1_v_frmbuf_rd_0_0_FrmbufRdHlsDataFlow.v design_1_v_frmbuf_rd_0_0_hls_deadlock_detection_unit.v design_1_v_frmbuf_rd_0_0_hls_deadlock_detector.vh design_1_v_frmbuf_rd_0_0_hls_deadlock_idx0_monitor.v design_1_v_frmbuf_rd_0_0_hls_deadlock_kernel_monitor_top.vh design_1_v_frmbuf_rd_0_0_hls_deadlock_report_unit.vh design_1_v_frmbuf_rd_0_0_MEMORY2LIVE_ROM_AUTO_1R.dat design_1_v_frmbuf_rd_0_0_MEMORY2LIVE_ROM_AUTO_1R.v design_1_v_frmbuf_rd_0_0_mm_video_m_axi.v design_1_v_frmbuf_rd_0_0_mul_12ns_14ns_25_2_1.v design_1_v_frmbuf_rd_0_0_mul_15s_3ns_15_2_1.v design_1_v_frmbuf_rd_0_0_MultiPixStream2AXIvideo.v design_1_v_frmbuf_rd_0_0_MultiPixStream2AXIvideo_Pipeline_VITIS_LOOP_405_1.v design_1_v_frmbuf_rd_0_0_MultiPixStream2AXIvideo_Pipeline_VITIS_LOOP_405_1_mapComp_ROM_AUTO_1R.dat design_1_v_frmbuf_rd_0_0_MultiPixStream2AXIvideo_Pipeline_VITIS_LOOP_405_1_mapComp_ROM_AUTO_1R.v design_1_v_frmbuf_rd_0_0_MultiPixStream2AXIvideo_Pipeline_VITIS_LOOP_414_3.v design_1_v_frmbuf_rd_0_0_reg_unsigned_short_s.v design_1_v_frmbuf_rd_0_0_regslice_both.v design_1_v_frmbuf_rd_0_0_sparsemux_7_2_8_1_1.v design_1_v_frmbuf_rd_0_0_start_for_Bytes2MultiPixStream_U0.v design_1_v_frmbuf_rd_0_0_start_for_MultiPixStream2AXIvideo_U0.v design_1_v_frmbuf_rd_0_0_urem_12ns_3ns_2_16_seq_1.v design_1_v_frmbuf_rd_0_0_v_frmbuf_rd.v design_1_v_frmbuf_rd_0_0.xdc design_1_v_frmbuf_rd_0_0.v design_1_v_frmbuf_rd_0_0.dcp design_1_v_frmbuf_rd_0_0_stub.v design_1_v_frmbuf_rd_0_0_stub.vhdl design_1_v_frmbuf_rd_0_0_sim_netlist.v design_1_v_frmbuf_rd_0_0_sim_netlist.vhdl design_1_v_frmbuf_rd_0_0.v design_1_v_frmbuf_rd_0_0_ooc.xdc hls_commands.txt v_frmbuf_rd_config.h v_frmbuf_rd.h hls_video.h hls_opencv.h hls_axi_io.h hls_video_arithm.h hls_video_core.h hls_video_fast.h hls_video_haar.h hls_video_harris.h hls_video_histogram.h hls_video_hough.h hls_video_imgbase.h hls_video_imgproc.h hls_video_io.h hls_video_mem.h hls_video_stereobm.h hls_video_types.h hls_video_undistort.h design_1_v_axi4s_vid_out_0_0.xci axi_lite_ipif_v3_0_vh_rfs.vhd v_vid_in_axi4s_v5_0_rfs.v design_1_v_axi4s_vid_out_0_0_clocks.xdc v_axi4s_vid_out_v4_0_rfs.v design_1_v_axi4s_vid_out_0_0.v design_1_v_axi4s_vid_out_0_0.dcp design_1_v_axi4s_vid_out_0_0_stub.v design_1_v_axi4s_vid_out_0_0_stub.vhdl design_1_v_axi4s_vid_out_0_0_sim_netlist.v design_1_v_axi4s_vid_out_0_0_sim_netlist.vhdl design_1_v_axi4s_vid_out_0_0.v design_1_v_axi4s_vid_out_0_0_ooc.xdc design_1_v_tc_0_0.xci axi_lite_ipif_v3_0_vh_rfs.vhd design_1_v_tc_0_0_clocks.xdc design_1_v_tc_0_0.vhd design_1_v_tc_0_0.dcp design_1_v_tc_0_0_stub.v design_1_v_tc_0_0_stub.vhdl design_1_v_tc_0_0.vhd design_1_v_tc_0_0_ooc.xdc design_1_axi_dynclk_0_0.xci axi_dynclk.xdc mmcme2_drp.v SyncAsync.vhd axi_dynclk_S00_AXI.vhd axi_dynclk.vhd design_1_axi_dynclk_0_0.vhd design_1_axi_dynclk_0_0.dcp design_1_axi_dynclk_0_0_stub.v design_1_axi_dynclk_0_0_stub.vhdl design_1_axi_dynclk_0_0_sim_netlist.v design_1_axi_dynclk_0_0_sim_netlist.vhdl dynclk.mdd dynclk.tcl Makefile ddynclk.h ddynclk.c ddynclk_selftest.c ddynclk_g.c ddynclk_sinit.c design_1_axi_dynclk_0_0.vhd design_1_rgb2dvi_0_0.xci rgb2dvi.xdc rgb2dvi_ooc.xdc rgb2dvi_clocks.xdc ClockGen.vhd SyncAsync.vhd SyncAsyncReset.vhd DVI_Constants.vhd OutputSERDES.vhd TMDS_Encoder.vhd rgb2dvi.vhd design_1_rgb2dvi_0_0.vhd design_1_rgb2dvi_0_0.dcp design_1_rgb2dvi_0_0_stub.v design_1_rgb2dvi_0_0_stub.vhdl design_1_rgb2dvi_0_0_sim_netlist.v design_1_rgb2dvi_0_0_sim_netlist.vhdl design_1_rgb2dvi_0_0.vhd design_1_axi_gpio_0_0.xci design_1_axi_gpio_0_0_board.xdc axi_lite_ipif_v3_1_rfs.vhd interrupt_control_v3_2_rfs.vhd design_1_axi_gpio_0_0_ooc.xdc axi_gpio_v2_0_rfs.vhd design_1_axi_gpio_0_0.vhd design_1_axi_gpio_0_0.dcp design_1_axi_gpio_0_0_stub.v design_1_axi_gpio_0_0_stub.vhdl design_1_axi_gpio_0_0_sim_netlist.v design_1_axi_gpio_0_0_sim_netlist.vhdl design_1_axi_gpio_0_0.vhd design_1_proc_sys_reset_2_0.xci design_1_proc_sys_reset_2_0_board.xdc proc_sys_reset_v5_0_rfs.vhd design_1_proc_sys_reset_2_0.vhd design_1_proc_sys_reset_2_0.dcp design_1_proc_sys_reset_2_0_stub.v design_1_proc_sys_reset_2_0_stub.vhdl design_1_proc_sys_reset_2_0_sim_netlist.v design_1_proc_sys_reset_2_0_sim_netlist.vhdl design_1_proc_sys_reset_2_0.vhd design_1_proc_sys_reset_2_0_ooc.xdc design_1_proc_sys_reset_0_0.xci design_1_proc_sys_reset_0_0_board.xdc proc_sys_reset_v5_0_rfs.vhd design_1_proc_sys_reset_0_0.vhd design_1_proc_sys_reset_0_0.dcp design_1_proc_sys_reset_0_0_stub.v design_1_proc_sys_reset_0_0_stub.vhdl design_1_proc_sys_reset_0_0_sim_netlist.v design_1_proc_sys_reset_0_0_sim_netlist.vhdl design_1_proc_sys_reset_0_0.vhd design_1_proc_sys_reset_0_0_ooc.xdc design_1_proc_sys_reset_1_0.xci design_1_proc_sys_reset_1_0_board.xdc proc_sys_reset_v5_0_rfs.vhd design_1_proc_sys_reset_1_0.vhd design_1_proc_sys_reset_1_0.dcp design_1_proc_sys_reset_1_0_stub.v design_1_proc_sys_reset_1_0_stub.vhdl design_1_proc_sys_reset_1_0_sim_netlist.v design_1_proc_sys_reset_1_0_sim_netlist.vhdl design_1_proc_sys_reset_1_0.vhd design_1_proc_sys_reset_1_0_ooc.xdc design_1.v design_1.v design_1.vho design_1.veo design_1_sv.sveo design_1_ooc.xdc design_1.hwh design_1.bda design_1.hwdef design_1.protoinst design_1_wrapper.v}
_rc_restore_fileset_order utils_1 design_1_wrapper.dcp

#─────────────────────────────────────────────────────────────────────────────────
# Step 13: Finalize Project
#─────────────────────────────────────────────────────────────────────────────────
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "──────────────────────────────────────────────────────────────────────────"
puts "Project recreated successfully!"
puts "──────────────────────────────────────────────────────────────────────────"
