module rv32_address_adder (
    input logic [31:0] base, 
    input logic [31:0] offset, 
    
    output logic [31:0] address
    );
    
    assign address = base + offset; 
endmodule 