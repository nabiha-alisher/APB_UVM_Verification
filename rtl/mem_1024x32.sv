//------------------------------------------------------------------------------
// Module: mem_1024x32
//
// Description:
//   A simple synchronous-write, asynchronous-read single-port RAM.
//   It models a memory with 1024 entries, each 32 bits wide.
//
//   - Write operations are synchronous to the positive edge of 'clk'.
//   - Read operations are asynchronous; 'rdata' reflects the content of
//     'mem[addr]' combinationally.
//------------------------------------------------------------------------------

module mem_1024x32 (
    //- Inputs
    input  logic        clk,    // Clock
    input  logic [ 9:0] addr,   // 10-bit address for 1024 locations
    input  logic        we,     // Write enable, active high
    input  logic [31:0] wdata,  // 32-bit data to write
    //- Outputs
    output logic [31:0] rdata   // 32-bit data to read
);

  // Memory array: 1024 locations, each 32 bits wide.
  logic [31:0] mem[1024];

  // Synchronous write logic.
  // On the positive edge of the clock, if write enable is asserted,
  // the input data is written to the specified address.
  always_ff @(posedge clk) begin
    if (we) begin
      mem[addr] <= wdata;
    end
  end

  // Asynchronous read logic.
  // The read data output is combinationally driven by the memory content
  // at the current address. This means a change in 'addr' will immediately
  // reflect on 'rdata'.
  assign rdata = mem[addr];

endmodule