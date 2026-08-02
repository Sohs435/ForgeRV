module rv32_next_pc (
    input logic [31:0] pc,
    input logic [31:0] alu_result,
    input logic branch_taken,
    input rv32_pkg::jump_op_t jump_operation,
    
    output logic [31:0] next_pc,
    output logic [31:0] pc_plus_4,
    output logic control_transfer_taken,
    output logic instruction_address_misaligned
);

    import rv32_pkg::*;

    always_comb begin
        pc_plus_4 = pc + 32'd4;

        control_transfer_taken = branch_taken || (jump_operation == JUMP_JAL) || (jump_operation == JUMP_JALR);

        if (control_transfer_taken) next_pc = alu_result;
        else next_pc = pc_plus_4;

        if (jump_operation == JUMP_JALR) next_pc[0] = 1'b0;

        instruction_address_misaligned = control_transfer_taken && (next_pc[1:0] != 2'b00);
    end

endmodule