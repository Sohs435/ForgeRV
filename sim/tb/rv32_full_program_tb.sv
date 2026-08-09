`timescale 1ns/1ps

module rv32_full_program_tb;

    localparam logic [31:0] RESET_VECTOR = 32'h00000100;
    localparam INSTRUCTION_MEMORY_DEPTH_WORDS = 256;
    localparam DATA_MEMORY_DEPTH_WORDS = 256;
    localparam INSTRUCTION_MEMORY_SIZE_BYTES =
        INSTRUCTION_MEMORY_DEPTH_WORDS * 4;

    localparam string PROGRAM_BINARY_PATH =
        "C:/root_pqnq/RISC-V/streamcore-rv/scripts/program.bin";

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
    logic [7:0] program_bytes [0:INSTRUCTION_MEMORY_SIZE_BYTES-1];

    logic program_status_written;
    logic failure_code_written;
    logic observed_value_written;
    logic expected_value_written;

    logic [31:0] program_status;
    logic [31:0] failure_code;
    logic [31:0] observed_value;
    logic [31:0] expected_value;

    logic execution_finished;

    integer program_file;
    integer bytes_read;
    integer test_count;
    integer failure_count;
    integer cycle_count;
    integer stall_count;
    integer control_transfer_count;
    integer register_commit_count;

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

    // Model the processor-facing one-cycle synchronous instruction Block RAM.
    always_ff @(posedge clk) begin
        if (instruction_memory_enable)
            instruction_memory_read_data <= instruction_memory[
                instruction_memory_address
            ];
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

        program_status_written = 1'b0;
        failure_code_written = 1'b0;
        observed_value_written = 1'b0;
        expected_value_written = 1'b0;

        program_status = 32'b0;
        failure_code = 32'b0;
        observed_value = 32'b0;
        expected_value = 32'b0;

        execution_finished = 1'b0;

        test_count = 0;
        failure_count = 0;
        cycle_count = 0;
        stall_count = 0;
        control_transfer_count = 0;
        register_commit_count = 0;

        for (int i = 0;
             i < INSTRUCTION_MEMORY_DEPTH_WORDS;
             i = i + 1)
            instruction_memory[i] = NOP;

        for (int i = 0;
             i < INSTRUCTION_MEMORY_SIZE_BYTES;
             i = i + 1)
            program_bytes[i] = 8'b0;

        $display("ForgeRV Full Compiled Program Test");
        $display("----------------------------------");
        $display(
            "Opening binary: %s",
            PROGRAM_BINARY_PATH
        );

        program_file = $fopen(
            PROGRAM_BINARY_PATH,
            "rb"
        );

        if (program_file == 0) begin
            $display(
                "FAIL: could not open program binary"
            );

            $display(
                "Check PROGRAM_BINARY_PATH in the testbench"
            );

            $finish;
        end

        bytes_read = $fread(
            program_bytes,
            program_file
        );

        $fclose(program_file);

        $display(
            "Read %0d bytes from program.bin",
            bytes_read
        );

        if (bytes_read !=
            INSTRUCTION_MEMORY_SIZE_BYTES) begin

            $display(
                "FAIL: expected %0d bytes but read %0d bytes",
                INSTRUCTION_MEMORY_SIZE_BYTES,
                bytes_read
            );

            $finish;
        end

        // program.bin stores each instruction in little-endian byte order.
        // Reassemble every four bytes into the 32-bit word expected by the processor.
        for (int i = 0;
             i < INSTRUCTION_MEMORY_DEPTH_WORDS;
             i = i + 1) begin

            instruction_memory[i] = {
                program_bytes[(i * 4) + 3],
                program_bytes[(i * 4) + 2],
                program_bytes[(i * 4) + 1],
                program_bytes[(i * 4)]
            };
        end

        $display(
            "First instruction: 0x%08h",
            instruction_memory[0]
        );

        $display(
            "Final instruction: 0x%08h",
            instruction_memory[255]
        );

        check_32(
            "first compiled instruction",
            instruction_memory[0],
            32'h07b00013
        );

        check_32(
            "final compiled instruction",
            instruction_memory[255],
            32'h0000006f
        );

        repeat (4) @(posedge clk);
        #1;

        check_32(
            "reset Program Counter",
            pc,
            RESET_VECTOR
        );

        check_1(
            "instruction memory disabled during reset",
            instruction_memory_enable,
            1'b0
        );

        check_1(
            "no core fault during reset",
            core_fault,
            1'b0
        );

        @(negedge clk);
        resetn = 1'b1;
        core_enable = 1'b0;

        repeat (3) @(posedge clk);
        #1;

        check_32(
            "core disabled Program Counter",
            pc,
            RESET_VECTOR
        );

        @(negedge clk);
        core_enable = 1'b1;

        $display("");
        $display("Starting complete assembly program");
        $display("----------------------------------");

        while (!execution_finished &&
               (cycle_count < 5000)) begin

            @(negedge clk);

            cycle_count = cycle_count + 1;

            if (pipeline_stalled)
                stall_count = stall_count + 1;

            if (control_transfer_taken)
                control_transfer_count =
                    control_transfer_count + 1;

            if (register_write_enable)
                register_commit_count =
                    register_commit_count + 1;

            // Mirror the program-status monitor by observing the
            // committed data-memory stores generated by the processor.
            if (dut.memory_write_enable) begin
                case (dut.ex_mem_memory_address)
                    32'd64: begin
                        program_status =
                            dut.ex_mem_store_data;

                        program_status_written =
                            1'b1;

                        $display(
                            "Program status store at cycle %0d: 0x%08h",
                            cycle_count,
                            dut.ex_mem_store_data
                        );
                    end

                    32'd68: begin
                        failure_code =
                            dut.ex_mem_store_data;

                        failure_code_written =
                            1'b1;

                        $display(
                            "Failure code store at cycle %0d: 0x%08h",
                            cycle_count,
                            dut.ex_mem_store_data
                        );
                    end

                    32'd72: begin
                        observed_value =
                            dut.ex_mem_store_data;

                        observed_value_written =
                            1'b1;

                        $display(
                            "Observed value store at cycle %0d: 0x%08h",
                            cycle_count,
                            dut.ex_mem_store_data
                        );
                    end

                    32'd76: begin
                        expected_value =
                            dut.ex_mem_store_data;

                        expected_value_written =
                            1'b1;

                        $display(
                            "Expected value store at cycle %0d: 0x%08h",
                            cycle_count,
                            dut.ex_mem_store_data
                        );
                    end

                    default: begin
                    end
                endcase
            end

            // A passing program writes status and then failure code zero.
            if (program_status_written &&
                (program_status == 32'h00000001) &&
                failure_code_written)
                execution_finished = 1'b1;

            // A failing program writes all four diagnostic words.
            if (program_status_written &&
                (program_status == 32'hffffffff) &&
                expected_value_written)
                execution_finished = 1'b1;

            // Stop immediately if the core enters its sticky fault state.
            if (core_fault) begin
                execution_finished = 1'b1;

                $display(
                    "Core fault detected at cycle %0d",
                    cycle_count
                );

                $display(
                    "Fault Program Counter: 0x%08h",
                    pc
                );

                $display(
                    "IF/ID PC: 0x%08h",
                    dut.if_id_pc
                );

                $display(
                    "ID/EX PC: 0x%08h",
                    dut.id_ex_pc
                );

                $display(
                    "EX/MEM memory address: 0x%08h",
                    dut.ex_mem_memory_address
                );
            end
        end

        @(negedge clk);
        core_enable = 1'b0;

        $display("");
        $display("Complete program results");
        $display("------------------------");
        $display(
            "Cycles executed: %0d",
            cycle_count
        );
        $display(
            "Pipeline stall cycles: %0d",
            stall_count
        );
        $display(
            "Control transfers: %0d",
            control_transfer_count
        );
        $display(
            "Register commits: %0d",
            register_commit_count
        );
        $display(
            "Final Program Counter: 0x%08h",
            pc
        );
        $display(
            "Core fault: %0d",
            core_fault
        );
        $display(
            "Program status: 0x%08h",
            program_status
        );
        $display(
            "Failure code: 0x%08h",
            failure_code
        );
        $display(
            "Observed value: 0x%08h",
            observed_value
        );
        $display(
            "Expected value: 0x%08h",
            expected_value
        );

        if (cycle_count >= 5000) begin
            test_count = test_count + 1;
            failure_count = failure_count + 1;

            $display(
                "FAIL: complete program timed out"
            );
        end

        check_1(
            "program status was written",
            program_status_written,
            1'b1
        );

        check_32(
            "program reports pass",
            program_status,
            32'h00000001
        );

        check_1(
            "failure code was written",
            failure_code_written,
            1'b1
        );

        check_32(
            "failure code is zero",
            failure_code,
            32'h00000000
        );

        check_1(
            "core completed without fault",
            core_fault,
            1'b0
        );

        if (program_status == 32'hffffffff) begin
            $display("");
            $display(
                "Assembly CHECK %0d failed",
                failure_code
            );

            $display(
                "Observed: 0x%08h",
                observed_value
            );

            $display(
                "Expected: 0x%08h",
                expected_value
            );
        end

        $display("");

        if (failure_count == 0)
            $display(
                "All %0d full-program tests passed.",
                test_count
            );
        else
            $display(
                "%0d of %0d full-program tests failed.",
                failure_count,
                test_count
            );

        $finish;
    end

endmodule