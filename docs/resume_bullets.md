# Resume Bullets and Interview Script

## Project title

**AXI4-Lite Controlled Streaming DMA Engine with SystemVerilog Verification**

## Resume bullets, design-focused

- Designed a synthesizable SystemVerilog streaming DMA engine with AXI4-Lite control registers, ready/valid datapath, transfer counters, sticky status bits, and error handling.
- Implemented backpressure-safe AXI-Stream control logic so output stalls correctly propagate to the input source without data loss or reordering.
- Built a memory-mapped register block supporting independent AXI4-Lite write address/data handshakes, readback registers, byte strobes, and invalid address error responses.

## Resume bullets, verification-focused

- Developed a self-checking SystemVerilog testbench with randomized source valid gaps, randomized sink backpressure, directed error tests, and scoreboard-based data checking.
- Added SystemVerilog assertions to verify stream data stability during stalls, AXI-Lite response stability, and legal DMA status behavior.
- Created a multi-seed regression flow and verification plan covering normal transfers, zero-length command errors, illegal start-while-busy behavior, and invalid register accesses.

## Strong 2-line version for LinkedIn/GitHub

Built an AXI4-Lite controlled AXI-Stream DMA engine in SystemVerilog with sticky status/error handling and backpressure-safe ready/valid control. Verified using a self-checking randomized testbench, scoreboard, SVA assertions, and multi-seed regression scripting.

## Interview explanation

> I built a small DMA-style block that a CPU can program through AXI4-Lite registers. The register block generates a start pulse and provides status readback. The DMA core then transfers a programmed number of beats from an input stream to an output stream. The key part is that completion is counted on output handshakes, not input handshakes, so the design does not claim done until the final beat has actually passed downstream backpressure.

## Best waveform signals to show

Add these signals to your waveform screenshot:

- `clk`, `rst_n`
- `start_pulse`
- `length`
- `busy`, `done`, `error`
- `s_axis_tvalid`, `s_axis_tready`, `s_axis_tdata`
- `m_axis_tvalid`, `m_axis_tready`, `m_axis_tdata`
- `accepted_count_q`
- `delivered_count_q`

## Best GitHub README screenshot caption

> Randomized transfer with sink backpressure. Notice that `s_axis_tready` drops when the output side stalls, and `done` asserts only after the final output beat is accepted.

## What not to say

Do not say this is a full production DMA. Say it is a **streaming DMA engine / DMA-style datapath**. That is honest and still impressive.

Better wording:

> This is a compact DMA-style RTL block focused on register control, stream datapath flow control, and verification methodology. My next extension would be an AXI4 master read/write datapath and scatter-gather descriptors.
