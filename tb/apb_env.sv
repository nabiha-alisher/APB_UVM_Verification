//-------------------------------------------------------------------------
//						apb_env - www.verificationguide.com
//-------------------------------------------------------------------------

// `include "apb_agent.sv"
// `include "apb_scoreboard.sv"

class apb_model_env extends uvm_env;
  
  //---------------------------------------
  // agent and scoreboard instance
  //---------------------------------------
  apb_agent      apb_agnt;
 apb_scoreboard apb_scb;
  apb_coverage   apb_cov;
  
  `uvm_component_utils(apb_model_env)
  
  //--------------------------------------- 
  // constructor
  //---------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //---------------------------------------
  // build_phase - crate the components
  //---------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    apb_agnt = apb_agent::type_id::create("apb_agnt", this);
     apb_scb  = apb_scoreboard::type_id::create("apb_scb", this);
    apb_cov  = apb_coverage::type_id::create("apb_cov", this);
        `uvm_info("Env","Enter", UVM_LOW);
  endfunction : build_phase
  
  //---------------------------------------
  // connect_phase - connecting monitor and scoreboard port
  //---------------------------------------
  function void connect_phase(uvm_phase phase);
     apb_agnt.monitor.item_collected_port.connect(apb_scb.item_collected_export);
     apb_agnt.monitor.item_collected_port.connect(apb_cov.analysis_export);
  endfunction : connect_phase

endclass : apb_model_env