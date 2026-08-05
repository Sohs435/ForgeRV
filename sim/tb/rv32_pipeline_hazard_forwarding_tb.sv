`timescale 1ns/1ps

module rv32_pipeline_hazard_forwarding_tb;

    import rv32_pkg::*;

    localparam logic [31:0] RESET_VECTOR = 32'h00000100;
    localparam DATA_MEMORY_DEPTH_WORDS = 256;
    localparam PROGRAM_WORDS = 128;
    localparam NOP = 32'h00000013;

    logic clk;
    logic resetn;
    logic core_enable;
    logic [31:0] instruction;

    logic [31:0] pc;
    logic [31:0] writeback_data;
    logic register_write_enable;
    logic pipeline_stalled;
    logic control_transfer_taken;
    logic core_fault;

    logic [31:0] instruction_memory [0:PROGRAM_WORDS-1];
    logic [31:0] observed_registers [0:31];
    logic [31:0] instruction_index;

    integer test_count;
    integer failure_count;
    integer stall_count;
    integer control_transfer_count;
    integer register_commit_count;
    integer ex_mem_forward_count;
    integer mem_wb_forward_count;
    integer dual_forward_count;
    integer stall_control_failures;

    logic [31:0] held_pc;
    logic [31:0] held_if_id_instruction;

    rv32_pipeline_core #(
        .RESET_VECTOR(RESET_VECTOR),
        .DATA_MEMORY_DEPTH_WORDS(DATA_MEMORY_DEPTH_WORDS)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .core_enable(core_enable),
        .instruction(instruction),

        .pc(pc),
        .writeback_data(writeback_data),
        .register_write_enable(register_write_enable),
        .pipeline_stalled(pipeline_stalled),
        .control_transfer_taken(control_transfer_taken),
        .core_fault(core_fault)
    );

    always #4 clk = ~clk;

    always_comb begin
        instruction_index = (pc - RESET_VECTOR) >> 2;
        instruction = NOP;

        if ((pc >= RESET_VECTOR) &&
            (instruction_index < PROGRAM_WORDS))
            instruction = instruction_memory[instruction_index];
    end

    function automatic logic [31:0] encode_addi (
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );

        encode_addi = {
            immediate[11:0],
            rs1,
            3'b000,
            rd,
            OPCODE_OP_IMM
        };

    endfunction

    function automatic logic [31:0] encode_add (
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2
    );

        encode_add = {
            FUNCT7_NORMAL,
            rs2,
            rs1,
            3'b000,
            rd,
            OPCODE_OP
        };

    endfunction

    function automatic logic [31:0] encode_sub (
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2
    );

        encode_sub = {
            FUNCT7_SUB_SRA,
            rs2,
            rs1,
            3'b000,
            rd,
            OPCODE_OP
        };

    endfunction

    function automatic logic [31:0] encode_lw (
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );

        encode_lw = {
            immediate[11:0],
            rs1,
            3'b010,
            rd,
            OPCODE_LOAD
        };

    endfunction

    function automatic logic [31:0] encode_sw (
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );

        encode_sw = {
            immediate[11:5],
            rs2,
            rs1,
            3'b010,
            immediate[4:0],
            OPCODE_STORE
        };

    endfunction

    function automatic logic [31:0] encode_branch (
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] immediate
    );

        encode_branch = {
            immediate[12],
            immediate[10:5],
            rs2,
            rs1,
            funct3,
            immediate[4:1],
            immediate[11],
            OPCODE_BRANCH
        };

    endfunction

    function automatic logic [31:0] encode_jal (
        input logic [4:0] rd,
        input logic signed [31:0] immediate
    );

        encode_jal = {
            immediate[20],
            immediate[10:1],
            immediate[11],
            immediate[19:12],
            rd,
            OPCODE_JAL
        };

    endfunction

    task automatic check_value (
        input string test_name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );

        begin
            test_count = test_count + 1;

            if (actual === expected)
                $display(
                    "PASS: %s value=%08h",
                    test_name,
                    actual
                );
            else begin
                failure_count = failure_count + 1;

                $display(
                    "FAIL: %s expected=%08h actual=%08h",
                    test_name,
                    expected,
                    actual
                );
            end
        end

    endtask

    task automatic check_condition (
        input string test_name,
        input logic condition
    );

        begin
            test_count = test_count + 1;

            if (condition)
                $display("PASS: %s", test_name);
            else begin
                failure_count = failure_count + 1;
                $display("FAIL: %s", test_name);
            end
        end

    endtask

    // Record every architectural writeback so the testbench can
    // inspect final register values without directly modifying the DUT.
    always_ff @(posedge clk) begin
        if (!resetn) begin
            stall_count <= 0;
            control_transfer_count <= 0;
            register_commit_count <= 0;
            ex_mem_forward_count <= 0;
            mem_wb_forward_count <= 0;
            dual_forward_count <= 0;

            for (int i = 0; i < 32; i = i + 1)
                observed_registers[i] <= 32'b0;
        end
        else if (core_enable) begin
            // Ignore writes to x0 because x0 always remains zero.
            if (register_write_enable &&
                (dut.mem_wb_rd_address != 5'd0)) begin
                observed_registers[dut.mem_wb_rd_address]
                    <= writeback_data;

                register_commit_count
                    <= register_commit_count + 1;
            end

            if (pipeline_stalled)
                stall_count <= stall_count + 1;

            if (control_transfer_taken)
                control_transfer_count
                    <= control_transfer_count + 1;

            if ((dut.forward_a_select == FORWARD_EX_MEM) ||
                (dut.forward_b_select == FORWARD_EX_MEM))
                ex_mem_forward_count
                    <= ex_mem_forward_count + 1;

            if ((dut.forward_a_select == FORWARD_MEM_WB) ||
                (dut.forward_b_select == FORWARD_MEM_WB))
                mem_wb_forward_count
                    <= mem_wb_forward_count + 1;

            if (((dut.forward_a_select == FORWARD_EX_MEM) &&
                (dut.forward_b_select == FORWARD_MEM_WB)) ||
                ((dut.forward_a_select == FORWARD_MEM_WB) &&
                (dut.forward_b_select == FORWARD_EX_MEM)))
                dual_forward_count
                    <= dual_forward_count + 1;
        end
    end

    // Whenever the hazard unit requests a stall, verify that:
    // 1. The PC is held
    // 2. IF/ID is held
    // 3. ID/EX is changed into a bubble
    always @(posedge clk) begin
        if (resetn && core_enable && pipeline_stalled) begin
            held_pc = pc;
            held_if_id_instruction = dut.if_id_instruction;

            #1;

            if (pc !== held_pc) begin
                stall_control_failures =
                    stall_control_failures + 1;

                $display(
                    "FAIL: PC changed during load-use stall"
                );
            end

            if (dut.if_id_instruction !==
                held_if_id_instruction) begin
                stall_control_failures =
                    stall_control_failures + 1;

                $display(
                    "FAIL: IF/ID changed during load-use stall"
                );
            end

            if (dut.id_ex_valid !== 1'b0) begin
                stall_control_failures =
                    stall_control_failures + 1;

                $display(
                    "FAIL: ID/EX bubble was not inserted"
                );
            end
        end
    end

    initial begin
        clk = 1'b0;
        resetn = 1'b0;
        core_enable = 1'b0;

        test_count = 0;
        failure_count = 0;
        stall_control_failures = 0;
        held_pc = 32'b0;
        held_if_id_instruction = 32'b0;

        for (int i = 0; i < PROGRAM_WORDS; i = i + 1)
            instruction_memory[i] = NOP;

        // x1 = 10
        instruction_memory[0] =
            encode_addi(5'd1, 5'd0, 32'd10);

        // EX/MEM forwarding:
        // x2 must use the x1 result from the previous instruction.
        // x2 = 10 + 5 = 15
        instruction_memory[1] =
            encode_addi(5'd2, 5'd1, 32'd5);

        // Dual forwarding:
        // x2 comes from EX/MEM and x1 comes from MEM/WB.
        // x3 = 15 + 10 = 25
        instruction_memory[2] =
            encode_add(5'd3, 5'd2, 5'd1);

        // x3 comes from EX/MEM and x2 comes from MEM/WB.
        // x4 = 25 - 15 = 10
        instruction_memory[3] =
            encode_sub(5'd4, 5'd3, 5'd2);

        // x5 = memory base address 0x40
        instruction_memory[4] =
            encode_addi(5'd5, 5'd0, 32'h40);

        // Store-address and store-data forwarding:
        // x5 comes from EX/MEM and x4 comes from MEM/WB.
        instruction_memory[5] =
            encode_sw(5'd4, 5'd5, 32'd0);

        // x6 = memory[0x40] = 10
        instruction_memory[6] =
            encode_lw(5'd6, 5'd5, 32'd0);

        // Immediate load-use hazard on rs1.
        // This must create one stall and then forward from MEM/WB.
        // x7 = 10 + 1 = 11
        instruction_memory[7] =
            encode_addi(5'd7, 5'd6, 32'd1);

        // Normal EX/MEM forwarding after the load dependency.
        // x8 = 10 + 11 = 21
        instruction_memory[8] =
            encode_add(5'd8, 5'd1, 5'd7);

        // x9 = memory[0x40] = 10
        instruction_memory[9] =
            encode_lw(5'd9, 5'd5, 32'd0);

        // Immediate load-use hazard on rs2.
        // x10 = 10 + 10 = 20
        instruction_memory[10] =
            encode_add(5'd10, 5'd1, 5'd9);

        // x11 = memory[0x40] = 10
        instruction_memory[11] =
            encode_lw(5'd11, 5'd5, 32'd0);

        // Load-to-store-data hazard.
        // The store needs loaded x11 as rs2.
        instruction_memory[12] =
            encode_sw(5'd11, 5'd5, 32'd4);

        // Confirm that the forwarded store value reached memory.
        // x12 = memory[0x44] = 10
        instruction_memory[13] =
            encode_lw(5'd12, 5'd5, 32'd4);

        // Independent instruction after the load.
        // This must not cause a load-use stall.
        instruction_memory[14] =
            encode_addi(5'd13, 5'd0, 32'd1);

        // The load is now in MEM/WB, so x12 can be forwarded
        // without inserting another bubble.
        // x14 = 10 + 1 = 11
        instruction_memory[15] =
            encode_add(5'd14, 5'd12, 5'd13);

        // Older x15 = 1
        instruction_memory[16] =
            encode_addi(5'd15, 5'd0, 32'd1);

        // Newer x15 = 2
        instruction_memory[17] =
            encode_addi(5'd15, 5'd15, 32'd1);

        // Both EX/MEM and MEM/WB contain x15 results.
        // EX/MEM must receive priority, so x16 must become 2.
        instruction_memory[18] =
            encode_add(5'd16, 5'd15, 5'd0);

        // x17 = 5
        instruction_memory[19] =
            encode_addi(5'd17, 5'd0, 32'd5);

        // Branch comparison requires the forwarded x17 value.
        // Branch from index 20 to index 23.
        instruction_memory[20] =
            encode_branch(
                3'b000,
                5'd17,
                5'd17,
                32'd12
            );

        // Wrong-path instruction: must be flushed.
        instruction_memory[21] =
            encode_addi(5'd18, 5'd0, 32'd99);

        // Wrong-path instruction: must be flushed.
        instruction_memory[22] =
            encode_addi(5'd19, 5'd0, 32'd88);

        // BEQ target.
        instruction_memory[23] =
            encode_addi(5'd20, 5'd0, 32'd77);

        // BNE x20,x20 is not taken.
        // Both branch operands may require forwarding.
        instruction_memory[24] =
            encode_branch(
                3'b001,
                5'd20,
                5'd20,
                32'd8
            );

        // Must execute because the BNE is not taken.
        instruction_memory[25] =
            encode_addi(5'd21, 5'd0, 32'd33);

        // Jump from address 0x168 to address 0x174.
        // x22 receives the link address 0x16C.
        instruction_memory[26] =
            encode_jal(5'd22, 32'd12);

        // Wrong-path instruction: must be flushed.
        instruction_memory[27] =
            encode_addi(5'd23, 5'd0, 32'd111);

        // Wrong-path instruction: must be flushed.
        instruction_memory[28] =
            encode_addi(5'd24, 5'd0, 32'd122);

        // JAL target.
        instruction_memory[29] =
            encode_addi(5'd25, 5'd0, 32'd55);

        // Use the JAL link register.
        // x26 = 0x16C + 1 = 0x16D.
        instruction_memory[30] =
            encode_addi(5'd26, 5'd22, 32'd1);

        // Produce x28 = 42.
        instruction_memory[31] =
            encode_addi(5'd28, 5'd0, 32'd42);

        // First independent instruction.
        instruction_memory[32] =
            encode_addi(5'd29, 5'd0, 32'd1);

        // Second independent instruction.
        instruction_memory[33] =
            encode_addi(5'd30, 5'd0, 32'd2);

        // x28 is written in WB during the cycle this instruction
        // reads x28 in ID. This tests the WB-to-ID bypass.
        instruction_memory[34] =
            encode_add(5'd31, 5'd28, 5'd0);

        // Attempting to write x0 must have no effect.
        instruction_memory[35] =
            encode_addi(5'd0, 5'd0, 32'd9);

        // Must still read x0 as zero.
        instruction_memory[36] =
            encode_addi(5'd27, 5'd0, 32'd7);

        repeat (4) @(posedge clk);

        @(negedge clk);
        resetn = 1'b1;
        core_enable = 1'b1;

        repeat (150) @(posedge clk);

        @(negedge clk);
        core_enable = 1'b0;

        #1;

        check_value(
            "x1 initial ADDI",
            observed_registers[1],
            32'd10
        );

        check_value(
            "EX/MEM forwarding into x2",
            observed_registers[2],
            32'd15
        );

        check_value(
            "dual forwarding into x3",
            observed_registers[3],
            32'd25
        );

        check_value(
            "dual forwarding into x4",
            observed_registers[4],
            32'd10
        );

        check_value(
            "memory base register",
            observed_registers[5],
            32'h00000040
        );

        check_value(
            "load result x6",
            observed_registers[6],
            32'd10
        );

        check_value(
            "load-use forwarding into x7",
            observed_registers[7],
            32'd11
        );

        check_value(
            "forwarded x7 used by x8",
            observed_registers[8],
            32'd21
        );

        check_value(
            "second loaded value x9",
            observed_registers[9],
            32'd10
        );

        check_value(
            "load-use hazard on rs2",
            observed_registers[10],
            32'd20
        );

        check_value(
            "load-to-store source x11",
            observed_registers[11],
            32'd10
        );

        check_value(
            "forwarded store data loaded into x12",
            observed_registers[12],
            32'd10
        );

        check_value(
            "independent instruction after load",
            observed_registers[13],
            32'd1
        );

        check_value(
            "MEM/WB forwarding without extra stall",
            observed_registers[14],
            32'd11
        );

        check_value(
            "newest x15 value",
            observed_registers[15],
            32'd2
        );

        check_value(
            "EX/MEM priority over MEM/WB",
            observed_registers[16],
            32'd2
        );

        check_value(
            "branch source register",
            observed_registers[17],
            32'd5
        );

        check_value(
            "BEQ first wrong-path instruction flushed",
            observed_registers[18],
            32'd0
        );

        check_value(
            "BEQ second wrong-path instruction flushed",
            observed_registers[19],
            32'd0
        );

        check_value(
            "BEQ target executed",
            observed_registers[20],
            32'd77
        );

        check_value(
            "not-taken BNE continues normally",
            observed_registers[21],
            32'd33
        );

        check_value(
            "JAL link register",
            observed_registers[22],
            32'h0000016c
        );

        check_value(
            "JAL first wrong-path instruction flushed",
            observed_registers[23],
            32'd0
        );

        check_value(
            "JAL second wrong-path instruction flushed",
            observed_registers[24],
            32'd0
        );

        check_value(
            "JAL target executed",
            observed_registers[25],
            32'd55
        );

        check_value(
            "JAL link value used",
            observed_registers[26],
            32'h0000016d
        );

        check_value(
            "x0 remains zero",
            observed_registers[0],
            32'd0
        );

        check_value(
            "instruction reads x0 as zero",
            observed_registers[27],
            32'd7
        );

        check_value(
            "WB-to-ID source value",
            observed_registers[28],
            32'd42
        );

        check_value(
            "WB-to-ID bypass result",
            observed_registers[31],
            32'd42
        );

        check_value(
            "exactly three load-use stalls",
            stall_count,
            32'd3
        );

        check_value(
            "two taken control transfers",
            control_transfer_count,
            32'd2
        );

        check_value(
            "expected non-x0 register commits",
            register_commit_count,
            32'd28
        );

        check_condition(
            "EX/MEM forwarding was exercised",
            ex_mem_forward_count > 0
        );

        check_condition(
            "MEM/WB forwarding was exercised",
            mem_wb_forward_count > 0
        );

        check_condition(
            "simultaneous dual-source forwarding was exercised",
            dual_forward_count > 0
        );

        check_condition(
            "stall holds PC and IF/ID and bubbles ID/EX",
            stall_control_failures == 0
        );

        check_value(
            "pipeline completes without fault",
            core_fault,
            32'd0
        );

        if (failure_count == 0)
            $display(
                "All %0d rv32 pipeline hazard and forwarding tests passed.",
                test_count
            );
        else
            $display(
                "%0d of %0d rv32 pipeline hazard and forwarding tests failed.",
                failure_count,
                test_count
            );

        $finish;
    end

endmodule