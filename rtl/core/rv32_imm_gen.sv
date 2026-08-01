module rv32_imm_gen (
    input logic [31:0] instruction,
    input rv32_pkg::imm_type_t immediate_type,
    output logic [31:0] immediate
);

    import rv32_pkg::*;

    always_comb begin
        case (immediate_type)
            IMM_I: immediate = {{20{instruction[31]}}, instruction[31:20]};
            IMM_S: immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            IMM_B: immediate = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            IMM_U: immediate = {instruction[31:12], 12'b0};
            IMM_J: immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            IMM_NONE: immediate = 32'b0;
            default: immediate = 32'b0;
        endcase
    end

endmodule