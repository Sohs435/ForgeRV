`timescale 1ns / 1ps

module rv32_memory_stage_tb;

    import rv32_pkg::*;

    localparam DEPTH_WORDS = 256;

    logic clk;
    logic [31:0] address;
    logic [31:0] store_data;
    logic memory_read_enable;
    logic memory_write_enable;
    memory_size_t memory_size;
    logic load_unsigned;

    logic [31:0] load_data;
    logic memory_access_misaligned;

    integer test_count;
    integer failure_count;

    rv32_memory_stage #(
        .DEPTH_WORDS(DEPTH_WORDS)
    ) dut (
        .clk(clk),
        .address(address),
        .store_data(store_data),
        .memory_read_enable(memory_read_enable),
        .memory_write_enable(memory_write_enable),
        .memory_size(memory_size),
        .load_unsigned(load_unsigned),

        .load_data(load_data),
        .memory_access_misaligned(memory_access_misaligned)
    );

    always #5 clk = ~clk;

    task automatic check_store(
        input logic [31:0] test_address,
        input logic [31:0] test_store_data,
        input memory_size_t test_memory_size,
        input logic [31:0] expected_write_data,
        input logic [3:0] expected_strobe,
        input logic expected_misaligned,
        input string test_name
    );
        logic expected_request;

        begin
            @(negedge clk);

            address = test_address;
            store_data = test_store_data;
            memory_size = test_memory_size;
            load_unsigned = 1'b0;
            memory_read_enable = 1'b0;
            memory_write_enable = 1'b1;

            #1;

            expected_request = !expected_misaligned;
            test_count = test_count + 1;

            if (
                dut.memory_address === {test_address[31:2], 2'b00} &&
                dut.memory_write_data === expected_write_data &&
                dut.memory_write_strobe === expected_strobe &&
                dut.memory_write_request === expected_request &&
                memory_access_misaligned === expected_misaligned
            ) begin
                $display(
                    "PASS: %s address=%08h write_data=%08h strobe=%04b misaligned=%0b",
                    test_name,
                    test_address,
                    dut.memory_write_data,
                    dut.memory_write_strobe,
                    memory_access_misaligned
                );
            end
            else begin
                failure_count = failure_count + 1;

                $display(
                    "FAIL: %s address=%08h write_data=%08h expected_data=%08h strobe=%04b expected_strobe=%04b request=%0b expected_request=%0b misaligned=%0b expected_misaligned=%0b",
                    test_name,
                    test_address,
                    dut.memory_write_data,
                    expected_write_data,
                    dut.memory_write_strobe,
                    expected_strobe,
                    dut.memory_write_request,
                    expected_request,
                    memory_access_misaligned,
                    expected_misaligned
                );
            end

            @(posedge clk);
            #1;

            memory_write_enable = 1'b0;
        end
    endtask

    task automatic check_load(
        input logic [31:0] test_address,
        input memory_size_t test_memory_size,
        input logic test_load_unsigned,
        input logic [31:0] expected_load_data,
        input logic expected_misaligned,
        input string test_name
    );
        logic expected_request;

        begin
            @(negedge clk);

            address = test_address;
            store_data = 32'b0;
            memory_size = test_memory_size;
            load_unsigned = test_load_unsigned;
            memory_read_enable = 1'b1;
            memory_write_enable = 1'b0;

            #1;

            expected_request = !expected_misaligned;
            test_count = test_count + 1;

            if (
                dut.memory_address === {test_address[31:2], 2'b00} &&
                dut.memory_read_request === expected_request &&
                load_data === expected_load_data &&
                memory_access_misaligned === expected_misaligned
            ) begin
                $display(
                    "PASS: %s address=%08h load_data=%08h misaligned=%0b",
                    test_name,
                    test_address,
                    load_data,
                    memory_access_misaligned
                );
            end
            else begin
                failure_count = failure_count + 1;

                $display(
                    "FAIL: %s address=%08h load_data=%08h expected_data=%08h request=%0b expected_request=%0b misaligned=%0b expected_misaligned=%0b",
                    test_name,
                    test_address,
                    load_data,
                    expected_load_data,
                    dut.memory_read_request,
                    expected_request,
                    memory_access_misaligned,
                    expected_misaligned
                );
            end

            @(posedge clk);
            #1;

            memory_read_enable = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        address = 32'b0;
        store_data = 32'b0;
        memory_read_enable = 1'b0;
        memory_write_enable = 1'b0;
        memory_size = MEMORY_NONE;
        load_unsigned = 1'b0;

        test_count = 0;
        failure_count = 0;

        #1;

        check_store(
            32'h00000020,
            32'hDEADBEEF,
            MEMORY_WORD,
            32'hDEADBEEF,
            4'b1111,
            1'b0,
            "SW aligned"
        );

        check_load(
            32'h00000020,
            MEMORY_WORD,
            1'b0,
            32'hDEADBEEF,
            1'b0,
            "LW after SW"
        );

        check_store(
            32'h00000040,
            32'h00000000,
            MEMORY_WORD,
            32'h00000000,
            4'b1111,
            1'b0,
            "initialize byte-store word"
        );

        check_store(
            32'h00000040,
            32'h123456AA,
            MEMORY_BYTE,
            32'hAAAAAAAA,
            4'b0001,
            1'b0,
            "SB byte offset 0"
        );

        check_store(
            32'h00000041,
            32'h123456BB,
            MEMORY_BYTE,
            32'hBBBBBBBB,
            4'b0010,
            1'b0,
            "SB byte offset 1"
        );

        check_store(
            32'h00000042,
            32'h123456CC,
            MEMORY_BYTE,
            32'hCCCCCCCC,
            4'b0100,
            1'b0,
            "SB byte offset 2"
        );

        check_store(
            32'h00000043,
            32'h123456DD,
            MEMORY_BYTE,
            32'hDDDDDDDD,
            4'b1000,
            1'b0,
            "SB byte offset 3"
        );

        check_load(
            32'h00000040,
            MEMORY_WORD,
            1'b0,
            32'hDDCCBBAA,
            1'b0,
            "little-endian byte-store result"
        );

        check_store(
            32'h00000060,
            32'hAABBCCDD,
            MEMORY_WORD,
            32'hAABBCCDD,
            4'b1111,
            1'b0,
            "initialize halfword-store word"
        );

        check_store(
            32'h00000060,
            32'hDEAD1122,
            MEMORY_HALF,
            32'h11221122,
            4'b0011,
            1'b0,
            "SH lower halfword"
        );

        check_load(
            32'h00000060,
            MEMORY_WORD,
            1'b0,
            32'hAABB1122,
            1'b0,
            "SH preserves upper bytes"
        );

        check_store(
            32'h00000062,
            32'hCAFE3344,
            MEMORY_HALF,
            32'h33443344,
            4'b1100,
            1'b0,
            "SH upper halfword"
        );

        check_load(
            32'h00000060,
            MEMORY_WORD,
            1'b0,
            32'h33441122,
            1'b0,
            "combined halfword-store result"
        );

        check_store(
            32'h00000080,
            32'h80FF7F01,
            MEMORY_WORD,
            32'h80FF7F01,
            4'b1111,
            1'b0,
            "initialize load-test word"
        );

        check_load(
            32'h00000081,
            MEMORY_BYTE,
            1'b0,
            32'h0000007F,
            1'b0,
            "LB positive byte"
        );

        check_load(
            32'h00000082,
            MEMORY_BYTE,
            1'b0,
            32'hFFFFFFFF,
            1'b0,
            "LB negative byte"
        );

        check_load(
            32'h00000082,
            MEMORY_BYTE,
            1'b1,
            32'h000000FF,
            1'b0,
            "LBU zero extension"
        );

        check_load(
            32'h00000083,
            MEMORY_BYTE,
            1'b0,
            32'hFFFFFF80,
            1'b0,
            "LB highest byte"
        );

        check_load(
            32'h00000083,
            MEMORY_BYTE,
            1'b1,
            32'h00000080,
            1'b0,
            "LBU highest byte"
        );

        check_load(
            32'h00000080,
            MEMORY_HALF,
            1'b0,
            32'h00007F01,
            1'b0,
            "LH positive halfword"
        );

        check_load(
            32'h00000082,
            MEMORY_HALF,
            1'b0,
            32'hFFFF80FF,
            1'b0,
            "LH negative halfword"
        );

        check_load(
            32'h00000082,
            MEMORY_HALF,
            1'b1,
            32'h000080FF,
            1'b0,
            "LHU zero extension"
        );

        check_load(
            32'h00000080,
            MEMORY_WORD,
            1'b0,
            32'h80FF7F01,
            1'b0,
            "LW complete word"
        );

        check_store(
            32'h000000A0,
            32'h12345678,
            MEMORY_WORD,
            32'h12345678,
            4'b1111,
            1'b0,
            "initialize misalignment-test word"
        );

        check_store(
            32'h000000A1,
            32'hCAFEBABE,
            MEMORY_HALF,
            32'hBABEBABE,
            4'b0000,
            1'b1,
            "misaligned SH offset 1"
        );

        check_store(
            32'h000000A3,
            32'hCAFEBABE,
            MEMORY_HALF,
            32'hBABEBABE,
            4'b0000,
            1'b1,
            "misaligned SH offset 3"
        );

        check_load(
            32'h000000A0,
            MEMORY_WORD,
            1'b0,
            32'h12345678,
            1'b0,
            "misaligned SH writes suppressed"
        );

        check_store(
            32'h000000A1,
            32'hDEADBEEF,
            MEMORY_WORD,
            32'hDEADBEEF,
            4'b0000,
            1'b1,
            "misaligned SW offset 1"
        );

        check_store(
            32'h000000A2,
            32'hDEADBEEF,
            MEMORY_WORD,
            32'hDEADBEEF,
            4'b0000,
            1'b1,
            "misaligned SW offset 2"
        );

        check_store(
            32'h000000A3,
            32'hDEADBEEF,
            MEMORY_WORD,
            32'hDEADBEEF,
            4'b0000,
            1'b1,
            "misaligned SW offset 3"
        );

        check_load(
            32'h000000A0,
            MEMORY_WORD,
            1'b0,
            32'h12345678,
            1'b0,
            "misaligned SW writes suppressed"
        );

        check_load(
            32'h000000A1,
            MEMORY_HALF,
            1'b0,
            32'h00000000,
            1'b1,
            "misaligned LH"
        );

        check_load(
            32'h000000A2,
            MEMORY_WORD,
            1'b0,
            32'h00000000,
            1'b1,
            "misaligned LW"
        );

        check_store(
            32'h000000C0,
            32'h0BADF00D,
            MEMORY_WORD,
            32'h0BADF00D,
            4'b1111,
            1'b0,
            "initialize disabled-write word"
        );

        @(negedge clk);

        address = 32'h000000C0;
        store_data = 32'hFFFFFFFF;
        memory_size = MEMORY_WORD;
        load_unsigned = 1'b0;
        memory_read_enable = 1'b0;
        memory_write_enable = 1'b0;

        #1;

        test_count = test_count + 1;

        if (
            dut.memory_write_request === 1'b0 &&
            dut.memory_write_strobe === 4'b0000 &&
            memory_access_misaligned === 1'b0
        ) begin
            $display("PASS: disabled write ignored");
        end
        else begin
            failure_count = failure_count + 1;
            $display("FAIL: disabled write generated a memory transaction");
        end

        @(posedge clk);
        #1;

        check_load(
            32'h000000C0,
            MEMORY_WORD,
            1'b0,
            32'h0BADF00D,
            1'b0,
            "disabled write preserved memory"
        );

        @(negedge clk);

        address = 32'h000000C0;
        store_data = 32'b0;
        memory_size = MEMORY_WORD;
        load_unsigned = 1'b0;
        memory_read_enable = 1'b0;
        memory_write_enable = 1'b0;

        #1;

        test_count = test_count + 1;

        if (
            dut.memory_read_request === 1'b0 &&
            load_data === 32'b0 &&
            memory_access_misaligned === 1'b0
        ) begin
            $display("PASS: disabled read returns no load data");
        end
        else begin
            failure_count = failure_count + 1;
            $display("FAIL: disabled read generated a memory transaction");
        end

        @(negedge clk);

        address = 32'h000000C0;
        memory_size = MEMORY_NONE;
        memory_read_enable = 1'b1;
        memory_write_enable = 1'b0;

        #1;

        test_count = test_count + 1;

        if (
            dut.memory_read_request === 1'b0 &&
            load_data === 32'b0 &&
            memory_access_misaligned === 1'b0
        ) begin
            $display("PASS: MEMORY_NONE generates no request");
        end
        else begin
            failure_count = failure_count + 1;
            $display("FAIL: MEMORY_NONE generated a memory transaction");
        end

        memory_read_enable = 1'b0;
        memory_size = MEMORY_NONE;

        #1;

        if (failure_count == 0) begin
            $display("All %0d rv32_memory_stage tests passed.", test_count);
        end
        else begin
            $fatal(
                1,
                "%0d of %0d rv32_memory_stage tests failed.",
                failure_count,
                test_count
            );
        end

        $finish;
    end

endmodule