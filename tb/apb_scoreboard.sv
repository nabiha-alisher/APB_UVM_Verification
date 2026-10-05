//-------------------------------------------------------------------------
//                      apb_scoreboard
//-------------------------------------------------------------------------
// Reference model + checker for the APB memory slave.
//
// Spec modelled
//   - AMBA APB: IDLE -> SETUP -> ACCESS, minimum 2 cycles per transfer
//   - 64 KB memory (65,536 bytes) at parameterizable base address
//   - 64-bit data bus, 32-bit byte address, little-endian
//   - Access must be 8-byte aligned
//   - PSLVERR=1 for: address outside the 64 KB window, misaligned access
//   - PSTRB[7:0] byte-enable writes
//   - One transfer at a time (no outstanding transactions)
//   - Active-low asynchronous reset (PRESETn)
//
// Input from monitor: ONE apb_seq_item per COMPLETED transfer, sampled in the
// ACCESS phase (PSEL=1, PENABLE=1, PREADY=1).
//
// Checks
//   A. Data      : read data vs reference memory (little-endian, PSTRB aware)
//   B. Error     : actual PSLVERR must equal expected PSLVERR
//                  (out of window OR misaligned)
//   C. Item      : X/Z checks, PSEL/PENABLE/PREADY at completion, PSTRB=0 on read
//   D. Phases    : (needs vif) SETUP->ACCESS sequencing, min 2 cycles,
//                  signals stable SETUP..ACCESS, PENABLE low after completion,
//                  PENABLE never high without PSEL
//
// Optional knobs (uvm_config_db, set on this component):
//   base_addr          bit[31:0]  (default 0)      base of the 64 KB window
//   chk_protocol       bit        (default 1)      item-level checks (C)
//   chk_phases         bit        (default 1)      phase checks (D), needs vif
//   chk_unwritten      bit        (default 0)      compare reads of never-written
//                                                  locations with reset_value
//   reset_value        bit[63:0]  (default 0)      expected content of unwritten
//   mem_clear_on_reset bit        (default 0)      clear model on PRESETn assert
//-------------------------------------------------------------------------

class apb_scoreboard extends uvm_scoreboard;

  //---------------------------------------
  // Spec constants
  //---------------------------------------
  localparam int DATA_W   = 64;
  localparam int STRB_W   = DATA_W/8;            // 8 byte lanes
  localparam int ADDR_LSB = $clog2(STRB_W);      // 3 -> 8-byte alignment
  localparam int MEM_BYTES = 65536;              // 64 KB window

  //---------------------------------------
  // Reference memory, indexed by word number inside the window
  //---------------------------------------
  bit [DATA_W-1:0] sc_apb [bit [31:0]];

  //---------------------------------------
  // Knobs
  //---------------------------------------
  bit [31:0]       base_addr          = 32'h0;
  bit              chk_protocol       = 1;
  bit              chk_phases         = 1;
  bit              chk_unwritten      = 0;
  bit [DATA_W-1:0] reset_value        = '0;
  bit              mem_clear_on_reset = 0;

  //---------------------------------------
  // Optional virtual interface (phase / reset checks)
  //---------------------------------------
  virtual apb_if vif;

  //---------------------------------------
  // Statistics
  //---------------------------------------
  int unsigned total_cnt, wr_cnt, rd_cnt;
  int unsigned rd_match_cnt, rd_mismatch_cnt, rd_skipped_cnt;
  int unsigned exp_err_cnt;       // transfers where PSLVERR was expected
  int unsigned err_mismatch_cnt;  // PSLVERR actual != expected
  int unsigned proto_err_cnt;     // item-level check failures
  int unsigned phase_err_cnt;     // phase-level check failures
  int unsigned reset_cnt;

  uvm_analysis_imp#(apb_seq_item, apb_scoreboard) item_collected_export;
  `uvm_component_utils(apb_scoreboard)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //---------------------------------------
  // build_phase
  //---------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    item_collected_export = new("item_collected_export", this);
    void'(uvm_config_db#(bit [31:0])::get(this, "", "base_addr",          base_addr));
    void'(uvm_config_db#(bit)::get(this, "", "chk_protocol",       chk_protocol));
    void'(uvm_config_db#(bit)::get(this, "", "chk_phases",         chk_phases));
    void'(uvm_config_db#(bit)::get(this, "", "chk_unwritten",      chk_unwritten));
    void'(uvm_config_db#(bit)::get(this, "", "mem_clear_on_reset", mem_clear_on_reset));
    void'(uvm_config_db#(bit [DATA_W-1:0])::get(this, "", "reset_value", reset_value));
    // vif is optional - only needed for phase/reset checks
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_info(get_type_name(), "No vif given: phase and reset checks disabled", UVM_LOW)
  endfunction : build_phase

  //---------------------------------------
  // write - called by monitor for each completed transfer
  //---------------------------------------
  virtual function void write(apb_seq_item t);
    apb_seq_item pkt;

    // transfers seen while reset is asserted are not meaningful
    if (vif != null && vif.PRESETn === 1'b0) return;

    if (!$cast(pkt, t.clone()))
      `uvm_fatal(get_type_name(), "Unable to clone received apb_seq_item")

    total_cnt++;
    if (chk_protocol) check_item(pkt);

    if (pkt.PWRITE === 1'b1)      process_write(pkt);
    else if (pkt.PWRITE === 1'b0) process_read(pkt);
    else
      `uvm_error(get_type_name(), "PWRITE is X/Z - direction unknown, item ignored")
  endfunction : write

  //---------------------------------------
  // Address helpers
  //---------------------------------------
  // 1 if address is outside [base_addr, base_addr + 64KB)
  function bit out_of_window(logic [31:0] addr);
    bit [32:0] off;
    if (addr < base_addr) return 1;
    off = {1'b0, addr} - {1'b0, base_addr};
    return (off >= MEM_BYTES);
  endfunction : out_of_window

  // 1 if address is not 8-byte aligned
  function bit misaligned(logic [31:0] addr);
    return (addr[ADDR_LSB-1:0] != '0);
  endfunction : misaligned

  // word number inside the window
  function bit [31:0] word_idx(logic [31:0] addr);
    return (addr - base_addr) >> ADDR_LSB;
  endfunction : word_idx

  //---------------------------------------
  // Expected-error check shared by reads and writes.
  // Returns 1 if the spec says this access must be an error.
  //---------------------------------------
  function bit check_slverr(apb_seq_item p);
    bit oow, mis, exp_err;
    string kind = (p.PWRITE === 1'b1) ? "WRITE" : "READ";

    oow     = out_of_window(p.PADDR);
    mis     = misaligned(p.PADDR);
    exp_err = oow | mis;

    if (exp_err) exp_err_cnt++;

    if (p.PSLVERR !== exp_err) begin
      err_mismatch_cnt++;
      `uvm_error(get_type_name(),
        $sformatf("%s addr=%h PSLVERR mismatch: expected=%b actual=%b (out_of_window=%b misaligned=%b)",
                  kind, p.PADDR, exp_err, p.PSLVERR, oow, mis))
    end
    else if (exp_err) begin
      `uvm_info(get_type_name(),
        $sformatf("%s addr=%h correctly returned PSLVERR (out_of_window=%b misaligned=%b)",
                  kind, p.PADDR, oow, mis), UVM_LOW)
    end
    return exp_err;
  endfunction : check_slverr

  //---------------------------------------
  // Item-level checks (C)
  //---------------------------------------
  function void check_item(apb_seq_item p);
    string id = get_type_name();

    if (p.PSELx !== 1'b1)   begin proto_err_cnt++; `uvm_error(id, $sformatf("PSEL=%b at completed transfer (expected 1)", p.PSELx)) end
    if (p.PENABLE !== 1'b1) begin proto_err_cnt++; `uvm_error(id, $sformatf("PENABLE=%b at completed transfer (expected 1)", p.PENABLE)) end
    if (p.PREADY !== 1'b1)  begin proto_err_cnt++; `uvm_error(id, $sformatf("PREADY=%b at completed transfer (expected 1)", p.PREADY)) end
    if ($isunknown(p.PADDR))   begin proto_err_cnt++; `uvm_error(id, $sformatf("PADDR has X/Z: %h", p.PADDR)) end
    if ($isunknown(p.PSLVERR)) begin proto_err_cnt++; `uvm_error(id, $sformatf("PSLVERR is X/Z: %b", p.PSLVERR)) end

    if (p.PWRITE === 1'b1) begin
      if ($isunknown(p.PWDATA)) begin proto_err_cnt++; `uvm_error(id, $sformatf("Write PWDATA has X/Z: %h (addr %h)", p.PWDATA, p.PADDR)) end
      if ($isunknown(p.PSTRB))  begin proto_err_cnt++; `uvm_error(id, $sformatf("Write PSTRB has X/Z: %b (addr %h)", p.PSTRB, p.PADDR)) end
    end
    else if (p.PWRITE === 1'b0) begin
      if (p.PSTRB !== '0) begin
        proto_err_cnt++;
        `uvm_warning(id, $sformatf("Read has PSTRB=%b (must be 0 for reads, addr %h)", p.PSTRB, p.PADDR))
      end
    end
  endfunction : check_item

  //---------------------------------------
  // Write: update reference memory (little-endian lanes, PSTRB aware)
  //---------------------------------------
  function void process_write(apb_seq_item p);
    bit              exp_err;
    bit [31:0]       idx;
    bit [DATA_W-1:0] cur, nxt;

    if ($isunknown(p.PADDR)) return;

    exp_err = check_slverr(p);
    if (exp_err) return;                       // errored write must not change memory

    idx = word_idx(p.PADDR);
    cur = sc_apb.exists(idx) ? sc_apb[idx] : reset_value;
    nxt = cur;
    for (int b = 0; b < STRB_W; b++)
      if (p.PSTRB[b] === 1'b1) nxt[b*8 +: 8] = p.PWDATA[b*8 +: 8];
    sc_apb[idx] = nxt;
    wr_cnt++;

    `uvm_info(get_type_name(), "------ :: WRITE DATA       :: ------", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Addr: %h (offset %h, word %0d)", p.PADDR, p.PADDR - base_addr, idx), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("PWDATA: %h  PSTRB: %b", p.PWDATA, p.PSTRB), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Model now holds: %h", nxt), UVM_LOW)
    `uvm_info(get_type_name(), "------------------------------------", UVM_LOW)
  endfunction : process_write

  //---------------------------------------
  // Read: compare PRDATA with reference memory
  //---------------------------------------
  function void process_read(apb_seq_item p);
    bit              exp_err;
    bit [31:0]       idx;
    bit [DATA_W-1:0] exp;
    bit              known;

    rd_cnt++;
    if ($isunknown(p.PADDR)) begin rd_skipped_cnt++; return; end

    exp_err = check_slverr(p);
    if (exp_err || p.PSLVERR === 1'b1) begin   // no data compare on an error response
      rd_skipped_cnt++;
      return;
    end

    idx   = word_idx(p.PADDR);
    known = sc_apb.exists(idx);

    if (!known && !chk_unwritten) begin
      rd_skipped_cnt++;
      `uvm_info(get_type_name(),
        $sformatf("READ addr=%h never written - compare skipped (PRDATA=%h)", p.PADDR, p.PRDATA), UVM_LOW)
      return;
    end

    exp = known ? sc_apb[idx] : reset_value;

    if (exp === p.PRDATA) begin
      rd_match_cnt++;
      `uvm_info(get_type_name(), "------ :: READ DATA Match :: ------", UVM_LOW)
      `uvm_info(get_type_name(), $sformatf("Addr: %h (offset %h, word %0d)", p.PADDR, p.PADDR - base_addr, idx), UVM_LOW)
      `uvm_info(get_type_name(), $sformatf("Expected Data: %h Actual Data: %h", exp, p.PRDATA), UVM_LOW)
      `uvm_info(get_type_name(), "------------------------------------", UVM_LOW)
    end
    else begin
      rd_mismatch_cnt++;
      `uvm_error(get_type_name(), "------ :: READ DATA MisMatch :: ------")
      `uvm_info(get_type_name(), $sformatf("Addr: %h (offset %h, word %0d)", p.PADDR, p.PADDR - base_addr, idx), UVM_LOW)
      `uvm_info(get_type_name(), $sformatf("Expected Data: %h Actual Data: %h", exp, p.PRDATA), UVM_LOW)
      `uvm_info(get_type_name(), $sformatf("Differing byte lanes (1=diff, [7]..[0]): %b", byte_diff(exp, p.PRDATA)), UVM_LOW)
      `uvm_info(get_type_name(), "------------------------------------", UVM_LOW)
    end
  endfunction : process_read

  function bit [STRB_W-1:0] byte_diff(bit [DATA_W-1:0] e, logic [DATA_W-1:0] a);
    bit [STRB_W-1:0] m;
    for (int b = 0; b < STRB_W; b++) m[b] = (e[b*8 +: 8] !== a[b*8 +: 8]);
    return m;
  endfunction : byte_diff

  //---------------------------------------
  // run_phase - interface-level checkers (reset + phases)
  //---------------------------------------
  virtual task run_phase(uvm_phase phase);
    if (vif == null) return;
    fork
      reset_watcher();
      if (chk_phases) phase_checker();
    join
  endtask : run_phase

  // Async active-low reset: optionally clear the model when reset asserts
  task reset_watcher();
    forever begin
      @(negedge vif.PRESETn);
      reset_cnt++;
      `uvm_info(get_type_name(), "PRESETn asserted", UVM_LOW)
      if (mem_clear_on_reset) sc_apb.delete();
    end
  endtask : reset_watcher

  // IDLE/SETUP/ACCESS sequencing (D)
  task phase_checker();
    bit          prev_sel, prev_en, prev_rdy;
    bit          sel, en, rdy;
    bit          completed_prev, setup_prev, wait_prev;
    logic [31:0] s_addr;
    logic        s_wr;
    logic [DATA_W-1:0] s_wdata;
    logic [STRB_W-1:0] s_strb;
    string       id = {get_type_name(), "_PHASE"};

    forever begin
      @(vif.monitor_cb);

      if (vif.PRESETn !== 1'b1) begin          // in reset: bus must restart from IDLE
        prev_sel = 0; prev_en = 0; prev_rdy = 0;
        continue;
      end

      sel = (vif.monitor_cb.PSELx   === 1'b1);
      en  = (vif.monitor_cb.PENABLE === 1'b1);
      rdy = (vif.monitor_cb.PREADY  === 1'b1);

      completed_prev = prev_sel &&  prev_en &&  prev_rdy;
      setup_prev     = prev_sel && !prev_en;
      wait_prev      = prev_sel &&  prev_en && !prev_rdy;

      if (en && !sel) begin
        phase_err_cnt++;
        `uvm_error(id, "PENABLE high while PSEL low")
      end

      if (sel) begin
        if (!prev_sel || completed_prev) begin
          // first cycle of a new transfer = SETUP
          if (en) begin
            phase_err_cnt++;
            `uvm_error(id, "SETUP phase missing: PENABLE high in first PSEL cycle (min 2 cycles per transfer)")
          end
          else begin                            // remember SETUP values
            s_addr = vif.monitor_cb.PADDR;   s_wr   = vif.monitor_cb.PWRITE;
            s_wdata = vif.monitor_cb.PWDATA; s_strb = vif.monitor_cb.PSTRB;
          end
        end
        else if (setup_prev || wait_prev) begin
          if (!en) begin
            phase_err_cnt++;
            `uvm_error(id, setup_prev ? "ACCESS phase must follow SETUP in the next cycle (PENABLE not asserted)"
                                      : "PENABLE dropped while waiting for PREADY")
          end
          // control/address/data must be stable from SETUP until completion
          if (vif.monitor_cb.PADDR !== s_addr || vif.monitor_cb.PWRITE !== s_wr) begin
            phase_err_cnt++;
            `uvm_error(id, $sformatf("PADDR/PWRITE changed between SETUP and ACCESS (addr %h->%h, wr %b->%b)",
                       s_addr, vif.monitor_cb.PADDR, s_wr, vif.monitor_cb.PWRITE))
          end
          if (s_wr === 1'b1 && (vif.monitor_cb.PWDATA !== s_wdata || vif.monitor_cb.PSTRB !== s_strb)) begin
            phase_err_cnt++;
            `uvm_error(id, "PWDATA/PSTRB changed between SETUP and ACCESS of a write")
          end
        end
      end
      else begin
        if (setup_prev || wait_prev) begin
          phase_err_cnt++;
          `uvm_error(id, "PSEL dropped before the transfer completed")
        end
      end

      prev_sel = sel;
      prev_en  = en;
      prev_rdy = rdy;
    end
  endtask : phase_checker

  //---------------------------------------
  // check_phase
  //---------------------------------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (total_cnt == 0)
      `uvm_error(get_type_name(), "No transfers were received from the monitor - nothing was checked")
    else if (rd_cnt == 0)
      `uvm_warning(get_type_name(), "No READ transfers observed - no data compare was performed")
    else if (rd_match_cnt + rd_mismatch_cnt == 0)
      `uvm_warning(get_type_name(), "Reads observed but none could be compared (unwritten address / error response)")
  endfunction : check_phase

  //---------------------------------------
  // report_phase
  //---------------------------------------
  function void report_phase(uvm_phase phase);
    bit fail;
    super.report_phase(phase);
    fail = (rd_mismatch_cnt != 0) || (err_mismatch_cnt != 0) ||
           (proto_err_cnt != 0)   || (phase_err_cnt != 0)    || (total_cnt == 0);

    `uvm_info(get_type_name(), "=========== APB SCOREBOARD SUMMARY ===========", UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Window              : base=%h size=%0d bytes", base_addr, MEM_BYTES), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Total transfers     : %0d", total_cnt),        UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Writes (model upd.) : %0d", wr_cnt),           UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Reads               : %0d", rd_cnt),           UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("  Read matches      : %0d", rd_match_cnt),     UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("  Read mismatches   : %0d", rd_mismatch_cnt),  UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("  Read skipped      : %0d", rd_skipped_cnt),   UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Expected PSLVERR    : %0d transfers", exp_err_cnt), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("PSLVERR mismatches  : %0d", err_mismatch_cnt), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Item check failures : %0d", proto_err_cnt),    UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Phase check failures: %0d", phase_err_cnt),    UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Resets seen         : %0d", reset_cnt),        UVM_NONE)
    `uvm_info(get_type_name(), fail ? "RESULT: FAIL" : "RESULT: PASS", UVM_NONE)
    `uvm_info(get_type_name(), "==============================================", UVM_NONE)
  endfunction : report_phase

endclass : apb_scoreboard