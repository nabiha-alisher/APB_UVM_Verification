
// This module acts as a wrapper, connecting the APB bus interface to an internal
// memory. It integrates an APB state machine (`apb_fsm`), a generic memory block
// (`generic_mem`), and error generation logic (`err_gen`).
`include "apb_fsm.sv"
`include "generic_mem.sv"
`include "err_gen.sv"
module apb_wrapper #(
    parameter int                  ADDR_W = 32,
    parameter int                  DATA_W = 64,
    parameter int                  MEM_SIZE_K = 64,
    parameter int unsigned         BASE_ADDR = 0
)(
    input   logic                  PCLK,
    input   logic                  PRESETn,
    input   logic                  PSELx,
    input   logic                  PENABLE,
    input   logic                  PWRITE,
    input   logic [DATA_W-1:0]     PWDATA,
    input   logic [DATA_W/8-1:0]   PSTRB,
    input   logic [ADDR_W-1:0]     PADDR,
    output  logic [DATA_W-1:0]     PRDATA, 
    output  logic                  PREADY,
    output  logic                  PSLVERR
);

    // --- Address Translation ---
    // This section translates the system-level APB address (PADDR) to the local address
    // space of the internal memory (`generic_mem`). It calculates the required internal
    // address width and subtracts the base address to get the local address.
    localparam ADDR_W_T = $clog2(MEM_SIZE_K) + 10;
    wire [ADDR_W-1:0] PADDR_T = PADDR - BASE_ADDR;
    
    // --- Internal Signals ---
    logic [2:0]        slv_err;        // Slave error flags from the error generator
    logic              rdata_valid;    // Indicates that read data from memory is valid
    logic              req_fsm_to_mem; // Request signal from FSM to the memory
    logic              we_fsm_to_mem;  // Write enable signal from FSM to the memory
    logic [DATA_W-1:0] prdata_intr;    // Internal read data bus from memory to the FSM


    // --- APB State Machine Instance ---
    // This FSM implements the APB slave protocol logic.
    apb_fsm #(.DATA_W(DATA_W)) fsm(
        .PCLK   (PCLK),
        .PRESETn(PRESETn),
        .PSELx(PSELx),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .error(slv_err[0] | slv_err[1]),
        .rdata_valid(rdata_valid),
        .prdata_intr(prdata_intr),
        .req(req_fsm_to_mem),
        .we(we_fsm_to_mem),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR),
        .PRDATA(PRDATA)
    );


    // --- Generic Memory Instance ---
    // This is the synthesizable memory block that stores the data.
    generic_mem #(.AW(ADDR_W_T),.DW(DATA_W)) memory(
        .clk  (PCLK),
        .rst_n(PRESETn),
        .req(req_fsm_to_mem),
        .addr(PADDR_T[ADDR_W_T-1:0]),
        .we(we_fsm_to_mem),
        .wdata(PWDATA),
        .wstrb(PSTRB),
        .rdata(prdata_intr),
        .rdata_valid(rdata_valid)
    );


    // --- Error Generator Instance ---
    // This module checks for address-related errors, such as out-of-bounds access.
    err_gen #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .MEM_SIZE_K(MEM_SIZE_K),
        .BASE_ADDR(BASE_ADDR)
    ) e_gen(
        .addr(PADDR),
        .error(slv_err)
    );

endmodule