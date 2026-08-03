module rv32_core_interconnect #(
    parameter logic [31:0] RESET_VECTOR = 32'h00000000,
    parameter DATA_MEMORY_DEPTH_WORDS = 1024
) (
    input logic clk,
    input logic resetn,
    input logic core_enable,
    input logic [31:0] instruction,

    output logic [31:0] pc,
    output logic [31:0] next_pc,
    output logic [31:0] pc_plus_4,
    output logic [31:0] alu_result,
    output logic [31:0] load_data,
    output logic [31:0] writeback_data,

    output logic register_write_enable,
    output logic branch_taken,
    output logic control_transfer_taken,
    output logic illegal_instruction,
    output logic instruction_address_misaligned,
    output logic memory_access_misaligned,
    output logic core_fault,

    output rv32_pkg::imm_type_t immediate_type,
    output rv32_pkg::special_op_t special_operation
);

    import rv32_pkg::*;

    logic [4:0] rs1_address;
    logic [4:0] rs2_address;
    logic [4:0] rd_address;

    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] immediate;

    alu_op_t alu_operation;
    alu_a_sel_t alu_a_select;
    alu_b_sel_t alu_b_select;
    writeback_sel_t writeback_select;
    branch_op_t branch_operation;
    jump_op_t jump_operation;
    memory_size_t memory_size;

    logic decoded_register_write_enable;
    logic memory_read_enable;
    logic memory_write_enable;
    logic load_unsigned;

    logic safe_memory_read_enable;
    logic safe_memory_write_enable;
    logic safe_pc_enable;

    logic [31:0] alu_lhs;
    logic [31:0] alu_rhs;
    logic [31:0] memory_address_result; 

    rv32_decode_stage decode_stage (
        .instruction(instruction),

        .rs1_address(rs1_address),
        .rs2_address(rs2_address),
        .rd_address(rd_address),
        .immediate(immediate),

        .immediate_type(immediate_type),
        .alu_operation(alu_operation),
        .alu_a_select(alu_a_select),
        .alu_b_select(alu_b_select),
        .writeback_select(writeback_select),
        .branch_operation(branch_operation),
        .jump_operation(jump_operation),
        .memory_size(memory_size),
        .special_operation(special_operation),

        .register_write_enable(decoded_register_write_enable),
        .memory_read_enable(memory_read_enable),
        .memory_write_enable(memory_write_enable),
        .load_unsigned(load_unsigned),
        .illegal_instruction(illegal_instruction)
    );

    rv32_regfile register_file (
        .clk(clk),
        .rs1_address(rs1_address),
        .rs2_address(rs2_address),

        .rs1_data(rs1_data),
        .rs2_data(rs2_data),

        .rd_write_enable(register_write_enable),
        .rd_address(rd_address),
        .rd_data(writeback_data)
    );
    
    (* keep_hierarchy = "yes" *) rv32_address_adder load_store_address_adder (
    .base(rs1_data),
    .offset(immediate),

    .address(memory_address_result)
    );

    always_comb begin // choose lhs value (rs1, pc, 0)
        case (alu_a_select)
            ALU_A_RS1: alu_lhs = rs1_data;
            ALU_A_PC: alu_lhs = pc;
            ALU_A_ZERO: alu_lhs = 32'b0;
            default: alu_lhs = 32'b0;
        endcase

        case (alu_b_select) // choose rhs value (rs2 or immediate)
            ALU_B_RS2: alu_rhs = rs2_data;
            ALU_B_IMMEDIATE: alu_rhs = immediate;
            default: alu_rhs = 32'b0;
        endcase
    end

    rv32_alu alu (
        .lhs(alu_lhs),
        .rhs(alu_rhs),
        .operation(alu_operation),

        .result(alu_result)
    );

    rv32_memory_stage #(
        .DEPTH_WORDS(DATA_MEMORY_DEPTH_WORDS)
    ) memory_stage (
        .clk(clk),
        .address(memory_address_result),
        .store_data(rs2_data),
        .memory_read_enable(safe_memory_read_enable),
        .memory_write_enable(safe_memory_write_enable),
        .memory_size(memory_size),
        .load_unsigned(load_unsigned),

        .load_data(load_data),
        .memory_access_misaligned(memory_access_misaligned)
    );

    rv32_control_flow #(
        .RESET_VECTOR(RESET_VECTOR)
    ) control_flow (
        .clk(clk),
        .resetn(resetn),
        .pc_enable(safe_pc_enable),

        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .alu_result(alu_result),

        .branch_operation(branch_operation),
        .jump_operation(jump_operation),

        .pc(pc),
        .next_pc(next_pc),
        .pc_plus_4(pc_plus_4),
        .branch_taken(branch_taken),
        .control_transfer_taken(control_transfer_taken),
        .instruction_address_misaligned(
            instruction_address_misaligned
        )
    );

    always_comb begin //write back data is either ALU result, loaded data , or PC result
        case (writeback_select)
            WB_ALU: writeback_data = alu_result;
            WB_MEMORY: writeback_data = load_data;
            WB_PC_PLUS_4: writeback_data = pc_plus_4;
            default: writeback_data = 32'b0;
        endcase
    end
    
    // resetn cannot be active (low), general core enable has to be high (in case of multicore system with some cores on and off at different times)
    // instruction has to legal, and the read enable has to be high 
    assign safe_memory_read_enable = resetn && 
                                     core_enable &&
                                     !illegal_instruction &&
                                     memory_read_enable;
    // same logic as above but for write 
    assign safe_memory_write_enable = resetn &&
                                      core_enable &&
                                      !illegal_instruction &&
                                      memory_write_enable;
                                      
    //clear operational fail when a bogus strobe or shift (memory misaligned)
    // or an illegal instruction (opcode, func 3, func7 is bogus)
    // or when control transfer taken with pc not a multiple of 4 
    assign core_fault = resetn &&
                        core_enable &&
                        (illegal_instruction ||
                        instruction_address_misaligned ||
                        memory_access_misaligned);
    
    //same logic as read and write enable 
    assign register_write_enable = resetn &&
                                   core_enable &&
                                   decoded_register_write_enable &&
                                   !core_fault;
    // same logic as above
    assign safe_pc_enable = resetn &&
                            core_enable &&
                            !core_fault;

endmodule