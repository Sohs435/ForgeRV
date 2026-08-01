# ForgeRV Architecture

## Initial Target

- 32-bit RISC-V processor
- RV32I instruction set
- SystemVerilog implementation
- Bare-metal assembly programs
- PYNQ-Z2 FPGA target
- Single-issue, in-order execution
- Five-stage pipeline in the final implementation

## Initial CPU Rules

- Registers are 32 bits wide
- There are 32 integer registers
- Register `x0` is permanently zero
- Instructions are initially 32 bits wide
- Memory is byte-addressed
- The system is little-endian
- The reset program counter is `0x00000000`
- The initial version does not support compressed instructions
- The initial version does not support multiplication or division

## Development Strategy

1. Test individual datapath components
2. Construct a basic non-pipelined RV32I processor
3. Verify complete RV32I instruction execution
4. Convert the processor into a five-stage pipeline
5. Add hazards, forwarding, exceptions and interrupts
6. Integrate the processor onto the PYNQ-Z2
7. Add the XForge accelerator extension