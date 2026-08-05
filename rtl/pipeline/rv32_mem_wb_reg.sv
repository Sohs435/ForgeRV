module rv32_mem_wb_reg (
    input logic clk,
    input logic resetn,
    input logic enable,
    input logic flush,

    input logic valid_in,
    input logic [31:0] alu_result_in,
    input logic [31:0] load_data_in,
    input logic [31:0] pc_plus_4_in,
    input logic [4:0] rd_address_in,

    input rv32_pkg::writeback_sel_t writeback_select_in,
    input rv32_pkg::special_op_t special_operation_in,

    input logic register_write_enable_in,
    input logic illegal_instruction_in,
    input logic instruction_address_misaligned_in,
    input logic memory_access_misaligned_in,

    output logic valid_out,
    output logic [31:0] alu_result_out,
    output logic [31:0] load_data_out,
    output logic [31:0] pc_plus_4_out,
    output logic [4:0] rd_address_out,

    output rv32_pkg::writeback_sel_t writeback_select_out,
    output rv32_pkg::special_op_t special_operation_out,

    output logic register_write_enable_out,
    output logic illegal_instruction_out,
    output logic instruction_address_misaligned_out,
    output logic memory_access_misaligned_out
);

    import rv32_pkg::*;

    always_ff @(posedge clk) begin
        if (!resetn || flush) begin
            valid_out <= 1'b0;
            alu_result_out <= 32'b0;
            load_data_out <= 32'b0;
            pc_plus_4_out <= 32'b0;
            rd_address_out <= 5'b0;

            writeback_select_out <= WB_NONE;
            special_operation_out <= SPECIAL_NONE;

            register_write_enable_out <= 1'b0;
            illegal_instruction_out <= 1'b0;
            instruction_address_misaligned_out <= 1'b0;
            memory_access_misaligned_out <= 1'b0;
        end
        else if (enable) begin
            valid_out <= valid_in;
            alu_result_out <= alu_result_in;
            load_data_out <= load_data_in;
            pc_plus_4_out <= pc_plus_4_in;
            rd_address_out <= rd_address_in;

            writeback_select_out <= writeback_select_in;
            special_operation_out <= special_operation_in;

            register_write_enable_out <= register_write_enable_in;
            illegal_instruction_out <= illegal_instruction_in;
            instruction_address_misaligned_out <= instruction_address_misaligned_in;
            memory_access_misaligned_out <= memory_access_misaligned_in;
        end
    end

endmodule