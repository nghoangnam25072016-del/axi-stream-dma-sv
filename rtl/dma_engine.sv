// -----------------------------------------------------------------------------
// dma_engine.sv
// -----------------------------------------------------------------------------
// A small but resume-worthy streaming DMA datapath.
//
// Function:
//   - Latches a programmed transfer length when start_pulse arrives.
//   - Accepts DATA_W-bit beats from an AXI-Stream-like source channel.
//   - Delivers those beats to an AXI-Stream-like destination channel.
//   - Handles downstream backpressure using ready/valid control.
//   - Exposes sticky done/error status and delivered beat count.
//
// This is intentionally simple enough to understand in an interview but still
// demonstrates real hardware design concepts: FSMs, ready/valid flow control,
// counters, sticky status, and error paths.
// -----------------------------------------------------------------------------

module dma_engine #(
  parameter int DATA_W = 32,
  parameter int LEN_W  = 16
)(
  input  logic                  clk,
  input  logic                  rst_n,

  input  logic                  start_pulse,
  input  logic                  clear_status_pulse,
  input  logic [LEN_W-1:0]      length_i,

  input  logic [DATA_W-1:0]     s_axis_tdata,
  input  logic                  s_axis_tvalid,
  output logic                  s_axis_tready,

  output logic [DATA_W-1:0]     m_axis_tdata,
  output logic                  m_axis_tvalid,
  input  logic                  m_axis_tready,

  output logic                  busy_o,
  output logic                  done_o,
  output logic                  error_o,
  output logic [LEN_W-1:0]      delivered_count_o
);

  typedef enum logic [1:0] {
    ST_IDLE = 2'b00,
    ST_RUN  = 2'b01,
    ST_DONE = 2'b10
  } dma_state_e;

  dma_state_e             state_q, state_d;
  logic [LEN_W-1:0]       length_q;
  logic [LEN_W-1:0]       accepted_count_q;
  logic [LEN_W-1:0]       delivered_count_q;

  logic                   can_accept;
  logic                   in_hs;
  logic                   out_hs;
  logic                   last_out_hs;

  assign busy_o              = (state_q == ST_RUN);
  assign delivered_count_o   = delivered_count_q;

  // Accept a new input beat only while running, while the transfer still needs
  // more input beats, and while the output register can take new data.
  assign can_accept = (state_q == ST_RUN) &&
                      (accepted_count_q < length_q) &&
                      (!m_axis_tvalid || m_axis_tready);

  assign s_axis_tready = can_accept;
  assign in_hs         = s_axis_tvalid && s_axis_tready;
  assign out_hs        = m_axis_tvalid && m_axis_tready;
  assign last_out_hs   = out_hs && (delivered_count_q == (length_q - 1'b1));

  always_comb begin
    state_d = state_q;

    unique case (state_q)
      ST_IDLE: begin
        if (start_pulse && (length_i != '0)) begin
          state_d = ST_RUN;
        end
      end

      ST_RUN: begin
        if (last_out_hs) begin
          state_d = ST_DONE;
        end
      end

      ST_DONE: begin
        // Done is sticky. A new valid start immediately begins another transfer.
        if (start_pulse && (length_i != '0)) begin
          state_d = ST_RUN;
        end else if (clear_status_pulse) begin
          state_d = ST_IDLE;
        end
      end

      default: begin
        state_d = ST_IDLE;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q          <= ST_IDLE;
      length_q         <= '0;
      accepted_count_q <= '0;
      delivered_count_q<= '0;
      m_axis_tdata     <= '0;
      m_axis_tvalid    <= 1'b0;
      done_o           <= 1'b0;
      error_o          <= 1'b0;
    end else begin
      state_q <= state_d;

      if (clear_status_pulse) begin
        done_o  <= 1'b0;
        error_o <= 1'b0;
      end

      // Illegal command handling.
      if (start_pulse && (length_i == '0)) begin
        error_o <= 1'b1;
      end

      if (start_pulse && (state_q == ST_RUN)) begin
        error_o <= 1'b1;
      end

      // Start or restart a transfer.
      if (start_pulse && (length_i != '0) && (state_q != ST_RUN)) begin
        length_q          <= length_i;
        accepted_count_q  <= '0;
        delivered_count_q <= '0;
        done_o            <= 1'b0;
      end

      // Output register control.
      // If output beat is consumed and no new input arrives, clear valid.
      // If output beat is consumed and new input arrives, replace data.
      if (out_hs && !in_hs) begin
        m_axis_tvalid <= 1'b0;
      end

      if (in_hs) begin
        m_axis_tdata  <= s_axis_tdata;
        m_axis_tvalid <= 1'b1;
        accepted_count_q <= accepted_count_q + 1'b1;
      end

      if (out_hs) begin
        delivered_count_q <= delivered_count_q + 1'b1;
      end

      if (last_out_hs) begin
        done_o <= 1'b1;
      end
    end
  end

endmodule
