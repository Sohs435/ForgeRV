`timescale 1ns/1ps

module rv32_load_use_hazard_tb;

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

    integer test_count;
    integer failure_count;
    integer timeout_count;
    integer stall_count;

    logic hazard_found;
    logic dependent_execute_found;
    logic dependent_commit_found;

    rv32_pipeline_core #(
        .RESET_VECTOR(RESET_VECTOR),
        .INSTRUCTION_MEMORY_DEPTH_WORDS(INSTRUCTION_MEMORY_DEPTH_WORDS),
        .DATA_MEMORY_DEPTH_WORDS(DATA_MEMORY_DEPTH_WORDS)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .core_enable(core_enable),

        .instruction_memory_read_data(instruction_memory_read_data),

        .instruction_memory_enable(instruction_memory_enable),
        .instruction_memory_address(instruction_memory_address),

        .pc(pc),
        .writeback_data(writeback_data),
        .register_write_enable(register_write_enable),
        .pipeline_stalled(pipeline_stalled),
        .control_transfer_taken(control_transfer_taken),
        .core_fault(core_fault)
    );

    always #4 clk = ~clk; // 8 ns period = 125 MHz

    // Model the one-cycle synchronous instruction Block RAM used on the FPGA.
    always_ff @(posedge clk) begin
        if (instruction_memory_enable)
            instruction_memory_read_data <= instruction_memory[
                instruction_memory_address
            ];
    end

    // Count how many complete clock cycles the pipeline remains stalled.
    always @(negedge clk) begin
        if (resetn && core_enable && pipeline_stalled)
            stall_count = stall_count + 1;
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

        test_count = 0;
        failure_count = 0;
        timeout_count = 0;
        stall_count = 0;

        hazard_found = 1'b0;
        dependent_execute_found = 1'b0;
        dependent_commit_found = 1'b0;

        for (int i = 0; i < INSTRUCTION_MEMORY_DEPTH_WORDS; i = i + 1)
            instruction_memory[i] = NOP;

        // Prepare data value 0x00000123.
        instruction_memory[0] = 32'h12300093; // addi x1, x0, 0x123

        // Allow x1 to reach writeback before the store.
        instruction_memory[1] = NOP;
        instruction_memory[2] = NOP;
        instruction_memory[3] = NOP;

        // Store 0x00000123 at data-memory byte address 192.
        instruction_memory[4] = 32'h0c102023; // sw x1, 192(x0)

        // Allow the store to complete before testing the load.
        instruction_memory[5] = NOP;
        instruction_memory[6] = NOP;
        instruction_memory[7] = NOP;

        // Exact dependency which failed at CHECK 32.
        instruction_memory[8] = 32'h0c002103; // lw x2, 192(x0)
        instruction_memory[9] = 32'h00110e93; // addi x29, x2, 1

        // Prevent the Program Counter from leaving instruction memory.
        instruction_memory[10] = 32'h0000006f; // jal x0, 0

        repeat (4) @(posedge clk);
        #1;

        check_32(
            "reset Program Counter",
            pc,
            RESET_VECTOR
        );

        check_1(
            "no core fault during reset",
            core_fault,
            1'b0
        );

        @(negedge clk);
        resetn = 1'b1;
        core_enable = 1'b1;

        // Wait for the exact cycle where:
        // lw x2, 192(x0) is in ID/EX
        // addi x29, x2, 1 is in IF/ID
        timeout_count = 0;

        while (!hazard_found && (timeout_count < 100)) begin
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
                held_if_id_instruction = dut.if_id_instruction;

                $display("");
                $display("Load-use dependency reached the hazard unit");
                $display("-------------------------------------------");

                check_1(
                    "IF/ID instruction is valid",
                    dut.if_id_valid,
                    1'b1
                );

                check_1(
                    "dependent instruction uses rs1",
                    dut.decode_uses_rs1,
                    1'b1
                );

                check_5(
                    "dependent rs1 is x2",
                    dut.decode_rs1_address,
                    5'd2
                );

                check_1(
                    "ID/EX load is valid",
                    dut.id_ex_valid,
                    1'b1
                );

                check_1(
                    "ID/EX instruction is a memory read",
                    dut.id_ex_memory_read_enable,
                    1'b1
                );

                check_5(
                    "load destination is x2",
                    dut.id_ex_rd_address,
                    5'd2
                );

                check_1(
                    "hazard unit detects load-use dependency",
                    dut.hazard_stall,
                    1'b1
                );

                check_1(
                    "pipeline stall output is asserted",
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
                "FAIL: load-use dependency never reached the hazard unit"
            );
        end
        else begin
            // The edge following detection must hold the Program Counter
            // and IF/ID while replacing ID/EX with an invalid bubble.
            @(posedge clk);
            #1;

            $display("");
            $display("Checking the pipeline response to the stall");
            $display("-------------------------------------------");

            check_32(
                "Program Counter held during stall",
                pc,
                held_pc
            );

            check_32(
                "IF/ID Program Counter held during stall",
                dut.if_id_pc,
                held_if_id_pc
            );

            check_32(
                "IF/ID dependent instruction held during stall",
                dut.if_id_instruction,
                held_if_id_instruction
            );

            check_1(
                "ID/EX bubble inserted",
                dut.id_ex_valid,
                1'b0
            );

            check_1(
                "load advanced into EX/MEM",
                dut.ex_mem_valid,
                1'b1
            );

            check_1(
                "EX/MEM instruction remains a memory read",
                dut.ex_mem_memory_read_enable,
                1'b1
            );
        end

        // After one bubble, the load must be in MEM/WB while the dependent
        // ADDI is in Execute. The loaded value must be forwarded.
        timeout_count = 0;

        while (!dependent_execute_found && (timeout_count < 40)) begin
            @(negedge clk);

            if (dut.id_ex_valid &&
                (dut.id_ex_rd_address == 5'd29)) begin

                dependent_execute_found = 1'b1;

                $display("");
                $display("Checking MEM/WB forwarding after the bubble");
                $display("--------------------------------------------");

                check_5(
                    "dependent instruction destination is x29",
                    dut.id_ex_rd_address,
                    5'd29
                );

                check_1(
                    "load is valid in MEM/WB",
                    dut.mem_wb_valid,
                    1'b1
                );

                check_5(
                    "MEM/WB load destination is x2",
                    dut.mem_wb_rd_address,
                    5'd2
                );

                check_32(
                    "load writeback value",
                    writeback_data,
                    32'h00000123
                );

                check_32(
                    "forwarded rs1 value",
                    dut.ex_forwarded_rs1,
                    32'h00000123
                );

                check_32(
                    "dependent ADDI ALU result",
                    dut.ex_alu_result,
                    32'h00000124
                );

                test_count = test_count + 1;

                if (dut.forward_a_select === FORWARD_MEM_WB)
                    $display(
                        "PASS: forwarding source is MEM/WB"
                    );
                else begin
                    failure_count = failure_count + 1;

                    $display(
                        "FAIL: forwarding source is not MEM/WB actual=%0d",
                        dut.forward_a_select
                    );
                end
            end

            timeout_count = timeout_count + 1;
        end

        if (!dependent_execute_found) begin
            test_count = test_count + 1;
            failure_count = failure_count + 1;

            $display(
                "FAIL: dependent ADDI never reached the Execute stage"
            );
        end

        // Finally confirm that x29 receives 0x124.
        timeout_count = 0;

        while (!dependent_commit_found && (timeout_count < 40)) begin
            @(negedge clk);

            if (register_write_enable &&
                (dut.mem_wb_rd_address == 5'd29)) begin

                dependent_commit_found = 1'b1;

                check_32(
                    "x29 receives loaded value plus one",
                    writeback_data,
                    32'h00000124
                );
            end

            timeout_count = timeout_count + 1;
        end

        if (!dependent_commit_found) begin
            test_count = test_count + 1;
            failure_count = failure_count + 1;

            $display(
                "FAIL: x29 writeback was never observed"
            );
        end

        check_32(
            "exactly one stall cycle inserted",
            stall_count,
            32'd1
        );

        check_1(
            "load-use test completed without core fault",
            core_fault,
            1'b0
        );

        @(negedge clk);
        core_enable = 1'b0;

        $display("");

        if (failure_count == 0)
            $display(
                "All %0d rv32 load-use hazard tests passed.",
                test_count
            );
        else
            $display(
                "%0d of %0d rv32 load-use hazard tests failed.",
                failure_count,
                test_count
            );

        $finish;
    end

endmodule