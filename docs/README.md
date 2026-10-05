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
<img width="346" height="292" alt="image" src="https://github.com/user-attachments/assets/30f9e886-ff95-42c3-a210-dc5715f38944" />


The slave design is implemented using a **Mealy FSM** with the following states:
- **IDLE**
- **SETUP**
- **ACCESS**

<img width="531" height="283" alt="image" src="https://github.com/user-attachments/assets/5d844906-f595-4f40-b960-46bce242b664" />


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
