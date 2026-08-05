module rv32_if_id_reg (
    input logic clk, 
    input logic resetn, 
    input logic enable, 
    input logic flush, 
    
    input logic valid_in,
    input logic [31:0] pc_in,
    input logic [31:0] pc_plus_4_in, 
    input logic [31:0] instruction_in, 
    
    output logic valid_out,
    output logic [31:0] pc_out, 
    output logic [31:0] pc_plus_4_out, 
    output logic [31:0] instruction_out 
);

    always_ff @(posedge clk) begin 
        if (!resetn || flush) begin 
            valid_out <= 1'b0;
            pc_out <= 32'b0;
            pc_plus_4_out <= 32'b0;
            instruction_out <= 32'b0;
        end
        else if (enable) begin 
            valid_out <= valid_in;
            pc_out <= pc_in;
            pc_plus_4_out <= pc_plus_4_in;
            instruction_out <= instruction_in;
        end 
    end 

endmodule