# HW2 — Single-Cycle CPU with Custom FPU

A multi-stage controller running a **17-instruction RISC-V-like ISA**, including a hand-built **IEEE-754 single-precision** floating-point multiplier and subtractor — written from RTL with no DesignWare FP IP.

## What This Demonstrates

- **CPU micro-architecture** — fetch/decode/execute/write-back FSM, branch and jump handling, register hazard avoidance
- **Custom IEEE-754 FP arithmetic** — exponent alignment, mantissa add/sub, normalization, round-to-nearest-even, special-value handling (NaN/Inf/zero/subnormal classification via `FCLASS`)
- **Modular RTL** — reused HW1 ALU, separate `regfile`, `pc`, `fmul_sp`, `fsub_sp` units, all stitched together via SystemVerilog `typedef enum` for clean opcode/state coding
- **Memory-mapped I/O contract** with the testbench (status valid handshake, single-port memory)

## Supported ISA

| Class | Instructions | Notes |
|-------|--------------|-------|
| Integer ALU | `SUB`, `ADDI`, `SLT`, `SRL` | Reuses HW1 ALU primitive |
| Branch | `BEQ`, `BLT` | PC-relative |
| Memory | `LW`, `SW`, `FLW`, `FSW` | 32-bit aligned |
| PC-relative | `JALR`, `AUIPC` | Link register write-back |
| Floating-point | `FSUB`, `FMUL`, `FCVT`, `FCLASS` | IEEE-754 binary32 |
| Control | `EOF` | End-of-program sentinel |

## Architecture

```
            ┌──────────────────────────────────────────────────┐
            │                       core                       │
            │  ┌──────┐                                        │
            │  │ FSM  │   IDLE → IF → ID → EX → WB → NPC      │
            │  └───┬──┘                                        │
            │      │                                            │
            │      ▼                                            │
            │  ┌──────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐│
            │  │  pc  │  │ regfile │  │  alu    │  │ fmul_sp ││
            │  │      │  │ 32x32   │  │ (HW1)   │  │ fsub_sp ││
            │  └──────┘  └─────────┘  └─────────┘  └─────────┘│
            │                                                  │
            └─────────┬───────────────────────────────┬────────┘
                      │ o_addr / o_wdata / o_we      │ o_status
                      ▼                               ▼
                 Unified Memory                   Testbench
```

**Sub-modules in `01_RTL/`:**

| Module | File | Role |
|--------|------|------|
| `core` | `core.sv` | Top: FSM + datapath wiring |
| `alu`  | `alu.sv` | Integer ALU (reused from HW1) |
| `regfile` | `regfile.v` | 32 × 32-bit register file, 2R/1W |
| `pc` | `pc.v` | PC update with branch / jump mux |
| `fmul_sp` | `fmul_sp.sv` | IEEE-754 FP multiplier |
| `fsub_sp` | `fsub_sp.sv` | IEEE-754 FP subtractor |

## Module Interface

```
module core #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input  i_clk, i_rst_n,
    output [2:0] o_status, output o_status_valid,
    output [ADDR_WIDTH-1:0] o_addr,
    output [DATA_WIDTH-1:0] o_wdata,
    output o_we,
    input  [DATA_WIDTH-1:0] i_rdata
);
```

## Verification

| Check | Tool | Result |
|-------|------|--------|
| RTL functional simulation | Synopsys VCS + Verdi | All instruction-mix programs pass |
| FPU unit tests | `tb_alu_fsub.sv` | FSUB / FMUL bit-exact vs golden |

## Directory Layout

```
HW2_Single_Cycle_CPU/
├── 00_TB/
│   ├── testbed.v          ← top testbench
│   ├── data_mem.vp        ← unified memory model
│   └── define.v
├── 01_RTL/
│   ├── core.sv            ← CPU top
│   ├── alu.sv  pc.v  regfile.v
│   ├── fmul_sp.sv         ← custom IEEE-754 multiplier
│   ├── fsub_sp.sv         ← custom IEEE-754 subtractor
│   ├── tb_alu_fsub.sv     ← FPU unit test
│   └── rtl.f
└── 1141_HW2_v4.pdf        ← assignment specification
```
