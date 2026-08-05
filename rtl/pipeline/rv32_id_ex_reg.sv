module rv32_id_ex_reg (
    input logic clk,
    input logic resetn,
    input logic enable,
    input logic flush,

    input logic valid_in,
    input logic [31:0] pc_in,
    input logic [31:0] pc_plus_4_in,

    input logic [4:0] rs1_address_in,
    input logic [4:0] rs2_address_in,
    input logic [4:0] rd_address_in,
    input logic [31:0] rs1_data_in,
    input logic [31:0] rs2_data_in,
    input logic [31:0] immediate_in,

    input rv32_pkg::alu_op_t alu_operation_in,
    input rv32_pkg::alu_a_sel_t alu_a_select_in,
    input rv32_pkg::alu_b_sel_t alu_b_select_in,
    input rv32_pkg::writeback_sel_t writeback_select_in,
    input rv32_pkg::branch_op_t branch_operation_in,
    input rv32_pkg::jump_op_t jump_operation_in,
    input rv32_pkg::memory_size_t memory_size_in,
    input rv32_pkg::special_op_t special_operation_in,

    input logic register_write_enable_in,
    input logic memory_read_enable_in,
    input logic memory_write_enable_in,
    input logic load_unsigned_in,
    input logic illegal_instruction_in,

    output logic valid_out,
    output logic [31:0] pc_out,
    output logic [31:0] pc_plus_4_out,

    output logic [4:0] rs1_address_out,
    output logic [4:0] rs2_address_out,
    output logic [4:0] rd_address_out,
    output logic [31:0] rs1_data_out,
    output logic [31:0] rs2_data_out,
    output logic [31:0] immediate_out,

    output rv32_pkg::alu_op_t alu_operation_out,
    output rv32_pkg::alu_a_sel_t alu_a_select_out,
    output rv32_pkg::alu_b_sel_t alu_b_select_out,
    output rv32_pkg::writeback_sel_t writeback_select_out,
    output rv32_pkg::branch_op_t branch_operation_out,
    output rv32_pkg::jump_op_t jump_operation_out,
    output rv32_pkg::memory_size_t memory_size_out,
    output rv32_pkg::special_op_t special_operation_out,

    output logic register_write_enable_out,
    output logic memory_read_enable_out,
    output logic memory_write_enable_out,
    output logic load_unsigned_out,
    output logic illegal_instruction_out
);

    import rv32_pkg::*;

    always_ff @(posedge clk) begin
        if (!resetn || flush) begin
            valid_out <= 1'b0;
            pc_out <= 32'b0;
            pc_plus_4_out <= 32'b0;

            rs1_address_out <= 5'b0;
            rs2_address_out <= 5'b0;
            rd_address_out <= 5'b0;
            rs1_data_out <= 32'b0;
            rs2_data_out <= 32'b0;
            immediate_out <= 32'b0;

            alu_operation_out <= ALU_ADD;
            alu_a_select_out <= ALU_A_RS1;
            alu_b_select_out <= ALU_B_RS2;
            writeback_select_out <= WB_NONE;
            branch_operation_out <= BRANCH_NONE;
            jump_operation_out <= JUMP_NONE;
            memory_size_out <= MEMORY_NONE;
            special_operation_out <= SPECIAL_NONE;

            register_write_enable_out <= 1'b0;
            memory_read_enable_out <= 1'b0;
            memory_write_enable_out <= 1'b0;
            load_unsigned_out <= 1'b0;
            illegal_instruction_out <= 1'b0;
        end
        else if (enable) begin
            valid_out <= valid_in;
            pc_out <= pc_in;
            pc_plus_4_out <= pc_plus_4_in;

            rs1_address_out <= rs1_address_in;
            rs2_address_out <= rs2_address_in;
            rd_address_out <= rd_address_in;
            rs1_data_out <= rs1_data_in;
            rs2_data_out <= rs2_data_in;
            immediate_out <= immediate_in;

            alu_operation_out <= alu_operation_in;
            alu_a_select_out <= alu_a_select_in;
            alu_b_select_out <= alu_b_select_in;
            writeback_select_out <= writeback_select_in;
            branch_operation_out <= branch_operation_in;
            jump_operation_out <= jump_operation_in;
            memory_size_out <= memory_size_in;
            special_operation_out <= special_operation_in;

            register_write_enable_out <= register_write_enable_in;
            memory_read_enable_out <= memory_read_enable_in;
            memory_write_enable_out <= memory_write_enable_in;
            load_unsigned_out <= load_unsigned_in;
            illegal_instruction_out <= illegal_instruction_in;
        end
    end

endmodule