// -----------------------------------------------------------------------------
// axi_lite_regs.sv
// -----------------------------------------------------------------------------
// Small AXI4-Lite style register block for the DMA engine.
//
// Supported registers:
//   0x00 CTRL   W: bit0=start, bit1=soft reset, bit2=clear status
//               R: returns zero
//   0x04 LENGTH W/R transfer length in beats
//   0x08 STATUS R: bit0=busy, bit1=done, bit2=error
//   0x0C COUNT  R: delivered beat count
//
// The write address and write data channels are accepted independently, then a
// response is generated after both have arrived. This mirrors the important
// handshake idea of AXI4-Lite while keeping the block interview-sized.
// -----------------------------------------------------------------------------

`include "dma_defs.svh"

module axi_lite_regs #(
  parameter int ADDR_W = 8,
  parameter int LEN_W  = 16
)(
  input  logic                  clk,
  input  logic                  rst_n,

  input  logic [ADDR_W-1:0]     s_axil_awaddr,
  input  logic                  s_axil_awvalid,
  output logic                  s_axil_awready,

  input  logic [31:0]           s_axil_wdata,
  input  logic [3:0]            s_axil_wstrb,
  input  logic                  s_axil_wvalid,
  output logic                  s_axil_wready,

  output logic [1:0]            s_axil_bresp,
  output logic                  s_axil_bvalid,
  input  logic                  s_axil_bready,

  input  logic [ADDR_W-1:0]     s_axil_araddr,
  input  logic                  s_axil_arvalid,
  output logic                  s_axil_arready,

  output logic [31:0]           s_axil_rdata,
  output logic [1:0]            s_axil_rresp,
  output logic                  s_axil_rvalid,
  input  logic                  s_axil_rready,

  output logic                  start_pulse_o,
  output logic                  soft_reset_pulse_o,
  output logic                  clear_status_pulse_o,
  output logic [LEN_W-1:0]      length_o,

  input  logic                  busy_i,
  input  logic                  done_i,
  input  logic                  error_i,
  input  logic [LEN_W-1:0]      delivered_count_i
);

  logic [LEN_W-1:0]  length_q;

  logic              aw_seen_q;
  logic              w_seen_q;
  logic [ADDR_W-1:0] awaddr_q;
  logic [31:0]       wdata_q;
  logic [3:0]        wstrb_q;

  logic              aw_accept;
  logic              w_accept;
  logic              write_fire;
  logic [ADDR_W-1:0] wr_addr;
  logic [31:0]       wr_data;
  logic [3:0]        wr_strb;

  assign length_o        = length_q;
  assign s_axil_awready  = !aw_seen_q && !s_axil_bvalid;
  assign s_axil_wready   = !w_seen_q  && !s_axil_bvalid;
  assign s_axil_arready  = !s_axil_rvalid;

  assign aw_accept = s_axil_awvalid && s_axil_awready;
  assign w_accept  = s_axil_wvalid  && s_axil_wready;

  assign write_fire = !s_axil_bvalid &&
                      (aw_seen_q || aw_accept) &&
                      (w_seen_q  || w_accept);

  assign wr_addr = aw_accept ? s_axil_awaddr : awaddr_q;
  assign wr_data = w_accept  ? s_axil_wdata  : wdata_q;
  assign wr_strb = w_accept  ? s_axil_wstrb  : wstrb_q;

  function automatic [LEN_W-1:0] apply_len_wstrb(
    input [LEN_W-1:0] old_value,
    input [31:0]      new_value,
    input [3:0]       wstrb
  );
    automatic logic [31:0] result;
    begin
      result = {{(32-LEN_W){1'b0}}, old_value};
      if (wstrb[0]) result[7:0]   = new_value[7:0];
      if (wstrb[1]) result[15:8]  = new_value[15:8];
      if (wstrb[2]) result[23:16] = new_value[23:16];
      if (wstrb[3]) result[31:24] = new_value[31:24];
      return result[LEN_W-1:0];
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      length_q             <= '0;
      aw_seen_q            <= 1'b0;
      w_seen_q             <= 1'b0;
      awaddr_q             <= '0;
      wdata_q              <= '0;
      wstrb_q              <= '0;
      s_axil_bvalid        <= 1'b0;
      s_axil_bresp         <= `DMA_RESP_OKAY;
      s_axil_rvalid        <= 1'b0;
      s_axil_rdata         <= '0;
      s_axil_rresp         <= `DMA_RESP_OKAY;
      start_pulse_o        <= 1'b0;
      soft_reset_pulse_o   <= 1'b0;
      clear_status_pulse_o <= 1'b0;
    end else begin
      start_pulse_o        <= 1'b0;
      soft_reset_pulse_o   <= 1'b0;
      clear_status_pulse_o <= 1'b0;

      if (s_axil_bvalid && s_axil_bready) begin
        s_axil_bvalid <= 1'b0;
      end

      if (s_axil_rvalid && s_axil_rready) begin
        s_axil_rvalid <= 1'b0;
      end

      if (!write_fire) begin
        if (aw_accept) begin
          aw_seen_q <= 1'b1;
          awaddr_q  <= s_axil_awaddr;
        end

        if (w_accept) begin
          w_seen_q <= 1'b1;
          wdata_q  <= s_axil_wdata;
          wstrb_q  <= s_axil_wstrb;
        end
      end

      if (write_fire) begin
        aw_seen_q     <= 1'b0;
        w_seen_q      <= 1'b0;
        s_axil_bvalid <= 1'b1;
        s_axil_bresp  <= `DMA_RESP_OKAY;

        unique case (wr_addr)
          `DMA_REG_CTRL: begin
            start_pulse_o        <= wr_data[0];
            soft_reset_pulse_o   <= wr_data[1];
            clear_status_pulse_o <= wr_data[2];
          end

          `DMA_REG_LENGTH: begin
            length_q <= apply_len_wstrb(length_q, wr_data, wr_strb);
          end

          default: begin
            s_axil_bresp <= `DMA_RESP_DECERR;
          end
        endcase
      end

      if (s_axil_arvalid && s_axil_arready) begin
        s_axil_rvalid <= 1'b1;
        s_axil_rresp  <= `DMA_RESP_OKAY;

        unique case (s_axil_araddr)
          `DMA_REG_CTRL: begin
            s_axil_rdata <= 32'h0;
          end

          `DMA_REG_LENGTH: begin
            s_axil_rdata <= {{(32-LEN_W){1'b0}}, length_q};
          end

          `DMA_REG_STATUS: begin
            s_axil_rdata <= {29'h0, error_i, done_i, busy_i};
          end

          `DMA_REG_COUNT: begin
            s_axil_rdata <= {{(32-LEN_W){1'b0}}, delivered_count_i};
          end

          default: begin
            s_axil_rdata <= 32'hDEAD_BEEF;
            s_axil_rresp <= `DMA_RESP_DECERR;
          end
        endcase
      end
    end
  end

endmodule
