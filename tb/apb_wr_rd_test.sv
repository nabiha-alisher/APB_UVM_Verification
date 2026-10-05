//-------------------------------------------------------------------------
//						apb_write_read_test - www.verificationguide.com 
//-------------------------------------------------------------------------
class apb_wr_rd_test extends apb_model_base_test;

  `uvm_component_utils(apb_wr_rd_test)
  
  //---------------------------------------
  // wtuence instance 
  //--------------------------------------- 
  //apb_wtuence wt;
  write_sequence wt;
  read_sequence rd;
  //---------------------------------------
  // constructor
  //---------------------------------------
  function new(string name = "apb_wr_rd_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction : new

  //---------------------------------------
  // build_phase
  //---------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create the wtuence
    wt = write_sequence::type_id::create("wt");
    rd = read_sequence::type_id::create("rd");
     `uvm_info("test_CHILD","build Phase Executed", UVM_NONE);

  endfunction : build_phase
  
  //---------------------------------------
  // run_phase - starting the test
  //---------------------------------------
  task run_phase(uvm_phase phase);

     `uvm_info("test ","run Phase Executed", UVM_NONE);

    
    phase.raise_objection(this);
    //`uvm_info("test_apb ","run1 Phase Executed", UVM_NONE);
     wt.start(env.apb_agnt.sqr);
    //  #20;
      rd.start(env.apb_agnt.sqr);
     //  `uvm_info("test_apb ","run Phase Executed", UVM_NONE);
    phase.drop_objection(this);
    
    //set a drain-time for the environment if desird
    phase.phase_done.set_drain_time(this, 50);
  endtask : run_phase
  
endclass : apb_wr_rd_test