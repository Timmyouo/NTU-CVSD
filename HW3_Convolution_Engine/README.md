# HW3 — 2D Convolution Accelerator

## Overview

A hardware accelerator that performs barcode detection followed by 2D convolution on grayscale images. The design streams an input image into on-chip SRAM, detects a barcode region, reads convolution weights from a second memory region, and writes four convolved output feature maps back to SRAM — all under a single top-level controller.

## Architecture

```
                      ┌───────────────────────────────────────────────┐
    i_in_data ──────► │                   core.sv                     │
    i_in_valid        │                                               │
                      │  ┌──────────────┐    ┌─────────────────────┐ │
                      │  │  Barcode.sv  │    │    ConvCore.sv      │ │
                      │  │  (detect     │    │  (5×5 / 3×3 kernel  │ │
                      │  │   barcode    │    │   sliding window)   │ │
                      │  │   location)  │    └────────┬────────────┘ │
                      │  └──────────────┘             │              │
                      │                               ▼              │
                      │        sram_4096x8 (image + weight SRAM)     │
                      │                                               │
                      │  o_out_data{1-4}, o_out_addr{1-4},           │
                      │  o_out_valid{1-4}, o_exe_finish              │
                      └───────────────────────────────────────────────┘
```

**FSM states:** `IDLE → READ_IMG → BARCODE → READ_WEIGHT → CONV → DONE`

## Interface

```
module core (
    input        i_clk, i_rst_n,
    input        i_in_valid,
    input [31:0] i_in_data,
    output       o_in_ready,
    output [7:0] o_out_data1 / 2 / 3 / 4,
    output [11:0] o_out_addr1 / 2 / 3 / 4,
    output       o_out_valid1 / 2 / 3 / 4,
    output       o_exe_finish
);
```

## Synthesis Results (Synopsys DC, TSMC 0.13 µm, slow corner)

| Metric | Value |
|--------|-------|
| Target clock period | 6 ns |
| Combinational cell area | 34,591 µm² |
| Sequential cell area | 11,810 µm² |
| SRAM (macro) area | 131,907 µm² |
| **Total cell area** | **178,308 µm²** |
| Timing | Met (slack ≥ 0) |

SRAM used: `sram_4096x8` (4096 × 8-bit, single-port)

## Flow Completed

| Stage | Status | Script |
|-------|--------|--------|
| RTL   | ✅ | `01_RTL/rtl_01.f` |
| Lint  | ✅ | `01_RTL/lint.tcl`; violations report: `spyglass_violations.rpt` |
| Sim   | ✅ | VCS + Verdi; `01_RTL/01_run` |
| **Synthesis** | ✅ | `02_SYN/syn.tcl`, SDC: `core_dc.sdc` |
| Gate sim | ✅ | `03_GATE/` |

## Directory Layout

```
HW3_Convolution_Engine/
├── 00_TESTBED/
│   ├── testbench.v
│   └── PATTERNS/          ← input images + golden outputs (.dat, .png)
├── 01_RTL/
│   ├── core.sv            ← top-level controller
│   ├── ConvCore.sv        ← convolution engine
│   ├── Barcode.sv         ← barcode detector
│   ├── rtl_01.f
│   └── spyglass_violations.rpt
├── 02_SYN/
│   ├── syn.tcl            ← Synopsys DC synthesis script
│   ├── core_dc.sdc        ← timing constraints
│   ├── Netlist/           ← synthesized gate-level netlist
│   └── Report/            ← area & timing reports
├── 03_GATE/               ← gate-level simulation
├── sram_4096x8/           ← SRAM model (.v, .lib, .db)
└── 1141_hw3_*.pdf         ← assignment specification
```
