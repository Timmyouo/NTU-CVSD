# HW4 — IoT Data Filtering (DES + CRC + Sort) with Power Sign-off

A unified 128-bit IoT-packet processing datapath that selects between **DES encryption / decryption**, **128-bit CRC generation**, and **byte-wise sorting**. The first project where the flow is extended to **PrimeTime PX power analysis** with switching activity from gate-level simulation.

## What This Demonstrates

- **Cryptographic RTL** — full DES (16 Feistel rounds, 8 S-boxes, IP/FP/E/P permutations, key schedule with PC-1/PC-2)
- **Heavily reused control** — single shared FSM dispatches operands to one of four engines and aggregates results, minimizing area
- **Tight timing closure** — synthesized at **3.0 ns clock period** (333 MHz), the most aggressive target in the course
- **Full power sign-off** — PrimeTime PX with FSDB switching activity per mode, separate `.power` reports for each function

## Function Modes

| `fn_sel` | Mode | Description |
|----------|------|-------------|
| `001` | **DES Encrypt** | 64-bit block encryption (with internal key schedule) |
| `010` | **DES Decrypt** | 64-bit block decryption (reversed sub-key order) |
| `011` | **CRC** | 128-bit CRC checksum across the input packet |
| `100` | **Sort** | Ascending sort of 16 × 8-bit bytes |

## Architecture

```
                              ┌──────────────────────────────────┐
   iot_in[7:0] ─────────────▶ │            IOTDF (top)           │
   fn_sel[2:0] ─────────────▶ │                                  │
   in_en       ─────────────▶ │  FSM: IDLE → LOAD(16B) → ENC /   │
                              │            DEC / CRC / SORT      │
                              │            → OUT                 │
                              │                                  │
                              │   ┌───────────┐  ┌────────────┐  │
                              │   │ DESCore   │  │ CRCGen     │  │
                              │   │ (16 round │  │ (128-bit   │  │
                              │   │  Feistel, │  │  shift     │  │
                              │   │  S-boxes) │  │  register) │  │
                              │   └───────────┘  └────────────┘  │
                              │   ┌───────────┐                  │
                              │   │  Sort     │                  │
                              │   │ (compare- │                  │
                              │   │  swap nw) │                  │
                              │   └───────────┘                  │
                              │                                  │
   iot_out[127:0] ◀───────────┤   busy, valid                    │
                              └──────────────────────────────────┘
```

## Synthesis Results

**Synopsys Design Compiler U-2022.12 · TSMC 0.13 µm slow corner**

| Metric | Value |
|--------|-------|
| Clock period (`clk`) | **3.0 ns** (333 MHz target) |
| Input / output delay | 1.0 ns max, 0.0 ns min |
| **Total cell area** | **51,264 µm²** |
| Combinational cells | 3,523 (29,161 µm²) |
| Sequential cells | 662 (22,103 µm²) |
| Buf/Inv | 461 (2,125 µm²) |

## Power Analysis (PrimeTime PX)

Average power computed from FSDB-driven gate-level activity, per mode:

| Mode | Function | Latency | Avg. Power |
|------|----------|---------|-----------:|
| F1 | DES Encrypt | 7,113 ns | **6.43 mW** |
| F2 | DES Decrypt | 7,113 ns | **6.48 mW** |
| F3 | CRC         | 28,425 ns | **4.87 mW** |
| F4 | Sort        | 29,961 ns | **5.06 mW** |

Cryptographic modes draw the highest power (toggle-heavy S-boxes); CRC and Sort are dominated by sequential storage with lower switching.

## Flow Completed

| Stage | Status | Key files |
|-------|--------|-----------|
| RTL | ✓ | `01_RTL/IOTDF.sv` + `DESCore.sv`, `CRCGen.sv`, `Sort.sv` |
| Functional simulation | ✓ | Per-mode FSDB: `IOTDF_F{1-4}.fsdb`, logs `rtl_F{1-4}.log` |
| Synthesis | ✓ | `02_SYN/syn.tcl`, `IOTDF_DC.sdc` |
| Gate-level simulation | ✓ | `03_GATE/` (back-annotated SDF) |
| **Power analysis** | ✓ | `06_POWER/pt_script.tcl`, `F1_4.power` |

## Directory Layout

```
HW4_IoT_Data_Filtering/
├── 01_RTL/
│   ├── IOTDF.sv            ← top-level FSM + dispatcher
│   ├── DESCore.sv          ← 16-round Feistel DES engine
│   ├── CRCGen.sv           ← 128-bit CRC generator
│   ├── Sort.sv             ← byte-wise sorting network
│   └── rtl_01.f
├── 02_SYN/
│   ├── syn.tcl             ← DC synthesis script
│   ├── IOTDF_DC.sdc        ← timing constraints (3 ns)
│   ├── Netlist/            ← gate-level netlist + SDF
│   └── Report/             ← area, timing, clock-gating reports
├── 03_GATE/                ← gate-level simulation scripts
├── 06_POWER/
│   ├── pt_script.tcl       ← PrimeTime PX flow
│   └── F1_4.power          ← average-power results per mode
├── DES_additional_material/  ← S-boxes & permutations (Excel reference)
└── 1141_hw4.pdf            ← assignment specification
```
