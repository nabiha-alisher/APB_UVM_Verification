//=========================================================================
//                    APB SEQUENCES
//=========================================================================
//
// APB Specification:
//   Memory       : 64 KB
//   Data width   : 64-bit
//   Address      : 32-bit byte address
//   Alignment    : 8-byte aligned
//   PSTRB        : 8-bit byte enable
//   Endianness   : Little endian
//   Valid range  : BASE_ADDR -> BASE_ADDR + 64KB - 1
//
// Sequences:
//   1.  apb_sequence
//   2.  write_sequence
//   3.  read_sequence
//   4.  random_write_sequence
//   5.  random_read_sequence
//   6.  write_read_sequence
//   7.  random_write_read_sequence
//   8.  memory_init_sequence
//   9.  full_strobe_sequence
//   10. byte_strobe_sequence
//   11. boundary_sequence
//   12. invalid_address_sequence
//   13. misaligned_sequence
//   14. protocol_sequence
//
//=========================================================================


//=========================================================================
// Configuration
//=========================================================================

`ifndef APB_BASE_ADDR
  `define APB_BASE_ADDR 32'h0000_0000
`endif


//=========================================================================
// 1. APB RANDOM SEQUENCE
//=========================================================================

class apb_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(apb_sequence)

  function new(string name = "apb_sequence");
    super.new(name);
  endfunction

  `uvm_declare_p_sequencer(apb_sequencer)

  virtual task body();

    repeat (10) begin

      req = apb_seq_item::type_id::create("req");

      start_item(req);

      if (!req.randomize()) begin
        `uvm_error("SEQ",
                   "APB transaction randomization failed")
      end

      finish_item(req);

    end

  endtask

endclass


//=========================================================================
// 2. DIRECTED WRITE SEQUENCE
//=========================================================================

class write_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(write_sequence)

  function new(string name = "write_sequence");
    super.new(name);
  endfunction

  virtual task body();

    req = apb_seq_item::type_id::create("req");

    start_item(req);

    if (!req.randomize() with {
      PADDR  == 32'h0000_0010;
      PWRITE == 1'b1;
      PSTRB  == 8'hFF;
    }) begin
      `uvm_error("WRITE_SEQ",
                 "Write transaction randomization failed")
    end

    req.PWDATA = 64'd45;

    finish_item(req);

  endtask

endclass


//=========================================================================
// 3. DIRECTED READ SEQUENCE
//=========================================================================

class read_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(read_sequence)

  function new(string name = "read_sequence");
    super.new(name);
  endfunction

  virtual task body();

    req = apb_seq_item::type_id::create("req");

    start_item(req);

    if (!req.randomize() with {
      PADDR  == 32'h0000_0010;
      PWRITE == 1'b0;
    }) begin
      `uvm_error("READ_SEQ",
                 "Read transaction randomization failed")
    end

    finish_item(req);

  endtask

endclass


//=========================================================================
// 4. RANDOM WRITE SEQUENCE
//=========================================================================

class random_write_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(random_write_sequence)

  function new(string name = "random_write_sequence");
    super.new(name);
  endfunction

  virtual task body();

    repeat (20) begin

      req = apb_seq_item::type_id::create("req");

      start_item(req);

      if (!req.randomize() with {
        PWRITE == 1'b1;
      }) begin
        `uvm_error("RAND_WRITE",
                   "Random write randomization failed")
      end

      finish_item(req);

    end

  endtask

endclass


//=========================================================================
// 5. RANDOM READ SEQUENCE
//=========================================================================

class random_read_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(random_read_sequence)

  function new(string name = "random_read_sequence");
    super.new(name);
  endfunction

  virtual task body();

    repeat (20) begin

      req = apb_seq_item::type_id::create("req");

      start_item(req);

      if (!req.randomize() with {
        PWRITE == 1'b0;
      }) begin
        `uvm_error("RAND_READ",
                   "Random read randomization failed")
      end

      finish_item(req);

    end

  endtask

endclass


//=========================================================================
// 6. WRITE FOLLOWED BY READ
//=========================================================================

class write_read_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(write_read_sequence)

  function new(string name = "write_read_sequence");
    super.new(name);
  endfunction

  virtual task body();

    logic [31:0] addr;
    logic [63:0] data;

    //========================================================
    // WRITE
    //========================================================

    req = apb_seq_item::type_id::create("write_req");

    start_item(req);

    if (!req.randomize() with {
      PWRITE == 1'b1;
      PSTRB  == 8'hFF;
    }) begin
      `uvm_error("WR_RD",
                 "Write randomization failed")
    end

    addr = req.PADDR;
    data = req.PWDATA;

    finish_item(req);


    //========================================================
    // READ SAME ADDRESS
    //========================================================

    req = apb_seq_item::type_id::create("read_req");

    start_item(req);

    if (!req.randomize() with {
      PWRITE == 1'b0;
      PADDR  == addr;
    }) begin
      `uvm_error("WR_RD",
                 "Read randomization failed")
    end

    finish_item(req);

  endtask

endclass


//=========================================================================
// 7. RANDOM WRITE FOLLOWED BY RANDOM READ
//=========================================================================

class random_write_read_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(random_write_read_sequence)

  function new(string name = "random_write_read_sequence");
    super.new(name);
  endfunction

  virtual task body();

    logic [31:0] addr;

    repeat (20) begin

      //======================================================
      // RANDOM WRITE
      //======================================================

      req = apb_seq_item::type_id::create("write_req");

      start_item(req);

      if (!req.randomize() with {
        PWRITE == 1'b1;
      }) begin
        `uvm_error("RAND_WR_RD",
                   "Write randomization failed")
      end

      addr = req.PADDR;

      finish_item(req);


      //======================================================
      // READ SAME RANDOM ADDRESS
      //======================================================

      req = apb_seq_item::type_id::create("read_req");

      start_item(req);

      if (!req.randomize() with {
        PWRITE == 1'b0;
        PADDR  == addr;
      }) begin
        `uvm_error("RAND_WR_RD",
                   "Read randomization failed")
      end

      finish_item(req);

    end

  endtask

endclass


//=========================================================================
// 8. MEMORY INITIALIZATION SEQUENCE
//=========================================================================
//
// 64 KB memory
// 64-bit data = 8 bytes
//
// Number of 64-bit locations:
//
//       65536 / 8 = 8192
//
// All locations are written with zero.
//
//=========================================================================

class memory_init_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(memory_init_sequence)

  function new(string name = "memory_init_sequence");
    super.new(name);
  endfunction

  virtual task body();

    for (int i = 0; i < 8192; i++) begin

      req = apb_seq_item::type_id::create("req");

      start_item(req);

      req.PADDR  = `APB_BASE_ADDR + (i * 8);
      req.PWRITE = 1'b1;
      req.PWDATA = 64'h0000_0000_0000_0000;
      req.PSTRB  = 8'hFF;

      finish_item(req);

    end

    `uvm_info("MEM_INIT",
              "64 KB memory initialization completed",
              UVM_LOW)

  endtask

endclass


//=========================================================================
// 9. FULL STROBE WRITE SEQUENCE
//=========================================================================
//
// PSTRB = 11111111
//
// All 8 bytes are written.
//
//=========================================================================

class full_strobe_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(full_strobe_sequence)

  function new(string name = "full_strobe_sequence");
    super.new(name);
  endfunction

  virtual task body();

    repeat (10) begin

      req = apb_seq_item::type_id::create("req");

      start_item(req);

      if (!req.randomize() with {
        PWRITE == 1'b1;
        PSTRB  == 8'hFF;
      }) begin
        `uvm_error("FULL_STROBE",
                   "Full strobe randomization failed")
      end

      finish_item(req);

    end

  endtask

endclass


//=========================================================================
// 10. BYTE STROBE SEQUENCE
//=========================================================================
//
// Tests each individual byte enable.
//
// 0000_0001
// 0000_0010
// 0000_0100
// 0000_1000
// 0001_0000
// 0010_0000
// 0100_0000
// 1000_0000
//
//=========================================================================

class byte_strobe_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(byte_strobe_sequence)

  function new(string name = "byte_strobe_sequence");
    super.new(name);
  endfunction

  virtual task body();

    for (int i = 0; i < 8; i++) begin

      req = apb_seq_item::type_id::create("req");

      start_item(req);

      if (!req.randomize() with {
        PWRITE == 1'b1;
        PSTRB  == (8'b0000_0001 << i);
      }) begin
        `uvm_error("BYTE_STROBE",
                   "Byte strobe randomization failed")
      end

      finish_item(req);

    end

  endtask

endclass


//=========================================================================
// 11. BOUNDARY ADDRESS SEQUENCE
//=========================================================================
//
// First valid aligned address:
//     0x0000_0000
//
// Last valid aligned 64-bit address:
//     0x0000_FFF8
//
//=========================================================================

class boundary_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(boundary_sequence)

  function new(string name = "boundary_sequence");
    super.new(name);
  endfunction

  virtual task body();

    //========================================================
    // FIRST VALID ADDRESS
    //========================================================

    req = apb_seq_item::type_id::create("first_addr");

    start_item(req);

    req.PADDR  = `APB_BASE_ADDR;
    req.PWRITE = 1'b1;
    req.PWDATA = 64'h1111_1111_1111_1111;
    req.PSTRB  = 8'hFF;

    finish_item(req);


    //========================================================
    // LAST VALID ALIGNED ADDRESS
    //========================================================

    req = apb_seq_item::type_id::create("last_addr");

    start_item(req);

    req.PADDR  = `APB_BASE_ADDR + 32'h0000_FFF8;
    req.PWRITE = 1'b1;
    req.PWDATA = 64'hAAAA_BBBB_CCCC_DDDD;
    req.PSTRB  = 8'hFF;

    finish_item(req);

  endtask

endclass


//=========================================================================
// 12. INVALID ADDRESS SEQUENCE
//=========================================================================
//
// 64 KB range:
//
//     0x0000_0000 -> 0x0000_FFFF
//
// First address outside memory:
//
//     0x0001_0000
//
// Expected:
//
//     PSLVERR = 1
//
//=========================================================================

class invalid_address_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(invalid_address_sequence)

  function new(string name = "invalid_address_sequence");
    super.new(name);
  endfunction

  virtual task body();

    req = apb_seq_item::type_id::create("req");

    start_item(req);

    if (!req.randomize() with {
      PWRITE == 1'b1;
      PADDR  == (`APB_BASE_ADDR + 32'h0001_0000);
    }) begin
      `uvm_error("INVALID_ADDR",
                 "Invalid address randomization failed")
    end

    req.PWDATA = 64'hDEAD_BEEF_DEAD_BEEF;
    req.PSTRB  = 8'hFF;

    finish_item(req);

    `uvm_info("INVALID_ADDR",
              "Invalid address transaction sent. PSLVERR expected.",
              UVM_LOW)

  endtask

endclass


//=========================================================================
// 13. MISALIGNED ADDRESS SEQUENCE
//=========================================================================
//
// APB specification:
//
// Access must be 8-byte aligned.
//
// Invalid examples:
//
//     0x01
//     0x02
//     0x03
//     ...
//     0x07
//
// Expected:
//
//     PSLVERR = 1
//
//=========================================================================

class misaligned_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(misaligned_sequence)

  function new(string name = "misaligned_sequence");
    super.new(name);
  endfunction

  virtual task body();

    for (int i = 1; i <= 7; i++) begin

      req = apb_seq_item::type_id::create("req");

      start_item(req);

      // Deliberately generate an unaligned address.
      // This sequence is intended to violate the normal
      // 8-byte alignment requirement.

      req.PADDR  = `APB_BASE_ADDR + i;
      req.PWRITE = 1'b1;
      req.PWDATA = 64'h1234_5678_9ABC_DEF0;
      req.PSTRB  = 8'hFF;

      finish_item(req);

    end

    `uvm_info("MISALIGNED",
              "Misaligned address transactions completed. PSLVERR expected.",
              UVM_LOW)

  endtask

endclass


//=========================================================================
// 14. APB PROTOCOL / BACK-TO-BACK SEQUENCE
//=========================================================================
//
// Generates consecutive APB transactions.
//
// Driver should convert each transaction into:
//
//       IDLE
//         |
//       SETUP
//         |
//       ACCESS
//         |
//       IDLE
//         |
//       SETUP
//         |
//       ACCESS
//
//=========================================================================

class protocol_sequence extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(protocol_sequence)

  function new(string name = "protocol_sequence");
    super.new(name);
  endfunction

  virtual task body();

    repeat (10) begin

      req = apb_seq_item::type_id::create("req");

      start_item(req);

      if (!req.randomize()) begin
        `uvm_error("PROTOCOL",
                   "Protocol transaction randomization failed")
      end

      finish_item(req);

    end

    `uvm_info("PROTOCOL",
              "Back-to-back APB transactions completed",
              UVM_LOW)

  endtask

endclass