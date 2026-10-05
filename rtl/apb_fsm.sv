// APB slave state machine states
typedef enum logic [1:0] {
    IDLE   = 2'b00, // Default state, waiting for a transfer
    SETUP  = 2'b01, // PSELx is high, transfer is initiated
    ACCESS = 2'b10  // PENABLE is high, address and data are valid
} state_e;

// This module implements the state machine for an APB slave.
// It controls the APB protocol signals (PREADY, PSLVERR) and generates internal
// requests to the memory based on the APB master's signals.
module apb_fsm #(
    parameter int DATA_W = 64
) (
    input PCLK, PRESETn, PSELx, PENABLE, PWRITE, error, rdata_valid,
    input logic [DATA_W-1:0] prdata_intr,
    output reg req, we, 
    output reg PREADY,
    output reg PSLVERR,
    output reg [DATA_W-1 : 0] PRDATA
);

    state_e state, next_state;
    
    // State register: Sequential logic to update the current state on every
    // positive clock edge, with an asynchronous active-low reset.
    always @(posedge PCLK) begin
        if(~PRESETn) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    // Next state logic: Combinational logic to determine the next state based on the current state and inputs.
    always_comb begin
        case (state)
            IDLE:   next_state  = (PSELx & ~PENABLE) ? SETUP : IDLE;
            SETUP:  next_state  = PSELx & PENABLE ? ACCESS : SETUP;
            ACCESS: next_state  = rdata_valid ? (PSELx ? SETUP : IDLE) : ACCESS;
            default: next_state = IDLE;
        endcase
    end

    // Output logic: Combinational logic to drive the module outputs based on the current state.
    always_comb begin
        case (state)
            IDLE: begin
                req     = '0;
                we      = '0;
                PREADY  = '0;
                PSLVERR = '0;
                PRDATA  = 'z;
            end
            SETUP: begin
                req     = '0;
                we      = '0;
                PREADY  = '0;
                PSLVERR = '0;
                PRDATA  = 'z;
            end
            ACCESS: begin
                // Signal a request to the internal memory/logic
                req     = '1;
                // Drive write enable, but not if there's an error
                we      = error ? 0 : PWRITE;
                // PREADY is asserted when data is ready (for reads) or write is complete
                PREADY  = rdata_valid;
                // PSLVERR is asserted in the same cycle as PREADY if an error occurred
                PSLVERR = rdata_valid & error;
                // Drive read data only on the last cycle of a read transfer
                PRDATA  = rdata_valid & ~PWRITE ? prdata_intr : 'z;
            end
            default: begin
                req     = '0;
                we      = '0;
                PREADY  = 'z;
                PSLVERR = 'z;
                PRDATA  = 'z;
            end
        endcase
    end


endmodule