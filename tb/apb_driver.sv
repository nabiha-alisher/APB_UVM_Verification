//-------------------------------------------------------------------------
//						apb_driver - www.verificationguide.com
//-------------------------------------------------------------------------
// include "apb_interface.sv"
`define DRIV_IF vif.DRIVER.driver_cb

class apb_driver extends uvm_driver #(apb_seq_item);

  //--------------------------------------- 
  // Virtual Interface
  //--------------------------------------- 
  virtual apb_if vif;
  `uvm_component_utils(apb_driver)
    
  //--------------------------------------- 
  // Constructor
  //--------------------------------------- 
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //--------------------------------------- 
  // build phase
  //---------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
     if(!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
       `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
       `uvm_info("Driver","Enter", UVM_LOW);
  endfunction: build_phase

  //---------------------------------------  
  // run phase
  //---------------------------------------  
  virtual task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      drive();
     // read();
      seq_item_port.item_done();
      `uvm_info("Driver","End", UVM_LOW);
    end
  endtask : run_phase
  
  task drive();        
  // ---- SETUP Phase ----
        @(vif.driver_cb);   
        `DRIV_IF.PSELx   <= 1'b1;
        `DRIV_IF.PENABLE <= 1'b0;
        `DRIV_IF.PWRITE  <= req.PWRITE;
        `DRIV_IF.PADDR   <= req.PADDR;
        `DRIV_IF.PWDATA  <= req.PWDATA;
        `DRIV_IF.PSTRB   <= req.PSTRB;
        // ---- ACCESS Phase ----
      if (req.PWRITE==1) begin
        @(vif.driver_cb);
        `DRIV_IF.PENABLE <= 1'b1; //end 
         wait (`DRIV_IF.PREADY==1);    
      // ---- Deassert ----
        @(vif.driver_cb);
        `DRIV_IF.PSELx   <= 1'b0;
        `DRIV_IF.PENABLE <= 1'b0;
        `DRIV_IF.PWRITE  <= 1'b0;
        `DRIV_IF.PADDR   <= '0;
        `DRIV_IF.PWDATA  <= '0;
        `DRIV_IF.PSTRB   <= 4;
      end
      else begin
      @(vif.driver_cb);
        `DRIV_IF.PENABLE <= 1'b1; //end 
         wait (`DRIV_IF.PREADY==1); 
         req.PRDATA<=`DRIV_IF.PRDATA;
         req.PSLVERR <= `DRIV_IF.PSLVERR;     
       // ---- Deassert ----
      @(vif.driver_cb);
        `DRIV_IF.PSELx   <= 1'b0;
        `DRIV_IF.PENABLE <= 1'b0;
        `DRIV_IF.PWRITE  <= 1'b0;
        `DRIV_IF.PADDR   <= '0;
        `DRIV_IF.PWDATA  <= '0;
        `DRIV_IF.PSTRB   <= '0;
      end
    endtask
endclass : apb_driver