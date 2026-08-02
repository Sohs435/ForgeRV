`timescale 1ns / 1ps

module rv32_control_flow_tb;

    import rv32_pkg::*;

    logic clk;
    logic resetn;
    logic pc_enable;

    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] alu_result;

    branch_op_t branch_operation;
    jump_op_t jump_operation;

    logic [31:0] pc;
    logic [31:0] next_pc;
    logic [31:0] pc_plus_4;
    logic branch_taken;
    logic control_transfer_taken;
    logic instruction_address_misaligned;

    integer test_count;
    integer failure_count;

    rv32_control_flow #(
        .RESET_VECTOR(32'h00000100)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .pc_enable(pc_enable),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .alu_result(alu_result),
        .branch_operation(branch_operation),
        .jump_operation(jump_operation),
        .pc(pc),
        .next_pc(next_pc),
        .pc_plus_4(pc_plus_4),
        .branch_taken(branch_taken),
        .control_transfer_taken(control_transfer_taken),
        .instruction_address_misaligned(instruction_address_misaligned)
    );

    always #5 clk = ~clk;

    task automatic check_flow (
        input logic expected_branch_taken,
        input logic [31:0] expected_next_pc,
        input logic expected_control_transfer,
        input logic expected_misaligned,
        input string test_name
    );
        begin
            #1;
            test_count = test_count + 1;

            if (
                branch_taken !== expected_branch_taken ||
                pc_plus_4 !== pc + 32'd4 ||
                next_pc !== expected_next_pc ||
                control_transfer_taken !== expected_control_transfer ||
                instruction_address_misaligned !== expected_misaligned
            ) begin
                failure_count = failure_count + 1;

                $display("FAIL: %s", test_name);
                $display("pc=%h pc_plus_4=%h next_pc=%h", pc, pc_plus_4, next_pc);
                $display("branch_taken expected=%b result=%b", expected_branch_taken, branch_taken);
                $display("next_pc expected=%h result=%h", expected_next_pc, next_pc);
                $display("control_transfer expected=%b result=%b", expected_control_transfer, control_transfer_taken);
                $display("misaligned expected=%b result=%b", expected_misaligned, instruction_address_misaligned);
            end
            else begin
                $display(
                    "PASS: %s pc=%h next_pc=%h branch_taken=%b transfer=%b misaligned=%b",
                    test_name,
                    pc,
                    next_pc,
                    branch_taken,
                    control_transfer_taken,
                    instruction_address_misaligned
                );
            end
        end
    endtask

    task automatic check_pc_after_edge (
        input logic [31:0] expected_pc,
        input string test_name
    );
        begin
            @(posedge clk);
            #1;
            test_count = test_count + 1;

            if (pc !== expected_pc) begin
                failure_count = failure_count + 1;
                $display("FAIL: %s expected_pc=%h result=%h", test_name, expected_pc, pc);
            end
            else begin
                $display("PASS: %s pc=%h", test_name, pc);
            end
        end
    endtask

    task automatic check_branch_case (
        input branch_op_t test_operation,
        input logic [31:0] test_rs1,
        input logic [31:0] test_rs2,
        input logic expected_taken,
        input logic [31:0] target,
        input string test_name
    );
        logic [31:0] expected_next_pc;
        begin
            branch_operation = test_operation;
            jump_operation = JUMP_NONE;
            rs1_data = test_rs1;
            rs2_data = test_rs2;
            alu_result = target;

            if (expected_taken) expected_next_pc = target;
            else expected_next_pc = pc + 32'd4;

            check_flow(
                expected_taken,
                expected_next_pc,
                expected_taken,
                1'b0,
                test_name
            );
        end
    endtask

    initial begin
        clk = 1'b0;
        resetn = 1'b0;
        pc_enable = 1'b1;

        rs1_data = 32'b0;
        rs2_data = 32'b0;
        alu_result = 32'b0;

        branch_operation = BRANCH_NONE;
        jump_operation = JUMP_NONE;

        test_count = 0;
        failure_count = 0;

        check_pc_after_edge(32'h00000100, "reset vector");

        @(negedge clk);
        resetn = 1'b1;

        check_flow(
            1'b0,
            32'h00000104,
            1'b0,
            1'b0,
            "normal sequential next PC"
        );

        check_pc_after_edge(32'h00000104, "sequential PC update");

        pc_enable = 1'b0;

        check_flow(
            1'b0,
            32'h00000108,
            1'b0,
            1'b0,
            "next PC remains combinational while PC disabled"
        );

        check_pc_after_edge(32'h00000104, "PC enable holds current PC");

        check_branch_case(
            BRANCH_NONE,
            32'd5,
            32'd5,
            1'b0,
            32'h00000200,
            "BRANCH_NONE"
        );

        check_branch_case(
            BRANCH_EQ,
            32'd5,
            32'd5,
            1'b1,
            32'h00000200,
            "BEQ taken"
        );

        check_branch_case(
            BRANCH_EQ,
            32'd5,
            32'd6,
            1'b0,
            32'h00000200,
            "BEQ not taken"
        );

        check_branch_case(
            BRANCH_NE,
            32'd5,
            32'd6,
            1'b1,
            32'h00000200,
            "BNE taken"
        );

        check_branch_case(
            BRANCH_NE,
            32'd5,
            32'd5,
            1'b0,
            32'h00000200,
            "BNE not taken"
        );

        check_branch_case(
            BRANCH_LT,
            32'hFFFFFFFF,
            32'h00000001,
            1'b1,
            32'h00000200,
            "BLT signed taken"
        );

        check_branch_case(
            BRANCH_LT,
            32'h00000001,
            32'hFFFFFFFF,
            1'b0,
            32'h00000200,
            "BLT signed not taken"
        );

        check_branch_case(
            BRANCH_GE,
            32'h00000001,
            32'hFFFFFFFF,
            1'b1,
            32'h00000200,
            "BGE signed taken"
        );

        check_branch_case(
            BRANCH_GE,
            32'hFFFFFFFF,
            32'h00000001,
            1'b0,
            32'h00000200,
            "BGE signed not taken"
        );

        check_branch_case(
            BRANCH_LTU,
            32'h00000001,
            32'hFFFFFFFF,
            1'b1,
            32'h00000200,
            "BLTU unsigned taken"
        );

        check_branch_case(
            BRANCH_LTU,
            32'hFFFFFFFF,
            32'h00000001,
            1'b0,
            32'h00000200,
            "BLTU unsigned not taken"
        );

        check_branch_case(
            BRANCH_GEU,
            32'hFFFFFFFF,
            32'h00000001,
            1'b1,
            32'h00000200,
            "BGEU unsigned taken"
        );

        check_branch_case(
            BRANCH_GEU,
            32'h00000001,
            32'hFFFFFFFF,
            1'b0,
            32'h00000200,
            "BGEU unsigned not taken"
        );

        pc_enable = 1'b1;
        branch_operation = BRANCH_EQ;
        jump_operation = JUMP_NONE;
        rs1_data = 32'd10;
        rs2_data = 32'd10;
        alu_result = 32'h00000200;

        check_flow(
            1'b1,
            32'h00000200,
            1'b1,
            1'b0,
            "taken branch target selection"
        );

        check_pc_after_edge(32'h00000200, "taken branch PC update");

        branch_operation = BRANCH_NONE;
        jump_operation = JUMP_JAL;
        alu_result = 32'h00000300;

        check_flow(
            1'b0,
            32'h00000300,
            1'b1,
            1'b0,
            "JAL target selection"
        );

        check_pc_after_edge(32'h00000300, "JAL PC update");

        jump_operation = JUMP_JALR;
        alu_result = 32'h00000405;

        check_flow(
            1'b0,
            32'h00000404,
            1'b1,
            1'b0,
            "JALR bit zero clearing"
        );

        check_pc_after_edge(32'h00000404, "JALR PC update");

        pc_enable = 1'b0;
        jump_operation = JUMP_JAL;
        alu_result = 32'h00000502;

        check_flow(
            1'b0,
            32'h00000502,
            1'b1,
            1'b1,
            "misaligned JAL target"
        );

        jump_operation = JUMP_JALR;
        alu_result = 32'h00000503;

        check_flow(
            1'b0,
            32'h00000502,
            1'b1,
            1'b1,
            "misaligned JALR after bit zero clearing"
        );

        branch_operation = BRANCH_EQ;
        jump_operation = JUMP_NONE;
        rs1_data = 32'd1;
        rs2_data = 32'd2;
        alu_result = 32'h00000602;

        check_flow(
            1'b0,
            32'h00000408,
            1'b0,
            1'b0,
            "untaken branch ignores misaligned target"
        );

        branch_operation = BRANCH_NONE;
        pc_enable = 1'b1;

        check_flow(
            1'b0,
            32'h00000408,
            1'b0,
            1'b0,
            "sequential execution after control transfers"
        );

        check_pc_after_edge(32'h00000408, "final sequential PC update");

        jump_operation = JUMP_JAL;
        alu_result = 32'h00000800;
        resetn = 1'b0;

        check_pc_after_edge(32'h00000100, "reset has priority over PC update");

        if (failure_count == 0) begin
            $display("All %0d rv32_control_flow tests passed.", test_count);
        end
        else begin
            $fatal(1, "%0d of %0d rv32_control_flow tests failed.", failure_count, test_count);
        end

        $finish;
    end

endmodule