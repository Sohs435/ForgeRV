`timescale 1ns / 1ps

module rv32_alu_tb;

    import rv32_pkg::*;

    logic [31:0] lhs;
    logic [31:0] rhs;
    alu_op_t     operation;
    logic [31:0] result;

    integer test_count;
    integer failure_count;

    rv32_alu dut (
        .lhs       (lhs),
        .rhs       (rhs),
        .operation (operation),
        .result    (result)
    );

    task automatic check_alu (
        input alu_op_t    test_operation,
        input logic [31:0] test_lhs,
        input logic [31:0] test_rhs,
        input logic [31:0] expected_result,
        input string       test_name
    );
        begin
            operation = test_operation;
            lhs       = test_lhs;
            rhs       = test_rhs;

            #1;

            test_count = test_count + 1;

            if (result !== expected_result) begin
                failure_count = failure_count + 1;

                $display(
                    "FAIL: %s lhs=%h rhs=%h expected=%h result=%h",
                    test_name,
                    lhs,
                    rhs,
                    expected_result,
                    result
                );
            end
            else begin
                $display(
                    "PASS: %s result=%h",
                    test_name,
                    result
                );
            end
        end
    endtask

    initial begin
        lhs           = 32'b0;
        rhs           = 32'b0;
        operation     = ALU_ADD;
        test_count    = 0;
        failure_count = 0;

        // Addition
        check_alu(ALU_ADD, 32'd10, 32'd20,
                  32'd30, "ADD normal");

        check_alu(ALU_ADD, 32'hFFFF_FFFF, 32'd1,
                  32'h0000_0000, "ADD wraparound");

        // Subtraction
        check_alu(ALU_SUB, 32'd20, 32'd10,
                  32'd10, "SUB normal");

        check_alu(ALU_SUB, 32'd5, 32'd7,
                  32'hFFFF_FFFE, "SUB wraparound");

        // Left shift
        check_alu(ALU_SLL, 32'h0000_0001, 32'd31,
                  32'h8000_0000, "SLL by 31");

        check_alu(ALU_SLL, 32'h0000_0001, 32'd33,
                  32'h0000_0002, "SLL lower five bits");

        // Signed comparison
        check_alu(ALU_SLT, 32'hFFFF_FFFF, 32'd1,
                  32'd1, "SLT negative less than positive");

        check_alu(ALU_SLT, 32'd1, 32'hFFFF_FFFF,
                  32'd0, "SLT positive not less than negative");

        // Unsigned comparison
        check_alu(ALU_SLTU, 32'hFFFF_FFFF, 32'd1,
                  32'd0, "SLTU maximum not less than one");

        check_alu(ALU_SLTU, 32'd1, 32'hFFFF_FFFF,
                  32'd1, "SLTU one less than maximum");

        // Bitwise operations
        check_alu(ALU_XOR, 32'hA5A5_F0F0, 32'h5A5A_0FF0,
                  32'hFFFF_FF00, "XOR");

        check_alu(ALU_OR, 32'hF0F0_0000, 32'h0000_0F0F,
                  32'hF0F0_0F0F, "OR");

        check_alu(ALU_AND, 32'hFFFF_00FF, 32'h0F0F_F0F0,
                  32'h0F0F_00F0, "AND");

        // Right shifts
        check_alu(ALU_SRL, 32'h8000_0000, 32'd31,
                  32'h0000_0001, "SRL by 31");

        check_alu(ALU_SRA, 32'h8000_0000, 32'd31,
                  32'hFFFF_FFFF, "SRA sign extension");

        // Pass operand B
        check_alu(ALU_COPY_B, 32'h1234_5678, 32'hDEAD_BEEF,
                  32'hDEAD_BEEF, "COPY_B");

        if (failure_count == 0) begin
            $display(
                "All %0d rv32_alu tests passed.",
                test_count
            );
        end
        else begin
            $fatal(
                1,
                "%0d of %0d rv32_alu tests failed.",
                failure_count,
                test_count
            );
        end

        $finish;
    end

endmodule