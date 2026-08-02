// just connection of the decoder and immediate generator 
module rv32_decode_stage (
    input logic [31:0] instruction,

    output logic [4:0] rs1_address,
    output logic [4:0] rs2_address,
    output logic [4:0] rd_address,
    output logic [31:0] immediate,

    output rv32_pkg::imm_type_t immediate_type,
    output rv32_pkg::alu_op_t alu_operation,
    output rv32_pkg::alu_a_sel_t alu_a_select,
    output rv32_pkg::alu_b_sel_t alu_b_select,
    output rv32_pkg::writeback_sel_t writeback_select,
    output rv32_pkg::branch_op_t branch_operation,
    output rv32_pkg::jump_op_t jump_operation,
    output rv32_pkg::memory_size_t memory_size,
    output rv32_pkg::special_op_t special_operation,

    output logic register_write_enable,
    output logic memory_read_enable,
    output logic memory_write_enable,
    output logic load_unsigned,
    output logic illegal_instruction
);

    assign rs1_address = instruction[19:15];
    assign rs2_address = instruction[24:20];
    assign rd_address = instruction[11:7];

    rv32_decoder decoder (
        .instruction(instruction),
        .immediate_type(immediate_type),
        .alu_operation(alu_operation),
        .alu_a_select(alu_a_select),
        .alu_b_select(alu_b_select),
        .writeback_select(writeback_select),
        .branch_operation(branch_operation),
        .jump_operation(jump_operation),
        .memory_size(memory_size),
        .special_operation(special_operation),
        .register_write_enable(register_write_enable),
        .memory_read_enable(memory_read_enable),
        .memory_write_enable(memory_write_enable),
        .load_unsigned(load_unsigned),
        .illegal_instruction(illegal_instruction)
    );

    rv32_imm_gen immediate_generator (
        .instruction(instruction),
        .immediate_type(immediate_type),
        .immediate(immediate)
    );

endmodule