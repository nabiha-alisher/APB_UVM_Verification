// This module generates slave error signals based on the incoming APB address.
// It checks for two primary types of errors:
// 1. Out-of-bounds access: The address is outside the memory's defined range.
// 2. Misaligned access: The address is not aligned to the data bus width.
module err_gen #(
    parameter int              ADDR_W = 32,
    parameter int              DATA_W = 64,
    parameter int              MEM_SIZE_K = 64,
    parameter int unsigned     BASE_ADDR = 0
)(
    input  logic [ADDR_W-1:0]  addr,   // Input: APB address from the master
    output logic [2:0]         error   // Output: Vector of error flags
);

    // --- Local Parameters ---
    // MEM_SIZE_B: Total memory size in bytes.
    localparam int MEM_SIZE_B = MEM_SIZE_K * 1024; // e.g., 64 * 1024 = 65536 bytes for 64KB

    // ADDR_ALIGN: Required address alignment in bytes, based on the data bus width.
    // For a 64-bit data bus, accesses must be 8-byte aligned.
    localparam int ADDR_ALIGN = DATA_W / 8;

    // --- Error Generation Logic ---
    // error[0]: Out-of-bounds error. Set if the address is outside the valid memory range.
    assign error[0] = (addr < BASE_ADDR) || (addr >= (BASE_ADDR + MEM_SIZE_B));
    // error[1]: Misaligned address error. Set if the address is not aligned to the data bus width.
    assign error[1] = (addr % ADDR_ALIGN) != 0;
    // error[2]: Reserved for future use.
    assign error[2] = 1'b0; // Currently unused

endmodule