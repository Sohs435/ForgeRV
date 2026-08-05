`timescale 1ns/1ps

module rv32_pipeline_core_tb;

    import rv32_pkg::*;

    localparam logic [31:0] RESET_VECTOR = 32'h00000100;
    localparam DATA_MEMORY_DEPTH_WORDS = 256;
    localparam PROGRAM_WORDS = 128;
    localparam logic [31:0] NOP = 32'h00000013;

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

    integer test_count;
    integer failure_count;
    integer transfer_count;
    integer register_commit_count;
    integer i;

    logic [31:0] sampled_control_transfer_target;

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

    always #5 clk = ~clk; //10 ns clock as clock switches between 0 and 1 every 5ns

    always_comb begin
        instruction = NOP; // set instruction to no operation initially

        if ((pc >= RESET_VECTOR) && // reset vector essentially corresponds to instruction[0]
            (((pc - RESET_VECTOR) >> 2) < PROGRAM_WORDS)) // (pc - REST_VECTOR) // 4 = instruction number and cannot be greater than the maximum depth 
            // of instruction memory
            instruction = instruction_memory[
                (pc - RESET_VECTOR) >> 2 // extract corresponding instruction 
            ];
    end
    
    // instruction encoding functions 
    function automatic logic [31:0] encode_lui ( // load upper immediate, ex encode_lui ( 20, 5'd1 ) -> lui x1, 20
        input logic [4:0] rd,
        input logic [19:0] upper_immediate
    );
        begin
            encode_lui = {
                upper_immediate,
                rd,
                OPCODE_LUI
            };
        end
    endfunction

    function automatic logic [31:0] encode_addi ( // addition with immediate ex encode_addi (5'd4, 5'd3, 10) -> addi x4, x3, 10
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input integer signed immediate
    );

        logic [11:0] immediate_bits;

        begin
            immediate_bits = immediate[11:0];

            encode_addi = {
                immediate_bits,
                rs1,
                3'b000,
                rd,
                OPCODE_OP_IMM
            };
        end
    endfunction

    function automatic logic [31:0] encode_add (
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2
    );
        begin
            encode_add = {
                FUNCT7_NORMAL,
                rs2,
                rs1,
                3'b000,
                rd,
                OPCODE_OP
            };
        end
    endfunction

    function automatic logic [31:0] encode_sub (
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2
    );
        begin
            encode_sub = {
                FUNCT7_SUB_SRA,
                rs2,
                rs1,
                3'b000,
                rd,
                OPCODE_OP
            };
        end
    endfunction

    function automatic logic [31:0] encode_sw (
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input integer signed immediate
    );

        logic [11:0] immediate_bits;

        begin
            immediate_bits = immediate[11:0];

            encode_sw = {
                immediate_bits[11:5],
                rs2,
                rs1,
                3'b010,
                immediate_bits[4:0],
                OPCODE_STORE
            };
        end
    endfunction

    function automatic logic [31:0] encode_lw (
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input integer signed immediate
    );

        logic [11:0] immediate_bits;

        begin
            immediate_bits = immediate[11:0];

            encode_lw = {
                immediate_bits,
                rs1,
                3'b010,
                rd,
                OPCODE_LOAD
            };
        end
    endfunction

    function automatic logic [31:0] encode_beq (
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input integer signed offset
    );

        logic [12:0] immediate_bits;

        begin
            immediate_bits = offset[12:0];

            encode_beq = {
                immediate_bits[12],
                immediate_bits[10:5],
                rs2,
                rs1,
                3'b000,
                immediate_bits[4:1],
                immediate_bits[11],
                OPCODE_BRANCH
            };
        end
    endfunction

    function automatic logic [31:0] encode_jal (
        input logic [4:0] rd,
        input integer signed offset
    );

        logic [20:0] immediate_bits;

        begin
            immediate_bits = offset[20:0];

            encode_jal = {
                immediate_bits[20],
                immediate_bits[10:1],
                immediate_bits[11],
                immediate_bits[19:12],
                rd,
                OPCODE_JAL
            };
        end
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

    task automatic check_bit (
        input string test_name,
        input logic actual,
        input logic expected
    );
        begin
            test_count = test_count + 1;

            if (actual === expected)
                $display(
                    "PASS: %s value=%0b",
                    test_name,
                    actual
                );
            else begin
                failure_count = failure_count + 1;

                $display(
                    "FAIL: %s expected=%0b actual=%0b",
                    test_name,
                    expected,
                    actual
                );
            end
        end
    endtask

    always @(posedge clk) begin
        if (resetn &&
            register_write_enable &&
            (dut.mem_wb_rd_address != 5'd0))
            register_commit_count = register_commit_count + 1;
    end

    always @(posedge clk) begin
        if (resetn && control_transfer_taken) begin
            sampled_control_transfer_target =
                dut.ex_control_transfer_target;

            transfer_count = transfer_count + 1;

            #1;

            check_value(
                "control transfer updates PC",
                pc,
                sampled_control_transfer_target
            );

            check_bit(
                "control transfer flushes IF/ID",
                dut.if_id_valid,
                1'b0
            );

            check_bit(
                "control transfer flushes ID/EX",
                dut.id_ex_valid,
                1'b0
            );
        end
    end

    initial begin
        clk = 1'b0;
        resetn = 1'b0;
        core_enable = 1'b0;

        test_count = 0;
        failure_count = 0;
        transfer_count = 0;
        register_commit_count = 0;
        sampled_control_transfer_target = 32'b0;

        for (i = 0; i < PROGRAM_WORDS; i = i + 1) // initially set every instruction memory location to NOP since hazard detection has not been implemented yet
            instruction_memory[i] = NOP;

        instruction_memory[0] = encode_addi(5'd10, 5'd0, 0);
        instruction_memory[1] = encode_addi(5'd11, 5'd0, 0);
        instruction_memory[2] = encode_addi(5'd15, 5'd0, 0);

        instruction_memory[3] = encode_lui(5'd1, 20'h00001);

        instruction_memory[4] = NOP;
        instruction_memory[5] = NOP;
        instruction_memory[6] = NOP;
        instruction_memory[7] = NOP;

        instruction_memory[8] = encode_addi(5'd2, 5'd0, 5);

        instruction_memory[9] = NOP;
        instruction_memory[10] = NOP;
        instruction_memory[11] = NOP;
        instruction_memory[12] = NOP;

        instruction_memory[13] = encode_add(
            5'd3,
            5'd1,
            5'd2
        );

        instruction_memory[14] = NOP;
        instruction_memory[15] = NOP;
        instruction_memory[16] = NOP;
        instruction_memory[17] = NOP;

        instruction_memory[18] = encode_sub(
            5'd4,
            5'd3,
            5'd2
        );

        instruction_memory[19] = NOP;
        instruction_memory[20] = NOP;
        instruction_memory[21] = NOP;
        instruction_memory[22] = NOP;

        instruction_memory[23] = encode_addi(
            5'd5,
            5'd0,
            64
        );

        instruction_memory[24] = NOP;
        instruction_memory[25] = NOP;
        instruction_memory[26] = NOP;
        instruction_memory[27] = NOP;

        instruction_memory[28] = encode_sw(
            5'd3,
            5'd5,
            0
        );

        instruction_memory[29] = NOP;
        instruction_memory[30] = NOP;
        instruction_memory[31] = NOP;
        instruction_memory[32] = NOP;

        instruction_memory[33] = encode_lw(
            5'd6,
            5'd5,
            0
        );

        instruction_memory[34] = NOP;
        instruction_memory[35] = NOP;
        instruction_memory[36] = NOP;
        instruction_memory[37] = NOP;

        instruction_memory[38] = encode_addi(
            5'd7,
            5'd6,
            1
        );

        instruction_memory[39] = NOP;
        instruction_memory[40] = NOP;
        instruction_memory[41] = NOP;
        instruction_memory[42] = NOP;

        instruction_memory[43] = encode_beq(
            5'd7,
            5'd7,
            12
        );

        instruction_memory[44] = encode_addi(
            5'd10,
            5'd0,
            99
        );

        instruction_memory[45] = encode_addi(
            5'd11,
            5'd0,
            88
        );

        instruction_memory[46] = encode_addi(
            5'd12,
            5'd0,
            77
        );

        instruction_memory[47] = NOP;
        instruction_memory[48] = NOP;
        instruction_memory[49] = NOP;
        instruction_memory[50] = NOP;

        instruction_memory[51] = encode_jal(
            5'd13,
            12
        );

        instruction_memory[52] = encode_addi(
            5'd14,
            5'd0,
            1
        );

        instruction_memory[53] = encode_addi(
            5'd15,
            5'd0,
            2
        );

        instruction_memory[54] = encode_addi(
            5'd14,
            5'd0,
            55
        );

        repeat (2) @(posedge clk);

        #1;

        check_value(
            "reset vector",
            pc,
            RESET_VECTOR
        );

        check_bit(
            "no fault during reset",
            core_fault,
            1'b0
        );

        @(negedge clk);

        resetn = 1'b1;
        core_enable = 1'b1;

        @(posedge clk);

        #1;

        check_value(
            "first sequential PC update",
            pc,
            RESET_VECTOR + 32'd4
        );

        @(posedge clk);

        #1;

        check_value(
            "second sequential PC update",
            pc,
            RESET_VECTOR + 32'd8
        );

        repeat (5) @(posedge clk);

        #1;

        check_bit(
            "IF/ID contains valid instruction",
            dut.if_id_valid,
            1'b1
        );

        check_bit(
            "ID/EX contains valid instruction",
            dut.id_ex_valid,
            1'b1
        );

        check_bit(
            "EX/MEM contains valid instruction",
            dut.ex_mem_valid,
            1'b1
        );

        check_bit(
            "MEM/WB contains valid instruction",
            dut.mem_wb_valid,
            1'b1
        );

        check_bit(
            "base pipeline does not stall",
            pipeline_stalled,
            1'b0
        );

        repeat (85) @(posedge clk);

        #1;

        check_value(
            "LUI writes x1",
            dut.register_file.registers[1],
            32'h00001000
        );

        check_value(
            "ADDI writes x2",
            dut.register_file.registers[2],
            32'h00000005
        );

        check_value(
            "ADD writes x3",
            dut.register_file.registers[3],
            32'h00001005
        );

        check_value(
            "SUB writes x4",
            dut.register_file.registers[4],
            32'h00001000
        );

        check_value(
            "memory base writes x5",
            dut.register_file.registers[5],
            32'h00000040
        );

        check_value(
            "LW returns stored value",
            dut.register_file.registers[6],
            32'h00001005
        );

        check_value(
            "loaded value used after NOP spacing",
            dut.register_file.registers[7],
            32'h00001006
        );

        check_value(
            "BEQ flushes first wrong-path instruction",
            dut.register_file.registers[10],
            32'h00000000
        );

        check_value(
            "BEQ flushes second wrong-path instruction",
            dut.register_file.registers[11],
            32'h00000000
        );

        check_value(
            "BEQ target executes",
            dut.register_file.registers[12],
            32'h0000004d
        );

        check_value(
            "JAL writes PC plus 4",
            dut.register_file.registers[13],
            32'h000001d0
        );

        check_value(
            "JAL target executes",
            dut.register_file.registers[14],
            32'h00000037
        );

        check_value(
            "JAL flushes second wrong-path instruction",
            dut.register_file.registers[15],
            32'h00000000
        );

        check_value(
            "two control transfers occurred",
            transfer_count,
            32'd2
        );

        check_value(
            "expected architectural register commits",
            register_commit_count,
            32'd13
        );

        check_bit(
            "pipeline completes without fault",
            core_fault,
            1'b0
        );

        if (failure_count == 0)
            $display(
                "All %0d rv32_pipeline_core tests passed.",
                test_count
            );
        else
            $display(
                "%0d of %0d rv32_pipeline_core tests failed.",
                failure_count,
                test_count
            );

        $finish;
    end

endmodule