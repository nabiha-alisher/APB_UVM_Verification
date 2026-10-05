//-------------------------------------------------------------------------
//                      apb_coverage  (cov.sv)
//-------------------------------------------------------------------------
// Functional coverage for the APB memory slave.
//
// Spec covered
//   - 64 KB window at parameterizable base, 64-bit data, 8-byte alignment
//   - PSLVERR for out-of-window / misaligned accesses
//   - PSTRB[7:0] byte-enable writes
//   - Read / write ordering, read-after-write, overwrite
//   - Transfer timing (wait states, back-to-back vs idle gap)
//   - Reset applied while IDLE / SETUP / ACCESS
//
// Covergroups
//   cg_xfer   : sampled from the monitor, once per completed transfer
//   cg_timing : sampled from the interface, once per completed transfer
//   cg_reset  : sampled on every PRESETn assertion
//
// Knobs (uvm_config_db, set on this component):
//   base_addr (bit[31:0], default 0)  must match the DUT / scoreboard base
// vif is optional: without it only cg_xfer is collected.
//-------------------------------------------------------------------------

class apb_coverage extends uvm_subscriber #(apb_seq_item);

  `uvm_component_utils(apb_coverage)

  //---------------------------------------
  // Spec constants
  //---------------------------------------
  localparam int MEM_BYTES = 65536;
  localparam int STRB_W    = 8;

  //---------------------------------------
  // Knob / interface
  //---------------------------------------
  bit [31:0]     base_addr = 32'h0;
  virtual apb_if vif;

  //---------------------------------------
  // Classification of the address
  //---------------------------------------
  typedef enum {R_BELOW_BASE, R_FIRST_WORD, R_MIDDLE, R_LAST_WORD,
                R_JUST_ABOVE, R_FAR_ABOVE} range_e;

  typedef enum {ST_IDLE, ST_SETUP, ST_ACCESS} bus_state_e;

  //---------------------------------------
  // Values sampled by cg_xfer
  //---------------------------------------
  bit                is_write;
  bit                slverr;
  bit                exp_err;        // spec says this access must error
  bit                in_window;
  bit                misaligned;
  bit [2:0]          byte_off;
  bit [12:0]         word;           // word number inside the window (valid if in_window)
  range_e            range_cls;
  bit [STRB_W-1:0]   strb;
  bit [63:0]         wdata;
  bit                hit_prev_wr;    // address was written earlier by a valid write

  bit                seen_wr [bit [31:0]];   // word addresses already written

  //---------------------------------------
  // Values sampled by cg_timing / cg_reset
  //---------------------------------------
  int unsigned       wait_cycles;    // PREADY=0 cycles in ACCESS before completion
  int unsigned       idle_cycles;    // PSEL=0 cycles since previous completion
  bit                started;        // at least one transfer completed
  bus_state_e        rst_state;

  //=======================================
  // Covergroup 1 : transfer content
  //=======================================
  covergroup cg_xfer;
    option.per_instance = 1;
    option.name         = "cg_xfer";

    // ---- direction and ordering
    cp_dir : coverpoint is_write {
      bins read  = {0};
      bins write = {1};
    }
    cp_dir_trans : coverpoint is_write {
      bins wr_to_wr = (1 => 1);
      bins wr_to_rd = (1 => 0);
      bins rd_to_wr = (0 => 1);
      bins rd_to_rd = (0 => 0);
    }

    // ---- address
    cp_range : coverpoint range_cls;   // auto bins from enum

    cp_align : coverpoint misaligned {
      bins aligned    = {0};
      bins misaligned = {1};
    }
    cp_byte_off : coverpoint byte_off {
      bins aligned = {0};
      bins off[]   = {[1:7]};
    }
    cp_word : coverpoint word iff (in_window && !misaligned) {
      bins first_word = {0};
      bins low        = {[1    : 2047]};
      bins mid        = {[2048 : 6143]};
      bins high       = {[6144 : 8190]};
      bins last_word  = {8191};
    }

    // ---- error response
    cp_exp_err : coverpoint exp_err { bins no_err = {0}; bins err = {1}; }
    cp_slverr  : coverpoint slverr  { bins no_err = {0}; bins err = {1}; }

    // ---- write strobes / data (valid writes only)
    cp_wstrb : coverpoint strb iff (is_write && !exp_err) {
      bins none        = {8'h00};
      bins all         = {8'hFF};
      bins low_half    = {8'h0F};
      bins high_half   = {8'hF0};
      bins alt_55      = {8'h55};
      bins alt_AA      = {8'hAA};
      bins single[]    = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
      bins other       = default;
    }
    cp_wdata : coverpoint wdata iff (is_write && !exp_err) {
      bins zero  = {64'h0};
      bins ones  = {64'hFFFF_FFFF_FFFF_FFFF};
      bins p_55  = {64'h5555_5555_5555_5555};
      bins p_AA  = {64'hAAAA_AAAA_AAAA_AAAA};
      bins other = default;
    }

    // ---- read-after-write / overwrite (valid accesses only)
    cp_rd_after_wr : coverpoint hit_prev_wr iff (!is_write && !exp_err) {
      bins read_written   = {1};
      bins read_unwritten = {0};
    }
    cp_overwrite : coverpoint hit_prev_wr iff (is_write && !exp_err) {
      bins first_write = {0};
      bins overwrite   = {1};
    }

    // ---- crosses
    cross_dir_range_align : cross cp_dir, cp_range, cp_align;
    cross_dir_word        : cross cp_dir, cp_word;

    // expected vs actual PSLVERR: only the matching combinations are meaningful
    // (mismatches are reported by the scoreboard)
    cross_err : cross cp_exp_err, cp_slverr {
      ignore_bins mismatch = binsof(cp_exp_err.no_err) && binsof(cp_slverr.err) ||
                             binsof(cp_exp_err.err)    && binsof(cp_slverr.no_err);
    }

    // partial / full strobe over fresh vs already-written location
    cross_strb_overwrite : cross cp_wstrb, cp_overwrite;
  endgroup : cg_xfer

  //=======================================
  // Covergroup 2 : transfer timing
  //=======================================
  covergroup cg_timing;
    option.per_instance = 1;
    option.name         = "cg_timing";

    cp_wait : coverpoint wait_cycles {
      bins no_wait   = {0};
      bins one_wait  = {1};
      bins few_waits = {[2:4]};
      bins many      = {[5:$]};
    }
    cp_gap : coverpoint idle_cycles iff (started) {
      bins back_to_back = {0};
      bins gap_1        = {1};
      bins gap_short    = {[2:4]};
      bins gap_long     = {[5:$]};
    }
  endgroup : cg_timing

  //=======================================
  // Covergroup 3 : reset
  //=======================================
  covergroup cg_reset;
    option.per_instance = 1;
    option.name         = "cg_reset";

    cp_rst_state : coverpoint rst_state {
      bins in_idle   = {ST_IDLE};
      bins in_setup  = {ST_SETUP};
      bins in_access = {ST_ACCESS};
    }
  endgroup : cg_reset

  //---------------------------------------
  // new
  //---------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_xfer   = new();
    cg_timing = new();
    cg_reset  = new();
  endfunction : new

  //---------------------------------------
  // build_phase
  //---------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(bit [31:0])::get(this, "", "base_addr", base_addr));
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_info(get_type_name(), "No vif given: timing and reset coverage disabled", UVM_LOW)
  endfunction : build_phase

  //---------------------------------------
  // write - one call per completed transfer from the monitor
  //---------------------------------------
  virtual function void write(apb_seq_item t);
    bit [32:0] off;
    bit [31:0] key;

    if ($isunknown(t.PWRITE) || $isunknown(t.PADDR)) return;

    is_write   = t.PWRITE;
    slverr     = (t.PSLVERR === 1'b1);
    strb       = t.PSTRB;
    wdata      = t.PWDATA;
    byte_off   = t.PADDR[2:0];
    misaligned = (t.PADDR[2:0] != 3'b000);

    // ---- address classification
    off = {1'b0, t.PADDR} - {1'b0, base_addr};
    if (t.PADDR < base_addr) begin
      in_window = 0;
      range_cls = R_BELOW_BASE;
    end
    else if (off >= MEM_BYTES) begin
      in_window = 0;
      range_cls = (off == MEM_BYTES) ? R_JUST_ABOVE : R_FAR_ABOVE;
    end
    else begin
      in_window = 1;
      if      (off < 8)              range_cls = R_FIRST_WORD;
      else if (off >= MEM_BYTES - 8) range_cls = R_LAST_WORD;
      else                           range_cls = R_MIDDLE;
    end
    word    = off[15:3];
    exp_err = !in_window || misaligned;

    // ---- history
    key         = t.PADDR >> 3;
    hit_prev_wr = seen_wr.exists(key);

    cg_xfer.sample();

    if (is_write && !exp_err && !slverr) seen_wr[key] = 1;
  endfunction : write

  //---------------------------------------
  // run_phase - interface-level coverage (timing + reset)
  //---------------------------------------
  virtual task run_phase(uvm_phase phase);
    if (vif == null) return;
    fork
      timing_sampler();
      reset_sampler();
    join
  endtask : run_phase

  task timing_sampler();
    bit sel, en, rdy;
    forever begin
      @(vif.monitor_cb);

      if (vif.PRESETn !== 1'b1) begin
        wait_cycles = 0;
        idle_cycles = 0;
        started     = 0;
        continue;
      end

      sel = (vif.monitor_cb.PSELx   === 1'b1);
      en  = (vif.monitor_cb.PENABLE === 1'b1);
      rdy = (vif.monitor_cb.PREADY  === 1'b1);

      if (sel && en && rdy) begin            // transfer completes this cycle
        cg_timing.sample();
        wait_cycles = 0;
        idle_cycles = 0;
        started     = 1;
      end
      else if (sel && en && !rdy) wait_cycles++;
      else if (!sel)              idle_cycles++;
    end
  endtask : timing_sampler

  task reset_sampler();
    forever begin
      @(negedge vif.PRESETn);
      if (vif.PSELx === 1'b1 && vif.PENABLE === 1'b1) rst_state = ST_ACCESS;
      else if (vif.PSELx === 1'b1)                    rst_state = ST_SETUP;
      else                                            rst_state = ST_IDLE;
      cg_reset.sample();
    end
  endtask : reset_sampler

  //---------------------------------------
  // report_phase
  //---------------------------------------
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), "=========== APB FUNCTIONAL COVERAGE ===========", UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("cg_xfer   : %6.2f %%", cg_xfer.get_inst_coverage()),   UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("cg_timing : %6.2f %%", cg_timing.get_inst_coverage()), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("cg_reset  : %6.2f %%", cg_reset.get_inst_coverage()),  UVM_NONE)
    `uvm_info(get_type_name(), "===============================================", UVM_NONE)
  endfunction : report_phase

endclass : apb_coverage