module rv32_pipeline_core #(
    parameter logic [31:0] RESET_VECTOR = 32'h00000100,
    // PHASE 9 CHANGE: define the number of words available in the external instruction Block RAM.
    parameter INSTRUCTION_MEMORY_DEPTH_WORDS = 256,
    parameter DATA_MEMORY_DEPTH_WORDS = 256
) (
    input logic clk,
    input logic resetn,
    input logic core_enable,

    // PHASE 9 CHANGE: the instruction now returns from synchronous external Block RAM.
    input logic [31:0] instruction_memory_read_data,

    // PHASE 9 CHANGE: these signals drive the processor-facing port of instruction Block RAM.
    output logic instruction_memory_enable,
    output logic [$clog2(INSTRUCTION_MEMORY_DEPTH_WORDS)-1:0] instruction_memory_address,

    output logic [31:0] pc,
    output logic [31:0] writeback_data,
    output logic register_write_enable,
    output logic pipeline_stalled,
    output logic control_transfer_taken,
    output logic core_fault,
    
    output logic data_memory_write_commit,
    output logic [31:0] data_memory_write_address,
    output logic [31:0] data_memory_write_data,
    output rv32_pkg::memory_size_t data_memory_write_size
);

    import rv32_pkg::*;

    logic [31:0] fetch_next_pc;
    logic [31:0] fetch_pc_plus_4;
    logic fetch_pc_enable;

    // PHASE 9 CHANGE: the request enable is separate from fetch_pc_enable to avoid a fault feedback loop.
    logic fetch_request_enable;

    // PHASE 9 CHANGE: these signals align a synchronous memory response with its original PC.
    logic fetch_instruction_valid;
    logic [31:0] fetch_instruction_pc;
    logic [31:0] fetch_instruction_pc_plus_4;
    logic [31:0] fetch_instruction;
    logic fetch_instruction_address_misaligned;
    logic fetch_instruction_address_out_of_range;

    logic if_id_enable;
    logic if_id_flush;
    logic if_id_valid;
    logic [31:0] if_id_pc;
    logic [31:0] if_id_pc_plus_4;
    logic [31:0] if_id_instruction;

    logic [4:0] decode_rs1_address;
    logic [4:0] decode_rs2_address;
    logic [4:0] decode_rd_address;
    logic [31:0] decode_immediate;

    imm_type_t decode_immediate_type;
    alu_op_t decode_alu_operation;
    alu_a_sel_t decode_alu_a_select;
    alu_b_sel_t decode_alu_b_select;
    writeback_sel_t decode_writeback_select;
    branch_op_t decode_branch_operation;
    jump_op_t decode_jump_operation;
    memory_size_t decode_memory_size;
    special_op_t decode_special_operation;

    logic decode_register_write_enable;
    logic decode_memory_read_enable;
    logic decode_memory_write_enable;
    logic decode_load_unsigned;
    logic decode_illegal_instruction;

    logic [31:0] register_rs1_data;
    logic [31:0] register_rs2_data;
    logic [31:0] decode_rs1_data;
    logic [31:0] decode_rs2_data;

    logic decode_uses_rs1;
    logic decode_uses_rs2;
    logic hazard_stall;

    logic id_ex_enable;
    logic id_ex_flush;
    logic id_ex_valid;
    logic [31:0] id_ex_pc;
    logic [31:0] id_ex_pc_plus_4;
    logic [4:0] id_ex_rs1_address;
    logic [4:0] id_ex_rs2_address;
    logic [4:0] id_ex_rd_address;
    logic [31:0] id_ex_rs1_data;
    logic [31:0] id_ex_rs2_data;
    logic [31:0] id_ex_immediate;
    


    alu_op_t id_ex_alu_operation;
    alu_a_sel_t id_ex_alu_a_select;
    alu_b_sel_t id_ex_alu_b_select;
    writeback_sel_t id_ex_writeback_select;
    branch_op_t id_ex_branch_operation;
    jump_op_t id_ex_jump_operation;
    memory_size_t id_ex_memory_size;
    special_op_t id_ex_special_operation;

    logic id_ex_register_write_enable;
    logic id_ex_memory_read_enable;
    logic id_ex_memory_write_enable;
    logic id_ex_load_unsigned;
    logic id_ex_illegal_instruction;

    forward_sel_t forward_a_select;
    forward_sel_t forward_b_select;

    logic [31:0] ex_mem_forward_data;
    logic [31:0] ex_forwarded_rs1;
    logic [31:0] ex_forwarded_rs2;
    logic [31:0] ex_alu_lhs;
    logic [31:0] ex_alu_rhs;
    logic [31:0] ex_alu_result;
    logic [31:0] ex_pq_result;
    logic [31:0] ex_execute_result;
    logic ex_mem_valid_in;
    logic [31:0] ex_memory_address;
    logic ex_branch_taken;
    logic [31:0] ex_control_transfer_target;
    logic ex_instruction_address_misaligned;

    logic ex_mem_enable;
    logic ex_mem_valid;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_memory_address;
    logic [31:0] ex_mem_store_data;
    logic [31:0] ex_mem_pc_plus_4;
    logic [4:0] ex_mem_rd_address;

    writeback_sel_t ex_mem_writeback_select;
    memory_size_t ex_mem_memory_size;
    special_op_t ex_mem_special_operation;

    logic ex_mem_register_write_enable;
    logic ex_mem_memory_read_enable;
    logic ex_mem_memory_write_enable;
    logic ex_mem_load_unsigned;
    logic ex_mem_illegal_instruction;
    logic ex_mem_instruction_address_misaligned;

    logic memory_read_enable;
    logic memory_write_enable;
    logic [31:0] memory_load_data;
    logic memory_access_misaligned;

    logic mem_wb_enable;
    logic mem_wb_valid;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_load_data;
    logic [31:0] mem_wb_pc_plus_4;
    logic [4:0] mem_wb_rd_address;

    writeback_sel_t mem_wb_writeback_select;
    special_op_t mem_wb_special_operation;

    logic mem_wb_register_write_enable;
    logic mem_wb_illegal_instruction;
    logic mem_wb_instruction_address_misaligned;
    logic mem_wb_memory_access_misaligned;

    logic fault_detected;
    
    // The PQ instruction remains in ID/EX while its internal pipeline is busy.
    logic pq_start;
    logic pq_busy;
    logic pq_stall;
    logic pq_done;
    logic load_use_stall;
    
    assign data_memory_write_commit = memory_write_enable;
    assign data_memory_write_address = ex_mem_memory_address;
    assign data_memory_write_data = ex_mem_store_data;
    assign data_memory_write_size = ex_mem_memory_size;

    assign fetch_pc_plus_4 = pc + 32'd4;

    always_comb begin
        if (control_transfer_taken)
            fetch_next_pc = ex_control_transfer_target;
        else
            fetch_next_pc = fetch_pc_plus_4;
    end

    rv32_pc #(
        .RESET_VECTOR(RESET_VECTOR)
    ) pc_register (
        .clk(clk),
        .resetn(resetn),
        .pc_enable(fetch_pc_enable),
        .next_pc(fetch_next_pc),

        .pc(pc)
    );

    // PHASE 9 CHANGE: convert the byte-addressed PC into a Block RAM word address and retain its metadata.
    rv32_instruction_fetch #(
        .RESET_VECTOR(RESET_VECTOR),
        .INSTRUCTION_MEMORY_DEPTH_WORDS(INSTRUCTION_MEMORY_DEPTH_WORDS)
    ) instruction_fetch (
        .clk(clk),
        .resetn(resetn),
        .fetch_enable(fetch_request_enable),
        .flush(if_id_flush),

        .pc(pc),
        .pc_plus_4(fetch_pc_plus_4),

        .instruction_memory_read_data(instruction_memory_read_data),

        .instruction_memory_enable(instruction_memory_enable),
        .instruction_memory_address(instruction_memory_address),

        .valid_out(fetch_instruction_valid),
        .pc_out(fetch_instruction_pc),
        .pc_plus_4_out(fetch_instruction_pc_plus_4),
        .instruction_out(fetch_instruction),

        .instruction_address_misaligned(fetch_instruction_address_misaligned),
        .instruction_address_out_of_range(fetch_instruction_address_out_of_range)
    );

    rv32_if_id_reg if_id_register (
        .clk(clk),
        .resetn(resetn),
        .enable(if_id_enable),
        .flush(if_id_flush),

        // PHASE 9 CHANGE: IF/ID now receives the response and PC aligned by the fetch controller.
        .valid_in(fetch_instruction_valid),
        .pc_in(fetch_instruction_pc),
        .pc_plus_4_in(fetch_instruction_pc_plus_4),
        .instruction_in(fetch_instruction),

        .valid_out(if_id_valid),
        .pc_out(if_id_pc),
        .pc_plus_4_out(if_id_pc_plus_4),
        .instruction_out(if_id_instruction)
    );

    rv32_decode_stage decode_stage (
        .instruction(if_id_instruction),

        .rs1_address(decode_rs1_address),
        .rs2_address(decode_rs2_address),
        .rd_address(decode_rd_address),
        .immediate(decode_immediate),

        .immediate_type(decode_immediate_type),
        .alu_operation(decode_alu_operation),
        .alu_a_select(decode_alu_a_select),
        .alu_b_select(decode_alu_b_select),
        .writeback_select(decode_writeback_select),
        .branch_operation(decode_branch_operation),
        .jump_operation(decode_jump_operation),
        .memory_size(decode_memory_size),
        .special_operation(decode_special_operation),

        .register_write_enable(decode_register_write_enable),
        .memory_read_enable(decode_memory_read_enable),
        .memory_write_enable(decode_memory_write_enable),
        .load_unsigned(decode_load_unsigned),
        .illegal_instruction(decode_illegal_instruction)
    );

    rv32_regfile register_file (
        .clk(clk),
        .rs1_address(decode_rs1_address),
        .rs2_address(decode_rs2_address),

        .rs1_data(register_rs1_data),
        .rs2_data(register_rs2_data),

        .rd_write_enable(register_write_enable),
        .rd_address(mem_wb_rd_address),
        .rd_data(writeback_data)
    );

    // If WB writes a register during the same cycle that ID reads it,
    // use writeback_data directly instead of capturing the old value.
    always_comb begin
        decode_rs1_data = register_rs1_data;
        decode_rs2_data = register_rs2_data;

        if (register_write_enable &&
            (mem_wb_rd_address != 5'd0) &&
            (mem_wb_rd_address == decode_rs1_address))
            decode_rs1_data = writeback_data;

        if (register_write_enable &&
            (mem_wb_rd_address != 5'd0) &&
            (mem_wb_rd_address == decode_rs2_address))
            decode_rs2_data = writeback_data;
    end

    // Determine which register fields are genuinely used by the
    // instruction in IF/ID. This prevents false load-use stalls.
    always_comb begin
        decode_uses_rs1 = 1'b0;
        decode_uses_rs2 = 1'b0;

        if (!decode_illegal_instruction) begin
            case (if_id_instruction[6:0])
                OPCODE_JALR: begin
                    decode_uses_rs1 = 1'b1;
                end

                OPCODE_LOAD: begin
                    decode_uses_rs1 = 1'b1;
                end

                OPCODE_OP_IMM: begin
                    decode_uses_rs1 = 1'b1;
                end

                OPCODE_BRANCH: begin
                    decode_uses_rs1 = 1'b1;
                    decode_uses_rs2 = 1'b1;
                end

                OPCODE_STORE: begin
                    decode_uses_rs1 = 1'b1;
                    decode_uses_rs2 = 1'b1;
                end

                OPCODE_OP: begin
                    decode_uses_rs1 = 1'b1;
                    decode_uses_rs2 = 1'b1;
                end
                
                OPCODE_CUSTOM_0: begin 
                    decode_uses_rs1 = 1'b1;
                    decode_uses_rs2 = 1'b1; 
                end 

                default: begin
                    decode_uses_rs1 = 1'b0;
                    decode_uses_rs2 = 1'b0;
                end
            endcase
        end
    end

    rv32_hazard_unit hazard_unit (
        .if_id_valid(if_id_valid),
        .if_id_uses_rs1(decode_uses_rs1),
        .if_id_uses_rs2(decode_uses_rs2),
        .if_id_rs1_address(decode_rs1_address),
        .if_id_rs2_address(decode_rs2_address),

        .id_ex_valid(id_ex_valid),
        .id_ex_memory_read_enable(id_ex_memory_read_enable),
        .id_ex_rd_address(id_ex_rd_address),

        .pq_stall(pq_stall),

        .load_use_stall(load_use_stall),
        .pipeline_stalled(hazard_stall)
    );

    // PHASE 9 CHANGE: issue a memory request whenever the core runs and no load-use stall holds fetch.
    // This deliberately does not depend on fault_detected because fetch faults feed fault_detected below.
    assign fetch_request_enable = resetn &&
                                  core_enable &&
                                  !core_fault &&
                                  !pipeline_stalled;

    // A taken branch or jump discards the younger instructions,
    // so control transfer takes priority over a detected stall.
    assign pipeline_stalled = resetn &&
                              core_enable &&
                              !core_fault &&
                              hazard_stall &&
                              !control_transfer_taken;

    // Hold the PC during a load-use stall.
    // A taken branch or jump is still allowed to update the PC.
    assign fetch_pc_enable = resetn &&
                             core_enable &&
                             !core_fault &&
                             !fault_detected &&
                             (!pipeline_stalled ||
                             control_transfer_taken);

    // Hold IF/ID so the dependent instruction remains in ID.
    assign if_id_enable = resetn &&
                          core_enable &&
                          !core_fault &&
                          !pipeline_stalled;

    // Taken branches and jumps remove the wrong-path IF instruction.
    assign if_id_flush = control_transfer_taken;

    // A load-use stall inserts a bubble, but a PQ stall holds the PQ
    // instruction in ID/EX until its multi-cycle calculation is complete.
    assign id_ex_flush = load_use_stall ||
                         control_transfer_taken;

    assign id_ex_enable = resetn &&
                          core_enable &&
                          !core_fault &&
                          !pq_stall;

    assign ex_mem_enable = resetn &&
                           core_enable &&
                           !core_fault;

    assign mem_wb_enable = resetn &&
                           core_enable &&
                           !core_fault;

    rv32_id_ex_reg id_ex_register (
        .clk(clk),
        .resetn(resetn),
        .enable(id_ex_enable),
        .flush(id_ex_flush),

        .valid_in(if_id_valid),
        .pc_in(if_id_pc),
        .pc_plus_4_in(if_id_pc_plus_4),

        .rs1_address_in(decode_rs1_address),
        .rs2_address_in(decode_rs2_address),
        .rd_address_in(decode_rd_address),

        .rs1_data_in(decode_rs1_data),
        .rs2_data_in(decode_rs2_data),
        .immediate_in(decode_immediate),

        .alu_operation_in(decode_alu_operation),
        .alu_a_select_in(decode_alu_a_select),
        .alu_b_select_in(decode_alu_b_select),
        .writeback_select_in(decode_writeback_select),
        .branch_operation_in(decode_branch_operation),
        .jump_operation_in(decode_jump_operation),
        .memory_size_in(decode_memory_size),
        .special_operation_in(decode_special_operation),

        .register_write_enable_in(decode_register_write_enable),
        .memory_read_enable_in(decode_memory_read_enable),
        .memory_write_enable_in(decode_memory_write_enable),
        .load_unsigned_in(decode_load_unsigned),
        .illegal_instruction_in(decode_illegal_instruction),

        .valid_out(id_ex_valid),
        .pc_out(id_ex_pc),
        .pc_plus_4_out(id_ex_pc_plus_4),

        .rs1_address_out(id_ex_rs1_address),
        .rs2_address_out(id_ex_rs2_address),
        .rd_address_out(id_ex_rd_address),

        .rs1_data_out(id_ex_rs1_data),
        .rs2_data_out(id_ex_rs2_data),
        .immediate_out(id_ex_immediate),

        .alu_operation_out(id_ex_alu_operation),
        .alu_a_select_out(id_ex_alu_a_select),
        .alu_b_select_out(id_ex_alu_b_select),
        .writeback_select_out(id_ex_writeback_select),
        .branch_operation_out(id_ex_branch_operation),
        .jump_operation_out(id_ex_jump_operation),
        .memory_size_out(id_ex_memory_size),
        .special_operation_out(id_ex_special_operation),

        .register_write_enable_out(id_ex_register_write_enable),
        .memory_read_enable_out(id_ex_memory_read_enable),
        .memory_write_enable_out(id_ex_memory_write_enable),
        .load_unsigned_out(id_ex_load_unsigned),
        .illegal_instruction_out(id_ex_illegal_instruction)
    );

    rv32_forwarding_unit forwarding_unit (
        .id_ex_valid(id_ex_valid),
        .id_ex_rs1_address(id_ex_rs1_address),
        .id_ex_rs2_address(id_ex_rs2_address),

        .ex_mem_valid(ex_mem_valid),
        .ex_mem_register_write_enable(ex_mem_register_write_enable),
        .ex_mem_rd_address(ex_mem_rd_address),
        .ex_mem_writeback_select(ex_mem_writeback_select),

        .mem_wb_valid(mem_wb_valid),
        .mem_wb_register_write_enable(mem_wb_register_write_enable),
        .mem_wb_rd_address(mem_wb_rd_address),

        .forward_a_select(forward_a_select),
        .forward_b_select(forward_b_select)
    );

    // Select the actual value that EX/MEM can forward.
    // Loads are excluded because their final data is not in EX/MEM.
    always_comb begin
        case (ex_mem_writeback_select)
            WB_ALU: ex_mem_forward_data = ex_mem_alu_result;
            WB_PC_PLUS_4: ex_mem_forward_data = ex_mem_pc_plus_4;
            default: ex_mem_forward_data = 32'b0;
        endcase
    end

    // Select the newest available value for each source register.
    always_comb begin
        case (forward_a_select)
            FORWARD_NONE: ex_forwarded_rs1 = id_ex_rs1_data;
            FORWARD_MEM_WB: ex_forwarded_rs1 = writeback_data;
            FORWARD_EX_MEM: ex_forwarded_rs1 = ex_mem_forward_data;
            default: ex_forwarded_rs1 = id_ex_rs1_data;
        endcase

        case (forward_b_select)
            FORWARD_NONE: ex_forwarded_rs2 = id_ex_rs2_data;
            FORWARD_MEM_WB: ex_forwarded_rs2 = writeback_data;
            FORWARD_EX_MEM: ex_forwarded_rs2 = ex_mem_forward_data;
            default: ex_forwarded_rs2 = id_ex_rs2_data;
        endcase
    end

    // After forwarding has corrected the register values, select
    // whether the ALU receives a register, PC, zero or immediate.
    always_comb begin
        case (id_ex_alu_a_select)
            ALU_A_RS1: ex_alu_lhs = ex_forwarded_rs1;
            ALU_A_PC: ex_alu_lhs = id_ex_pc;
            ALU_A_ZERO: ex_alu_lhs = 32'b0;
            default: ex_alu_lhs = 32'b0;
        endcase

        case (id_ex_alu_b_select)
            ALU_B_RS2: ex_alu_rhs = ex_forwarded_rs2;
            ALU_B_IMMEDIATE: ex_alu_rhs = id_ex_immediate;
            default: ex_alu_rhs = 32'b0;
        endcase
    end

    rv32_alu alu (
        .lhs(ex_alu_lhs),
        .rhs(ex_alu_rhs),
        .operation(id_ex_alu_operation),

        .result(ex_alu_result)
    );
    
    // start remains asserted while the PQ instruction is held in ID/EX.
    // The PQ unit accepts it only once while its internal stages are empty.
    assign pq_start = resetn &&
                      core_enable &&
                      !core_fault &&
                      id_ex_valid &&
                      (id_ex_alu_operation == ALU_PQ);

    rv32_pq_unit pq_unit (
        .clk(clk),
        .resetn(resetn),
        .start(pq_start),

        .alpha_values(ex_forwarded_rs1),
        .beta_values(ex_forwarded_rs2),

        .busy(pq_busy),
        .stall(pq_stall),
        .done(pq_done),
        .power_result(ex_pq_result)
    );
    
    // Normal ALU instructions enter EX/MEM immediately. PQ creates EX/MEM
    // bubbles until pq_done marks the pipelined result as valid.
    always_comb begin
        ex_execute_result = ex_alu_result;
        ex_mem_valid_in = id_ex_valid;

        if (id_ex_alu_operation == ALU_PQ) begin
            ex_execute_result = ex_pq_result;
            ex_mem_valid_in = id_ex_valid &&
                              pq_done;
        end
    end

    // Branches must compare the forwarded values rather than stale
    // values originally captured from the register file.
    rv32_branch_unit branch_unit (
        .rs1_data(ex_forwarded_rs1),
        .rs2_data(ex_forwarded_rs2),
        .branch_operation(id_ex_branch_operation),

        .branch_taken(ex_branch_taken)
    );

    // Loads and stores may also depend on a recently calculated
    // base-register value, so the forwarded rs1 value is used.
    rv32_memory_address_adder memory_address_adder (
        .base(ex_forwarded_rs1),
        .offset(id_ex_immediate),

        .address(ex_memory_address)
    );

    // A jump is always taken. A branch is taken only when its
    // comparison condition is true.
    assign control_transfer_taken = resetn &&
                                    core_enable &&
                                    !core_fault &&
                                    id_ex_valid &&
                                    !id_ex_illegal_instruction &&
                                    ((id_ex_jump_operation != JUMP_NONE) ||
                                    ((id_ex_branch_operation != BRANCH_NONE) &&
                                    ex_branch_taken));

    // Branch and JAL targets use the ALU result directly.
    // JALR must clear target bit zero.
    always_comb begin
        if (id_ex_jump_operation == JUMP_JALR)
            ex_control_transfer_target = {
                ex_alu_result[31:1],
                1'b0
            };
        else
            ex_control_transfer_target = ex_alu_result;
    end

    // This RV32I design uses four-byte instruction alignment.
    assign ex_instruction_address_misaligned =
        control_transfer_taken &&
        (ex_control_transfer_target[1:0] != 2'b00);
    
    
    rv32_ex_mem_reg ex_mem_register (
        .clk(clk),
        .resetn(resetn),
        .enable(ex_mem_enable),
        .flush(1'b0),

        .valid_in(ex_mem_valid_in),
        .alu_result_in(ex_execute_result),
        .memory_address_in(ex_memory_address),
        .store_data_in(ex_forwarded_rs2),
        .pc_plus_4_in(id_ex_pc_plus_4),
        .rd_address_in(id_ex_rd_address),

        .writeback_select_in(id_ex_writeback_select),
        .memory_size_in(id_ex_memory_size),
        .special_operation_in(id_ex_special_operation),

        .register_write_enable_in(id_ex_register_write_enable),
        .memory_read_enable_in(id_ex_memory_read_enable),
        .memory_write_enable_in(id_ex_memory_write_enable),
        .load_unsigned_in(id_ex_load_unsigned),
        .illegal_instruction_in(id_ex_illegal_instruction),
        .instruction_address_misaligned_in(
            ex_instruction_address_misaligned
        ),

        .valid_out(ex_mem_valid),
        .alu_result_out(ex_mem_alu_result),
        .memory_address_out(ex_mem_memory_address),
        .store_data_out(ex_mem_store_data),
        .pc_plus_4_out(ex_mem_pc_plus_4),
        .rd_address_out(ex_mem_rd_address),

        .writeback_select_out(ex_mem_writeback_select),
        .memory_size_out(ex_mem_memory_size),
        .special_operation_out(ex_mem_special_operation),

        .register_write_enable_out(
            ex_mem_register_write_enable
        ),
        .memory_read_enable_out(ex_mem_memory_read_enable),
        .memory_write_enable_out(ex_mem_memory_write_enable),
        .load_unsigned_out(ex_mem_load_unsigned),
        .illegal_instruction_out(ex_mem_illegal_instruction),
        .instruction_address_misaligned_out(
            ex_mem_instruction_address_misaligned
        )
    );

    assign memory_read_enable = resetn &&
                                core_enable &&
                                !core_fault &&
                                ex_mem_valid &&
                                !ex_mem_illegal_instruction &&
                                !ex_mem_instruction_address_misaligned &&
                                ex_mem_memory_read_enable;

    assign memory_write_enable = resetn &&
                                 core_enable &&
                                 !core_fault &&
                                 ex_mem_valid &&
                                 !ex_mem_illegal_instruction &&
                                 !ex_mem_instruction_address_misaligned &&
                                 ex_mem_memory_write_enable;

    rv32_memory_stage #(
        .DEPTH_WORDS(DATA_MEMORY_DEPTH_WORDS)
    ) memory_stage (
        .clk(clk),
        .address(ex_mem_memory_address),
        .store_data(ex_mem_store_data),
        .memory_read_enable(memory_read_enable),
        .memory_write_enable(memory_write_enable),
        .memory_size(ex_mem_memory_size),
        .load_unsigned(ex_mem_load_unsigned),

        .load_data(memory_load_data),
        .memory_access_misaligned(memory_access_misaligned)
    );

    rv32_mem_wb_reg mem_wb_register (
        .clk(clk),
        .resetn(resetn),
        .enable(mem_wb_enable),
        .flush(1'b0),

        .valid_in(ex_mem_valid),
        .alu_result_in(ex_mem_alu_result),
        .load_data_in(memory_load_data),
        .pc_plus_4_in(ex_mem_pc_plus_4),
        .rd_address_in(ex_mem_rd_address),

        .writeback_select_in(ex_mem_writeback_select),
        .special_operation_in(ex_mem_special_operation),
        .register_write_enable_in(
            ex_mem_register_write_enable
        ),

        .illegal_instruction_in(ex_mem_illegal_instruction),
        .instruction_address_misaligned_in(
            ex_mem_instruction_address_misaligned
        ),
        .memory_access_misaligned_in(
            memory_access_misaligned
        ),

        .valid_out(mem_wb_valid),
        .alu_result_out(mem_wb_alu_result),
        .load_data_out(mem_wb_load_data),
        .pc_plus_4_out(mem_wb_pc_plus_4),
        .rd_address_out(mem_wb_rd_address),

        .writeback_select_out(mem_wb_writeback_select),
        .special_operation_out(mem_wb_special_operation),
        .register_write_enable_out(
            mem_wb_register_write_enable
        ),

        .illegal_instruction_out(mem_wb_illegal_instruction),
        .instruction_address_misaligned_out(
            mem_wb_instruction_address_misaligned
        ),
        .memory_access_misaligned_out(
            mem_wb_memory_access_misaligned
        )
    );
    

    always_comb begin
        case (mem_wb_writeback_select)
            WB_ALU: writeback_data = mem_wb_alu_result;
            WB_MEMORY: writeback_data = mem_wb_load_data;
            WB_PC_PLUS_4: writeback_data = mem_wb_pc_plus_4;
            default: writeback_data = 32'b0;
        endcase
    end

    assign register_write_enable =
        resetn &&
        core_enable &&
        !core_fault &&
        mem_wb_valid &&
        mem_wb_register_write_enable &&
        !mem_wb_illegal_instruction &&
        !mem_wb_instruction_address_misaligned &&
        !mem_wb_memory_access_misaligned;

    // Ignore an illegal younger instruction when an older taken branch
    // is simultaneously flushing that wrong-path instruction.
    assign fault_detected =
        // PHASE 9 CHANGE: an invalid actual fetch address now becomes a sticky core fault.
        fetch_instruction_address_misaligned ||
        fetch_instruction_address_out_of_range ||
        (if_id_valid &&
        decode_illegal_instruction &&
        !control_transfer_taken) ||
        (id_ex_valid &&
        ex_instruction_address_misaligned) ||
        (ex_mem_valid &&
        memory_access_misaligned);

    // Once a fault is detected, hold the core until reset.
    always_ff @(posedge clk) begin
        if (!resetn)
            core_fault <= 1'b0;
        else if (core_enable && fault_detected)
            core_fault <= 1'b1;
    end

endmodule
