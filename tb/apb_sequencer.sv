//-------------------------------------------------------------------------
//						apb_sequencer - www.verificationguide.com
//-------------------------------------------------------------------------

class apb_sequencer extends uvm_sequencer#(apb_seq_item);

  `uvm_component_utils(apb_sequencer) 

  //---------------------------------------
  //constructor
  //---------------------------------------
  function new(string name, uvm_component parent);
    super.new(name,parent);
     `uvm_info("Sequencer","Enter_sEQUENCER", UVM_LOW);
  endfunction
  
endclass