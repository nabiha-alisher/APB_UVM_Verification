//-------------------------------------------------------------------------
//                      apb_monitor
//-------------------------------------------------------------------------
// Passive APB monitor.
//
// Publishes exactly ONE apb_seq_item per COMPLETED transfer, sampled in the
// ACCESS phase when PSEL=1, PENABLE=1 and PREADY=1.
//   - SETUP cycles (PENABLE=0) and wait-state cycles (PREADY=0) are not
//     published; only the completing cycle is.
//   - Reads and writes are both published, with PRDATA / PSLVERR captured.
//   - A NEW item is created for every transfer (no handle re-use), so the
//     scoreboard always receives independent objects.
//   - Nothing is sampled while PRESETn is low.
//
// Phase-sequencing checks (SETUP->ACCESS, min 2 cycles, stability, etc.)
// are done in apb_scoreboard.phase_checker; the monitor only collects.
//-------------------------------------------------------------------------

class apb_monitor extends uvm_monitor;

  //---------------------------------------
  // Virtual Interface
  //---------------------------------------
  virtual apb_if vif;

  //---------------------------------------
  // Analysis port, sends completed transfers to the scoreboard
  //---------------------------------------
  uvm_analysis_port #(apb_seq_item) item_collected_port;

  //---------------------------------------
  // Number of transfers published
  //---------------------------------------
  int unsigned num_trans;

  `uvm_component_utils(apb_monitor)

  //---------------------------------------
  // new - constructor
  //---------------------------------------
  function new (string name, uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction : new

  //---------------------------------------
  // build_phase - get the interface handle
  //---------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
  endfunction : build_phase

  //---------------------------------------
  // run_phase - signal level -> transaction level
  //---------------------------------------
  virtual task run_phase(uvm_phase phase);
    apb_seq_item trans;

    forever begin
      @(vif.monitor_cb);

      // ignore everything while reset is asserted (active-low, async)
      if (vif.PRESETn !== 1'b1) continue;

      // a transfer completes in the ACCESS phase when PREADY is high
      if (vif.monitor_cb.PSELx   === 1'b1 &&
          vif.monitor_cb.PENABLE === 1'b1 &&
          vif.monitor_cb.PREADY  === 1'b1) begin

        trans = apb_seq_item::type_id::create("trans");

        trans.PSELx   = vif.monitor_cb.PSELx;
        trans.PENABLE = vif.monitor_cb.PENABLE;
        trans.PWRITE  = vif.monitor_cb.PWRITE;
        trans.PADDR   = vif.monitor_cb.PADDR;
        trans.PWDATA  = vif.monitor_cb.PWDATA;
        trans.PSTRB   = vif.monitor_cb.PSTRB;
        trans.PRDATA  = vif.monitor_cb.PRDATA;
        trans.PREADY  = vif.monitor_cb.PREADY;
        trans.PSLVERR = vif.monitor_cb.PSLVERR;

        num_trans++;
        `uvm_info(get_type_name(),
          $sformatf("#%0d %s addr=%h wdata=%h strb=%b rdata=%h slverr=%b",
                    num_trans, trans.PWRITE ? "WRITE" : "READ ",
                    trans.PADDR, trans.PWDATA, trans.PSTRB, trans.PRDATA, trans.PSLVERR),
          UVM_MEDIUM)

        item_collected_port.write(trans);
      end
    end
  endtask : run_phase

  //---------------------------------------
  // report_phase
  //---------------------------------------
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Monitor published %0d transfers", num_trans), UVM_LOW)
  endfunction : report_phase

endclass : apb_monitor