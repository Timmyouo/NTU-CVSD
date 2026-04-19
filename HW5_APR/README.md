# HW5 — Place & Route Sign-off (Cadence Innovus)

Full physical implementation of the HW3 convolution `core` from synthesized netlist to **DRC-clean, antenna-clean, timing-met layout** using **Cadence Innovus 17.11** on the TSMC 0.13 µm 8-metal-layer (`tsmc13fsg_8lm_cic.lef`) library.

## What This Demonstrates

- Hands-on **complete APR flow** in an industry-standard tool — not just running a canned script, but writing the configuration (`core.conf`), MMMC view (`mmmc.view`), CTS spec (`ccopt.spec`), and IO constraints (`core.ioc`)
- **Macro placement** — manually placing a `4096×8` SRAM macro on the floorplan with proper halo and pin orientation
- **Power planning** — top-level VDD/VSS rings, vertical/horizontal stripes, standard-cell rail connection
- **Sign-off cleanliness** — zero violations across DRC, geometry, antenna, and connectivity checks
- **Post-route timing closure** with positive slack across all path groups

## APR Flow (as captured in `innovus.cmd`)

```
                  ┌──────────────────────────────────────────────┐
core_syn.v        │   1. Init Design (LEF + LIB + Netlist + SDC) │
core_syn.sdc ────▶│   2. Floorplan + Power Ring/Stripes          │
                  │   3. Place Standard Cells (placeDesign)      │
                  │   4. Pre-CTS optimization                    │
                  │   5. CTS  (ccopt_design + ccopt.spec)        │
                  │   6. Route (NanoRoute)                        │
                  │   7. Post-route opt + filler insertion        │
                  │   8. Sign-off:                                │
                  │        verify_drc · verifyGeometry           │
                  │        verifyConnectivity · verifyAntenna    │
                  │        timeDesign -postRoute                 │
                  └──────────┬───────────────────────────────────┘
                             ▼
                core.gds · core_pr.v · core_pr.sdf
```

## Sign-off Results

**Cadence Innovus 17.11**

| Check | Tool command | Result |
|-------|--------------|--------|
| DRC | `verify_drc` | **0 violations** |
| Geometry | `verifyGeometry` | **0 violations** |
| Antenna | `verifyProcessAntenna` | **0 violations** |
| Connectivity | `verifyConnectivity` | **0 problems, 0 warnings** |

### Post-route static timing (`timeDesign -postRoute`)

| Path group | WNS (ns) | TNS (ns) | Violating paths |
|-----------|---------:|---------:|----------------:|
| All       | **+0.913** | 0.000 | 0 |
| reg2reg   | +0.913   | 0.000 | 0 |
| in2reg    | +0.913   | 0.000 | 0 |
| reg2out   | +2.386   | 0.000 | 0 |

(Values from final post-route summary; positive WNS = timing met.)

## Tool Configuration Highlights

| File | Purpose |
|------|---------|
| `innovus.cmd` | **Reproducible** Innovus session command log |
| `core.conf` | Design / library / netlist / SDC paths |
| `mmmc.view` | Multi-Mode Multi-Corner timing view definition |
| `ccopt.spec` | CTS target skew / max transition / NDR rules |
| `core.ioc` | IO pin constraints |
| `core_cts.sdc` | Post-CTS SDC (propagated clock) |

## Outputs Produced

| File | What it is |
|------|-----------|
| `core.gds` | Final layout (excluded from git via `.gitignore`) |
| `core_pr.v` | Post-route gate-level netlist |
| `core_pr.sdf` | Back-annotated SDF for post-layout simulation |
| `core.{drc,geom,conn,antenna}.rpt` | Sign-off reports |
| `summaryReport.rpt` | Innovus design summary |
| `sim/` | Post-layout simulation environment |

## Directory Layout

```
HW5_APR/
├── innovus.cmd                ← full Innovus command log
├── core.conf  mmmc.view  ccopt.spec  core.ioc
├── design_data/
│   ├── core_syn.v             ← INPUT: synthesized netlist
│   └── core_syn.sdc           ← INPUT: SDC constraints
├── core_pr.v / core_pr.sdf    ← OUTPUT: post-route netlist + SDF
├── core.{drc,geom,conn,antenna}.rpt   ← sign-off reports (all clean)
├── summaryReport.rpt
├── library/                   ← LEF / LIB / capTbl for std cells & SRAM
├── sram_lef/                  ← additional SRAM LEFs
├── sim/                       ← post-layout simulation
└── 1141_hw5.pdf               ← assignment specification
```
