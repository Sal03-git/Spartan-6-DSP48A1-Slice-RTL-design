# ⚡ Spartan-6 DSP48A1 Slice — RTL Implementation

A complete Verilog RTL model of the **Xilinx Spartan-6 DSP48A1** arithmetic slice, verified in QuestaSim with directed test patterns and implemented in Vivado targeting the `xc7a200tffg1156-3` FPGA.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Parameters](#parameters)
- [Port Reference](#port-reference)
- [OPMODE Bit Descriptions](#opmode-bit-descriptions)
- [Getting Started](#getting-started)
  - [Simulation (QuestaSim)](#simulation-questasim)
  - [Implementation (Vivado)](#implementation-vivado)
- [Test Cases](#test-cases)
- [Vivado Results](#vivado-results)
- [Author](#author)

---

## Overview

The DSP48A1 is the core arithmetic building block in Spartan-6 FPGAs. It combines a **pre-adder/subtracter**, an **18×18 multiplier**, and a **post-adder/subtracter** in a single pipelined datapath, enabling efficient implementation of multiply-accumulate (MAC), FIR filter, and wide-addition operations.

This RTL model faithfully replicates:
- All pipeline register stages (A0, A1, B0, B1, C, D, M, P, OPMODE, CYI, CYO)
- Configurable synchronous or asynchronous reset via `RSTTYPE`
- Dynamic datapath selection via the 8-bit `OPMODE` control word
- DSP cascade ports (`BCIN`/`BCOUT`, `PCIN`/`PCOUT`)

---

## Architecture

```
                     ┌──────────────────────────────────────────────────────────────┐
  D[17:0] ──D_REG──► │                                                              │
                     │   Pre-Adder/Subtracter                                       │
  B[17:0] ──B0_REG──►│   (OPMODE[6]: 0=D+B, 1=D-B)                                 │
  BCIN ────────────► │   (OPMODE[4]: 0=bypass, 1=use pre-adder)                    │
                     │                            ▼ B1_REG ──► BCOUT               │
  A[17:0] ──A0_REG──A1_REG──────────────────────►│                                 │
                     │                   18×18 Multiplier ──M_REG──► M[35:0]       │
                     │                            ▼                                 │
                     │           X Mux (OPMODE[1:0]): 0/Mult/P/D:A:B               │
  C[47:0] ──C_REG──► │           Z Mux (OPMODE[3:2]): 0/PCIN/P/C                   │
  PCIN ────────────► │                            ▼                                 │
  CARRYIN / OPMODE[5]│         Post-Adder/Subtracter (OPMODE[7]: add/sub)          │
                     │                   Z ± (X + CIN)                              │
                     │                            ▼ P_REG ──► P[47:0] / PCOUT      │
                     │                       CYO_REG ──► CARRYOUT / CARRYOUTF      │
                     └──────────────────────────────────────────────────────────────┘
```

Grey-shaded muxes are configured at elaboration time via **parameters**. Clear muxes are controlled dynamically by **OPMODE** at runtime.

---

## Repository Structure

```
DSP48A1/
│
├── src/
│   ├── DSP48A1.v            # Top-level DSP48A1 RTL model
│   └── grey_mux.v           # Parameterised pipeline register / bypass mux
│
├── sim/
│   ├── DSP48A1_tb.v         # Directed testbench (5 test cases)
│   └── run_DSP48A1_tb.do    # QuestaSim do file
│
├── constraints/
│   └── DSP48A1.xdc          # Vivado timing constraint (100 MHz clock)
│
├── .gitignore
└── README.md
```

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `A0REG` | 0 | Pipeline register stage 0 for input A (0=bypass, 1=register) |
| `A1REG` | 1 | Pipeline register stage 1 for input A |
| `B0REG` | 0 | Pipeline register stage 0 for input B |
| `B1REG` | 1 | Pipeline register stage 1 for input B |
| `CREG` | 1 | Register for input C |
| `DREG` | 1 | Register for input D |
| `MREG` | 1 | Multiplier output register |
| `PREG` | 1 | P output register |
| `CARRYINREG` | 1 | Carry-in register (CYI) |
| `CARRYOUTREG` | 1 | Carry-out register (CYO) |
| `OPMODEREG` | 1 | OPMODE register |
| `RSTTYPE` | `"SYNC"` | Reset type: `"SYNC"` or `"ASYNC"` |
| `CARRYINSEL` | `"OPMODE5"` | Carry-in source: `"CARRYIN"` or `"OPMODE5"` |
| `B_INPUT` | `"DIRECT"` | B input source: `"DIRECT"` or `"CASCADE"` (uses BCIN) |

---

## Port Reference

### Data Inputs

| Port | Width | Description |
|------|-------|-------------|
| `A` | 18 | Input to multiplier and optionally post-adder |
| `B` | 18 | Input to pre-adder/subtracter and multiplier |
| `C` | 48 | Input to post-adder (Z mux option 3) |
| `D` | 18 | Input to pre-adder; D[11:0] joins D:A:B concat |
| `CARRYIN` | 1 | Carry input to post-adder |
| `BCIN` | 18 | Cascaded B input from adjacent DSP48A1 |
| `PCIN` | 48 | Cascaded P input from adjacent DSP48A1 |

### Control Inputs

| Port | Width | Description |
|------|-------|-------------|
| `OPMODE` | 8 | Selects datapath operations (see table below) |
| `CLK` | 1 | Design clock |
| `CEA…CEOPMODE` | 1 | Clock enables for each register stage |
| `RSTA…RSTOPMODE` | 1 | Active-high resets for each register stage |

### Outputs

| Port | Width | Description |
|------|-------|-------------|
| `P` | 48 | Post-adder/subtracter output (registered if PREG=1) |
| `M` | 36 | Multiplier output (registered if MREG=1) |
| `BCOUT` | 18 | Cascade output of B1 register |
| `PCOUT` | 48 | Cascade output = copy of P |
| `CARRYOUT` | 1 | Registered carry output (cascade to adjacent DSP) |
| `CARRYOUTF` | 1 | Copy of CARRYOUT for FPGA user logic |

---

## OPMODE Bit Descriptions

| Bits | Function | Values |
|------|----------|--------|
| `[1:0]` | X mux — source of X input to post-adder | `00`=0, `01`=Multiplier, `10`=P (accum), `11`=D:A:B |
| `[3:2]` | Z mux — source of Z input to post-adder | `00`=0, `01`=PCIN, `10`=P (accum), `11`=C |
| `[4]` | Pre-adder enable | `0`=bypass (B→mult), `1`=use pre-adder |
| `[5]` | Carry-in value (when CARRYINSEL=OPMODE5) | `0` or `1` |
| `[6]` | Pre-adder operation | `0`=D+B, `1`=D−B |
| `[7]` | Post-adder operation | `0`=Z+(X+CIN), `1`=Z−(X+CIN) |

---

## Getting Started

### Simulation (QuestaSim)

```bash
cd sim/
vsim -do run_DSP48A1_tb.do
```

Expected console output:
```
PASS  Section 2.1 — Reset
PASS  Section 2.2 — Path 1
PASS  Section 2.3 — Path 2
PASS  Section 2.4 — Path 3
PASS  Section 2.5 — Path 4
```

### Implementation (Vivado)

1. Create a new Vivado project targeting **`xc7a200tffg1156-3`**
   *(the Basys3 xc7a35t does not have enough I/O pins for all DSP48A1 ports)*
2. Add sources: `src/grey_mux.v`, `src/DSP48A1.v`
3. Add constraint: `constraints/DSP48A1.xdc`
4. Run **Elaboration → Synthesis → Implementation** in sequence
5. Verify no critical warnings or errors in the Messages tab

---

## Test Cases

| Test | OPMODE | A | B | C | D | Expected BCOUT | Expected M | Expected P | Expected CARRYOUT |
|------|--------|---|---|---|---|---------------|-----------|-----------|------------------|
| Reset | — | rand | rand | rand | rand | `0x00000` | `0x000000000` | `0x000000000000` | `0` |
| Path 1 | `0xDD` | 20 | 10 | 350 | 25 | `0x00f` | `0x00000012c` | `0x000000000032` | `0` |
| Path 2 | `0x10` | 20 | 10 | 350 | 25 | `0x023` | `0x0000002bc` | `0x000000000000` | `0` |
| Path 3 | `0x0A` | 20 | 10 | 350 | 25 | `0x00a` | `0x0000000c8` | `0x000000000000` | `0` |
| Path 4 | `0xA7` | 5  | 6  | 350 | 25 | `0x006` | `0x00000001e` | `0xfe6fffec0bb1` | `1` |

Pipeline latency varies per path (3–4 clock edges) due to the register configuration `A0REG=0, A1REG=1, B0REG=0, B1REG=1, MREG=1, PREG=1, OPMODEREG=1`.

---

## Vivado Results

| Metric | Value |
|--------|-------|
| Target FPGA | xc7a200tffg1156-3 |
| Clock frequency | 100 MHz |
| Worst Negative Slack (WNS) | 4.319 ns |
| Total Negative Slack (TNS) | 0.000 ns |
| Failing endpoints | 0 |
| Slice LUTs used | 190 |
| Slice Registers used | 159 |
| DSP blocks inferred | 1 |
| Bonded IOBs used | 327 |

All timing constraints met. No critical warnings during elaboration, synthesis, or implementation.

---

## Author

**Salaheldeen Abdelmoneim** — [github.com/Sal03-git](https://github.com/Sal03-git)

Arab Academy for Science, Technology and Maritime Transport — Digital IC Design Course, 2025
