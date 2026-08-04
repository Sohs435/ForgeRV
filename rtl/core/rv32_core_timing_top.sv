module rv32_core_timing_top #(
    parameter logic [31:0] RESET_VECTOR = 32'h00000100,
    parameter DATA_MEMORY_DEPTH_WORDS = 256
) (
    input logic clk,
    input logic resetn,
    input logic core_enable,
    input logic [31:0] instruction,
    input logic [2:0] debug_select,

    output logic [31:0] debug_data,
    output logic [7:0] debug_status
);

    import rv32_pkg::*;

    logic [31:0] pc;
    logic [31:0] next_pc;
    logic [31:0] pc_plus_4;
    logic [31:0] alu_result;
    logic [31:0] load_data;
    logic [31:0] writeback_data;

    logic register_write_enable;
    logic branch_taken;
    logic control_transfer_taken;
    logic illegal_instruction;
    logic instruction_address_misaligned;
    logic memory_access_misaligned;
    logic core_fault;

    imm_type_t immediate_type;
    special_op_t special_operation;

    rv32_core_interconnect #(
        .RESET_VECTOR(RESET_VECTOR),
        .DATA_MEMORY_DEPTH_WORDS(DATA_MEMORY_DEPTH_WORDS)
    ) core_interconnect (
        .clk(clk),
        .resetn(resetn),
        .core_enable(core_enable),
        .instruction(instruction),

        .pc(pc),
        .next_pc(next_pc),
        .pc_plus_4(pc_plus_4),
        .alu_result(alu_result),
        .load_data(load_data),
        .writeback_data(writeback_data),

        .register_write_enable(register_write_enable),
        .branch_taken(branch_taken),
        .control_transfer_taken(control_transfer_taken),
        .illegal_instruction(illegal_instruction),
        .instruction_address_misaligned(instruction_address_misaligned),
        .memory_access_misaligned(memory_access_misaligned),
        .core_fault(core_fault),

        .immediate_type(immediate_type),
        .special_operation(special_operation)
    );

    always_comb begin
        case (debug_select)
            3'd0: debug_data = pc;
            3'd1: debug_data = next_pc;
            3'd2: debug_data = pc_plus_4;
            3'd3: debug_data = alu_result;
            3'd4: debug_data = load_data;
            3'd5: debug_data = writeback_data;
            3'd6: debug_data = {29'b0, immediate_type};
            3'd7: debug_data = {30'b0, special_operation};
            default: debug_data = 32'b0;
        endcase
    end

    assign debug_status = {
        core_enable,
        core_fault,
        memory_access_misaligned,
        instruction_address_misaligned,
        illegal_instruction,
        control_transfer_taken,
        branch_taken,
        register_write_enable
    };

endmodule