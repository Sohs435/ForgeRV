`timescale 1ns / 1ps

module rv32_decode_stage_tb;

    import rv32_pkg::*;

    logic [31:0] instruction;

    logic [4:0] rs1_address;
    logic [4:0] rs2_address;
    logic [4:0] rd_address;
    logic [31:0] immediate;

    imm_type_t immediate_type;
    alu_op_t alu_operation;
    alu_a_sel_t alu_a_select;
    alu_b_sel_t alu_b_select;
    writeback_sel_t writeback_select;
    branch_op_t branch_operation;
    jump_op_t jump_operation;
    memory_size_t memory_size;
    special_op_t special_operation;

    logic register_write_enable;
    logic memory_read_enable;
    logic memory_write_enable;
    logic load_unsigned;
    logic illegal_instruction;

    integer test_count;
    integer failure_count;

    rv32_decode_stage dut (
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
        .register_write_enable(register_write_enable),
        .memory_read_enable(memory_read_enable),
        .memory_write_enable(memory_write_enable),
        .load_unsigned(load_unsigned),
        .illegal_instruction(illegal_instruction)
    );

    task automatic check_outputs (
        input string test_name,
        input logic [31:0] expected_immediate,
        input imm_type_t expected_immediate_type,
        input alu_op_t expected_alu_operation,
        input alu_a_sel_t expected_alu_a_select,
        input alu_b_sel_t expected_alu_b_select,
        input writeback_sel_t expected_writeback_select,
        input branch_op_t expected_branch_operation,
        input jump_op_t expected_jump_operation,
        input memory_size_t expected_memory_size,
        input special_op_t expected_special_operation,
        input logic expected_register_write_enable,
        input logic expected_memory_read_enable,
        input logic expected_memory_write_enable,
        input logic expected_load_unsigned,
        input logic expected_illegal_instruction
    );
        begin
            #1;
            test_count = test_count + 1;

            if (
                rs1_address !== instruction[19:15] ||
                rs2_address !== instruction[24:20] ||
                rd_address !== instruction[11:7] ||
                immediate !== expected_immediate ||
                immediate_type !== expected_immediate_type ||
                alu_operation !== expected_alu_operation ||
                alu_a_select !== expected_alu_a_select ||
                alu_b_select !== expected_alu_b_select ||
                writeback_select !== expected_writeback_select ||
                branch_operation !== expected_branch_operation ||
                jump_operation !== expected_jump_operation ||
                memory_size !== expected_memory_size ||
                special_operation !== expected_special_operation ||
                register_write_enable !== expected_register_write_enable ||
                memory_read_enable !== expected_memory_read_enable ||
                memory_write_enable !== expected_memory_write_enable ||
                load_unsigned !== expected_load_unsigned ||
                illegal_instruction !== expected_illegal_instruction
            ) begin
                failure_count = failure_count + 1;

                $display("FAIL: %s instruction=%h", test_name, instruction);
                $display("immediate expected=%h result=%h", expected_immediate, immediate);
                $display("immediate_type expected=%0d result=%0d", expected_immediate_type, immediate_type);
                $display("alu_operation expected=%0d result=%0d", expected_alu_operation, alu_operation);
                $display("alu_a_select expected=%0d result=%0d", expected_alu_a_select, alu_a_select);
                $display("alu_b_select expected=%0d result=%0d", expected_alu_b_select, alu_b_select);
                $display("writeback_select expected=%0d result=%0d", expected_writeback_select, writeback_select);
                $display("branch_operation expected=%0d result=%0d", expected_branch_operation, branch_operation);
                $display("jump_operation expected=%0d result=%0d", expected_jump_operation, jump_operation);
                $display("memory_size expected=%0d result=%0d", expected_memory_size, memory_size);
                $display("special_operation expected=%0d result=%0d", expected_special_operation, special_operation);
                $display("register_write expected=%b result=%b", expected_register_write_enable, register_write_enable);
                $display("memory_read expected=%b result=%b", expected_memory_read_enable, memory_read_enable);
                $display("memory_write expected=%b result=%b", expected_memory_write_enable, memory_write_enable);
                $display("load_unsigned expected=%b result=%b", expected_load_unsigned, load_unsigned);
                $display("illegal expected=%b result=%b", expected_illegal_instruction, illegal_instruction);
            end
            else begin
                $display("PASS: %s instruction=%h immediate=%h", test_name, instruction, immediate);
            end
        end
    endtask

    task automatic check_r_type (
        input logic [31:0] test_instruction,
        input alu_op_t expected_operation,
        input string test_name
    );
        begin
            instruction = test_instruction;

            check_outputs(
                test_name,
                32'b0,
                IMM_NONE,
                expected_operation,
                ALU_A_RS1,
                ALU_B_RS2,
                WB_ALU,
                BRANCH_NONE,
                JUMP_NONE,
                MEMORY_NONE,
                SPECIAL_NONE,
                1'b1,
                1'b0,
                1'b0,
                1'b0,
                1'b0
            );
        end
    endtask

    task automatic check_op_imm (
        input logic [31:0] test_instruction,
        input logic [31:0] expected_immediate,
        input alu_op_t expected_operation,
        input string test_name
    );
        begin
            instruction = test_instruction;

            check_outputs(
                test_name,
                expected_immediate,
                IMM_I,
                expected_operation,
                ALU_A_RS1,
                ALU_B_IMMEDIATE,
                WB_ALU,
                BRANCH_NONE,
                JUMP_NONE,
                MEMORY_NONE,
                SPECIAL_NONE,
                1'b1,
                1'b0,
                1'b0,
                1'b0,
                1'b0
            );
        end
    endtask

    task automatic check_branch (
        input logic [31:0] test_instruction,
        input branch_op_t expected_operation,
        input string test_name
    );
        begin
            instruction = test_instruction;

            check_outputs(
                test_name,
                32'h00000008,
                IMM_B,
                ALU_ADD,
                ALU_A_PC,
                ALU_B_IMMEDIATE,
                WB_NONE,
                expected_operation,
                JUMP_NONE,
                MEMORY_NONE,
                SPECIAL_NONE,
                1'b0,
                1'b0,
                1'b0,
                1'b0,
                1'b0
            );
        end
    endtask

    task automatic check_load (
        input logic [31:0] test_instruction,
        input memory_size_t expected_size,
        input logic expected_unsigned,
        input string test_name
    );
        begin
            instruction = test_instruction;

            check_outputs(
                test_name,
                32'h00000004,
                IMM_I,
                ALU_ADD,
                ALU_A_RS1,
                ALU_B_IMMEDIATE,
                WB_MEMORY,
                BRANCH_NONE,
                JUMP_NONE,
                expected_size,
                SPECIAL_NONE,
                1'b1,
                1'b1,
                1'b0,
                expected_unsigned,
                1'b0
            );
        end
    endtask

    task automatic check_store (
        input logic [31:0] test_instruction,
        input memory_size_t expected_size,
        input string test_name
    );
        begin
            instruction = test_instruction;

            check_outputs(
                test_name,
                32'h00000004,
                IMM_S,
                ALU_ADD,
                ALU_A_RS1,
                ALU_B_IMMEDIATE,
                WB_NONE,
                BRANCH_NONE,
                JUMP_NONE,
                expected_size,
                SPECIAL_NONE,
                1'b0,
                1'b0,
                1'b1,
                1'b0,
                1'b0
            );
        end
    endtask

    task automatic check_illegal (
        input logic [31:0] test_instruction,
        input string test_name
    );
        begin
            instruction = test_instruction;
            #1;
            test_count = test_count + 1;

            if (
                illegal_instruction !== 1'b1 ||
                register_write_enable !== 1'b0 ||
                memory_read_enable !== 1'b0 ||
                memory_write_enable !== 1'b0 ||
                writeback_select !== WB_NONE ||
                branch_operation !== BRANCH_NONE ||
                jump_operation !== JUMP_NONE ||
                special_operation !== SPECIAL_NONE
            ) begin
                failure_count = failure_count + 1;
                $display("FAIL: %s instruction=%h", test_name, instruction);
            end
            else begin
                $display("PASS: %s instruction=%h", test_name, instruction);
            end
        end
    endtask

    initial begin
        instruction = 32'b0;
        test_count = 0;
        failure_count = 0;

        instruction = 32'h123452B7;
        check_outputs(
            "LUI",
            32'h12345000,
            IMM_U,
            ALU_COPY_B,
            ALU_A_ZERO,
            ALU_B_IMMEDIATE,
            WB_ALU,
            BRANCH_NONE,
            JUMP_NONE,
            MEMORY_NONE,
            SPECIAL_NONE,
            1'b1,
            1'b0,
            1'b0,
            1'b0,
            1'b0
        );

        instruction = 32'hABCDE317;
        check_outputs(
            "AUIPC",
            32'hABCDE000,
            IMM_U,
            ALU_ADD,
            ALU_A_PC,
            ALU_B_IMMEDIATE,
            WB_ALU,
            BRANCH_NONE,
            JUMP_NONE,
            MEMORY_NONE,
            SPECIAL_NONE,
            1'b1,
            1'b0,
            1'b0,
            1'b0,
            1'b0
        );

        instruction = 32'h008000EF;
        check_outputs(
            "JAL",
            32'h00000008,
            IMM_J,
            ALU_ADD,
            ALU_A_PC,
            ALU_B_IMMEDIATE,
            WB_PC_PLUS_4,
            BRANCH_NONE,
            JUMP_JAL,
            MEMORY_NONE,
            SPECIAL_NONE,
            1'b1,
            1'b0,
            1'b0,
            1'b0,
            1'b0
        );

        instruction = 32'h00C100E7;
        check_outputs(
            "JALR",
            32'h0000000C,
            IMM_I,
            ALU_ADD,
            ALU_A_RS1,
            ALU_B_IMMEDIATE,
            WB_PC_PLUS_4,
            BRANCH_NONE,
            JUMP_JALR,
            MEMORY_NONE,
            SPECIAL_NONE,
            1'b1,
            1'b0,
            1'b0,
            1'b0,
            1'b0
        );

        check_branch(32'h00208463, BRANCH_EQ, "BEQ");
        check_branch(32'h00209463, BRANCH_NE, "BNE");
        check_branch(32'h0020C463, BRANCH_LT, "BLT");
        check_branch(32'h0020D463, BRANCH_GE, "BGE");
        check_branch(32'h0020E463, BRANCH_LTU, "BLTU");
        check_branch(32'h0020F463, BRANCH_GEU, "BGEU");

        check_load(32'h00410183, MEMORY_BYTE, 1'b0, "LB");
        check_load(32'h00411183, MEMORY_HALF, 1'b0, "LH");
        check_load(32'h00412183, MEMORY_WORD, 1'b0, "LW");
        check_load(32'h00414183, MEMORY_BYTE, 1'b1, "LBU");
        check_load(32'h00415183, MEMORY_HALF, 1'b1, "LHU");

        check_store(32'h00310223, MEMORY_BYTE, "SB");
        check_store(32'h00311223, MEMORY_HALF, "SH");
        check_store(32'h00312223, MEMORY_WORD, "SW");

        check_op_imm(32'h00510193, 32'h00000005, ALU_ADD, "ADDI");
        check_op_imm(32'h00511193, 32'h00000005, ALU_SLL, "SLLI");
        check_op_imm(32'h00512193, 32'h00000005, ALU_SLT, "SLTI");
        check_op_imm(32'h00513193, 32'h00000005, ALU_SLTU, "SLTIU");
        check_op_imm(32'h00514193, 32'h00000005, ALU_XOR, "XORI");
        check_op_imm(32'h00515193, 32'h00000005, ALU_SRL, "SRLI");
        check_op_imm(32'h40515193, 32'h00000405, ALU_SRA, "SRAI");
        check_op_imm(32'h00516193, 32'h00000005, ALU_OR, "ORI");
        check_op_imm(32'h00517193, 32'h00000005, ALU_AND, "ANDI");

        check_r_type(32'h003100B3, ALU_ADD, "ADD");
        check_r_type(32'h403100B3, ALU_SUB, "SUB");
        check_r_type(32'h003110B3, ALU_SLL, "SLL");
        check_r_type(32'h003120B3, ALU_SLT, "SLT");
        check_r_type(32'h003130B3, ALU_SLTU, "SLTU");
        check_r_type(32'h003140B3, ALU_XOR, "XOR");
        check_r_type(32'h003150B3, ALU_SRL, "SRL");
        check_r_type(32'h403150B3, ALU_SRA, "SRA");
        check_r_type(32'h003160B3, ALU_OR, "OR");
        check_r_type(32'h003170B3, ALU_AND, "AND");

        instruction = 32'h0FF0000F;
        check_outputs(
            "FENCE",
            32'b0,
            IMM_NONE,
            ALU_ADD,
            ALU_A_RS1,
            ALU_B_RS2,
            WB_NONE,
            BRANCH_NONE,
            JUMP_NONE,
            MEMORY_NONE,
            SPECIAL_FENCE,
            1'b0,
            1'b0,
            1'b0,
            1'b0,
            1'b0
        );

        instruction = 32'h00000073;
        check_outputs(
            "ECALL",
            32'b0,
            IMM_NONE,
            ALU_ADD,
            ALU_A_RS1,
            ALU_B_RS2,
            WB_NONE,
            BRANCH_NONE,
            JUMP_NONE,
            MEMORY_NONE,
            SPECIAL_ECALL,
            1'b0,
            1'b0,
            1'b0,
            1'b0,
            1'b0
        );

        instruction = 32'h00100073;
        check_outputs(
            "EBREAK",
            32'b0,
            IMM_NONE,
            ALU_ADD,
            ALU_A_RS1,
            ALU_B_RS2,
            WB_NONE,
            BRANCH_NONE,
            JUMP_NONE,
            MEMORY_NONE,
            SPECIAL_EBREAK,
            1'b0,
            1'b0,
            1'b0,
            1'b0,
            1'b0
        );

        check_illegal(32'h00000000, "invalid opcode");
        check_illegal(32'h00001067, "invalid JALR funct3");
        check_illegal(32'h0020A463, "invalid branch funct3");
        check_illegal(32'h00413183, "invalid load funct3");
        check_illegal(32'h00313223, "invalid store funct3");
        check_illegal(32'h40511193, "invalid SLLI funct7");
        check_illegal(32'h023100B3, "unsupported R-type funct7");
        check_illegal(32'h0000100F, "unsupported FENCE.I");
        check_illegal(32'h00001073, "unsupported SYSTEM instruction");

        if (failure_count == 0) begin
            $display("All %0d rv32_decode_stage tests passed.", test_count);
        end
        else begin
            $fatal(1, "%0d of %0d rv32_decode_stage tests failed.", failure_count, test_count);
        end

        $finish;
    end

endmodule