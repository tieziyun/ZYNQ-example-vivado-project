# ZYNQ example Vivado project: PYNQ-Z2 HDMI framebuffer

A Vivado 2026.1 block design for the TUL **PYNQ-Z2** (Zynq-7020, `xc7z020clg400-1`) that drives the board's **HDMI output** from a framebuffer in DDR memory. The Arm cores write pixels to memory, and the programmable logic streams them to the HDMI port.

The repository holds only sources and scripts. Running `Scripts/build.tcl` recreates the full Vivado project.

## What's in the design

`design_1` (IP Integrator):

| Block | Role |
|---|---|
| Zynq-7000 Processing System (`processing_system7`) | Arm cores, DDR, AXI masters (GP0) and high-performance port (HP0) for video reads |
| Video Frame Buffer Read (`v_frmbuf_rd`) | Reads frames from DDR over AXI and outputs an AXI4-Stream video stream |
| Video Timing Controller (`v_tc`) | Generates the display timing |
| AXI4-Stream to Video Out (`v_axi4s_vid_out`) | Converts the stream plus timing into parallel video |
| Digilent `axi_dynclk` | Programmable pixel clock |
| Digilent `rgb2dvi` | Encodes parallel video as TMDS for the HDMI connector |
| AXI GPIO, AXI interconnects, processor system resets | Control and housekeeping |

The HDMI-display blocks are grouped in the `hdmi_display` hierarchy, and the reset blocks in `resets`. Pin constraints are in `Sources/Constraints/pynq_z2.xdc`.

## Requirements

- **Vivado 2026.1.** The block design script checks the version and stops on a mismatch.
- **PYNQ-Z2 board files** (`tul.com.tw:pynq-z2:part0:1.0`). Install them from Vivado's board store (**Tools → Vivado Store → Boards**, search for "pynq-z2"). If you keep board files in your own folder, set the `PYNQZ2_BOARD_DIR` environment variable to it before building.
- **Digilent vivado-library.** Included as a git submodule; see below.

## Getting the sources

Clone with submodules:

```
git clone --recursive <this repository's URL>
```

If you already cloned without `--recursive`:

```
git submodule update --init
```

## Building the project

From Vivado's Tcl console:

```
source <path-to-repo>/Scripts/build.tcl
```

Or in batch mode:

```
vivado -mode batch -source Scripts/build.tcl
```

The script creates the project in `build/` inside the repository (ignored by git), recreates `design_1` from `Sources/BD/design_1.tcl`, generates its output products and the HDL wrapper, and applies the saved synthesis and implementation settings from `Scripts/project_settings.tcl`. Then run synthesis, implementation and bitstream generation as usual.

Expected messages: Vivado reports critical warnings `PSU-1` to `PSU-4` about negative DDR DQS-to-clock delays. They come from the PYNQ-Z2 board preset for the processing system and also appear in the original project.

## Repository layout

| Path | Contents |
|---|---|
| `Sources/BD/design_1.tcl` | The block design, as written by `write_bd_tcl` |
| `Sources/Constraints/pynq_z2.xdc` | Pin and timing constraints |
| `Scripts/build.tcl` | Recreates the project |
| `Scripts/project_settings.tcl` | Part, board, top module, and synthesis/implementation settings |
| `Scripts/verification_manifest.tcl` | Expected structure, for checking a rebuild (see below) |
| `vivado-library/` | Digilent IP library (git submodule) |

## Checking a rebuild

After `build.tcl` finishes, you can confirm the recreated project has the expected block design, top module, runs and IP count. The `verify_rebuild` procedure comes from the vivado-revision-control helper scripts used to create this export:

```
verify_rebuild Scripts/verification_manifest.tcl
```

## Updating the repository after changing the design

Edit the project in `build/`, then write the block design back over the exported script and commit it:

```
write_bd_tcl -force <path-to-repo>/Sources/BD/design_1.tcl
```

Copy any changed constraint files into `Sources/Constraints/`.
