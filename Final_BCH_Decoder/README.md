# Final Project — Configurable BCH Error-Correcting Decoder (RTL → GDS)

A team capstone project: a **dual-code, dual-mode BCH decoder** taken end-to-end from spec to sign-off-clean layout. Supports both **hard-decision** and **soft-decision (LLR-based)** decoding for two BCH codes commonly used in storage and communication systems.

## What This Demonstrates

- **Algorithmic ECC hardware** — implementing the full BCH decoding pipeline: syndrome computation over GF(2ⁿ), Berlekamp–Massey-style error-locator search, Chien search, and LLR-based soft decoding
- **Configurable architecture** — runtime selection between BCH(63,51) and BCH(255,231), and between hard / soft decoding modes via a 2-bit `code` input and 1-bit `mode` input
- **Synthesis-grade RTL** at scale: synthesized to **36k cells / 495k µm²** with timing met at 6.5 ns
- **Complete RTL → GDS flow** end to end — RTL · DC synthesis · gate-level sim · Innovus APR · post-route sim — with **zero DRC, geometry, antenna, or connectivity violations**
- **Team collaboration** — controller, hard-decoders, and verification split across team members; integrated under a single top (`bch.v`)

## Supported Codes & Modes

| Code | n | k | Correction `t` | Use case |
|------|--:|--:|---------------:|----------|
| BCH(63, 51) | 63 | 51 | 2 | Compact codes, small overhead |
| BCH(255, 231) | 255 | 231 | 3 | Storage / communication standard |

| `mode` | Decoding |
|--------|----------|
| `0` | **Hard-decision** — classical syndrome + Chien search on hard bits |
| `1` | **Soft-decision** — LLR-based decoding |

## Module Interface

```
module bch (
    input         clk, rstn,
    input         mode,         // 0 = hard, 1 = soft
    input  [1:0]  code,         // selects BCH(63) or BCH(255)
    input         set,
    input  [63:0] idata,        // packed input codeword
    output        ready, finish,
    output [9:0]  odata         // decoded output
);
```

Sub-modules (`01_RTL/`):

| Module | Role |
|--------|------|
| `controller.v` | Top-level FSM: framing, code/mode dispatch, output gating, clock-gating insertion |
| `hard_63.v` | BCH(63,51) hard-decision decoder |
| `hard_255.v` | BCH(255,231) hard-decision decoder |
| `hard_1023.v` | Additional hard decoder block |

## Synthesis Results

**Synopsys Design Compiler U-2022.12 · TSMC 0.13 µm slow corner**

| Metric | Value |
|--------|------:|
| Clock period | **6.5 ns** |
| Combinational area | 186,780 µm² |
| Sequential area | 308,170 µm² |
| Buf/Inv area | 14,628 µm² |
| **Total cell area** | **494,950 µm²** |
| Setup slack | **0.00 ns** (met) |

**Design size:** 36,643 cells (22,011 combinational + 12,189 sequential).

## APR Sign-off (Cadence Innovus 17.11)

| Check | Result |
|-------|--------|
| DRC violations | **0** |
| Geometry violations | **0** |
| Antenna violations | **0** |
| Connectivity issues | **0** (no problems, no warnings) |

### Post-route static timing (`timeDesign -postRoute`)

| Path group | WNS (ns) | TNS (ns) | Violating paths |
|-----------|---------:|---------:|----------------:|
| **All**   | **+0.913** | 0.000 | 0 / 12,203 |
| reg2reg   | +0.913   | 0.000 | 0 / 9,753 |
| reg2cgate | +1.262   | 0.000 | 0 / 2,433 |
| in2reg    | +0.913   | 0.000 | 0 / 12,189 |
| reg2out   | +2.386   | 0.000 | 0 / 12 |

### Layout statistics

| Metric | Value |
|--------|------:|
| Standard cells | **58,256** |
| Hard macros | 0 |
| Core utilization (density) | **77.77%** |
| SI glitches | 0 |
| max_cap / max_tran / max_fanout violations | 0 / 0 / 0 |

## Flow Completed

| Stage | Status | Key files |
|-------|--------|-----------|
| RTL design | ✓ | `01_RTL/bch.v`, `controller.v`, `hard_*.v` |
| RTL simulation | ✓ | `01_RTL/rtlsim.sh` + `testdata/` |
| Logic synthesis | ✓ | `02_SYN/syn.tcl`, `bch_dc.sdc` |
| Gate-level simulation | ✓ | `03_GATE/gatesim.sh` |
| **Place & route** | ✓ | `04_APR/` — Innovus (signed off) |
| Post-route simulation | ✓ | `05_POST/postsim.sh` |
| Final tape-out style sign-off | ✓ | All checks zero violation |

## Directory Layout

```
Final_BCH_Decoder/
├── 01_RTL/
│   ├── bch.v                  ← top-level decoder
│   ├── controller.v           ← FSM / dispatcher / clock gating
│   ├── hard_63.v / hard_255.v / hard_1023.v
│   ├── test.v                 ← testbench
│   ├── testdata/              ← test codewords (p100/p200/p300 a/b)
│   └── rtlsim.sh
├── 02_SYN/
│   ├── syn.tcl                ← Synopsys DC script
│   ├── bch_dc.sdc             ← timing constraints
│   ├── Netlist/               ← gate-level netlist + SDF
│   └── Report/                ← area, timing reports
├── 03_GATE/                   ← gate-level simulation
├── 04_APR/
│   ├── Netlist/               ← post-route netlist + SDF
│   └── Report/                ← DRC/geom/antenna/conn + post-route summary
├── 05_POST/                   ← post-route simulation
├── team042_report.pdf         ← full design report
├── 114-1_final_note_v2.pdf    ← assignment specification
└── BCH code example*.pdf      ← reference material
```
