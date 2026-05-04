# Architecture Notes

## Goal

The goal is to build a compact but realistic RTL block that looks like something inside a larger SoC: a CPU configures a DMA engine through memory-mapped registers, then the DMA moves data through a streaming datapath.

This project is not trying to be a full PCIe/NVMe/GPU DMA. It is the clean learning core: registers, control FSM, counters, valid/ready flow control, status bits, and verification.

## Main blocks

### `axi_lite_regs`

This block exposes a small AXI4-Lite style programming interface.

Responsibilities:

- Decode register addresses
- Store transfer length
- Generate one-cycle command pulses
- Return status and delivered count
- Return `DECERR` for invalid reads/writes
- Support independent write address and write data handshakes

Important interview talking point:

> AXI4-Lite write address and write data channels are independent. A robust slave should not assume AW and W arrive in the same cycle. This register block captures each channel separately, then fires the write only after both have arrived.

### `dma_engine`

This block owns the actual transfer.

Responsibilities:

- Latch `length_i` when `start_pulse` arrives
- Accept input stream beats only while busy
- Forward beats to output stream
- Stall the input stream when the output side applies backpressure
- Count accepted and delivered beats
- Set sticky `done_o` after the last output beat is delivered
- Set sticky `error_o` for zero-length start or start while busy

Important interview talking point:

> Completion is based on output delivery, not input acceptance. This avoids reporting `done` while the last beat is still stuck behind downstream backpressure.

## FSM

```text
          valid start,len>0
      +---------------------+
      |                     v
   +------+              +-----+   last output beat delivered   +------+
   | IDLE |              | RUN |------------------------------->| DONE |
   +------+              +-----+                                +------+
      ^                                                          |
      |                      clear_status or reset               |
      +----------------------------------------------------------+
```

## Ready/valid rule

The engine accepts a source beat only when the output register can accept it:

```text
s_axis_tready = running AND still_need_input AND (output_empty OR output_ready)
```

This creates a one-entry elastic buffer. It is small, easy to reason about, and sufficient to prove understanding of backpressure.

## Status behavior

- `busy`: high only in `RUN`
- `done`: sticky after transfer finishes
- `error`: sticky after invalid command
- `clear_status`: clears sticky `done` and `error`

## Possible extensions

Good extensions if you want to make the repo even stronger later:

1. Add source/destination memory addresses and an AXI4 master read/write datapath.
2. Add descriptor fetcher for scatter-gather DMA.
3. Add interrupt output with mask/status registers.
4. Add unaligned byte-enable support.
5. Replace the simple one-entry output register with a parameterized FIFO.
6. Build a full UVM testbench with sequencer, driver, monitor, scoreboard, coverage collector, and virtual sequence.
