# Final Project — Configurable BCH Decoder (RTL → GDS)

A team capstone in which we designed, verified, synthesized, and physically implemented a **runtime-configurable BCH error-correcting decoder** that supports **three code lengths** and **both hard-decision and Chase-II soft-decision decoding**, taken end-to-end through the complete RTL-to-GDS flow with **zero sign-off violations**.

---

## What This Project Demonstrates

- **Algorithmic ECC hardware** — finite-field arithmetic over GF(2^m), syndrome polynomial computation, **Berlekamp's iterative algorithm** for the error-locator polynomial, and **Chien search** for root finding
- **Soft-decision decoding** — a hardware **Chase-II decoder** that finds the least-reliable bits from received LLR values, generates test patterns by flipping subsets of those bits, runs each through the hard decoder, and selects the candidate with the highest correlation
- **Runtime configurability** — a single design that handles **three different BCH code lengths** with different correction capabilities, selected by a 2-bit `code` input
- **Hierarchical RTL** at scale — ~4,300 lines split across a top-level FSM controller (11 states) and three independent hard sub-decoders, each with its own 8-state FSM
- **Complete RTL → GDS flow** — RTL · DC synthesis with clock gating · gate-level simulation · Innovus place-and-route · post-route simulation — **all sign-off checks clean**, timing met with positive slack
- **Team workflow** — modular interfaces designed so controller, hard-decoders, and verification could be developed in parallel

---

## Supported Codes & Decoding Modes

| `code` | Code | n  | k   | Correction `t` | Use case |
|:------:|------|---:|----:|---------------:|----------|
| `01`   | BCH(63, 51)   |   63 |  51 | 2 | Compact codes, low overhead |
| `10`   | BCH(255, 239) |  255 | 239 | 2 | Storage / network ECC |
| `11`   | BCH(1023, 983) | 1023 | 983 | 3 | Long-block, higher correction power |

| `mode` | Decoding |
|:------:|----------|
| `0`    | **Hard-decision** — syndrome computation → Berlekamp → Chien search on the received hard bits |
| `1`    | **Soft-decision (Chase-II)** — sort LLRs, flip `2^p` test patterns over the *p* least-reliable bits, hard-decode each, pick the most-correlated candidate |

## Top Module Interface

```
module bch (
    input         clk, rstn,
    input         mode,        // 0 = hard, 1 = soft (Chase-II)
    input  [1:0]  code,        // selects one of three BCH codes
    input         set,         // start signal
    input  [63:0] idata,       // streaming input (codeword + LLRs)
    output        ready,       // decoder ready to accept input
    output        finish,      // decoding complete
    output [9:0]  odata        // decoded output
);
```

---

## Architecture

```
                      ┌────────────────────────────────────────────────────┐
                      │                       bch (top)                    │
                      │                                                    │
   idata[63:0] ─────▶ │  ┌──────────────────────────────────────────────┐ │
   mode, code  ─────▶ │  │  controller   (11-state FSM)                 │ │
   set         ─────▶ │  │   IDLE → HARD → LEAST → WAIT → LRB           │ │
                      │  │        → FLIP → CORR  → DELAY → SORT         │ │
                      │  │        → FINISH                              │ │
                      │  │   • dispatches to the correct sub-decoder    │ │
                      │  │   • implements Chase-II loop (soft mode)     │ │
                      │  │   • clock-gating insertion for LLR registers │ │
                      │  └────────┬────────────┬────────────┬────────────┘ │
                      │           │            │            │              │
                      │           ▼            ▼            ▼              │
                      │     ┌─────────┐  ┌──────────┐  ┌──────────┐       │
                      │     │ hard_63 │  │ hard_255 │  │ hard_1023│       │
                      │     │ (t=2)   │  │ (t=2)    │  │ (t=3)    │       │
                      │     │         │  │          │  │          │       │
                      │     │ 8-state │  │ 8-state  │  │ 8-state  │       │
                      │     │  FSM:   │  │   FSM    │  │   FSM    │       │
                      │     │ DIVIDE  │  │          │  │          │       │
                      │     │ SYNDR.  │  │          │  │          │       │
                      │     │ BERLE-  │  │          │  │          │       │
                      │     │ KAMP    │  │          │  │          │       │
                      │     │ ROOT    │  │          │  │          │       │
                      │     │ (Chien) │  │          │  │          │       │
                      │     └─────────┘  └──────────┘  └──────────┘       │
                      │                                                    │
   ready, finish ◀────│                                                    │
   odata[9:0]    ◀────│                                                    │
                      └────────────────────────────────────────────────────┘
```

### Hard sub-decoder FSM (each of `hard_63`, `hard_255`, `hard_1023`)

```
IDLE → DIVIDE → SYNDRONE → BERLEKAMP → ROOT ─┬─▶ FINISH (success)
                                               └─▶ FAIL    (uncorrectable)
                                       └─▶ NO_ERROR (zero syndrome)
```

| Stage | Function |
|-------|----------|
| `DIVIDE` | Polynomial long-division by `g(x)` to get the parity-check residual |
| `SYNDRONE` | Compute the syndrome polynomial S(x) over GF(2^m) |
| `BERLEKAMP` | Iteratively solve for the error-locator polynomial σ(x) |
| `ROOT` | Chien search — evaluate σ(x) at all field elements to locate errors |
| `NO_ERROR` / `FINISH` / `FAIL` | Output flags + decoded codeword |

### Chase-II soft-decision flow (controller)

```
S_LEAST  ─▶ collect LLR magnitudes from input stream
S_LRB    ─▶ sort and identify the p least-reliable bits
S_FLIP   ─▶ generate test patterns by flipping subsets of those bits
            and dispatch each to the appropriate hard decoder
S_CORR   ─▶ compute correlation between each hard-decoded
            candidate and the received soft vector
S_SORT   ─▶ select the candidate with the highest correlation
S_FINISH ─▶ output the chosen codeword
```

---

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
| Total cells | **36,643** (22,011 comb. + 12,189 seq.) |

The synthesis script (`02_SYN/syn.tcl`) enables Synopsys clock-gating; the resulting netlist contains many `SNPS_CLOCK_GATE_HIGH` instances (visible in `summaryReport.rpt`) that gate the LLR storage during idle states.

## Place & Route Sign-off

**Cadence Innovus 17.11**

| Check | Result |
|-------|--------|
| `verify_drc` | **0 violations** |
| `verifyGeometry` | **0 violations** |
| `verifyProcessAntenna` | **0 violations** |
| `verifyConnectivity` | **0 problems / 0 warnings** |

### Post-route static timing (`timeDesign -postRoute`)

| Path group | WNS (ns) | TNS (ns) | Violating / Total |
|-----------|---------:|---------:|------------------:|
| **All**   | **+0.913** | 0.000 | 0 / 12,203 |
| reg2reg   | +0.913   | 0.000 | 0 / 9,753 |
| reg2cgate | +1.262   | 0.000 | 0 / 2,433 |
| in2reg    | +0.913   | 0.000 | 0 / 12,189 |
| reg2out   | +2.386   | 0.000 | 0 / 12 |

### Layout statistics (post-route)

| Metric | Value |
|--------|------:|
| Standard cells placed | **58,256** |
| Hard macros | 0 |
| Core utilization (density) | **77.77%** |
| max_cap / max_tran / max_fanout violations | 0 / 0 / 0 |
| SI glitch violations | 0 |

---

## Flow Completed (RTL → GDS)

| Stage | Tool | Status | Key files |
|-------|------|:------:|-----------|
| RTL design | — | ✓ | `01_RTL/bch.v`, `controller.v`, `hard_63.v`, `hard_255.v`, `hard_1023.v` |
| RTL simulation | VCS + Verdi | ✓ | `01_RTL/rtlsim.sh`, `testdata/p{100,200,300}{,a}.txt` |
| Logic synthesis | Synopsys DC | ✓ | `02_SYN/syn.tcl`, `bch_dc.sdc` |
| Gate-level simulation | VCS + SDF | ✓ | `03_GATE/gatesim.sh` |
| Place & route | Cadence Innovus | ✓ | `04_APR/Netlist/`, `04_APR/Report/` |
| Post-route simulation | VCS + back-annotated SDF | ✓ | `05_POST/postsim.sh` |

---

## Directory Layout

```
Final_BCH_Decoder/
├── 01_RTL/
│   ├── bch.v                  ← top-level (~131 LOC)
│   ├── controller.v           ← 11-state controller, Chase-II soft decoder
│   ├── hard_63.v              ← BCH(63,51)  hard decoder
│   ├── hard_255.v             ← BCH(255,239) hard decoder
│   ├── hard_1023.v            ← BCH(1023,983) hard decoder
│   ├── test.v                 ← testbench
│   ├── testdata/              ← p100/p200/p300 (with `a` soft-LLR variants)
│   └── rtlsim.sh
├── 02_SYN/
│   ├── syn.tcl                ← Synopsys DC script (with clock gating)
│   ├── bch_dc.sdc             ← timing constraints (6.5 ns clk)
│   ├── Netlist/               ← bch_syn.v, bch_syn.sdf
│   └── Report/                ← bch_syn.area, bch_syn.timing_max
├── 03_GATE/                   ← gate-level simulation
├── 04_APR/
│   ├── Netlist/               ← bch_apr.v, bch_apr.sdf
│   └── Report/                ← summaryReport.rpt + DRC / geom / antenna / conn
├── 05_POST/                   ← post-route simulation
├── team042_report.pdf         ← full design report (team submission)
├── 114-1_final_note_v2.pdf    ← assignment specification
└── BCH code example*.pdf      ← reference material
```

---

## Notes on Authorship

This was a **team project** (team 042). The repository preserves the team submission as `team042_report.pdf`. The final tape-out-style flow — from the integrated RTL through the sign-off-clean Innovus layout — was the joint result of the team's work.
