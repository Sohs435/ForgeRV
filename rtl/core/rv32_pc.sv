module rv32_pc #(
    parameter [31:0] RESET_VECTOR = 32'h00000000
) (
    input logic clk,
    input logic resetn,
    input logic pc_enable,
    input logic [31:0] next_pc,

    output logic [31:0] pc
);

    always_ff @ (posedge clk) begin 
        if (!resetn) begin 
            pc <= RESET_VECTOR; 
        end 
        else if (pc_enable) begin 
            pc <= next_pc; 
        end 
    end 

endmodule 