# APB Memory

## Overview
This project implements and verifies an **AMBA APB (Advanced Peripheral Bus) slave interface** with a 64 KB memory space. The design follows the standard APB protocol with IDLE, SETUP, and ACCESS phases, and has been verified using a SystemVerilog testbench with functional coverage, assertions, and directed/random tests.

---

## Features
- **Protocol**: AMBA APB (2-cycle minimum transfer)
- **Memory**: 64 KB total capacity (65,536 bytes)
- **Data Bus Width**: 64-bit (PWDATA / PRDATA)
- **Address Bus**: 32-bit (parameterizable base address)
- **Endianness**: Little-endian
- **Alignment**: 8-byte aligned
- **Error Conditions**:
  - Address outside 64 KB window
  - Misaligned access
- **Throughput**: One request per APB transfer, no outstanding transactions
- **Reset**: Active-low asynchronous (`PRESETn`)
- **Strobe Support**: Byte-enable writes via `PSTRB[7:0]`

---

## Microarchitecture
![Microarchitecture](img/uArch.png)

The slave design is implemented using a **Mealy FSM** with the following states:
- **IDLE**
- **SETUP**
- **ACCESS**

![Microarchitecture](img/fsm.png)

Key signals:
- `PSELx`, `PENABLE`, `PWRITE`, `PREADY`, `PSLVERR`
- `PWDATA`, `PRDATA`, `PADDR`
- Internal handshake with `req`, `we`, and `rdata_valid`

---

## Operations
### Write
1. **SETUP**: `PSEL=1`, `PENABLE=0`, `PWRITE=1`
2. **ACCESS**: `PENABLE=1`; slave asserts `PREADY` once `rdata_valid=1`
3. Write occurs with byte enables applied (`PSTRB`)
4. Transfer completes when `PREADY=1`

### Read
1. **SETUP**: `PSEL=1`, `PENABLE=0`, `PWRITE=0`
2. **ACCESS**: `PENABLE=1`; slave asserts `PREADY` once `rdata_valid=1`
3. Transfer completes when `PREADY=1`

---