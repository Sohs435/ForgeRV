module rv32_imm_gen (
    input logic [31:0] instruction,
    input rv32_pkg::imm_type_t immediate_type,
    output logic [31:0] immediate
);

    import rv32_pkg::*;

    always_comb begin
        immediate = 32'b0;

        if (immediate_type != IMM_NONE) begin
            immediate[31] = instruction[31];
            
            if (immediate_type == IMM_U) immediate[30:20] = instruction[30:20];
            else immediate[30:20] = {11{instruction[31]}};
            
            if (immediate_type == IMM_U || immediate_type == IMM_J) immediate[19:12] = instruction[19:12];
            else immediate[19:12] = {8{instruction[31]}};
            
            case (immediate_type)
                IMM_B: immediate[11] = instruction[7];
                IMM_J: immediate[11] = instruction[20];
                IMM_U: immediate[11] = 1'b0;
                default: immediate[11] = instruction[31];
            endcase

            if (immediate_type == IMM_U) immediate[10:5] = 6'b0;
            else immediate[10:5] = instruction[30:25];

            case (immediate_type)
                IMM_I: immediate[4:1] = instruction[24:21];
                IMM_J: immediate[4:1] = instruction[24:21];
                IMM_S: immediate[4:1] = instruction[11:8];
                IMM_B: immediate[4:1] = instruction[11:8];
                default: immediate[4:1] = 4'b0;
            endcase

            case (immediate_type)
                IMM_I: immediate[0] = instruction[20];
                IMM_S: immediate[0] = instruction[7];
                default: immediate[0] = 1'b0;
            endcase
        end
    end

endmodule