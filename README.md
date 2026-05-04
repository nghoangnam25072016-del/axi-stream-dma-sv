# AXI4-Lite Controlled AXI-Stream DMA Engine

A resume-ready RTL + verification project for digital design / ASIC verification roles.

This project implements a register-controlled streaming DMA datapath using SystemVerilog RTL. A CPU-style AXI4-Lite register block programs transfer length and start/clear commands. The DMA core moves data from an input AXI-Stream channel to an output AXI-Stream channel while handling backpressure, sticky status, error cases, and transfer accounting.

## Why this project is resume-worthy

It demonstrates skills that recruiters and hardware teams recognize immediately:

- Synthesizable SystemVerilog RTL design
- AXI4-Lite style register programming
- AXI-Stream ready/valid datapath control
- FSM design with backpressure handling
- Sticky status/error logic
- Self-checking randomized testbench
- Scoreboard-based data checking
- Assertions for protocol behavior
- Functional coverage plan
- Regression scripting
- Clean GitHub-ready documentation

## Block diagram

```text
             AXI4-Lite Register Bus
        AW/W/B/AR/R channels from CPU/testbench
                         |
                         v
+---------------------------------------------------+
|                    dma_top                        |
|                                                   |
|  +----------------+       +--------------------+  |
|  | axi_lite_regs  |-----> |    dma_engine      |  |
|  | CTRL/LEN/STAT  |      | FSM + counters      |  |
|  +----------------+      +--------------------+  |
|                                ^        |         |
|                                |        v         |
|                           S_AXIS     M_AXIS       |
+---------------------------------------------------+
```

## Register map

| Address | Name   | Access | Description |
|--------:|--------|:------:|-------------|
| `0x00`  | CTRL   | W/R    | bit0=start pulse, bit1=soft reset pulse, bit2=clear status pulse |
| `0x04`  | LENGTH | W/R    | Number of stream beats to transfer |
| `0x08`  | STATUS | R      | bit0=busy, bit1=done, bit2=error |
| `0x0C`  | COUNT  | R      | Number of beats delivered on output stream |

## Directory layout

```text
rtl/
  axi_lite_regs.sv       AXI4-Lite register block
  dma_engine.sv          Streaming DMA datapath + FSM
  dma_top.sv             Top-level integration
  dma_defs.svh           Shared register definitions

tb/
  tb_dma.sv              Self-checking randomized testbench
  dma_assertions.sv      SVA protocol/status checks

docs/
  architecture.md        Design explanation
  verification_plan.md   Test plan, coverage, assertions
  resume_bullets.md      Resume-ready bullets and interview talking points

sim/
  Makefile               Questa/VCS/Xcelium-style simulation targets

scripts/
  run_random_tests.py    Multi-seed regression helper
```

## How to run

### Questa/ModelSim

```bash
cd sim
make SIM=questa run
make SIM=questa regress
```

### Synopsys VCS

```bash
cd sim
make SIM=vcs run
```

### Cadence Xcelium

```bash
cd sim
make SIM=xcelium run
```

> Note: The project uses SystemVerilog assertions and coverage constructs. Questa/VCS/Xcelium are the intended simulators. Open-source simulators may require small edits.

## Suggested GitHub checklist

Before adding this to your resume:

1. Run at least 20 random seeds.
2. Save one waveform screenshot showing `start`, `busy`, stream handshakes, and `done`.
3. Save one terminal log showing `TEST PASSED`.
4. Add your own short explanation in the README.
5. Push the repo publicly.

## Resume title

**AXI4-Lite Controlled Streaming DMA Engine with SystemVerilog Verification**

See `docs/resume_bullets.md` for bullet points.
