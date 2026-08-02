module rv32_branch_unit (
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    input rv32_pkg::branch_op_t branch_operation,

    output logic branch_taken
);

    import rv32_pkg::*; 
    always_comb begin 
        case(branch_operation) 
            BRANCH_NONE: branch_taken = 1'b0;
            BRANCH_EQ: branch_taken = (rs1_data == rs2_data);
            BRANCH_NE: branch_taken = (rs1_data != rs2_data);
            BRANCH_LT: branch_taken = ($signed(rs1_data) < $signed(rs2_data));
            BRANCH_GE: branch_taken = ($signed(rs1_data) >= $signed(rs2_data));
            BRANCH_LTU: branch_taken = (rs1_data < rs2_data);
            BRANCH_GEU: branch_taken = (rs1_data >= rs2_data);
            default: branch_taken = 1'b0;
        endcase 
    end 
    
endmodule 