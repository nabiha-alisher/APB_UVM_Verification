`include "env.sv"
class test extends uvm_test;
 `uvm_component_utils(test)
 env e;

 function new(string path = "test", uvm_component parent = null);
   super.new(path, parent);
 endfunction

 function void build_phase(uvm_phase phase);
   super.build_phase(phase);
   e = env::type_id::create("e", this);
   `uvm_info("test","TEST  build Phase Executed", UVM_NONE);
 endfunction
// function void end_of_elaboration_phase(uvm_phase phase);
//   uvm_phase main_phase;
//   super.end_of_elaboration_phase(phase);
//    main_phase = phase.find_by_name("main", 0);
//    main_phase.phase_done.set_drain_time(this, 100);
//  endfunction
endclass