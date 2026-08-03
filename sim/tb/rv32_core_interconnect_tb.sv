`timescale 1ns / 1ps

module rv32_core_interconnect_tb;

    import rv32_pkg::*;

    localparam logic [31:0] RESET_VECTOR = 32'h00000100;
    localparam DATA_MEMORY_DEPTH_WORDS = 256;

    logic clk;
    logic resetn;
    logic core_enable;
    logic [31:0] instruction;

    logic [31:0] pc;
    logic [31:0] next_pc;
    logic [31:0] pc_plus_4;
    logic [31:0] alu_result;
    logic [31:0] load_data;
    logic [31:0] writeback_data;

    logic register_write_enable;
    logic branch_taken;
    logic control_transfer_taken;
    logic illegal_instruction;
    logic instruction_address_misaligned;
    logic memory_access_misaligned;
    logic core_fault;

    imm_type_t immediate_type;
    special_op_t special_operation;

    integer test_count;
    integer failure_count;

    rv32_core_interconnect #(
        .RESET_VECTOR(RESET_VECTOR),
        .DATA_MEMORY_DEPTH_WORDS(DATA_MEMORY_DEPTH_WORDS)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .core_enable(core_enable),
        .instruction(instruction),

        .pc(pc),
        .next_pc(next_pc),
        .pc_plus_4(pc_plus_4),
        .alu_result(alu_result),
        .load_data(load_data),
        .writeback_data(writeback_data),

        .register_write_enable(register_write_enable),
        .branch_taken(branch_taken),
        .control_transfer_taken(control_transfer_taken),
        .illegal_instruction(illegal_instruction),
        .instruction_address_misaligned(instruction_address_misaligned),
        .memory_access_misaligned(memory_access_misaligned),
        .core_fault(core_fault),

        .immediate_type(immediate_type),
        .special_operation(special_operation)
    );

    always #5 clk = ~clk;

    function automatic logic [31:0] encode_r(
        input logic [6:0] funct7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd
    );
        encode_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
    endfunction

    function automatic logic [31:0] encode_i(
        input integer immediate_value,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        logic [11:0] immediate_bits;
        begin
            immediate_bits = immediate_value[11:0];
            encode_i = {immediate_bits, rs1, funct3, rd, opcode};
        end
    endfunction

    function automatic logic [31:0] encode_s(
        input integer immediate_value,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3
    );
        logic [11:0] immediate_bits;
        begin
            immediate_bits = immediate_value[11:0];
            encode_s = {
                immediate_bits[11:5],
                rs2,
                rs1,
                funct3,
                immediate_bits[4:0],
                7'b0100011
            };
        end
    endfunction

    function automatic logic [31:0] encode_b(
        input integer immediate_value,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3
    );
        logic [12:0] immediate_bits;
        begin
            immediate_bits = immediate_value[12:0];
            encode_b = {
                immediate_bits[12],
                immediate_bits[10:5],
                rs2,
                rs1,
                funct3,
                immediate_bits[4:1],
                immediate_bits[11],
                7'b1100011
            };
        end
    endfunction

    function automatic logic [31:0] encode_u(
        input logic [19:0] upper_immediate,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        encode_u = {upper_immediate, rd, opcode};
    endfunction

    function automatic logic [31:0] encode_j(
        input integer immediate_value,
        input logic [4:0] rd
    );
        logic [20:0] immediate_bits;
        begin
            immediate_bits = immediate_value[20:0];
            encode_j = {
                immediate_bits[20],
                immediate_bits[10:1],
                immediate_bits[11],
                immediate_bits[19:12],
                rd,
                7'b1101111
            };
        end
    endfunction

    task automatic drive_instruction(
        input logic [31:0] instruction_value
    );
        begin
            @(negedge clk);
            instruction = instruction_value;
            #1;
        end
    endtask

    task automatic commit_instruction;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_32(
        input string test_name,
        input logic [31:0] actual_value,
        input logic [31:0] expected_value
    );
        begin
            test_count = test_count + 1;

            if (actual_value !== expected_value) begin
                failure_count = failure_count + 1;
                $display(
                    "FAIL: %s expected=%08h actual=%08h",
                    test_name,
                    expected_value,
                    actual_value
                );
            end
            else begin
                $display("PASS: %s value=%08h", test_name, actual_value);
            end
        end
    endtask

    task automatic check_1(
        input string test_name,
        input logic actual_value,
        input logic expected_value
    );
        begin
            test_count = test_count + 1;

            if (actual_value !== expected_value) begin
                failure_count = failure_count + 1;
                $display(
                    "FAIL: %s expected=%0b actual=%0b",
                    test_name,
                    expected_value,
                    actual_value
                );
            end
            else begin
                $display("PASS: %s value=%0b", test_name, actual_value);
            end
        end
    endtask

    task automatic check_immediate_type(
        input string test_name,
        input imm_type_t expected_value
    );
        begin
            test_count = test_count + 1;

            if (immediate_type !== expected_value) begin
                failure_count = failure_count + 1;
                $display(
                    "FAIL: %s expected=%s actual=%s",
                    test_name,
                    expected_value.name(),
                    immediate_type.name()
                );
            end
            else begin
                $display("PASS: %s value=%s", test_name, immediate_type.name());
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        resetn = 1'b0;
        core_enable = 1'b0;
        instruction = 32'h00000013;

        test_count = 0;
        failure_count = 0;

        // Hold reset across two rising clock edges.
        repeat (2) @(posedge clk);
        #1;

        check_32("reset vector", pc, RESET_VECTOR);
        check_1("register write disabled during reset", register_write_enable, 1'b0);

        @(negedge clk);
        resetn = 1'b1;
        core_enable = 1'b1;

        // LUI x1, 0x12345 checks the zero ALU input and upper-immediate path.
        instruction = encode_u(20'h12345, 5'd1, 7'b0110111);
        #1;
        check_immediate_type("LUI immediate type", IMM_U);
        check_32("LUI ALU result", alu_result, 32'h12345000);
        check_32("LUI writeback selection", writeback_data, 32'h12345000);
        check_1("LUI register write enabled", register_write_enable, 1'b1);
        commit_instruction();
        check_32("LUI register commit", dut.register_file.registers[1], 32'h12345000);
        check_32("LUI sequential PC update", pc, 32'h00000104);

        // ADDI x2, x1, 5 checks register source one and the immediate ALU input.
        drive_instruction(encode_i(5, 5'd1, 3'b000, 5'd2, 7'b0010011));
        check_immediate_type("ADDI immediate type", IMM_I);
        check_32("ADDI ALU result", alu_result, 32'h12345005);
        check_32("ADDI writeback selection", writeback_data, 32'h12345005);
        commit_instruction();
        check_32("ADDI register commit", dut.register_file.registers[2], 32'h12345005);
        check_32("ADDI sequential PC update", pc, 32'h00000108);

        // ADD x3, x1, x2 checks both register-file read ports and ALU writeback.
        drive_instruction(encode_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3));
        check_immediate_type("ADD has no immediate", IMM_NONE);
        check_32("ADD ALU result", alu_result, 32'h2468a005);
        commit_instruction();
        check_32("ADD register commit", dut.register_file.registers[3], 32'h2468a005);

        // SUB x4, x2, x1 produces five for later branch comparisons.
        drive_instruction(encode_r(7'b0100000, 5'd1, 5'd2, 3'b000, 5'd4));
        check_32("SUB ALU result", alu_result, 32'h00000005);
        commit_instruction();
        check_32("SUB register commit", dut.register_file.registers[4], 32'h00000005);

        // AUIPC x5, 1 checks the PC ALU input and ALU writeback path.
        drive_instruction(encode_u(20'h00001, 5'd5, 7'b0010111));
        check_32("AUIPC ALU result", alu_result, 32'h00001110);
        check_32("AUIPC writeback selection", writeback_data, 32'h00001110);
        commit_instruction();
        check_32("AUIPC register commit", dut.register_file.registers[5], 32'h00001110);

        // ADDI x10, x0, 64 creates an aligned data-memory base address.
        drive_instruction(encode_i(64, 5'd0, 3'b000, 5'd10, 7'b0010011));
        commit_instruction();
        check_32("memory base register", dut.register_file.registers[10], 32'h00000040);

        // LUI and ADDI construct 0x80ff7f01 in x11.
        drive_instruction(encode_u(20'h80ff8, 5'd11, 7'b0110111));
        commit_instruction();

        drive_instruction(encode_i(-255, 5'd11, 3'b000, 5'd11, 7'b0010011));
        check_32("store value construction", alu_result, 32'h80ff7f01);
        commit_instruction();
        check_32("store value register", dut.register_file.registers[11], 32'h80ff7f01);

        // SW x11, 0(x10) checks the ALU address path and complete-word store path.
        drive_instruction(encode_s(0, 5'd11, 5'd10, 3'b010));
        check_immediate_type("SW immediate type", IMM_S);
        check_32("SW effective address", alu_result, 32'h00000040);
        check_1("aligned SW has no fault", memory_access_misaligned, 1'b0);
        check_1("SW does not write a register", register_write_enable, 1'b0);
        commit_instruction();

        // LW x12, 0(x10) checks memory read data and the memory writeback mux input.
        drive_instruction(encode_i(0, 5'd10, 3'b010, 5'd12, 7'b0000011));
        check_32("LW effective address", alu_result, 32'h00000040);
        check_32("LW load data", load_data, 32'h80ff7f01);
        check_32("LW writeback selection", writeback_data, 32'h80ff7f01);
        check_1("LW register write enabled", register_write_enable, 1'b1);
        commit_instruction();
        check_32("LW register commit", dut.register_file.registers[12], 32'h80ff7f01);

        // LBU x13, 2(x10) checks byte selection and zero extension.
        drive_instruction(encode_i(2, 5'd10, 3'b100, 5'd13, 7'b0000011));
        check_32("LBU zero extension", load_data, 32'h000000ff);
        commit_instruction();
        check_32("LBU register commit", dut.register_file.registers[13], 32'h000000ff);

        // LB x14, 3(x10) checks byte selection and sign extension.
        drive_instruction(encode_i(3, 5'd10, 3'b000, 5'd14, 7'b0000011));
        check_32("LB sign extension", load_data, 32'hffffff80);
        commit_instruction();
        check_32("LB register commit", dut.register_file.registers[14], 32'hffffff80);

        // ADD uses the loaded word to prove that memory data reached the register file.
        drive_instruction(encode_r(7'b0000000, 5'd4, 5'd12, 3'b000, 5'd15));
        check_32("loaded value used by ALU", alu_result, 32'h80ff7f06);
        commit_instruction();
        check_32("load-to-ALU register commit", dut.register_file.registers[15], 32'h80ff7f06);

        // ADDI x16, x0, 5 creates a value equal to x4 for branch testing.
        drive_instruction(encode_i(5, 5'd0, 3'b000, 5'd16, 7'b0010011));
        commit_instruction();

        // BEQ x4, x16, 8 checks a taken conditional branch.
        drive_instruction(encode_b(8, 5'd16, 5'd4, 3'b000));
        check_immediate_type("BEQ immediate type", IMM_B);
        check_1("BEQ branch taken", branch_taken, 1'b1);
        check_1("BEQ control transfer", control_transfer_taken, 1'b1);
        check_32("BEQ target selection", next_pc, 32'h00000140);
        commit_instruction();
        check_32("BEQ PC update", pc, 32'h00000140);

        // BNE x4, x16, 8 checks an untaken conditional branch.
        drive_instruction(encode_b(8, 5'd16, 5'd4, 3'b001));
        check_1("BNE branch not taken", branch_taken, 1'b0);
        check_1("BNE no control transfer", control_transfer_taken, 1'b0);
        check_32("BNE sequential next PC", next_pc, 32'h00000144);
        commit_instruction();
        check_32("BNE sequential PC update", pc, 32'h00000144);

        // JAL x17, 8 checks jump targeting and PC-plus-four writeback.
        drive_instruction(encode_j(8, 5'd17));
        check_immediate_type("JAL immediate type", IMM_J);
        check_32("JAL ALU target", alu_result, 32'h0000014c);
        check_32("JAL link writeback", writeback_data, 32'h00000148);
        check_32("JAL next PC", next_pc, 32'h0000014c);
        check_1("JAL control transfer", control_transfer_taken, 1'b1);
        commit_instruction();
        check_32("JAL link register commit", dut.register_file.registers[17], 32'h00000148);
        check_32("JAL PC update", pc, 32'h0000014c);

        // JALR x18, 1(x17) produces 0x149 before target bit zero is cleared.
        drive_instruction(encode_i(1, 5'd17, 3'b000, 5'd18, 7'b1100111));
        check_32("JALR raw ALU target", alu_result, 32'h00000149);
        check_32("JALR cleared target bit zero", next_pc, 32'h00000148);
        check_32("JALR link writeback", writeback_data, 32'h00000150);
        check_1("aligned JALR has no address fault", instruction_address_misaligned, 1'b0);
        commit_instruction();
        check_32("JALR link register commit", dut.register_file.registers[18], 32'h00000150);
        check_32("JALR PC update", pc, 32'h00000148);

        // Initialize x19 before checking that core_enable suppresses state updates.
        drive_instruction(encode_i(1, 5'd0, 3'b000, 5'd19, 7'b0010011));
        commit_instruction();
        check_32("core hold test register initialized", dut.register_file.registers[19], 32'h00000001);

        @(negedge clk);
        core_enable = 1'b0;
        instruction = encode_i(7, 5'd0, 3'b000, 5'd19, 7'b0010011);
        #1;
        check_1("core disable suppresses register write", register_write_enable, 1'b0);
        check_32("core disable holds next PC externally", pc, 32'h0000014c);
        commit_instruction();
        check_32("core disable holds PC", pc, 32'h0000014c);
        check_32("core disable preserves register", dut.register_file.registers[19], 32'h00000001);

        // Re-enabling the core allows the same instruction to commit.
        @(negedge clk);
        core_enable = 1'b1;
        #1;
        check_1("core re-enable restores register write", register_write_enable, 1'b1);
        commit_instruction();
        check_32("core re-enable updates register", dut.register_file.registers[19], 32'h00000007);
        check_32("core re-enable updates PC", pc, 32'h00000150);

        // An invalid opcode must assert a fault and prevent the PC from advancing.
        drive_instruction(32'h00000000);
        check_1("invalid opcode detected", illegal_instruction, 1'b1);
        check_1("invalid opcode raises core fault", core_fault, 1'b1);
        check_1("invalid opcode suppresses register write", register_write_enable, 1'b0);
        check_32("invalid opcode proposed next PC", next_pc, 32'h00000154);
        commit_instruction();
        check_32("invalid opcode holds PC", pc, 32'h00000150);

        // A legal NOP proves that the core can continue after the invalid input is removed.
        drive_instruction(32'h00000013);
        check_1("legal NOP clears illegal flag", illegal_instruction, 1'b0);
        check_1("legal NOP clears core fault", core_fault, 1'b0);
        commit_instruction();
        check_32("legal NOP advances PC", pc, 32'h00000154);

        // Initialize x20 so a misaligned load can be checked for suppressed writeback.
        drive_instruction(encode_i(85, 5'd0, 3'b000, 5'd20, 7'b0010011));
        commit_instruction();
        check_32("misaligned load destination initialized", dut.register_file.registers[20], 32'h00000055);

        // LW x20, 2(x10) is misaligned because a word address must end in 00.
        drive_instruction(encode_i(2, 5'd10, 3'b010, 5'd20, 7'b0000011));
        check_32("misaligned LW effective address", alu_result, 32'h00000042);
        check_1("misaligned LW detected", memory_access_misaligned, 1'b1);
        check_1("misaligned LW raises core fault", core_fault, 1'b1);
        check_1("misaligned LW suppresses register write", register_write_enable, 1'b0);
        commit_instruction();
        check_32("misaligned LW holds PC", pc, 32'h00000158);
        check_32("misaligned LW preserves destination", dut.register_file.registers[20], 32'h00000055);

        // JAL x0, 2 creates an instruction-address target that is not four-byte aligned.
        drive_instruction(encode_j(2, 5'd0));
        check_32("misaligned JAL target", next_pc, 32'h0000015a);
        check_1("misaligned JAL detected", instruction_address_misaligned, 1'b1);
        check_1("misaligned JAL raises core fault", core_fault, 1'b1);
        check_1("misaligned JAL suppresses register write", register_write_enable, 1'b0);
        commit_instruction();
        check_32("misaligned JAL holds PC", pc, 32'h00000158);

        // ECALL checks that special instructions pass through the integrated decoder.
        drive_instruction(32'h00000073);
        test_count = test_count + 1;
        if (special_operation !== SPECIAL_ECALL) begin
            failure_count = failure_count + 1;
            $display(
                "FAIL: ECALL special operation expected=%0d actual=%0d",
                SPECIAL_ECALL,
                special_operation
            );
        end
        else begin
            $display("PASS: ECALL special operation value=0d", special_operation.name());
        end
        check_1("ECALL is a supported instruction", illegal_instruction, 1'b0);
        check_1("ECALL does not write a register", register_write_enable, 1'b0);
        commit_instruction();
        check_32("ECALL sequential PC update", pc, 32'h0000015c);

        // Active reset has priority over core execution and returns the PC to its vector.
        @(negedge clk);
        instruction = encode_i(9, 5'd0, 3'b000, 5'd21, 7'b0010011);
        resetn = 1'b0;
        #1;
        check_1("reset suppresses register write", register_write_enable, 1'b0);
        commit_instruction();
        check_32("reset priority returns PC to vector", pc, RESET_VECTOR);

        if (failure_count == 0) begin
            $display("All %0d rv32_core_interconnect tests passed.", test_count);
        end
        else begin
            $display(
                "%0d of %0d rv32_core_interconnect tests failed.",
                failure_count,
                test_count
            );
        end

        $finish;
    end

endmodule
