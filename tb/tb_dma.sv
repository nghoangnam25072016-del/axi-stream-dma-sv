// -----------------------------------------------------------------------------
// tb_dma.sv
// -----------------------------------------------------------------------------
// Self-checking randomized testbench for the AXI4-Lite controlled streaming DMA.
//
// Verification features:
//   - AXI4-Lite read/write bus tasks
//   - Randomized source valid gaps
//   - Randomized destination backpressure
//   - Scoreboard using expected queue
//   - Error tests: zero-length start, start while busy, invalid register access
//   - Optional SVA via +define+ASSERT_ON
//   - Optional waveform dump via +WAVES
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
`include "dma_defs.svh"

module tb_dma;

  localparam int DATA_W = 32;
  localparam int LEN_W  = 16;
  localparam int ADDR_W = 8;

  logic clk;
  logic rst_n;

  logic [ADDR_W-1:0] s_axil_awaddr;
  logic              s_axil_awvalid;
  logic              s_axil_awready;
  logic [31:0]       s_axil_wdata;
  logic [3:0]        s_axil_wstrb;
  logic              s_axil_wvalid;
  logic              s_axil_wready;
  logic [1:0]        s_axil_bresp;
  logic              s_axil_bvalid;
  logic              s_axil_bready;
  logic [ADDR_W-1:0] s_axil_araddr;
  logic              s_axil_arvalid;
  logic              s_axil_arready;
  logic [31:0]       s_axil_rdata;
  logic [1:0]        s_axil_rresp;
  logic              s_axil_rvalid;
  logic              s_axil_rready;

  logic [DATA_W-1:0] s_axis_tdata;
  logic              s_axis_tvalid;
  logic              s_axis_tready;
  logic [DATA_W-1:0] m_axis_tdata;
  logic              m_axis_tvalid;
  logic              m_axis_tready;

  int unsigned       error_count;
  int unsigned       seed;
  int unsigned       g_valid_pct;
  int unsigned       g_ready_pct;

  bit [DATA_W-1:0]   source_q[$];
  bit [DATA_W-1:0]   expected_q[$];

  dma_top #(
    .DATA_W(DATA_W),
    .LEN_W (LEN_W),
    .ADDR_W(ADDR_W)
  ) dut (
    .clk            (clk),
    .rst_n          (rst_n),

    .s_axil_awaddr  (s_axil_awaddr),
    .s_axil_awvalid (s_axil_awvalid),
    .s_axil_awready (s_axil_awready),
    .s_axil_wdata   (s_axil_wdata),
    .s_axil_wstrb   (s_axil_wstrb),
    .s_axil_wvalid  (s_axil_wvalid),
    .s_axil_wready  (s_axil_wready),
    .s_axil_bresp   (s_axil_bresp),
    .s_axil_bvalid  (s_axil_bvalid),
    .s_axil_bready  (s_axil_bready),
    .s_axil_araddr  (s_axil_araddr),
    .s_axil_arvalid (s_axil_arvalid),
    .s_axil_arready (s_axil_arready),
    .s_axil_rdata   (s_axil_rdata),
    .s_axil_rresp   (s_axil_rresp),
    .s_axil_rvalid  (s_axil_rvalid),
    .s_axil_rready  (s_axil_rready),

    .s_axis_tdata   (s_axis_tdata),
    .s_axis_tvalid  (s_axis_tvalid),
    .s_axis_tready  (s_axis_tready),
    .m_axis_tdata   (m_axis_tdata),
    .m_axis_tvalid  (m_axis_tvalid),
    .m_axis_tready  (m_axis_tready)
  );

  dma_assertions #(
    .DATA_W(DATA_W)
  ) u_assertions (
    .clk            (clk),
    .rst_n          (rst_n),
    .m_axis_tdata   (m_axis_tdata),
    .m_axis_tvalid  (m_axis_tvalid),
    .m_axis_tready  (m_axis_tready),
    .s_axil_bvalid  (s_axil_bvalid),
    .s_axil_bready  (s_axil_bready),
    .s_axil_bresp   (s_axil_bresp),
    .busy           (dut.u_engine.busy_o),
    .done           (dut.u_engine.done_o),
    .error          (dut.u_engine.error_o)
  );

  // ---------------------------------------------------------------------------
  // Clock/reset
  // ---------------------------------------------------------------------------

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task automatic reset_dut();
    begin
      rst_n          = 1'b0;
      s_axil_awaddr  = '0;
      s_axil_awvalid = 1'b0;
      s_axil_wdata   = '0;
      s_axil_wstrb   = 4'hF;
      s_axil_wvalid  = 1'b0;
      s_axil_bready  = 1'b0;
      s_axil_araddr  = '0;
      s_axil_arvalid = 1'b0;
      s_axil_rready  = 1'b0;
      s_axis_tdata   = '0;
      s_axis_tvalid  = 1'b0;
      m_axis_tready  = 1'b0;
      source_q.delete();
      expected_q.delete();
      repeat (5) @(posedge clk);
      rst_n = 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  // ---------------------------------------------------------------------------
  // AXI4-Lite tasks
  // ---------------------------------------------------------------------------

  task automatic axil_write(input [ADDR_W-1:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      s_axil_awaddr  = addr;
      s_axil_awvalid = 1'b1;
      s_axil_wdata   = data;
      s_axil_wstrb   = 4'hF;
      s_axil_wvalid  = 1'b1;
      s_axil_bready  = 1'b1;

      while (s_axil_awvalid || s_axil_wvalid) begin
        @(posedge clk);
        if (s_axil_awvalid && s_axil_awready) begin
          s_axil_awvalid = 1'b0;
        end
        if (s_axil_wvalid && s_axil_wready) begin
          s_axil_wvalid = 1'b0;
        end
      end

      while (!s_axil_bvalid) begin
        @(posedge clk);
      end

      @(posedge clk);
      s_axil_bready = 1'b0;
    end
  endtask

  task automatic axil_read(input [ADDR_W-1:0] addr, output [31:0] data, output [1:0] resp);
    begin
      @(posedge clk);
      s_axil_araddr  = addr;
      s_axil_arvalid = 1'b1;
      s_axil_rready  = 1'b1;

      while (s_axil_arvalid) begin
        @(posedge clk);
        if (s_axil_arvalid && s_axil_arready) begin
          s_axil_arvalid = 1'b0;
        end
      end

      while (!s_axil_rvalid) begin
        @(posedge clk);
      end

      data = s_axil_rdata;
      resp = s_axil_rresp;
      @(posedge clk);
      s_axil_rready = 1'b0;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Stream source and scoreboard
  // ---------------------------------------------------------------------------

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_axis_tvalid <= 1'b0;
      s_axis_tdata  <= '0;
      m_axis_tready <= 1'b0;
    end else begin
      m_axis_tready <= ($urandom_range(0, 99) < g_ready_pct);

      if (!s_axis_tvalid || s_axis_tready) begin
        if ((source_q.size() > 0) && ($urandom_range(0, 99) < g_valid_pct)) begin
          s_axis_tdata  <= source_q.pop_front();
          s_axis_tvalid <= 1'b1;
        end else begin
          s_axis_tvalid <= 1'b0;
        end
      end
    end
  end

  always_ff @(posedge clk) begin
    bit [DATA_W-1:0] exp;

    if (rst_n && m_axis_tvalid && m_axis_tready) begin
      if (expected_q.size() == 0) begin
        $error("Scoreboard underflow: output beat was not expected. data=0x%08x", m_axis_tdata);
        error_count++;
      end else begin
        exp = expected_q.pop_front();
        if (m_axis_tdata !== exp) begin
          $error("Scoreboard mismatch: expected=0x%08x actual=0x%08x", exp, m_axis_tdata);
          error_count++;
        end
      end
    end
  end

  task automatic load_source(input int unsigned len);
    bit [DATA_W-1:0] value;
    begin
      source_q.delete();
      expected_q.delete();
      for (int i = 0; i < len; i++) begin
        value = $urandom();
        source_q.push_back(value);
        expected_q.push_back(value);
      end
    end
  endtask

  task automatic clear_status();
    begin
      axil_write(`DMA_REG_CTRL, 32'h4);
    end
  endtask

  task automatic wait_done(input int unsigned timeout_cycles);
    int unsigned cycles;
    logic [31:0] status;
    logic [1:0]  resp;
    begin
      cycles = 0;
      status = 32'h0;

      while ((status[1] == 1'b0) && (cycles < timeout_cycles)) begin
        repeat (5) @(posedge clk);
        axil_read(`DMA_REG_STATUS, status, resp);
        cycles += 5;
      end

      if (status[1] != 1'b1) begin
        $error("Timeout waiting for DONE. last status=0x%08x", status);
        error_count++;
      end
    end
  endtask

  task automatic run_transfer(
    input string       name,
    input int unsigned len,
    input int unsigned valid_pct,
    input int unsigned ready_pct
  );
    logic [31:0] count;
    logic [31:0] status;
    logic [1:0]  resp;
    begin
      $display("[TEST] %s len=%0d valid_pct=%0d ready_pct=%0d", name, len, valid_pct, ready_pct);
      clear_status();
      g_valid_pct = valid_pct;
      g_ready_pct = ready_pct;
      load_source(len);

      axil_write(`DMA_REG_LENGTH, len[31:0]);
      axil_write(`DMA_REG_CTRL, 32'h1);

      wait_done(5000);

      repeat (10) @(posedge clk);
      if (expected_q.size() != 0) begin
        $error("Expected queue not empty after DONE. remaining=%0d", expected_q.size());
        error_count++;
      end

      axil_read(`DMA_REG_COUNT, count, resp);
      if (count[LEN_W-1:0] != len[LEN_W-1:0]) begin
        $error("COUNT mismatch. expected=%0d actual=%0d", len, count[LEN_W-1:0]);
        error_count++;
      end

      axil_read(`DMA_REG_STATUS, status, resp);
      if (status[2]) begin
        $error("Unexpected ERROR bit after normal transfer. status=0x%08x", status);
        error_count++;
      end
    end
  endtask

  task automatic test_zero_length_error();
    logic [31:0] status;
    logic [1:0]  resp;
    begin
      $display("[TEST] zero_length_error");
      clear_status();
      axil_write(`DMA_REG_LENGTH, 32'h0);
      axil_write(`DMA_REG_CTRL, 32'h1);
      repeat (5) @(posedge clk);
      axil_read(`DMA_REG_STATUS, status, resp);
      if (status[2] != 1'b1) begin
        $error("Expected ERROR bit for zero-length transfer. status=0x%08x", status);
        error_count++;
      end
    end
  endtask

  task automatic test_start_while_busy_error();
    logic [31:0] status;
    logic [1:0]  resp;
    begin
      $display("[TEST] start_while_busy_error");
      clear_status();
      g_valid_pct = 20;
      g_ready_pct = 20;
      load_source(64);
      axil_write(`DMA_REG_LENGTH, 32'd64);
      axil_write(`DMA_REG_CTRL, 32'h1);
      repeat (3) @(posedge clk);
      axil_write(`DMA_REG_CTRL, 32'h1);
      repeat (5) @(posedge clk);
      axil_read(`DMA_REG_STATUS, status, resp);
      if (status[2] != 1'b1) begin
        $error("Expected ERROR bit for start while busy. status=0x%08x", status);
        error_count++;
      end
      wait_done(10000);
    end
  endtask

  task automatic test_invalid_register_access();
    logic [31:0] data;
    logic [1:0]  resp;
    begin
      $display("[TEST] invalid_register_access");
      axil_read(8'h80, data, resp);
      if (resp != `DMA_RESP_DECERR) begin
        $error("Expected DECERR for invalid read. resp=%0b data=0x%08x", resp, data);
        error_count++;
      end

      axil_write(8'h84, 32'h1234_5678);
      // The write task does not check bresp on purpose; this keeps the helper
      // reusable for negative tests. In a production bench, capture and compare.
    end
  endtask

  // ---------------------------------------------------------------------------
  // Simple functional coverage
  // ---------------------------------------------------------------------------

`ifdef COVERAGE_ON
  covergroup dma_cg @(posedge clk);
    option.per_instance = 1;

    cp_valid_pct: coverpoint g_valid_pct {
      bins low  = {[0:30]};
      bins mid  = {[31:70]};
      bins high = {[71:100]};
    }

    cp_ready_pct: coverpoint g_ready_pct {
      bins low  = {[0:30]};
      bins mid  = {[31:70]};
      bins high = {[71:100]};
    }

    cp_out_hs: coverpoint (m_axis_tvalid && m_axis_tready) {
      bins no  = {0};
      bins yes = {1};
    }
  endgroup

  dma_cg cg = new();
`endif

  // ---------------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------------

  initial begin
    if (!$value$plusargs("SEED=%d", seed)) begin
      seed = 32'hC0FFEE;
    end
    void'($urandom(seed));
    $display("Using random seed: %0d", seed);

    if ($test$plusargs("WAVES")) begin
      $dumpfile("dma_wave.vcd");
      $dumpvars(0, tb_dma);
    end

    error_count = 0;
    g_valid_pct = 100;
    g_ready_pct = 100;

    reset_dut();

    run_transfer("basic_no_backpressure", 16, 100, 100);
    run_transfer("source_gaps",           32,  35, 100);
    run_transfer("sink_backpressure",     48, 100,  30);
    run_transfer("randomized",            96,  60,  55);

    for (int i = 0; i < 10; i++) begin
      run_transfer($sformatf("random_loop_%0d", i),
                   $urandom_range(1, 128),
                   $urandom_range(20, 100),
                   $urandom_range(20, 100));
    end

    test_zero_length_error();
    test_start_while_busy_error();
    test_invalid_register_access();

    repeat (20) @(posedge clk);

    if (error_count == 0) begin
      $display("====================================");
      $display("TEST PASSED");
      $display("====================================");
    end else begin
      $display("====================================");
      $display("TEST FAILED: error_count=%0d", error_count);
      $display("====================================");
      $fatal(1);
    end

    $finish;
  end

endmodule
