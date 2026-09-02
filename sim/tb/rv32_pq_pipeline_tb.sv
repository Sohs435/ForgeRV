`timescale 1ns / 1ps

module rv32_pq_pipeline_tb;

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
    logic [$clog2(INSTRUCTION_MEMORY_DEPTH_WORDS)-1:0] instruction_memory_address;

    logic [31:0] pc;
    logic [31:0] writeback_data;
    logic register_write_enable;
    logic pipeline_stalled;
    logic control_transfer_taken;
    logic core_fault;

    logic data_memory_write_commit;
    logic [31:0] data_memory_write_address;
    logic [31:0] data_memory_write_data;
    memory_size_t data_memory_write_size;

    logic [31:0] instruction_memory [0:INSTRUCTION_MEMORY_DEPTH_WORDS-1];
    logic [31:0] observed_registers [0:31];

    logic load_use_stall_seen;
    logic load_to_pq_forward_seen;
    logic alu_to_pq_forward_seen;
    logic pq_to_alu_forward_seen;

    logic pq_hold_seen;
    logic pq_hold_error;
    logic pq_bubble_seen;
    logic pq_bubble_error;
    logic pq_done_seen;
    logic pq_protocol_error;
    logic pq_stall_length_error;
    logic pq_stall_window_active;

    logic [31:0] held_pc;
    logic [31:0] held_if_id_pc;
    logic [31:0] held_if_id_instruction;
    logic [31:0] held_id_ex_pc;

    logic [31:0] stall_count;
    logic [31:0] load_use_stall_count;
    logic [31:0] pq_stall_count;
    logic [31:0] pq_completion_count;
    logic [31:0] pq_stall_window_count;
    logic [31:0] current_pq_stall_length;

    integer failure_count;
    integer timeout_count;
    integer i;

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
        .core_fault(core_fault),

        .data_memory_write_commit(
            data_memory_write_commit
        ),
        .data_memory_write_address(
            data_memory_write_address
        ),
        .data_memory_write_data(
            data_memory_write_data
        ),
        .data_memory_write_size(
            data_memory_write_size
        )
    );

    always #5 clk = ~clk;

    // Model the one-cycle synchronous instruction Block RAM.
    always_ff @(posedge clk) begin
        if (!resetn)
            instruction_memory_read_data <= NOP;
        else if (instruction_memory_enable)
            instruction_memory_read_data <=
                instruction_memory[
                    instruction_memory_address
                ];
    end

    // Reconstruct the architectural register state from writeback.
    always_ff @(posedge clk) begin
        if (!resetn) begin
            for (int register_index = 0;
                     register_index < 32;
                     register_index = register_index + 1)
                observed_registers[register_index] <= 32'b0;
        end
        else if (
            register_write_enable &&
            dut.mem_wb_rd_address != 5'd0
        ) begin
            observed_registers[
                dut.mem_wb_rd_address
            ] <= writeback_data;
        end
    end

    // Sample halfway through each cycle, after all rising-edge pipeline
    // register updates and PQ-unit state changes have settled.
    always @(negedge clk) begin
        if (!resetn) begin
            load_use_stall_seen = 1'b0;
            load_to_pq_forward_seen = 1'b0;
            alu_to_pq_forward_seen = 1'b0;
            pq_to_alu_forward_seen = 1'b0;

            pq_hold_seen = 1'b0;
            pq_hold_error = 1'b0;
            pq_bubble_seen = 1'b0;
            pq_bubble_error = 1'b0;
            pq_done_seen = 1'b0;
            pq_protocol_error = 1'b0;
            pq_stall_length_error = 1'b0;
            pq_stall_window_active = 1'b0;

            held_pc = 32'b0;
            held_if_id_pc = 32'b0;
            held_if_id_instruction = 32'b0;
            held_id_ex_pc = 32'b0;

            stall_count = 32'b0;
            load_use_stall_count = 32'b0;
            pq_stall_count = 32'b0;
            pq_completion_count = 32'b0;
            pq_stall_window_count = 32'b0;
            current_pq_stall_length = 32'b0;
        end
        else begin
            if (pipeline_stalled)
                stall_count = stall_count + 1'b1;

            if (dut.load_use_stall)
                load_use_stall_count =
                    load_use_stall_count + 1'b1;

            if (dut.pq_stall)
                pq_stall_count = pq_stall_count + 1'b1;

            // pq_done is a single-cycle completion pulse, so it counts
            // completed instructions instead of repeatedly counting the
            // PQ instruction while it is held in ID/EX.
            if (dut.pq_done)
                pq_completion_count =
                    pq_completion_count + 1'b1;

            // LW x11 is in Execute while the dependent PQ instruction
            // is held in Decode.
            if (
                dut.load_use_stall &&
                dut.decode_alu_operation == ALU_PQ &&
                dut.decode_rs1_address == 5'd11 &&
                dut.id_ex_rd_address == 5'd11
            )
                load_use_stall_seen = 1'b1;

            // The recently loaded x11 value must reach PQ from MEM/WB.
            if (
                dut.id_ex_valid &&
                dut.id_ex_alu_operation == ALU_PQ &&
                dut.id_ex_rs1_address == 5'd11 &&
                dut.forward_a_select == FORWARD_MEM_WB
            )
                load_to_pq_forward_seen = 1'b1;

            // LUI x8 is immediately followed by PQ using x8.
            if (
                dut.id_ex_valid &&
                dut.id_ex_alu_operation == ALU_PQ &&
                dut.id_ex_rs1_address == 5'd8 &&
                dut.forward_a_select == FORWARD_EX_MEM
            )
                alu_to_pq_forward_seen = 1'b1;

            // PQ x3 is immediately followed by ADDI using x3.
            if (
                dut.id_ex_valid &&
                dut.id_ex_rs1_address == 5'd3 &&
                dut.forward_a_select == FORWARD_EX_MEM
            )
                pq_to_alu_forward_seen = 1'b1;

            // Each PQ instruction must hold PC, IF/ID and ID/EX for two
            // cycles. Unlike a load-use stall, it must not flush ID/EX.
            if (dut.pq_stall) begin
                pq_bubble_seen = 1'b1;

                if (
                    !pipeline_stalled ||
                    dut.id_ex_flush ||
                    !dut.id_ex_valid ||
                    dut.id_ex_alu_operation != ALU_PQ ||
                    !dut.pq_busy
                )
                    pq_protocol_error = 1'b1;

                if (dut.ex_mem_valid_in)
                    pq_bubble_error = 1'b1;

                if (!pq_stall_window_active) begin
                    pq_stall_window_active = 1'b1;
                    current_pq_stall_length = 32'd1;

                    held_pc = pc;
                    held_if_id_pc = dut.if_id_pc;
                    held_if_id_instruction =
                        dut.if_id_instruction;
                    held_id_ex_pc = dut.id_ex_pc;
                end
                else begin
                    current_pq_stall_length =
                        current_pq_stall_length + 1'b1;

                    pq_hold_seen = 1'b1;

                    if (
                        pc != held_pc ||
                        dut.if_id_pc != held_if_id_pc ||
                        dut.if_id_instruction !=
                            held_if_id_instruction ||
                        dut.id_ex_pc != held_id_ex_pc
                    )
                        pq_hold_error = 1'b1;
                end
            end
            else if (pq_stall_window_active) begin
                if (current_pq_stall_length != 32'd2)
                    pq_stall_length_error = 1'b1;

                pq_stall_window_count =
                    pq_stall_window_count + 1'b1;
                pq_stall_window_active = 1'b0;
                current_pq_stall_length = 32'b0;
            end

            // When done is asserted, the completed PQ result must become
            // a valid EX/MEM input on that same cycle.
            if (dut.pq_done) begin
                pq_done_seen = 1'b1;

                if (
                    !dut.pq_busy ||
                    !dut.ex_mem_valid_in ||
                    dut.ex_execute_result != dut.ex_pq_result
                )
                    pq_protocol_error = 1'b1;
            end
        end
    end

    function automatic logic [31:0] encode_lui (
        input logic [4:0] rd,
        input logic [19:0] immediate
    );
        encode_lui = {
            immediate,
            rd,
            OPCODE_LUI
        };
    endfunction

    function automatic logic [31:0] encode_addi (
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [11:0] immediate
    );
        encode_addi = {
            immediate,
            rs1,
            3'b000,
            rd,
            OPCODE_OP_IMM
        };
    endfunction

    function automatic logic [31:0] encode_sw (
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic signed [11:0] immediate
    );
        encode_sw = {
            immediate[11:5],
            rs2,
            rs1,
            3'b010,
            immediate[4:0],
            OPCODE_STORE
        };
    endfunction

    function automatic logic [31:0] encode_lw (
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [11:0] immediate
    );
        encode_lw = {
            immediate,
            rs1,
            3'b010,
            rd,
            OPCODE_LOAD
        };
    endfunction

    function automatic logic [31:0] encode_pq (
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2
    );
        encode_pq = {
            FUNCT7_PQ,
            rs2,
            rs1,
            FUNCT3_PQ,
            rd,
            OPCODE_CUSTOM_0
        };
    endfunction

    task automatic check_32 (
        input string test_name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        begin
            if (actual !== expected) begin
                $display(
                    "FAIL: %s expected=%08h observed=%08h",
                    test_name,
                    expected,
                    actual
                );

                failure_count = failure_count + 1;
            end
            else begin
                $display(
                    "PASS: %s value=%08h",
                    test_name,
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
            if (actual !== expected) begin
                $display(
                    "FAIL: %s expected=%0b observed=%0b",
                    test_name,
                    expected,
                    actual
                );

                failure_count = failure_count + 1;
            end
            else begin
                $display(
                    "PASS: %s value=%0b",
                    test_name,
                    actual
                );
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        resetn = 1'b0;
        core_enable = 1'b0;

        failure_count = 0;
        timeout_count = 0;

        for (
            i = 0;
            i < INSTRUCTION_MEMORY_DEPTH_WORDS;
            i = i + 1
        )
            instruction_memory[i] = NOP;

        // ---------------------------------------------------------
        // Test 1:
        //
        // v_alpha = 0.5, i_alpha = 0.5
        // v_beta  = 0.5, i_beta  = 0.0
        //
        // p = 3/2(0.5*0.5 + 0.5*0.0) = 0.375
        // q = 3/2(0.5*0.5 - 0.5*0.0) = 0.375
        //
        // 0.375 in Q2.14 = 0x1800
        // Expected packed result = 0x18001800
        // ---------------------------------------------------------

        instruction_memory[0] =
            encode_lui(5'd1, 20'h40004);

        instruction_memory[1] =
            encode_lui(5'd2, 20'h40000);

        instruction_memory[2] =
            encode_pq(5'd3, 5'd1, 5'd2);

        // Tests PQ -> ALU forwarding.
        instruction_memory[3] =
            encode_addi(5'd4, 5'd3, 12'sd1);

        // ---------------------------------------------------------
        // Test 2:
        //
        // v_alpha = 0.5, i_alpha = 0.0
        // v_beta  = 0.0, i_beta  = 0.5
        //
        // p = 0
        // q = 3/2(0 - 0.5*0.5) = -0.375
        //
        // -0.375 in Q2.14 = 0xE800
        // Expected packed result = 0xE8000000
        // ---------------------------------------------------------

        instruction_memory[4] =
            encode_lui(5'd5, 20'h40000);

        instruction_memory[5] =
            encode_lui(5'd6, 20'h00004);

        instruction_memory[6] =
            encode_pq(5'd7, 5'd5, 5'd6);

        // ---------------------------------------------------------
        // Test 3: ALU -> PQ forwarding
        //
        // x8 is produced immediately before PQ reads it.
        //
        // v_alpha = 0.5, i_alpha = 0.5
        // beta vector = 0
        //
        // Expected p = 0.375, q = 0
        // ---------------------------------------------------------

        instruction_memory[7] =
            encode_lui(5'd8, 20'h40004);

        instruction_memory[8] =
            encode_pq(5'd9, 5'd8, 5'd0);

        // ---------------------------------------------------------
        // Test 4: Load -> PQ hazard
        //
        // Store 0x40004000, load it into x11 and immediately use
        // x11 in PQ. The load-use hazard inserts one bubble before
        // the PQ unit then applies its own two-cycle structural stall.
        // ---------------------------------------------------------

        instruction_memory[9] =
            encode_lui(5'd10, 20'h40004);

        instruction_memory[10] =
            encode_sw(5'd10, 5'd0, 12'sd0);

        instruction_memory[11] =
            encode_lw(5'd11, 5'd0, 12'sd0);

        instruction_memory[12] =
            encode_pq(5'd12, 5'd11, 5'd0);

        // Completion marker.
        instruction_memory[13] =
            encode_addi(5'd31, 5'd0, 12'sd1);

        repeat (5) @(posedge clk);
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

        resetn = 1'b1;

        repeat (2) @(posedge clk);
        #1;

        core_enable = 1'b1;

        $display("");
        $display("ForgeRV PQ pipeline test");
        $display("------------------------");

        timeout_count = 0;

        while (
            observed_registers[31] !== 32'd1 &&
            timeout_count < 300
        ) begin
            @(posedge clk);
            #1;

            timeout_count = timeout_count + 1;
        end

        core_enable = 1'b0;

        @(posedge clk);
        #1;

        if (timeout_count == 300) begin
            $display(
                "FAIL: pipeline timed out before completion"
            );

            failure_count = failure_count + 1;
        end

        $display("");
        $display("Checking PQ arithmetic results");

        check_32(
            "positive active and reactive power",
            observed_registers[3],
            32'h18001800
        );

        check_32(
            "PQ result forwarded into ADDI",
            observed_registers[4],
            32'h18001801
        );

        check_32(
            "negative reactive power",
            observed_registers[7],
            32'hE8000000
        );

        check_32(
            "ALU value forwarded into PQ",
            observed_registers[9],
            32'h00001800
        );

        check_32(
            "loaded value forwarded into PQ",
            observed_registers[12],
            32'h00001800
        );

        $display("");
        $display("Checking pipeline hazard handling");

        check_1(
            "load-use stall detected",
            load_use_stall_seen,
            1'b1
        );

        check_1(
            "load value forwarded from MEM/WB into PQ",
            load_to_pq_forward_seen,
            1'b1
        );

        check_1(
            "ALU value forwarded from EX/MEM into PQ",
            alu_to_pq_forward_seen,
            1'b1
        );

        check_1(
            "PQ result forwarded from EX/MEM",
            pq_to_alu_forward_seen,
            1'b1
        );

        check_1(
            "PQ stall holds the pipeline registers",
            pq_hold_seen && !pq_hold_error,
            1'b1
        );

        check_1(
            "PQ stall inserts EX/MEM bubbles",
            pq_bubble_seen && !pq_bubble_error,
            1'b1
        );

        check_1(
            "PQ done transfers result into EX/MEM",
            pq_done_seen && !pq_protocol_error,
            1'b1
        );

        check_1(
            "every PQ stall lasts exactly two cycles",
            !pq_stall_length_error,
            1'b1
        );

        check_32(
            "one load-use stall cycle",
            load_use_stall_count,
            32'd1
        );

        check_32(
            "eight PQ structural-stall cycles",
            pq_stall_count,
            32'd8
        );

        check_32(
            "nine combined pipeline-stall cycles",
            stall_count,
            32'd9
        );

        check_32(
            "four PQ stall windows",
            pq_stall_window_count,
            32'd4
        );

        check_32(
            "four PQ instructions completed",
            pq_completion_count,
            32'd4
        );

        check_1(
            "valid PQ program completed without fault",
            core_fault,
            1'b0
        );

        // ---------------------------------------------------------
        // Test an unsupported instruction in the Custom-0 space.
        // funct3=001 is not currently defined and must cause a fault.
        // ---------------------------------------------------------

        $display("");
        $display("Checking illegal Custom-0 encoding");

        resetn = 1'b0;
        core_enable = 1'b0;

        for (
            i = 0;
            i < INSTRUCTION_MEMORY_DEPTH_WORDS;
            i = i + 1
        )
            instruction_memory[i] = NOP;

        instruction_memory[0] = {
            FUNCT7_PQ,
            5'd0,
            5'd0,
            3'b001,
            5'd0,
            OPCODE_CUSTOM_0
        };

        repeat (5) @(posedge clk);
        #1;

        resetn = 1'b1;
        core_enable = 1'b1;

        timeout_count = 0;

        while (
            core_fault !== 1'b1 &&
            timeout_count < 50
        ) begin
            @(posedge clk);
            #1;

            timeout_count = timeout_count + 1;
        end

        check_1(
            "unsupported Custom-0 encoding causes fault",
            core_fault,
            1'b1
        );

        core_enable = 1'b0;
        resetn = 1'b0;

        $display("");

        if (failure_count == 0)
            $display(
                "All ForgeRV PQ pipeline tests passed."
            );
        else
            $display(
                "%0d ForgeRV PQ pipeline tests failed.",
                failure_count
            );

        $finish;
    end

endmodule
