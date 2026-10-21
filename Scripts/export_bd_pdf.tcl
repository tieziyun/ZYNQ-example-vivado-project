#*******************************************************************************
# export_bd_pdf.tcl - Write the block design diagram to docs/design_1.pdf
#
# Usage, from the Vivado GUI Tcl console (write_bd_layout needs the GUI):
#   source <repo>/Scripts/export_bd_pdf.tcl
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
set docs_dir [file join $base_dir docs]
file mkdir $docs_dir

# Portrait keeps the drawing upright (landscape rotates it on the page).
# Colors follow the Vivado GUI theme.

# Top level, where hdmi_display and resets appear as collapsed blocks
set pdf [file join $docs_dir design_1.pdf]
write_bd_layout -force -format pdf -orientation portrait $pdf
puts "export_bd_pdf.tcl: wrote $pdf"

# One page per user hierarchy (VLNV is empty; AXI interconnects are IP and
# are skipped), showing the blocks inside it
foreach hier [get_bd_cells -filter {TYPE == hier && VLNV == ""}] {
    set name [string trimleft $hier /]
    set pdf [file join $docs_dir design_1_${name}.pdf]
    write_bd_layout -force -format pdf -orientation portrait -hierarchy [get_bd_cells $hier] $pdf
    puts "export_bd_pdf.tcl: wrote $pdf"
}
