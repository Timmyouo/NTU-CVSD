# HW1 — Fixed-Point ALU

## Overview

A pipelined / multi-cycle Arithmetic Logic Unit (ALU) that operates on 16-bit fixed-point numbers in **Q6.10** format (6-bit integer, 10-bit fractional). The design accepts a 4-bit instruction and two signed operands, and produces the result along with a valid signal.

## Supported Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| `0000` | `ADD`  | Signed addition |
| `0001` | `SUB`  | Signed subtraction |
| `0010` | `MAC`  | Multiply-accumulate |
| `0011` | `TAY`  | Taylor-series approximation |
| `0100` | `GRAY` | Binary-to-Gray code conversion |
| `0101` | `LRCW` | Left-right circular word shift |
| `0110` | `RROT` | Right rotation |
| `0111` | `CLZR` | Count leading zeros |
| `1000` | `RM4`  | Rounding (round to nearest, ties to even / floor) |
| `1001` | `MATR` | 4×4 matrix transpose |

## Interface

```
module alu #(
    parameter INST_W = 4,
    parameter INT_W  = 6,   // integer bits
    parameter FRAC_W = 10,  // fractional bits
    parameter DATA_W = 16
)(
    input  i_clk, i_rst_n,
    input  i_in_valid,
    output o_busy,
    input  [INST_W-1:0] i_inst,
    input  signed [DATA_W-1:0] i_data_a, i_data_b,
    output o_out_valid,
    output [DATA_W-1:0] o_data
);
```

## Design Notes

- **FSM:** Three states — IDLE, SIMPLE (single-cycle ops), MTX\_LOAD / MTX\_OUT (matrix transpose requires 4 input pairs then 4 output cycles).
- **MAC:** Accumulates into a 36-bit internal register to avoid overflow before truncating back to Q6.10.
- **Lint:** Verified clean with SpyGlass (violations report: `01_RTL/spyglass_violations.rpt`).

## Flow Completed

| Stage | Status | Notes |
|-------|--------|-------|
| RTL   | ✅ | `01_RTL/alu.v` |
| Lint  | ✅ | SpyGlass; `spyglass_violations.rpt` |
| Sim   | ✅ | VCS + Verdi; waveform in `alu.fsdb` |

## Directory Layout

```
HW1_ALU/
├── 01_RTL/
│   ├── alu.v              ← top-level ALU module
│   ├── rtl.f              ← VCS file list
│   ├── 01_run             ← simulation run script
│   └── spyglass_violations.rpt
└── 114-1_HW1.pdf          ← assignment specification
```
