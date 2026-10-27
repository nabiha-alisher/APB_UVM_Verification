interface apb_if (input PCLK,PRESETn);
    // logic                  PCLK;
    // logic                  PRESETn;
    logic                   PSELx;
    logic                   PENABLE;
    logic                   PWRITE;
    logic [63:0]            PWDATA;
    logic [64/8-1:0]        PSTRB;
    logic [32-1:0]          PADDR;
    logic [64-1:0]          PRDATA; 
    logic                   PREADY;
    logic                   PSLVERR;
    
    
    clocking driver_cb @(posedge PCLK);
    default input #1 output #1;
    output PSELx;
    output PENABLE;
    output PWRITE;
    output PWDATA;
    output PSTRB;
    output PADDR;
    input  PRDATA; 
    input  PREADY;
    input  PSLVERR;
  endclocking
  
  //---------------------------------------
  //monitor clocking block
  //---------------------------------------
  clocking monitor_cb @(posedge PCLK);
    default input #1 output #1;
    input PSELx;
    input PENABLE;
    input PWRITE;
    input PWDATA;
    input PSTRB;
    input PADDR;
    input  PRDATA; 
    input  PREADY;
    input  PSLVERR;
  endclocking
  
  //---------------------------------------
  //driver modport
  //---------------------------------------
  modport DRIVER  (clocking driver_cb,input PCLK,input PRESETn);
  
  //---------------------------------------
  //monitor modport  
  //---------------------------------------
  modport MONITOR (clocking monitor_cb,input PCLK,input PRESETn);

  //=========================================
  // APB PROTOCOL ASSERTIONS
  //=========================================

  // 1. PENABLE must not be high when PSELx is low
  property penable_check;
    @(posedge PCLK)
    disable iff (!PRESETn)
    PENABLE |-> PSELx;
  endproperty

  assert property (penable_check)
    else $error("APB ERROR: PENABLE high without PSELx");


  // 2. Setup phase must be followed by Access phase
  property setup_to_access;
    @(posedge PCLK)
    disable iff (!PRESETn)
    (PSELx && !PENABLE) |=> (PSELx && PENABLE);
  endproperty

  assert property (setup_to_access)
    else $error("APB ERROR: Setup not followed by Access");


  // 3. Address must remain stable during wait states
  property address_stable;
    @(posedge PCLK)
    disable iff (!PRESETn)
    (PSELx && PENABLE && !PREADY)
    |=> $stable(PADDR);
  endproperty

  assert property (address_stable)
    else $error("APB ERROR: PADDR changed during wait state");


  // 4. Write control must remain stable during wait states
  property write_stable;
    @(posedge PCLK)
    disable iff (!PRESETn)
    (PSELx && PENABLE && !PREADY)
    |=> $stable(PWRITE);
  endproperty

  assert property (write_stable)
    else $error("APB ERROR: PWRITE changed during wait state");


  // 5. Write data must remain stable during wait states
  property wdata_stable;
    @(posedge PCLK)
    disable iff (!PRESETn)
    (PSELx && PENABLE && !PREADY && PWRITE)
    |=> $stable(PWDATA);
  endproperty

  assert property (wdata_stable)
    else $error("APB ERROR: PWDATA changed during wait state");


  // 6. Strobe must remain stable during wait states
  property strb_stable;
    @(posedge PCLK)
    disable iff (!PRESETn)
    (PSELx && PENABLE && !PREADY && PWRITE)
    |=> $stable(PSTRB);
  endproperty

  assert property (strb_stable)
    else $error("APB ERROR: PSTRB changed during wait state");


  // 7. PSELx must remain high during wait states
  property psel_stable;
    @(posedge PCLK)
    disable iff (!PRESETn)
    (PSELx && PENABLE && !PREADY)
    |=> PSELx;
  endproperty

  assert property (psel_stable)
    else $error("APB ERROR: PSELx dropped during wait state");


  // 8. PENABLE must remain high during wait states
  property penable_stable;
    @(posedge PCLK)
    disable iff (!PRESETn)
    (PSELx && PENABLE && !PREADY)
    |=> PENABLE;
  endproperty

  assert property (penable_stable)
    else $error("APB ERROR: PENABLE dropped during wait state");


  // 9. Read data must be known when read transfer completes
  property read_data_valid;
    @(posedge PCLK)
    disable iff (!PRESETn)
    (PSELx && PENABLE && PREADY && !PWRITE)
    |-> !$isunknown(PRDATA);
  endproperty

  assert property (read_data_valid)
    else $error("APB ERROR: PRDATA contains X or Z");


  // 10. Error response must be known when transfer completes
  property error_valid;
    @(posedge PCLK)
    disable iff (!PRESETn)
    (PSELx && PENABLE && PREADY)
    |-> !$isunknown(PSLVERR);
  endproperty

  assert property (error_valid)
    else $error("APB ERROR: PSLVERR contains X or Z");

endinterface //apb_if
