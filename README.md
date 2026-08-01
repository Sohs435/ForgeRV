# RISC-V FPGA CPU

A custom RISC-V processor implemented in SystemVerilog for the PYNQ-Z2 FPGA.

The final architecture and specialized use case are currently being defined.

ForgeRV will be a custom 32-bit RISC-V processor and small SoC implemented from scratch
on the PYNQ-Z2 development board in Verilog, SystemVerilog, Python and C. 

|Area|Planned Feature|
|---|---|
|ISA| RV32IMC|
|Pipeline| Five-stage, single-issue, in-order |
|Memory| BRAM/TCM initially, caches later on |
|Arithmetic| Harware Multiplication and Division |
|System| CSRs, exceptions and interrupts | 


