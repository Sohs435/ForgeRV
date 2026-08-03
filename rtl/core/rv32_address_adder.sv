module rv32_address_adder (
    input logic [31:0] base, 
    input logic [31:0] offset, 
    
    (* max_fanout = 32 *) output logic [31:0] address 
    // were essentially telling vivado that one address driver should not drive more than 
    // approx 32 loads 
    );
    
    assign address = base + offset; 
endmodule 