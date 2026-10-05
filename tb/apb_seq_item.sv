//-------------------------------------------------------------------------
//						mem_seq_item - www.verificationguide.com 
//-------------------------------------------------------------------------

class apb_seq_item extends uvm_sequence_item;
  //---------------------------------------
  //data and control fields
  //---------------------------------------
  //  rand logic                  PCLK;
  //   rand logic                  PRESETn;
    logic                         PSELx;
    logic                         PENABLE;
    rand logic                  PWRITE;
    rand logic [64-1:0]         PWDATA;
    rand logic [64/8-1:0]       PSTRB;
    rand logic [32-1:0]           PADDR;
    logic [64-1:0]                PRDATA; 
    logic                         PREADY;
    logic                         PSLVERR;
function new(string path="transaction");
super.new(path);
 `uvm_info("Seq_item","Enter", UVM_LOW);
endfunction

`uvm_object_utils_begin(apb_seq_item)
// `uvm_field_int(PCLK,UVM_DEFAULT);
// `uvm_field_int(PRESETn,UVM_DEFAULT);
`uvm_field_int(PSELx,UVM_DEFAULT);
`uvm_field_int(PENABLE,UVM_DEFAULT);
`uvm_field_int(PWRITE,UVM_DEFAULT);
`uvm_field_int(PWDATA,UVM_DEFAULT);
`uvm_field_int(PSTRB,UVM_DEFAULT);
`uvm_field_int(PADDR,UVM_DEFAULT);
`uvm_field_int(PRDATA,UVM_DEFAULT);
`uvm_field_int(PREADY,UVM_DEFAULT);
`uvm_field_int(PSLVERR,UVM_DEFAULT);
`uvm_object_utils_end
  

  //============================================================
  // Parameterizable Memory Configuration
  //============================================================

  parameter logic [31:0] BASE_ADDR = 32'h0000_0000;
  parameter int MEM_SIZE = 64 * 1024;
  //---------------------------------------
  //constaint, to generate any one among write and read
  //---------------------------------------
//  constraint wr_rd_c { wr_en != rd_en; }; 
  
endclass