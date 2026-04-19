# HW5 — Automated Place & Route (APR)

## Overview

Full physical implementation of the convolution engine `core` from HW3, using **Cadence Innovus 17.11** on the TSMC 0.13 µm standard-cell library. Starting from the HW3 synthesized gate-level netlist, the flow covers floorplanning, power routing, placement, clock tree synthesis (CTS), routing, and sign-off checks.

## APR Flow

```
Synthesized Netlist (core_syn.v)  +  SDC (core_syn.sdc)
            │
            ▼
  1. Floorplan & Power Ring / Stripes
            │
            ▼
  2. Standard-Cell Placement
            │
            ▼
  3. Clock Tree Synthesis (CTS)        ← ccopt.spec
            │
            ▼
  4. Route (NanoRoute)
            │
            ▼
  5. Sign-off: DRC · Geometry · Antenna · Connectivity
            │
            ▼
  Outputs: core.gds  |  core_pr.v  |  core_pr.sdf
```

## Sign-off Results (Cadence Innovus)

| Check | Result |
|-------|--------|
| DRC violations (`verify_drc`) | **0** |
| Geometry violations (`verifyGeometry`) | **0** |
| Antenna violations | **0** |
| Connectivity issues | **0 (no problems or warnings)** |

Post-route timing summary:

| Metric | Value |
|--------|-------|
| WNS (setup) | 0.913 ns (positive — timing met) |
| TNS | 0.000 ns |
| Violating paths | 0 |

## Key Files

| File | Description |
|------|-------------|
| `innovus.cmd` | Full Innovus session command log (reproducible flow) |
| `core.conf` | Innovus configuration |
| `mmmc.view` | Multi-mode multi-corner (MMMC) timing view definition |
| `ccopt.spec` | CTS specification |
| `design_data/core_syn.v` | Input synthesized netlist |
| `design_data/core_syn.sdc` | Input timing constraints |
| `core_pr.v` | Output post-route netlist |
| `core_pr.sdf` | Output back-annotated SDF for gate sim |
| `core.drc.rpt` | DRC report |
| `core.geom.rpt` | Geometry check report |
| `core.antenna.rpt` | Antenna rule check report |
| `core.conn.rpt` | Connectivity report |
| `sim/` | Post-layout simulation environment |

## Directory Layout

```
HW5_APR/
├── innovus.cmd           ← full Innovus command script
├── core.conf             ← tool configuration
├── mmmc.view             ← MMMC view
├── ccopt.spec            ← CTS spec
├── design_data/
│   ├── core_syn.v        ← synthesized netlist (input)
│   └── core_syn.sdc      ← SDC constraints (input)
├── core_pr.v             ← post-route netlist (output)
├── core_pr.sdf           ← back-annotated SDF (output)
├── core.drc.rpt          ← DRC sign-off report
├── core.geom.rpt         ← geometry sign-off report
├── core.antenna.rpt      ← antenna sign-off report  (via Final APR)
├── core.conn.rpt         ← connectivity report
├── sim/                  ← post-layout simulation
│   ├── 00_TESTBED/
│   └── PATTERNS/
├── library/              ← LEF / LIB / GDS for standard cells
└── 1141_hw5.pdf          ← assignment specification
```
