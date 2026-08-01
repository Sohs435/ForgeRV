module rv32_regfile (
    input logic clk,
    input logic [4:0] rs1_address,
    input logic [4:0] rs2_address, 
    
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data, 
    
    input logic rd_write_enable,
    input logic [4:0] rd_address,
    input logic [31:0] rd_data
);

logic [31:0] registers [0:31]; 
assign rs1_data = (rs1_address == 5'd0) ? 32'b0: registers[rs1_address];
assign rs2_data = (rs2_address == 5'd0) ? 32'b0: registers[rs2_address]; 

always_ff @ (posedge clk) begin 
    if (rd_write_enable && (rd_address != 5'd0))
        registers[rd_address] <= rd_data;  
end 

endmodule 