# HW1 — Fixed-Point ALU

A 16-bit signed **Q6.10 fixed-point** Arithmetic Logic Unit supporting 10 instructions, written from scratch in Verilog with a clean three-state controller.

## What This Demonstrates

- Hand-written FSM controller separating **single-cycle** ops from **multi-cycle** matrix-transpose flow
- Mixed combinational + registered datapath with proper overflow handling (36-bit accumulator for MAC)
- Implementation of non-trivial bit-level algorithms: count-leading-zeros, Gray code, circular shifts, banker's rounding
- Lint-clean RTL signed off with **SpyGlass** (zero unwaived violations in `01_RTL/spyglass_violations.rpt`)

## Instruction Set

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| `0000` | ADD  | Signed Q6.10 addition with saturation |
| `0001` | SUB  | Signed Q6.10 subtraction |
| `0010` | MAC  | Multiply-accumulate (36-bit internal accumulator → truncate to Q6.10) |
| `0011` | TAY  | Taylor-series approximation |
| `0100` | GRAY | Binary-to-Gray code conversion |
| `0101` | LRCW | Left-right circular word shift |
| `0110` | RROT | Right rotation |
| `0111` | CLZR | Count leading zeros |
| `1000` | RM4  | Round-to-nearest with banker's tie-break |
| `1001` | MATR | 4×4 matrix transpose (multi-cycle: 4 load + 4 output) |

## Architecture

```
                ┌─────────────────────────────────────────┐
i_inst[3:0]  ──▶│              alu (top)                  │
i_data_a[15:0]──▶                                          │
i_data_b[15:0]──▶  ┌──────┐    ┌────────────────────┐     │
i_in_valid   ──▶  │ FSM  │───▶│  Datapath          │     │
                  │      │    │   ─ ALU primitives  │     │
                  │ IDLE │    │   ─ MAC accumulator │     │
                  │ SIM  │    │   ─ Matrix buffer    │     │
                  │ MTX  │    │   ─ Round/saturate  │     │
                  │_LOAD │    └────────┬───────────┘     │
                  │ MTX_ │             │                  │
                  │ OUT  │             ▼                  │
                  └──────┘   ┌──────────────────┐        │
                             │  o_data[15:0]    │ ──▶ o_out_valid
                             └──────────────────┘        │
                └─────────────────────────────────────────┘
```

## Module Interface

```
module alu #(
    parameter INST_W = 4,
    parameter INT_W  = 6,    // integer bits
    parameter FRAC_W = 10,   // fractional bits  (→ Q6.10)
    parameter DATA_W = INT_W + FRAC_W
)(
    input                       i_clk, i_rst_n,
    input                       i_in_valid,
    output                      o_busy,
    input  [INST_W-1:0]         i_inst,
    input  signed [DATA_W-1:0]  i_data_a, i_data_b,
    output                      o_out_valid,
    output reg [DATA_W-1:0]     o_data
);
```

## Verification & Sign-off

| Check | Tool | Result |
|-------|------|--------|
| Functional simulation | Synopsys VCS + Verdi (FSDB) | All testbench patterns pass |
| RTL lint | SpyGlass | Clean (`spyglass_violations.rpt`) |

## Directory Layout

```
HW1_ALU/
├── 01_RTL/
│   ├── alu.v                       ← top-level RTL
│   ├── rtl.f                       ← VCS file list
│   ├── 01_run                      ← simulation run script
│   └── spyglass_violations.rpt     ← lint sign-off report
├── 00_TESTBED/testbench.v
└── 114-1_HW1.pdf                   ← assignment specification
```
