// ============================================================================
// Module: generic_mem
// Description: 
//   Parameterized generic memory wrapper using multiple instances of 
//   1024x32 memory blocks. 
//
// Features:
//   - Supports configurable address and data widths.
//   - Write strobe granularity (byte enable).
//   - Read data registered with valid signal.
//   - Internally arranges memory in rows (NUM_ROW) and columns (NUM_COL).
//
// Parameters:
//   AW : Address width in bits
//   DW : Data width in bits (must be multiple of 32)
//
// Dependencies:
//   - Requires a submodule `mem_1024x32` with ports:
//       .clk, .addr, .we, .wdata, .rdata
// ============================================================================
`include "mem_1024x32.sv"
module generic_mem #(
    parameter int AW = 32,   // Address width
    parameter int DW = 64    // Data width (must be multiple of 32)
) (
    input  logic            clk,        // Clock
    input  logic            rst_n,     // Active-low async reset
    input  logic            req,        // Request signal (read/write valid)

    input  logic [  AW-1:0] addr,       // Address input
    input  logic            we,         // Write enable
    input  logic [  DW-1:0] wdata,      // Write data
    input  logic [DW/8-1:0] wstrb,      // Write strobe (byte enables)

    output logic [  DW-1:0] rdata,      // Read data output
    output logic            rdata_valid // Read data valid
);

  // ==========================================================================
  // Local parameters: memory organization
  // ==========================================================================
  localparam MEM_CELL_ADDR_W = 10;

  localparam int NUM_COL = DW / 32;   // Number of 32-bit columns per word
  localparam longint unsigned NUM_ROW = (2 ** AW) / (1024 * 32 * NUM_COL / 8);
  // NUM_ROW = Total rows of memory after factoring columns and word size

  localparam int COL_IDX_START = $clog2(32 / 8);     // Column index LSB
  localparam int ROW_IDX_START = COL_IDX_START + $clog2(NUM_COL); // Row index start

  // ==========================================================================
  // Internal signals
  // ==========================================================================
  logic [DW-1:0] rdata_mux_d [NUM_ROW];  // Raw read data from memory array
  logic [DW-1:0] rdata_mux_q [NUM_ROW];  // Registered read data

  logic          we_demux    [NUM_ROW];  // Write enable demux per row

  logic [DW-1:0] rdata_intr;             // Selected row read data
  logic          rdata_valid_intr;       // Registered valid signal

  // ==========================================================================
  // Write enable logic
  // ==========================================================================
  logic          write_enable;
  assign write_enable = (we & req & rst_n); // Valid write only when request is active

  // Select which row’s read data to use based on address
  assign rdata_intr = rdata_mux_q[addr[AW-1-MEM_CELL_ADDR_W:ROW_IDX_START]];

  // Decode write enable per row
  always_comb begin
    foreach (we_demux[i]) we_demux[i] = '0;              // Default off
    we_demux[addr[AW-1-MEM_CELL_ADDR_W:ROW_IDX_START]] = write_enable;   // Enable target row
  end

  // ==========================================================================
  // Memory instantiation
  // Each row has NUM_COL x 32-bit memories
  // ==========================================================================
  for (genvar row = 0; row < NUM_ROW; row++) begin

    // Construct write data with byte enables applied
    logic [DW-1:0] write_data;
    for (genvar lane = 0; lane < (DW / 8); lane++) begin
      assign write_data[8*lane+7:8*lane] = wstrb[lane] ?
        wdata[8*lane+7:8*lane] : rdata_mux_d[row][8*lane+7:8*lane];
    end

    // Instantiate memories for each 32-bit column
    for (genvar col = 0; col < NUM_COL; col++) begin
      mem_1024x32 u_mem (
        .clk   (clk),
        .addr  (addr[AW-1:ROW_IDX_START + $clog2(NUM_ROW)]),  // Row address
        .we    (we_demux[row]), // Write enable per row
        .wdata (write_data[32*col+31:32*col]), // Write data for this column
        .rdata (rdata_mux_d[row][32*col+31:32*col]) // Read data for this column
      );
    end
  end

  // ==========================================================================
  // Pipeline registers
  // ==========================================================================
  // Register read data and valid flag
  always_ff @(posedge clk) begin
    if (~rst_n) begin
      foreach (rdata_mux_q[i]) rdata_mux_q[i] <= '0;
      rdata_valid_intr <= '0;
    end else begin
      rdata_mux_q      <= rdata_mux_d;
      rdata_valid_intr <= req;
    end
  end

  // Output registers
  always_ff @(posedge clk) begin
    if (~rst_n) begin
      rdata       <= '0;
      rdata_valid <= '0;
    end else begin
      rdata       <= rdata_intr;
      rdata_valid <= rdata_valid_intr;
    end
  end

endmodule