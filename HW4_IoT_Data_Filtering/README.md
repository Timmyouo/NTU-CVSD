# HW4 — IoT Data Filtering

## Overview

A hardware datapath for processing 128-bit IoT sensor packets. The top-level module `IOTDF` selects among four processing modes via a 3-bit function-select signal:

| `fn_sel` | Function | Description |
|----------|----------|-------------|
| `001` | DES Encryption | Encrypt 64-bit blocks using the DES algorithm |
| `010` | DES Decryption | Decrypt 64-bit blocks using the DES algorithm |
| `011` | CRC Generation | Compute a 128-bit CRC checksum over the packet |
| `100` | Sort | Sort 16 × 8-bit bytes in ascending order |

## Architecture

```
                        ┌──────────────────────────────────────┐
  clk, rst ────────────►│              IOTDF.sv                │
  in_en    ────────────►│                                      │
  iot_in[7:0] ─────────►│  ┌──────────────┐                  │
  fn_sel[2:0] ─────────►│  │  DESCore.sv  │ (64-bit DES)     │
                        │  ├──────────────┤                   │
                        │  │  CRCGen.sv   │ (128-bit CRC)     │
                        │  ├──────────────┤                   │
                        │  │  Sort.sv     │ (byte sort)       │
                        │  └──────────────┘                   │
  busy      ◄───────────│                                      │
  valid     ◄───────────│                                      │
  iot_out[127:0] ◄──────│                                      │
                        └──────────────────────────────────────┘
```

**FSM states:** `IDLE → LOAD (16 bytes) → ENC / DEC / CRC / SORT → OUT`

## Synthesis & Power Results (Synopsys DC + PrimeTime PX, TSMC 0.13 µm)

| Metric | Value |
|--------|-------|
| Target clock period | 3.0 ns |
| **Total cell area** | **51,264 µm²** |
| Timing | Met |

| Mode | Simulation time | Avg. power |
|------|----------------|-----------|
| F1 (DES enc) | 7,113 ns | 6.43 mW |
| F2 (DES dec) | 7,113 ns | 6.48 mW |
| F3 (CRC)     | 28,425 ns | 4.87 mW |
| F4 (Sort)    | 29,961 ns | 5.06 mW |

## Flow Completed

| Stage | Status | Script |
|-------|--------|--------|
| RTL   | ✅ | `01_RTL/rtl_01.f` |
| Sim   | ✅ | VCS; per-mode logs `rtl_F{1-4}.log` |
| Synthesis | ✅ | `02_SYN/` |
| Gate sim | ✅ | `03_GATE/` |
| **Power analysis** | ✅ | `06_POWER/pt_script.tcl` (PrimeTime PX) |

## Directory Layout

```
HW4_IoT_Data_Filtering/
├── 00_TESTBED/
│   ├── testfixture.v
│   ├── pattern1_data/     ← test vectors (F1/F2)
│   └── pattern2_data/     ← test vectors (F3/F4)
├── 01_RTL/
│   ├── IOTDF.sv           ← top-level controller
│   ├── DESCore.sv         ← DES encryption/decryption engine
│   ├── CRCGen.sv          ← CRC generator
│   ├── Sort.sv            ← byte sorter
│   └── rtl_01.f
├── 02_SYN/                ← synthesis scripts, netlist, reports
├── 03_GATE/               ← gate-level simulation
├── 06_POWER/
│   ├── pt_script.tcl      ← PrimeTime PX power script
│   └── *.power            ← power results per mode
├── DES_additional_material/  ← S-box & permutation tables (Excel)
└── 1141_hw4*.pdf          ← assignment specification
```
