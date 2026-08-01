package rv32_pkg;

    typedef enum logic [3:0] {
        ALU_ADD    = 4'd0,
        ALU_SUB    = 4'd1,
        ALU_SLL    = 4'd2,
        ALU_SLT    = 4'd3,
        ALU_SLTU   = 4'd4,
        ALU_XOR    = 4'd5,
        ALU_SRL    = 4'd6,
        ALU_SRA    = 4'd7,
        ALU_OR     = 4'd8,
        ALU_AND    = 4'd9,
        ALU_COPY_B = 4'd10
    } alu_op_t;

    typedef enum logic [2:0] {
        IMM_NONE = 3'd0,
        IMM_I    = 3'd1,
        IMM_S    = 3'd2,
        IMM_B    = 3'd3,
        IMM_U    = 3'd4,
        IMM_J    = 3'd5
    } imm_type_t;
    
endpackage