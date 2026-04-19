# CVSD — Computer Vision and System Design

**Course:** CVSD (EE 5073), National Taiwan University · Fall 2025  
**Language:** SystemVerilog / Verilog  
**Technology:** TSMC 0.13 µm standard-cell library (CBDK IC Contest)  
**Repository:** [github.com/Timmyouo/NTU-Computer-aided-VLSI-System-Design-](https://github.com/Timmyouo/NTU-Computer-aided-VLSI-System-Design-)

This repository contains all homework assignments and the final project from CVSD, covering the complete digital IC design flow from RTL coding through physical layout.

---

## Design Flow Covered

```
RTL (SV/Verilog)
    ↓  Lint (SpyGlass)
    ↓  Functional Simulation (Synopsys VCS + Verdi)
    ↓  Logic Synthesis (Synopsys Design Compiler)
    ↓  Gate-Level Simulation (with back-annotated SDF)
    ↓  Place & Route (Cadence Innovus)
    ↓  Post-Route Simulation & Sign-off
    ↓  Power Analysis (Synopsys PrimeTime PX)
```

---

## Tools

| Tool | Purpose |
|------|---------|
| Synopsys VCS + Verdi | Functional & gate-level simulation, waveform analysis |
| SpyGlass | RTL lint & CDC checks |
| Synopsys Design Compiler (U-2022.12) | Logic synthesis, timing/area reports |
| Cadence Innovus (17.11) | Floorplan, place & route, CTS, DRC |
| Synopsys PrimeTime PX | Static timing analysis & power estimation |

---

## Projects

| # | Folder | Design | Key Skills | Clock | Area (cell) |
|---|--------|--------|-----------|-------|-------------|
| HW1 | [`HW1_ALU/`](HW1_ALU/) | Fixed-point ALU | RTL FSM, fixed-point arithmetic, lint | — | — |
| HW2 | [`HW2_Single_Cycle_CPU/`](HW2_Single_Cycle_CPU/) | Single-cycle RISC-V-like CPU | Multi-cycle FSM, FPU integration | — | — |
| HW3 | [`HW3_Convolution_Engine/`](HW3_Convolution_Engine/) | 2D Convolution Accelerator | RTL → Synthesis, SRAM, SDC constraints | 6 ns | 178,308 µm² |
| HW4 | [`HW4_IoT_Data_Filtering/`](HW4_IoT_Data_Filtering/) | IoT Data Filtering (DES / CRC / Sort) | Crypto datapath, synthesis, power analysis | 3 ns | 51,264 µm² |
| HW5 | [`HW5_APR/`](HW5_APR/) | Place & Route (APR) | Innovus full P&R flow, CTS, DRC sign-off | — | 0 DRC violations |
| Final | [`Final_BCH_Decoder/`](Final_BCH_Decoder/) | BCH Error-Correcting Decoder | Full RTL-to-GDS, hard + soft decoding | 6.5 ns | 494,950 µm² |

---

## Repository Structure

```
CVSD/
├── HW1_ALU/                  ← Fixed-point ALU (10 operations)
├── HW2_Single_Cycle_CPU/     ← Single-cycle CPU w/ FPU
├── HW3_Convolution_Engine/   ← 2D convolution accelerator + SYN
├── HW4_IoT_Data_Filtering/   ← IoT datapath: DES / CRC / Sort + power
├── HW5_APR/                  ← Place & Route on HW3 core
└── Final_BCH_Decoder/        ← BCH(63,51) / BCH(255,231) decoder, full RTL→GDS
```

Each subfolder follows the same numbered-stage layout:

```
01_RTL/    ← source RTL + simulation scripts
02_SYN/    ← synthesis TCL, SDC, netlist, reports
03_GATE/   ← gate-level simulation
04_APR/    ← Innovus place & route output
05_POST/   ← post-route simulation
06_POWER/  ← PrimeTime PX power results  (HW4 only)
```
