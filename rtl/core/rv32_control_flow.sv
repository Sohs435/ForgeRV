module rv32_control_flow #(
    parameter logic [31:0] RESET_VECTOR = 32'h00000000
) (
    input logic clk,
    input logic resetn,
    input logic pc_enable,

    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    input logic [31:0] alu_result,

    input rv32_pkg::branch_op_t branch_operation,
    input rv32_pkg::jump_op_t jump_operation,

    output logic [31:0] pc,
    output logic [31:0] next_pc,
    output logic [31:0] pc_plus_4,
    output logic branch_taken,
    output logic control_transfer_taken,
    output logic instruction_address_misaligned
);

    rv32_pc #(
        .RESET_VECTOR(RESET_VECTOR)
    ) pc_register (
        .clk(clk),
        .resetn(resetn),
        .pc_enable(pc_enable),
        .next_pc(next_pc),
        .pc(pc)
    );

    rv32_branch_unit branch_unit (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .branch_operation(branch_operation),
        .branch_taken(branch_taken)
    );

    rv32_next_pc next_pc_selector (
        .pc(pc),
        .alu_result(alu_result),
        .branch_taken(branch_taken),
        .jump_operation(jump_operation),
        .next_pc(next_pc),
        .pc_plus_4(pc_plus_4),
        .control_transfer_taken(control_transfer_taken),
        .instruction_address_misaligned(instruction_address_misaligned)
    );

endmodule