// -----------------------------------------------------------------------------
// dma_assertions.sv
// -----------------------------------------------------------------------------
// Simple SVA checks for the DMA top-level interfaces.
// These assertions are intentionally easy to explain in an interview.
// -----------------------------------------------------------------------------

module dma_assertions #(
  parameter int DATA_W = 32
)(
  input logic              clk,
  input logic              rst_n,

  input logic [DATA_W-1:0] m_axis_tdata,
  input logic              m_axis_tvalid,
  input logic              m_axis_tready,

  input logic              s_axil_bvalid,
  input logic              s_axil_bready,
  input logic [1:0]        s_axil_bresp,

  input logic              busy,
  input logic              done,
  input logic              error
);

`ifdef ASSERT_ON

  property p_stream_data_stable_when_stalled;
    @(posedge clk) disable iff (!rst_n)
      (m_axis_tvalid && !m_axis_tready) |=> (m_axis_tvalid && $stable(m_axis_tdata));
  endproperty

  a_stream_data_stable_when_stalled:
    assert property (p_stream_data_stable_when_stalled)
    else $error("AXI-Stream output changed while stalled");

  property p_bresp_stable_when_waiting;
    @(posedge clk) disable iff (!rst_n)
      (s_axil_bvalid && !s_axil_bready) |=> (s_axil_bvalid && $stable(s_axil_bresp));
  endproperty

  a_bresp_stable_when_waiting:
    assert property (p_bresp_stable_when_waiting)
    else $error("AXI-Lite BRESP changed while waiting for BREADY");

  property p_done_not_busy;
    @(posedge clk) disable iff (!rst_n)
      done |-> !busy;
  endproperty

  a_done_not_busy:
    assert property (p_done_not_busy)
    else $error("DONE and BUSY asserted together");

  property p_error_sticky_until_clear_or_reset;
    @(posedge clk) disable iff (!rst_n)
      (error && !done) |=> error;
  endproperty

  // Note: the project clears error through CTRL[2]. This assertion is a simple
  // example and can be refined with the clear pulse exposed if desired.

`endif

endmodule
