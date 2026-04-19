# Final Project — BCH Error-Correcting Decoder

## Overview

A configurable hardware BCH (Bose–Chaudhuri–Hocquenghem) decoder supporting two code lengths and both hard-decision and soft-decision (LLR-based) decoding modes. The design was taken through the complete RTL-to-GDS flow, including synthesis, gate-level simulation, place & route, and post-route simulation.

## Supported Codes

| Code | Parameters | Correction capability |
|------|-----------|----------------------|
| BCH(63, 51) | n=63, k=51, t=2 | Up to 2-bit error correction |
| BCH(255, 231) | n=255, k=231, t=3 | Up to 3-bit error correction |

**Decoding modes** (selected via `mode` input):  
- **Hard-decision:** classical BM / Chien search on hard bits  
- **Soft-decision:** LLR (Log-Likelihood Ratio) based decoding

## Interface

```
module bch (
    input        clk,
    input        rstn,
    input        mode,         // 0 = hard, 1 = soft
    input  [1:0] code,         // select BCH(63) or BCH(255)
    input        set,
    input  [63:0] idata,       // input codeword (packed)
    output       ready,
    output       finish,
    output [9:0] odata         // decoded data output
);
```

Key sub-modules: `controller.v`, `hard_63.v`, `hard_255.v`, and associated syndrome / error-locator blocks.

## Results

### Synthesis (Synopsys DC, TSMC 0.13 µm, slow corner)

| Metric | Value |
|--------|-------|
| Target clock period | 6.5 ns |
| Combinational cell area | 186,780 µm² |
| Sequential cell area | 308,169 µm² |
| **Total cell area** | **494,950 µm²** |
| Timing slack | Met (0.00 ns) |

### Place & Route (Cadence Innovus 17.11)

| Check | Result |
|-------|--------|
| DRC violations | **0** |
| Geometry violations | **0** |
| Antenna violations | **0** |
| Connectivity issues | **0** |
| Post-route WNS (setup) | **+0.913 ns** |
| Post-route TNS | 0.000 ns |
| Violating paths | 0 |
| Core utilization (density) | **77.77%** |
| Standard cell count | 58,256 |

## Flow Completed

| Stage | Status | Key files |
|-------|--------|-----------|
| RTL | ✅ | `01_RTL/bch.v`, `controller.v`, `hard_*.v` |
| Simulation | ✅ | `01_RTL/rtlsim.sh` |
| **Synthesis** | ✅ | `02_SYN/syn.tcl`, `bch_dc.sdc` |
| Gate sim | ✅ | `03_GATE/gatesim.sh` |
| **APR** | ✅ | `04_APR/` — Cadence Innovus |
| Post-route sim | ✅ | `05_POST/postsim.sh` |

## Directory Layout

```
Final_BCH_Decoder/
├── 01_RTL/
│   ├── bch.v              ← top-level decoder
│   ├── controller.v       ← decoding controller
│   ├── hard_*.v           ← hard-decision decoders (BCH-63, BCH-255)
│   ├── test.v             ← testbench
│   ├── rtl.f
│   ├── rtlsim.sh          ← simulation run script
│   └── testdata/          ← test codewords
├── 02_SYN/
│   ├── syn.tcl            ← Synopsys DC script
│   ├── bch_dc.sdc         ← timing constraints
│   ├── Netlist/           ← synthesized gate-level netlist
│   └── Report/            ← area & timing reports
├── 03_GATE/
│   ├── gatesim.sh
│   └── cycle.txt
├── 04_APR/
│   ├── Netlist/           ← post-route netlist
│   └── Report/            ← DRC, geometry, antenna, timing reports
├── 05_POST/
│   ├── postsim.sh
│   └── cycle.txt
├── team042_report.pdf     ← full design report
└── 114-1_final_note_v2.pdf ← assignment specification
```
