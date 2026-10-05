
// `include "apb_interface.sv"
`include "uvm_macros.svh"
import uvm_pkg::*;
import apb_tb_uvm_pkg::*;

//---------------------------------------------------------------

module tbench_top;

  //---------------------------------------
  //clock and reset signal declaration
  //---------------------------------------
  bit clk;
  bit reset;
  
  //---------------------------------------
  //clock generation
  //---------------------------------------
  always #5 clk = ~clk;
  
  //---------------------------------------
  //reset Generation
  //---------------------------------------
  initial begin
    reset = 0;
  #5;
    reset =1;
    //  #5;
    // reset =0;
   
  end
  
  //---------------------------------------
  //interface instance
  //---------------------------------------
  apb_if if1(clk,reset);
  
  //---------------------------------------
  //DUT instance
  //---------------------------------------
 apb_wrapper DUT(.PCLK(if1.PCLK),
.PRESETn(if1.PRESETn),
.PSELx(if1.PSELx),
.PENABLE(if1.PENABLE),
.PWRITE(if1.PWRITE),
.PWDATA(if1.PWDATA),
.PSTRB(if1.PSTRB),
.PADDR(if1.PADDR),
.PRDATA(if1.PRDATA),
.PREADY(if1.PREADY),
.PSLVERR(if1.PSLVERR));
  //---------------------------------------
  //passing the interface handle to lower heirarchy using set method 
  //and enabling the wave dump
  //---------------------------------------
  initial begin 
    uvm_config_db#(virtual apb_if)::set(uvm_root::get(),"*","vif",if1);
     `uvm_info("Testbench","Enter", UVM_LOW);
    //enable wave dump
    // $dumpfile("dump.vcd"); 
    // $dumpvars;
 
    $vcdplusfile("waveform.vpd"); 
    $vcdpluson;
  end
  
  //---------------------------------------
  //calling test
  //---------------------------------------
  initial begin 
    run_test();
  end

endmodule 