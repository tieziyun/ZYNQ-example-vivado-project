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

## Prebuilt hardware platform

If you only need the hardware, download `design_1_wrapper.xsa` from the [latest release](../../releases/latest). It contains the bitstream, the hardware handoff file (`.hwh`) and the PS initialization files, ready for Vitis or for unzipping into a PYNQ overlay.

## Building the project

Two scripts, run from Vivado's Tcl console:

```
source <path-to-repo>/Scripts/build.tcl
source <path-to-repo>/Scripts/compile.tcl
```

Or in batch mode, in one step (`compile.tcl` runs `build.tcl` first if the project doesn't exist yet):

```
vivado -mode batch -source Scripts/compile.tcl
```

`build.tcl` creates the project in `build/` inside the repository (ignored by git), recreates `design_1` from `Sources/BD/design_1.tcl`, generates its output products and the HDL wrapper, and applies the saved synthesis and implementation settings from `Scripts/project_settings.tcl`.

`compile.tcl` runs synthesis, implementation and bitstream generation, stops with an error if timing is not met, and writes `build/design_1_wrapper.xsa` (bitstream included).

### Compile time

The scripts are set up for the shortest build:

- **IP cache outside the project.** Out-of-context IP synthesis results are cached in `ip_cache/` at the repository root (ignored by git). Deleting `build/` and rebuilding reuses them, so only the top level is synthesized again. Cache entries are tied to each IP's configuration and the Vivado version, so a changed IP is always re-synthesized.
- **All CPU threads.** Vivado uses 2 threads by default on Windows. `Sources/Scripts/max_threads.tcl` raises this to the number of logical CPUs (Vivado's limit is 32) for the Tcl session and, as a hook, for the implementation run.
- **Lighter strategies.** Top-level synthesis uses `Flow_RuntimeOptimized` (it is only the block design wrapper). Implementation uses `Vivado Implementation Defaults` instead of the original `Performance_ExplorePostRoutePhysOpt`. The IP runs keep the default synthesis strategy, because `v_frmbuf_rd` misses timing when synthesized with `Flow_RuntimeOptimized`.
- **Parallel runs.** `compile.tcl` launches runs with up to 8 parallel jobs (each IP run needs about 1 GB of RAM).

Implementation strategies tried, post-route worst negative slack (WNS):

| `impl_1` strategy | WNS | Result |
|---|---|---|
| `Flow_RuntimeOptimized` | −0.29 ns | Fails timing |
| `Vivado Implementation Defaults` (used) | +0.08 ns | Meets timing |
| `Performance_Explore` | +0.21 ns | Meets timing, about 1.5× longer placement |

If a design change breaks timing, set `impl_1` to `Performance_Explore` in `Scripts/project_settings.tcl`.

Measured on a laptop (Intel i7-1260P, 16 threads, 16 GB RAM), rebuilding from a deleted `build/` with the IP cache filled:

| Step | Time |
|---|---|
| `build.tcl` (recreate project and block design) | 30 s |
| Synthesis (13 of 14 IPs from the cache; only the processing system is synthesized) | 3.5 min |
| Implementation through bitstream | 6 min |

The first build on a machine fills the cache and adds about 4 minutes of IP synthesis.

Expected messages: Vivado reports critical warnings `PSU-1` to `PSU-4` about negative DDR DQS-to-clock delays. They come from the PYNQ-Z2 board preset for the processing system and also appear in the original project.

## Repository layout

| Path | Contents |
|---|---|
| `Sources/BD/design_1.tcl` | The block design, as written by `write_bd_tcl` |
| `Sources/Constraints/pynq_z2.xdc` | Pin and timing constraints |
| `Scripts/build.tcl` | Recreates the project |
| `Scripts/compile.tcl` | Synthesis, implementation, bitstream, timing check and `.xsa` export |
| `Scripts/project_settings.tcl` | Part, board, top module, and synthesis/implementation settings |
| `Sources/Scripts/max_threads.tcl` | Raises Vivado's thread count to the number of CPUs |
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
