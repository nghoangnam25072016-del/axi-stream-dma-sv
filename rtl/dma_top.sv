// -----------------------------------------------------------------------------
// dma_top.sv
// -----------------------------------------------------------------------------
// Top-level wrapper tying the AXI4-Lite register block to the streaming DMA core.
// -----------------------------------------------------------------------------

module dma_top #(
  parameter int DATA_W = 32,
  parameter int LEN_W  = 16,
  parameter int ADDR_W = 8
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

  input  logic [DATA_W-1:0]     s_axis_tdata,
  input  logic                  s_axis_tvalid,
  output logic                  s_axis_tready,

  output logic [DATA_W-1:0]     m_axis_tdata,
  output logic                  m_axis_tvalid,
  input  logic                  m_axis_tready
);

  logic                  start_pulse;
  logic                  soft_reset_pulse;
  logic                  clear_status_pulse;
  logic [LEN_W-1:0]      length;
  logic                  engine_rst_n;
  logic                  busy;
  logic                  done;
  logic                  error;
  logic [LEN_W-1:0]      delivered_count;

  assign engine_rst_n = rst_n && !soft_reset_pulse;

  axi_lite_regs #(
    .ADDR_W(ADDR_W),
    .LEN_W (LEN_W)
  ) u_regs (
    .clk                  (clk),
    .rst_n                (rst_n),

    .s_axil_awaddr        (s_axil_awaddr),
    .s_axil_awvalid       (s_axil_awvalid),
    .s_axil_awready       (s_axil_awready),
    .s_axil_wdata         (s_axil_wdata),
    .s_axil_wstrb         (s_axil_wstrb),
    .s_axil_wvalid        (s_axil_wvalid),
    .s_axil_wready        (s_axil_wready),
    .s_axil_bresp         (s_axil_bresp),
    .s_axil_bvalid        (s_axil_bvalid),
    .s_axil_bready        (s_axil_bready),
    .s_axil_araddr        (s_axil_araddr),
    .s_axil_arvalid       (s_axil_arvalid),
    .s_axil_arready       (s_axil_arready),
    .s_axil_rdata         (s_axil_rdata),
    .s_axil_rresp         (s_axil_rresp),
    .s_axil_rvalid        (s_axil_rvalid),
    .s_axil_rready        (s_axil_rready),

    .start_pulse_o        (start_pulse),
    .soft_reset_pulse_o   (soft_reset_pulse),
    .clear_status_pulse_o (clear_status_pulse),
    .length_o             (length),

    .busy_i               (busy),
    .done_i               (done),
    .error_i              (error),
    .delivered_count_i    (delivered_count)
  );

  dma_engine #(
    .DATA_W(DATA_W),
    .LEN_W (LEN_W)
  ) u_engine (
    .clk                  (clk),
    .rst_n                (engine_rst_n),
    .start_pulse          (start_pulse),
    .clear_status_pulse   (clear_status_pulse),
    .length_i             (length),

    .s_axis_tdata         (s_axis_tdata),
    .s_axis_tvalid        (s_axis_tvalid),
    .s_axis_tready        (s_axis_tready),
    .m_axis_tdata         (m_axis_tdata),
    .m_axis_tvalid        (m_axis_tvalid),
    .m_axis_tready        (m_axis_tready),

    .busy_o               (busy),
    .done_o               (done),
    .error_o              (error),
    .delivered_count_o    (delivered_count)
  );

endmodule
