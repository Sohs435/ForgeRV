`timescale 1ns/1ps

module rv32_program_status_tb;

    import rv32_pkg::*;

    logic clk;
    logic resetn;

    logic memory_write_commit;
    logic [31:0] memory_write_address;
    logic [31:0] memory_write_data;
    memory_size_t memory_write_size;

    logic program_complete;
    logic [31:0] program_status;
    logic [31:0] failure_code;
    logic [31:0] observed_value;
    logic [31:0] expected_value;

    integer test_count;
    integer failure_count;

    rv32_program_status dut (
        .clk(clk),
        .resetn(resetn),

        .memory_write_commit(memory_write_commit),
        .memory_write_address(memory_write_address),
        .memory_write_data(memory_write_data),
        .memory_write_size(memory_write_size),

        .program_complete(program_complete),
        .program_status(program_status),
        .failure_code(failure_code),
        .observed_value(observed_value),
        .expected_value(expected_value)
    );

    always #4 clk = ~clk; // 8 ns period = 125 MHz

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

    task automatic perform_store (
        input logic [31:0] address,
        input logic [31:0] data,
        input memory_size_t size
    );
        begin
            @(negedge clk);

            memory_write_commit = 1'b1;
            memory_write_address = address;
            memory_write_data = data;
            memory_write_size = size;

            @(posedge clk);
            #1;

            @(negedge clk);

            memory_write_commit = 1'b0;
            memory_write_address = 32'b0;
            memory_write_data = 32'b0;
            memory_write_size = MEMORY_NONE;
        end
    endtask

    initial begin
        clk = 1'b0;
        resetn = 1'b0;

        memory_write_commit = 1'b0;
        memory_write_address = 32'b0;
        memory_write_data = 32'b0;
        memory_write_size = MEMORY_NONE;

        test_count = 0;
        failure_count = 0;

        repeat (3) @(posedge clk);
        #1;

        check_1(
            "reset clears program complete",
            program_complete,
            1'b0
        );

        check_32(
            "reset clears program status",
            program_status,
            32'b0
        );

        check_32(
            "reset clears failure code",
            failure_code,
            32'b0
        );

        check_32(
            "reset clears observed value",
            observed_value,
            32'b0
        );

        check_32(
            "reset clears expected value",
            expected_value,
            32'b0
        );

        @(negedge clk);
        resetn = 1'b1;

        // A word store to an unrelated address must be ignored.
        perform_store(
            32'h00000080,
            32'h12345678,
            MEMORY_WORD
        );

        check_32(
            "unrelated address leaves program status unchanged",
            program_status,
            32'b0
        );

        check_1(
            "unrelated address does not complete program",
            program_complete,
            1'b0
        );

        // A byte store to a monitored address must be ignored.
        perform_store(
            32'h00000040,
            32'hFFFFFFFF,
            MEMORY_BYTE
        );

        check_32(
            "byte store to status address ignored",
            program_status,
            32'b0
        );

        // A halfword store to a monitored address must also be ignored.
        perform_store(
            32'h00000040,
            32'hFFFFFFFF,
            MEMORY_HALF
        );

        check_32(
            "halfword store to status address ignored",
            program_status,
            32'b0
        );

        // Passing-program sequence.
        perform_store(
            32'h00000040,
            32'h00000001,
            MEMORY_WORD
        );

        check_32(
            "pass status captured",
            program_status,
            32'h00000001
        );

        check_1(
            "status write alone does not complete pass",
            program_complete,
            1'b0
        );

        perform_store(
            32'h00000044,
            32'h00000000,
            MEMORY_WORD
        );

        check_32(
            "pass failure code captured as zero",
            failure_code,
            32'h00000000
        );

        check_1(
            "pass sequence completes after failure-code write",
            program_complete,
            1'b1
        );

        // Completion must remain high until reset.
        perform_store(
            32'h00000080,
            32'hCAFEBABE,
            MEMORY_WORD
        );

        check_1(
            "program complete remains high",
            program_complete,
            1'b1
        );

        // Reset between the passing and failing tests.
        @(negedge clk);
        resetn = 1'b0;

        repeat (2) @(posedge clk);
        #1;

        check_1(
            "reset clears pass completion",
            program_complete,
            1'b0
        );

        check_32(
            "reset clears previous pass status",
            program_status,
            32'b0
        );

        @(negedge clk);
        resetn = 1'b1;

        // Failing-program sequence.
        perform_store(
            32'h00000040,
            32'hFFFFFFFF,
            MEMORY_WORD
        );

        check_32(
            "failure status captured",
            program_status,
            32'hFFFFFFFF
        );

        check_1(
            "failure status write does not complete program",
            program_complete,
            1'b0
        );

        perform_store(
            32'h00000044,
            32'd23,
            MEMORY_WORD
        );

        check_32(
            "failure test number captured",
            failure_code,
            32'd23
        );

        check_1(
            "failure-code write does not complete failure",
            program_complete,
            1'b0
        );

        perform_store(
            32'h00000048,
            32'h44332211,
            MEMORY_WORD
        );

        check_32(
            "observed value captured",
            observed_value,
            32'h44332211
        );

        check_1(
            "observed-value write does not complete failure",
            program_complete,
            1'b0
        );

        perform_store(
            32'h0000004C,
            32'h44332210,
            MEMORY_WORD
        );

        check_32(
            "expected value captured",
            expected_value,
            32'h44332210
        );

        check_1(
            "failure completes after expected-value write",
            program_complete,
            1'b1
        );

        check_32(
            "failure status retained",
            program_status,
            32'hFFFFFFFF
        );

        check_32(
            "failure code retained",
            failure_code,
            32'd23
        );

        check_32(
            "observed value retained",
            observed_value,
            32'h44332211
        );

        check_32(
            "expected value retained",
            expected_value,
            32'h44332210
        );

        // Final reset verifies that every result register is reusable.
        @(negedge clk);
        resetn = 1'b0;

        repeat (2) @(posedge clk);
        #1;

        check_1(
            "final reset clears program complete",
            program_complete,
            1'b0
        );

        check_32(
            "final reset clears program status",
            program_status,
            32'b0
        );

        check_32(
            "final reset clears failure code",
            failure_code,
            32'b0
        );

        check_32(
            "final reset clears observed value",
            observed_value,
            32'b0
        );

        check_32(
            "final reset clears expected value",
            expected_value,
            32'b0
        );

        if (failure_count == 0)
            $display(
                "All %0d rv32_program_status tests passed.",
                test_count
            );
        else
            $display(
                "%0d of %0d rv32_program_status tests failed.",
                failure_count,
                test_count
            );

        $finish;
    end

endmodule