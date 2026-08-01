`timescale 1ns / 1ps

module rv32_regfile_tb;

    logic        clk;

    logic [4:0]  rs1_address;
    logic [4:0]  rs2_address;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;

    logic        rd_write_enable;
    logic [4:0]  rd_address;
    logic [31:0] rd_data;

    integer test_count;
    integer failure_count;

    rv32_regfile dut (
        .clk             (clk),
        .rs1_address     (rs1_address),
        .rs2_address     (rs2_address),
        .rs1_data        (rs1_data),
        .rs2_data        (rs2_data),
        .rd_write_enable (rd_write_enable),
        .rd_address      (rd_address),
        .rd_data         (rd_data)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic write_register (
        input logic [4:0]  address,
        input logic [31:0] data
    );
        begin
            @(negedge clk);

            rd_write_enable = 1'b1;
            rd_address      = address;
            rd_data         = data;

            @(posedge clk);
            #1;

            rd_write_enable = 1'b0;
        end
    endtask

    task automatic check_reads (
        input logic [4:0]  address_1,
        input logic [4:0]  address_2,
        input logic [31:0] expected_1,
        input logic [31:0] expected_2,
        input string       test_name
    );
        begin
            rs1_address = address_1;
            rs2_address = address_2;

            #1;

            test_count = test_count + 1;

            if ((rs1_data !== expected_1) ||
                (rs2_data !== expected_2)) begin

                failure_count = failure_count + 1;

                $display(
                    "FAIL: %s rs1=x%0d data=%h expected=%h rs2=x%0d data=%h expected=%h",
                    test_name,
                    address_1,
                    rs1_data,
                    expected_1,
                    address_2,
                    rs2_data,
                    expected_2
                );
            end
            else begin
                $display(
                    "PASS: %s rs1=%h rs2=%h",
                    test_name,
                    rs1_data,
                    rs2_data
                );
            end
        end
    endtask

    initial begin
        rs1_address     = 5'd0;
        rs2_address     = 5'd0;
        rd_write_enable = 1'b0;
        rd_address      = 5'd0;
        rd_data         = 32'b0;

        test_count      = 0;
        failure_count   = 0;

        #1;

        // x0 must always read as zero.
        check_reads(
            5'd0,
            5'd0,
            32'b0,
            32'b0,
            "x0 reads as zero"
        );

        // Write two normal registers.
        write_register(5'd1, 32'h1111_1111);
        write_register(5'd2, 32'h2222_2222);

        // Read two different registers simultaneously.
        check_reads(
            5'd1,
            5'd2,
            32'h1111_1111,
            32'h2222_2222,
            "simultaneous reads"
        );

        // Overwrite x1 while preserving x2.
        write_register(5'd1, 32'hDEAD_BEEF);

        check_reads(
            5'd1,
            5'd2,
            32'hDEAD_BEEF,
            32'h2222_2222,
            "register overwrite"
        );

        // Give x3 a known value.
        write_register(5'd3, 32'h1234_5678);

        // Attempt to overwrite x3 while write enable is low.
        @(negedge clk);

        rd_write_enable = 1'b0;
        rd_address      = 5'd3;
        rd_data         = 32'hCAFE_BABE;

        @(posedge clk);
        #1;

        check_reads(
            5'd3,
            5'd1,
            32'h1234_5678,
            32'hDEAD_BEEF,
            "disabled write ignored"
        );

        // Attempt to write x0.
        write_register(5'd0, 32'hFFFF_FFFF);

        check_reads(
            5'd0,
            5'd1,
            32'b0,
            32'hDEAD_BEEF,
            "write to x0 ignored"
        );

        // Both read ports select the same register.
        check_reads(
            5'd2,
            5'd2,
            32'h2222_2222,
            32'h2222_2222,
            "same register on both read ports"
        );

        // Back-to-back writes to different registers.
        write_register(5'd4, 32'h4444_4444);
        write_register(5'd5, 32'h5555_5555);

        check_reads(
            5'd4,
            5'd5,
            32'h4444_4444,
            32'h5555_5555,
            "back-to-back writes"
        );

        // Test the highest register address.
        write_register(5'd31, 32'hFFFF_0031);

        check_reads(
            5'd31,
            5'd0,
            32'hFFFF_0031,
            32'b0,
            "highest register address"
        );

        if (failure_count == 0) begin
            $display(
                "All %0d rv32_regfile tests passed.",
                test_count
            );
        end
        else begin
            $fatal(
                1,
                "%0d of %0d rv32_regfile tests failed.",
                failure_count,
                test_count
            );
        end

        $finish;
    end

endmodule