`timescale 1ns/1ps

module rv32_check_32_tb;

    import rv32_pkg::*;

    localparam logic [31:0] RESET_VECTOR = 32'h00000100;
    localparam INSTRUCTION_MEMORY_DEPTH_WORDS = 256;
    localparam DATA_MEMORY_DEPTH_WORDS = 256;
    localparam logic [31:0] NOP = 32'h00000013;

    logic clk;
    logic resetn;
    logic core_enable;

    logic [31:0] instruction_memory_read_data;
    logic instruction_memory_enable;
    logic [7:0] instruction_memory_address;

    logic [31:0] pc;
    logic [31:0] writeback_data;
    logic register_write_enable;
    logic pipeline_stalled;
    logic control_transfer_taken;
    logic core_fault;

    logic [31:0] instruction_memory [0:INSTRUCTION_MEMORY_DEPTH_WORDS-1];

    logic [31:0] held_pc;
    logic [31:0] held_if_id_pc;
    logic [31:0] held_if_id_instruction;

    logic [31:0] x29_commit_data;
    logic [31:0] x30_commit_data;
    logic [31:0] x31_commit_data;

    logic hazard_found;
    logic dependent_execute_found;
    logic branch_execute_found;
    logic x29_commit_found;
    logic x30_commit_found;
    logic x31_commit_found;
    logic failure_marker_committed;

    integer test_count;
    integer failure_count;
    integer timeout_count;
    integer stall_count;

    rv32_pipeline_core #(
        .RESET_VECTOR(RESET_VECTOR),
        .INSTRUCTION_MEMORY_DEPTH_WORDS(
            INSTRUCTION_MEMORY_DEPTH_WORDS
        ),
        .DATA_MEMORY_DEPTH_WORDS(
            DATA_MEMORY_DEPTH_WORDS
        )
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .core_enable(core_enable),

        .instruction_memory_read_data(
            instruction_memory_read_data
        ),

        .instruction_memory_enable(
            instruction_memory_enable
        ),
        .instruction_memory_address(
            instruction_memory_address
        ),

        .pc(pc),
        .writeback_data(writeback_data),
        .register_write_enable(register_write_enable),
        .pipeline_stalled(pipeline_stalled),
        .control_transfer_taken(control_transfer_taken),
        .core_fault(core_fault)
    );

    always #4 clk = ~clk; // 8 ns period = 125 MHz

    // Model the one-cycle synchronous instruction Block RAM.
    always_ff @(posedge clk) begin
        if (instruction_memory_enable)
            instruction_memory_read_data <= instruction_memory[
                instruction_memory_address
            ];
    end

    // Monitor register commits independently from the main test process.
    always @(negedge clk) begin
        if (resetn && core_enable && pipeline_stalled)
            stall_count = stall_count + 1;

        if (register_write_enable &&
            (dut.mem_wb_rd_address == 5'd29)) begin

            x29_commit_found = 1'b1;
            x29_commit_data = writeback_data;
        end

        if (register_write_enable &&
            (dut.mem_wb_rd_address == 5'd30)) begin

            x30_commit_found = 1'b1;
            x30_commit_data = writeback_data;
        end

        if (register_write_enable &&
            (dut.mem_wb_rd_address == 5'd31)) begin

            x31_commit_found = 1'b1;
            x31_commit_data = writeback_data;
        end

        // x28 is only written by the failed branch path.
        if (register_write_enable &&
            (dut.mem_wb_rd_address == 5'd28))
            failure_marker_committed = 1'b1;
    end

    task automatic check_1 (
        input string test_name,
        input logic actual,
        input logic expected
    );
        begin
            test_count = test_count + 1;

            if (actual === expected)
                $display(
                    "PASS: %s value=%0d",
                    test_name,
                    actual
                );
            else begin
                failure_count = failure_count + 1;

                $display(
                    "FAIL: %s expected=%0d actual=%0d",
                    test_name,
                    expected,
                    actual
                );
            end
        end
    endtask

    task automatic check_5 (
        input string test_name,
        input logic [4:0] actual,
        input logic [4:0] expected
    );
        begin
            test_count = test_count + 1;

            if (actual === expected)
                $display(
                    "PASS: %s value=%0d",
                    test_name,
                    actual
                );
            else begin
                failure_count = failure_count + 1;

                $display(
                    "FAIL: %s expected=%0d actual=%0d",
                    test_name,
                    expected,
                    actual
                );
            end
        end
    endtask

    task automatic check_32 (
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

    initial begin
        clk = 1'b0;
        resetn = 1'b0;
        core_enable = 1'b0;
        instruction_memory_read_data = NOP;

        held_pc = 32'b0;
        held_if_id_pc = 32'b0;
        held_if_id_instruction = 32'b0;

        x29_commit_data = 32'b0;
        x30_commit_data = 32'b0;
        x31_commit_data = 32'b0;

        hazard_found = 1'b0;
        dependent_execute_found = 1'b0;
        branch_execute_found = 1'b0;
        x29_commit_found = 1'b0;
        x30_commit_found = 1'b0;
        x31_commit_found = 1'b0;
        failure_marker_committed = 1'b0;

        test_count = 0;
        failure_count = 0;
        timeout_count = 0;
        stall_count = 0;

        for (int i = 0;
             i < INSTRUCTION_MEMORY_DEPTH_WORDS;
             i = i + 1)
            instruction_memory[i] = NOP;

        // Prepare the value used by CHECK 32.
        instruction_memory[0] = 32'h12300093;
        // addi x1, x0, 0x123

        instruction_memory[1] = NOP;
        instruction_memory[2] = NOP;
        instruction_memory[3] = NOP;

        instruction_memory[4] = 32'h0c102023;
        // sw x1, 192(x0)

        instruction_memory[5] = NOP;
        instruction_memory[6] = NOP;
        instruction_memory[7] = NOP;

        // Exact CHECK 32 sequence.
        instruction_memory[8] = 32'h0c002103;
        // lw x2, 192(x0)

        instruction_memory[9] = 32'h00110e93;
        // addi x29, x2, 1

        instruction_memory[10] = 32'h12400f13;
        // addi x30, x0, 0x124

        instruction_memory[11] = 32'h02000f93;
        // addi x31, x0, 32

        instruction_memory[12] = 32'h01ee9463;
        // bne x29, x30, failed
        // failed is eight bytes ahead

        instruction_memory[13] = 32'h0000006f;
        // passed: jal x0, passed

        instruction_memory[14] = 32'h00100e13;
        // failed: addi x28, x0, 1

        instruction_memory[15] = 32'h0000006f;
        // failed_loop: jal x0, failed_loop

        repeat (4) @(posedge clk);
        #1;

        check_32(
            "reset Program Counter",
            pc,
            RESET_VECTOR
        );

        check_1(
            "no fault during reset",
            core_fault,
            1'b0
        );

        @(negedge clk);
        resetn = 1'b1;
        core_enable = 1'b1;

        // Find the load-use dependency.
        timeout_count = 0;

        while (!hazard_found &&
               (timeout_count < 100)) begin

            @(negedge clk);

            if (dut.if_id_valid &&
                dut.decode_uses_rs1 &&
                (dut.decode_rs1_address == 5'd2) &&
                dut.id_ex_valid &&
                dut.id_ex_memory_read_enable &&
                (dut.id_ex_rd_address == 5'd2)) begin

                hazard_found = 1'b1;

                held_pc = pc;
                held_if_id_pc = dut.if_id_pc;
                held_if_id_instruction =
                    dut.if_id_instruction;

                $display("");
                $display("Checking CHECK 32 load-use hazard");
                $display("---------------------------------");

                check_1(
                    "hazard unit detects dependency",
                    dut.hazard_stall,
                    1'b1
                );

                check_1(
                    "pipeline stall is asserted",
                    pipeline_stalled,
                    1'b1
                );

                check_1(
                    "ID/EX flush requests a bubble",
                    dut.id_ex_flush,
                    1'b1
                );
            end

            timeout_count = timeout_count + 1;
        end

        if (!hazard_found) begin
            test_count = test_count + 1;
            failure_count = failure_count + 1;

            $display(
                "FAIL: CHECK 32 load-use hazard was not detected"
            );
        end
        else begin
            @(posedge clk);
            #1;

            check_32(
                "Program Counter held during stall",
                pc,
                held_pc
            );

            check_32(
                "IF/ID Program Counter held",
                dut.if_id_pc,
                held_if_id_pc
            );

            check_32(
                "dependent ADDI held in IF/ID",
                dut.if_id_instruction,
                held_if_id_instruction
            );

            check_1(
                "bubble inserted into ID/EX",
                dut.id_ex_valid,
                1'b0
            );
        end

        // Check loaded data forwarding into addi x29.
        timeout_count = 0;

        while (!dependent_execute_found &&
               (timeout_count < 40)) begin

            @(negedge clk);

            if (dut.id_ex_valid &&
                (dut.id_ex_rd_address == 5'd29)) begin

                dependent_execute_found = 1'b1;

                $display("");
                $display("Checking load forwarding into x29");
                $display("---------------------------------");

                check_5(
                    "dependent destination is x29",
                    dut.id_ex_rd_address,
                    5'd29
                );

                check_5(
                    "MEM/WB load destination is x2",
                    dut.mem_wb_rd_address,
                    5'd2
                );

                check_32(
                    "loaded writeback value",
                    writeback_data,
                    32'h00000123
                );

                check_32(
                    "forwarded x2 value",
                    dut.ex_forwarded_rs1,
                    32'h00000123
                );

                check_32(
                    "x29 ALU result",
                    dut.ex_alu_result,
                    32'h00000124
                );

                test_count = test_count + 1;

                if (dut.forward_a_select ===
                    FORWARD_MEM_WB)
                    $display(
                        "PASS: x2 forwarded from MEM/WB"
                    );
                else begin
                    failure_count = failure_count + 1;

                    $display(
                        "FAIL: x2 was not forwarded from MEM/WB"
                    );
                end
            end

            timeout_count = timeout_count + 1;
        end

        if (!dependent_execute_found) begin
            test_count = test_count + 1;
            failure_count = failure_count + 1;

            $display(
                "FAIL: addi x29 never reached Execute"
            );
        end

        // Find the final BNE from CHECK 32.
        timeout_count = 0;

        while (!branch_execute_found &&
               (timeout_count < 60)) begin

            @(negedge clk);

            if (dut.id_ex_valid &&
                (dut.id_ex_branch_operation ==
                 BRANCH_NE) &&
                (dut.id_ex_rs1_address == 5'd29) &&
                (dut.id_ex_rs2_address == 5'd30)) begin

                branch_execute_found = 1'b1;

                $display("");
                $display("Checking the final CHECK 32 BNE");
                $display("--------------------------------");

                check_32(
                    "BNE Program Counter",
                    dut.id_ex_pc,
                    32'h00000130
                );

                check_5(
                    "BNE rs1 is x29",
                    dut.id_ex_rs1_address,
                    5'd29
                );

                check_5(
                    "BNE rs2 is x30",
                    dut.id_ex_rs2_address,
                    5'd30
                );

                // x29 should already have been captured correctly
                // through the register-file/writeback bypass.
                check_32(
                    "BNE captured x29 value",
                    dut.id_ex_rs1_data,
                    32'h00000124
                );

                // x30 should currently be available from MEM/WB.
                check_1(
                    "MEM/WB contains a valid instruction",
                    dut.mem_wb_valid,
                    1'b1
                );

                check_5(
                    "MEM/WB destination is x30",
                    dut.mem_wb_rd_address,
                    5'd30
                );

                check_32(
                    "MEM/WB x30 value",
                    writeback_data,
                    32'h00000124
                );

                check_32(
                    "BNE forwarded x29 value",
                    dut.ex_forwarded_rs1,
                    32'h00000124
                );

                check_32(
                    "BNE forwarded x30 value",
                    dut.ex_forwarded_rs2,
                    32'h00000124
                );

                test_count = test_count + 1;

                if (dut.forward_b_select ===
                    FORWARD_MEM_WB)
                    $display(
                        "PASS: BNE x30 forwarded from MEM/WB"
                    );
                else begin
                    failure_count = failure_count + 1;

                    $display(
                        "FAIL: BNE x30 was not forwarded from MEM/WB"
                    );
                end

                check_1(
                    "equal values make BNE not taken",
                    dut.ex_branch_taken,
                    1'b0
                );

                check_1(
                    "CHECK 32 does not transfer to failed",
                    control_transfer_taken,
                    1'b0
                );
            end

            timeout_count = timeout_count + 1;
        end

        if (!branch_execute_found) begin
            test_count = test_count + 1;
            failure_count = failure_count + 1;

            $display(
                "FAIL: CHECK 32 BNE never reached Execute"
            );
        end

        // Allow enough time for the branch result and pass loop.
        repeat (16) @(negedge clk);

        $display("");
        $display("Checking final architectural results");
        $display("------------------------------------");

        check_1(
            "x29 committed",
            x29_commit_found,
            1'b1
        );

        check_32(
            "x29 committed value",
            x29_commit_data,
            32'h00000124
        );

        check_1(
            "x30 committed",
            x30_commit_found,
            1'b1
        );

        check_32(
            "x30 committed value",
            x30_commit_data,
            32'h00000124
        );

        check_1(
            "x31 committed",
            x31_commit_found,
            1'b1
        );

        check_32(
            "x31 contains CHECK 32 failure code",
            x31_commit_data,
            32'h00000020
        );

        check_32(
            "exactly one stall cycle",
            stall_count,
            32'd1
        );

        check_1(
            "failure marker never committed",
            failure_marker_committed,
            1'b0
        );

        check_1(
            "CHECK 32 completes without core fault",
            core_fault,
            1'b0
        );

        @(negedge clk);
        core_enable = 1'b0;

        $display("");

        if (failure_count == 0)
            $display(
                "All %0d complete CHECK 32 tests passed.",
                test_count
            );
        else
            $display(
                "%0d of %0d complete CHECK 32 tests failed.",
                failure_count,
                test_count
            );

        $finish;
    end

endmodule