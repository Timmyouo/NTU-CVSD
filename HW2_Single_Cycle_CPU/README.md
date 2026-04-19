# HW2 — Single-Cycle RISC-V-like CPU

## Overview

A single-cycle processor core that implements a subset of the RISC-V ISA extended with single-precision floating-point instructions. The CPU fetches, decodes, and executes one instruction per clock cycle (plus stall cycles for multi-cycle FPU operations).

## Supported Instructions

| Category | Instructions |
|----------|-------------|
| Integer ALU | `SUB`, `ADDI`, `SLT`, `SRL` |
| Branch | `BEQ`, `BLT` |
| Memory | `LW`, `SW`, `FLW`, `FSW` |
| PC-relative | `JALR`, `AUIPC` |
| Floating-point | `FSUB`, `FMUL`, `FCVT`, `FCLASS` |
| Control | `EOF` (end-of-program sentinel) |

## Architecture

```
        ┌──────┐   i_rdata     ┌─────────────────────────────────────┐
 i_clk ─►      │◄──────────────┤              Unified                 │
i_rstn ─► core │  o_addr       │          Memory (testbench)          │
        │      ├──────────────►│                                      │
        │      │  o_wdata      └─────────────────────────────────────┘
        │      ├──────────────►
        │      │  o_we
        └──────┘
```

**Pipeline stages (FSM):** `IDLE → IF → ID → EX → WB → NPC → (repeat)`

Key sub-modules instantiated inside `core.sv`:

| Module | File | Purpose |
|--------|------|---------|
| `alu` | `alu.sv` | Reused from HW1, integer operations |
| `regfile` | `regfile.v` | 32-entry × 32-bit register file |
| `pc` | `pc.v` | Program counter with branch/jump logic |
| `fmul_sp` | `fmul_sp.sv` | IEEE 754 single-precision multiplier |
| `fsub_sp` | `fsub_sp.sv` | IEEE 754 single-precision subtractor |

## Interface

```
module core #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input  i_clk, i_rst_n,
    output [2:0] o_status,       // execution status to testbench
    output       o_status_valid,
    output [ADDR_WIDTH-1:0] o_addr,
    output [DATA_WIDTH-1:0] o_wdata,
    output o_we,
    input  [DATA_WIDTH-1:0] i_rdata
);
```

## Flow Completed

| Stage | Status | Notes |
|-------|--------|-------|
| RTL   | ✅ | `01_RTL/core.sv` + sub-modules |
| Lint  | ✅ | SpyGlass |
| Sim   | ✅ | VCS + Verdi |

## Directory Layout

```
HW2_Single_Cycle_CPU/
├── 00_TB/
│   ├── testbed.v         ← testbench top
│   ├── PATTERN/          ← instruction memory images
│   ├── data_mem.vp       ← data memory model
│   └── define.v
├── 01_RTL/
│   ├── core.sv           ← CPU top module
│   ├── alu.sv
│   ├── pc.v
│   ├── regfile.v
│   ├── fmul_sp.sv        ← FP multiplier
│   ├── fsub_sp.sv        ← FP subtractor
│   └── rtl.f
└── 1141_HW2_v4.pdf       ← assignment specification
```
