# Verification Plan

## Verification goal

Prove that the DMA transfers exactly the programmed number of stream beats, preserves data order, handles ready/valid backpressure, and reports status/error correctly.

## Testbench structure

```text
+--------------------+       AXI4-Lite       +-------------+
| AXI register tasks | --------------------> |             |
+--------------------+                       |             |
                                             |   dma_top   |
+--------------------+       S_AXIS          |             |       M_AXIS       +------------+
| random src driver  | --------------------> |             | ----------------> | scoreboard |
+--------------------+                       +-------------+                  +------------+
                                                      ^
                                                      |
                                               assertions/SVA
```

## Test list

| Test | Purpose |
|------|---------|
| `basic_no_backpressure` | Checks clean transfer with source and sink always ready |
| `source_gaps` | Checks operation when input stream has random valid gaps |
| `sink_backpressure` | Checks operation when output stream randomly stalls |
| `randomized` | Mixes source gaps and sink backpressure |
| `random_loop_*` | Multi-seed randomized transfer lengths and handshake patterns |
| `zero_length_error` | Checks invalid zero-length command sets error bit |
| `start_while_busy_error` | Checks illegal command while active sets error bit |
| `invalid_register_access` | Checks invalid AXI-Lite address returns DECERR |

## Scoreboard strategy

The testbench creates a queue of expected data before each transfer.

1. The source driver pops data from `source_q` only when `s_axis_tvalid && s_axis_tready`.
2. The scoreboard pops expected data from `expected_q` only when `m_axis_tvalid && m_axis_tready`.
3. Every output beat must match the next expected beat.
4. At the end of the transfer, the expected queue must be empty.

This catches:

- Dropped beats
- Duplicated beats
- Reordered beats
- Incorrect data forwarding
- Premature `done`

## Assertions

Implemented in `tb/dma_assertions.sv`:

| Assertion | What it checks |
|-----------|----------------|
| Output stream data stable while stalled | If `m_axis_tvalid=1` and `m_axis_tready=0`, data must not change |
| AXI-Lite write response stable while waiting | `BRESP` must remain stable while `BVALID=1` and `BREADY=0` |
| Done not busy | `done` and `busy` should not be high together |

## Functional coverage ideas

The included coverage block samples:

- Low/mid/high source valid percentage
- Low/mid/high destination ready percentage
- Output handshake activity

Extra bins you can add later:

- Transfer length bins: 1, small, medium, large, max
- Start command during each FSM state
- Clear status during done/error states
- Invalid register read/write addresses
- Back-to-back transfers

## Regression command

```bash
cd sim
make regress
```

The default regression runs 20 seeds through `scripts/run_random_tests.py`.
