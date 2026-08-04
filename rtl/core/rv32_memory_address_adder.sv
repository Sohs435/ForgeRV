module rv32_memory_address_adder (
    input logic [31:0] base, 
    input logic [31:0] offset,
    output logic [9:0] address
);
    
    assign address = base[9:0] + offset[9:0]; 
    
endmodule 