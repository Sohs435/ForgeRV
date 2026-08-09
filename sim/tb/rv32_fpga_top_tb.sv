`timescale 1ns/1ps

// PHASE 9 NEW TESTBENCH: verify the FPGA wrapper with a synchronous instruction Block RAM model.
module rv32_fpga_top_tb;

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
    logic pipeline_stalled;
    logic control_transfer_taken;
    logic core_fault;

    logic [31:0] instruction_memory [0:INSTRUCTION_MEMORY_DEPTH_WORDS-1];
    logic [31:0] held_pc;

    integer test_count;
    integer failure_count;

    rv32_fpga_top #(
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
        .pipeline_stalled(pipeline_stalled),
        .control_transfer_taken(control_transfer_taken),
        .core_fault(core_fault)
    );

    always #4 clk = ~clk; // PHASE 9 TEST CHANGE: 8 ns period represents the 125 MHz board target.

    // PHASE 9 TEST CHANGE: nonblocking assignment models a one-cycle synchronous Block RAM read.
    always_ff @(posedge clk) begin
        if (instruction_memory_enable)
            instruction_memory_read_data <= instruction_memory[
                instruction_memory_address
            ];
    end

    task automatic check_32 (
        input string test_name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        begin
            test_count = test_count + 1;

            if (actual === expected)
                $display("PASS: %s value=%08h", test_name, actual);
            else begin
                failure_count = failure_count + 1;
                $display("FAIL: %s expected=%08h actual=%08h", test_name, expected, actual);
            end
        end
    endtask

    task automatic check_1 (
        input string test_name,
        input logic actual,
        input logic expected
    );
        begin
            test_count = test_count + 1;

            if (actual === expected)
                $display("PASS: %s value=%0d", test_name, actual);
            else begin
                failure_count = failure_count + 1;
                $display("FAIL: %s expected=%0d actual=%0d", test_name, expected, actual);
            end
        end
    endtask

    task automatic wait_for_writeback (
        input string test_name,
        input logic [31:0] expected
    );
        integer timeout_count;
        logic writeback_found;

        begin
            timeout_count = 0;
            writeback_found = 1'b0;

            // PHASE 9 TEST CHANGE: sample at the falling edge after all pipeline outputs have settled.
            while (!writeback_found && (timeout_count < 40)) begin
                @(negedge clk);

                if (dut.register_write_enable) begin
                    writeback_found = 1'b1;
                    check_32(test_name, dut.writeback_data, expected);
                end

                timeout_count = timeout_count + 1;
            end

            if (!writeback_found) begin
                test_count = test_count + 1;
                failure_count = failure_count + 1;
                $display("FAIL: %s timed out waiting for register writeback", test_name);
            end
        end
    endtask

    task automatic wait_for_control_transfer (
        input string test_name,
        input logic [31:0] expected_pc
    );
        integer timeout_count;
        logic transfer_found;

        begin
            timeout_count = 0;
            transfer_found = 1'b0;

            // PHASE 9 TEST CHANGE: detect the combinational transfer before the edge that updates the PC.
            while (!transfer_found && (timeout_count < 40)) begin
                @(negedge clk);

                if (control_transfer_taken) begin
                    transfer_found = 1'b1;
                    @(posedge clk);
                    #1;
                    check_32(test_name, pc, expected_pc);
                end

                timeout_count = timeout_count + 1;
            end

            if (!transfer_found) begin
                test_count = test_count + 1;
                failure_count = failure_count + 1;
                $display("FAIL: %s timed out waiting for control transfer", test_name);
            end
        end
    endtask

    task automatic wait_for_core_fault (
        input string test_name,
        input logic [31:0] expected_pc
    );
        integer timeout_count;
        logic fault_found;

        begin
            timeout_count = 0;
            fault_found = 1'b0;

            while (!fault_found && (timeout_count < 40)) begin
                @(posedge clk);
                #1;

                if (core_fault) begin
                    fault_found = 1'b1;
                    check_1(test_name, core_fault, 1'b1);
                    check_32("faulting Program Counter", pc, expected_pc);
                end

                timeout_count = timeout_count + 1;
            end

            if (!fault_found) begin
                test_count = test_count + 1;
                failure_count = failure_count + 1;
                $display("FAIL: %s timed out waiting for core fault", test_name);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        resetn = 1'b0;
        core_enable = 1'b0;
        instruction_memory_read_data = NOP;
        held_pc = 32'b0;

        test_count = 0;
        failure_count = 0;

        for (int i = 0; i < INSTRUCTION_MEMORY_DEPTH_WORDS; i = i + 1)
            instruction_memory[i] = NOP;

        instruction_memory[0] = 32'h00500093; // addi x1, x0, 5
        instruction_memory[1] = 32'h00700113; // addi x2, x0, 7
        instruction_memory[2] = 32'h002081b3; // add x3, x1, x2
        instruction_memory[3] = 32'h40118233; // sub x4, x3, x1
        instruction_memory[4] = 32'h0000006f; // jal x0, 0

        repeat (3) @(posedge clk);
        #1;

        check_32("reset vector", pc, RESET_VECTOR);
        check_1("instruction memory disabled during reset", instruction_memory_enable, 1'b0);
        check_1("no core fault during reset", core_fault, 1'b0);

        @(negedge clk);
        resetn = 1'b1;
        core_enable = 1'b0;

        repeat (3) @(posedge clk);
        #1;

        check_32("Program Counter held while core disabled", pc, RESET_VECTOR);
        check_1("instruction memory disabled while core disabled", instruction_memory_enable, 1'b0);

        @(negedge clk);
        core_enable = 1'b1;
        #1;

        check_1("instruction memory enabled after core start", instruction_memory_enable, 1'b1);
        check_32("reset vector maps to instruction zero", {24'b0, instruction_memory_address}, 32'd0);

        wait_for_writeback("ADDI writes five", 32'd5);
        wait_for_writeback("ADDI writes seven", 32'd7);
        wait_for_writeback("forwarded ADD writes twelve", 32'd12);
        wait_for_writeback("forwarded SUB writes seven", 32'd7);

        wait_for_control_transfer("JAL loops to its own address", 32'h00000110);

        check_1("functional program has no core fault", core_fault, 1'b0);

        @(negedge clk);
        core_enable = 1'b0;
        held_pc = pc;

        repeat (4) @(posedge clk);
        #1;

        check_32("core disable holds Program Counter", pc, held_pc);
        check_1("core disable stops instruction requests", instruction_memory_enable, 1'b0);

        // PHASE 9 TEST CHANGE: JAL from 0x100 to 0x500 verifies the instruction-range fault.
        @(negedge clk);
        resetn = 1'b0;
        core_enable = 1'b0;
        instruction_memory[0] = 32'h4000006f;

        repeat (3) @(posedge clk);
        #1;

        check_32("second reset returns to reset vector", pc, RESET_VECTOR);

        @(negedge clk);
        resetn = 1'b1;
        core_enable = 1'b1;

        wait_for_core_fault("out-of-range instruction fetch detected", 32'h00000500);

        @(negedge clk);
        resetn = 1'b0;
        core_enable = 1'b0;

        repeat (2) @(posedge clk);
        #1;

        check_32("final reset returns to reset vector", pc, RESET_VECTOR);
        check_1("final reset clears core fault", core_fault, 1'b0);

        if (failure_count == 0)
            $display("All %0d rv32_fpga_top tests passed.", test_count);
        else
            $display("%0d of %0d rv32_fpga_top tests failed.", failure_count, test_count);

        $finish;
    end

endmodule
