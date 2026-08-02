`timescale 1ns / 1ps

module rv32_imm_gen_tb;

    import rv32_pkg::*;

    logic [31:0] instruction;
    imm_type_t immediate_type;
    logic [31:0] immediate;

    integer test_count;
    integer failure_count;

    rv32_imm_gen dut (
        .instruction(instruction),
        .immediate_type(immediate_type),
        .immediate(immediate)
    );

    task automatic check_immediate (
        input logic [31:0] test_instruction,
        input imm_type_t test_type,
        input logic [31:0] expected_immediate,
        input string test_name
    );
        begin
            instruction = test_instruction;
            immediate_type = test_type;

            #1;

            test_count = test_count + 1;

            if (immediate !== expected_immediate) begin
                failure_count = failure_count + 1;

                $display(
                    "FAIL: %s instruction=%h type=%0d expected=%h result=%h",
                    test_name,
                    instruction,
                    immediate_type,
                    expected_immediate,
                    immediate
                );
            end
            else begin
                $display(
                    "PASS: %s immediate=%h",
                    test_name,
                    immediate
                );
            end
        end
    endtask

    initial begin
        instruction = 32'b0;
        immediate_type = IMM_NONE;
        test_count = 0;
        failure_count = 0;

        #1;

        check_immediate(
            32'h00500093,
            IMM_I,
            32'h00000005,
            "I-type positive immediate"
        );

        check_immediate(
            32'hFFC00093,
            IMM_I,
            32'hFFFFFFFC,
            "I-type negative immediate"
        );

        check_immediate(
            32'h7FF00093,
            IMM_I,
            32'h000007FF,
            "I-type maximum positive immediate"
        );

        check_immediate(
            32'h00512623,
            IMM_S,
            32'h0000000C,
            "S-type positive offset"
        );

        check_immediate(
            32'hFE512E23,
            IMM_S,
            32'hFFFFFFFC,
            "S-type negative offset"
        );

        check_immediate(
            32'h00208463,
            IMM_B,
            32'h00000008,
            "B-type forward branch"
        );

        check_immediate(
            32'hFE208EE3,
            IMM_B,
            32'hFFFFFFFC,
            "B-type backward branch"
        );

        check_immediate(
            32'h123452B7,
            IMM_U,
            32'h12345000,
            "U-type upper immediate"
        );

        check_immediate(
            32'hABCDE2B7,
            IMM_U,
            32'hABCDE000,
            "U-type high-bit immediate"
        );

        check_immediate(
            32'h008000EF,
            IMM_J,
            32'h00000008,
            "J-type forward jump"
        );

        check_immediate(
            32'hFFDFF0EF,
            IMM_J,
            32'hFFFFFFFC,
            "J-type backward jump"
        );

        check_immediate(
            32'h002081B3,
            IMM_NONE,
            32'h00000000,
            "R-type has no immediate"
        );

        if (failure_count == 0) begin
            $display(
                "All %0d rv32_imm_gen tests passed.",
                test_count
            );
        end
        else begin
            $fatal(
                1,
                "%0d of %0d rv32_imm_gen tests failed.",
                failure_count,
                test_count
            );
        end

        $finish;
    end

endmodule