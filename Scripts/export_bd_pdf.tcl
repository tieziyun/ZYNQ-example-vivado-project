#*******************************************************************************
# export_bd_pdf.tcl - Write the block design diagram to docs/design_1.pdf
#
# Usage, from the Vivado GUI Tcl console (write_bd_layout needs the GUI):
#   source <repo>/Scripts/export_bd_pdf.tcl
#
# Page 1 is the top level; each user hierarchy (hdmi_display, resets) gets its
# own page, with a PDF bookmark per page. Vivado writes one PDF per drawing, so
# the pages go to build/bd_pdf/ and Scripts/merge_pdfs.py combines them
# (needs Python with pypdf: python -m pip install pypdf).
#
# Opens build/vivado_project.xpr if no project is open. Run it again after
# changing the block design, then commit the updated PDF.
#*******************************************************************************

set script_dir [file dirname [file normalize [info script]]]
set base_dir [file dirname $script_dir]
set xpr [file join $base_dir build vivado_project.xpr]

if {[catch {current_project}]} {
    if {![file exists $xpr]} {
        error "No project found. Run Scripts/build.tcl first."
    }
    open_project $xpr
}

open_bd_design [get_files design_1.bd]
set page_dir [file join $base_dir build bd_pdf]
file delete -force $page_dir
file mkdir $page_dir
file mkdir [file join $base_dir docs]

# Portrait keeps the drawing upright (landscape rotates it on the page).
# Colors follow the Vivado GUI theme.

# Top level, where hdmi_display and resets appear as collapsed blocks
set page [file join $page_dir 0_top.pdf]
write_bd_layout -force -format pdf -orientation portrait $page
set pages [list "design_1 (top level)=$page"]

# One page per user hierarchy (VLNV is empty; AXI interconnects are IP and
# are skipped), showing the blocks inside it
foreach hier [get_bd_cells -filter {TYPE == hier && VLNV == ""}] {
    set name [string trimleft $hier /]
    set page [file join $page_dir 1_${name}.pdf]
    write_bd_layout -force -format pdf -orientation portrait -hierarchy [get_bd_cells $hier] $page
    lappend pages "$name=$page"
}

set pdf [file join $base_dir docs design_1.pdf]
# Inside Vivado, "python" is Vivado's bundled interpreter (no pypdf), and
# PYTHONHOME/PYTHONPATH point at it. Use the system Python (py launcher on
# Windows) with those two variables cleared for the call.
# Set PDF_MERGE_PYTHON to the interpreter to use instead.
if {[info exists ::env(PDF_MERGE_PYTHON)]} {
    set python [list $::env(PDF_MERGE_PYTHON)]
} elseif {$tcl_platform(platform) eq "windows"} {
    set python [list py -3]
} else {
    set python [list python3]
}
set saved_env {}
foreach var {PYTHONHOME PYTHONPATH} {
    if {[info exists ::env($var)]} {
        dict set saved_env $var $::env($var)
        unset ::env($var)
    }
}
set merge_failed [catch {exec -ignorestderr {*}$python [file join $script_dir merge_pdfs.py] $pdf {*}$pages} merge_msg]
dict for {var value} $saved_env { set ::env($var) $value }
if {$merge_failed} {
    error "Merging the pages failed: $merge_msg"
}
puts "export_bd_pdf.tcl: wrote $pdf ([llength $pages] pages)"
