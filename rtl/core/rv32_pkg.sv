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
        ALU_COPY_B = 4'd10,
        ALU_PQ = 4'd11 //new ALU operand
    } alu_op_t;

    typedef enum logic [2:0] {
        IMM_NONE = 3'd0,
        IMM_I    = 3'd1,
        IMM_S    = 3'd2,
        IMM_B    = 3'd3,
        IMM_U    = 3'd4,
        IMM_J    = 3'd5
    } imm_type_t;
    

    
    localparam logic [6:0] OPCODE_LUI = 7'b0110111; // load upper immediate 20 bits into register and clear lower 12 bits 
    localparam logic [6:0] OPCODE_AUIPC = 7'b0010111; // PC + U-type immediate 
    localparam logic [6:0] OPCODE_JAL = 7'b1101111; // jump target = PC + J-type immediate
    localparam logic [6:0] OPCODE_JALR = 7'b1100111; // jump target = rs1 + I-type immediate, rd = PC + 4
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011; // B type conditional branches 
    localparam logic [6:0] OPCODE_LOAD = 7'b0000011; // Identifies I-type load instructions 
    localparam logic [6:0] OPCODE_STORE = 7'b0100011; // Indentifies S-type stores
    localparam logic [6:0] OPCODE_OP_IMM = 7'b0010011; // I type ALU Operations 
    localparam logic [6:0] OPCODE_OP = 7'b0110011; // R-type register operations (ADD, SUB, etc)
    localparam logic [6:0] OPCODE_MISC_MEM = 7'b0001111; //memory ordering instructions like FENCE (all operations before 
    // FENCE are observed first no matter the thread) 
    localparam logic [6:0] OPCODE_SYSTEM = 7'b1110011; //system instructions (ECALL, EBREAK, etc) 
    
    //ECALL - System call instruction -> want to access something not directly accessible by user 
    //EBREAK - basically a debugger breakpoint, but implementation may differ 
    
    
    // Custom ISA stuff 
    localparam logic [6:0] OPCODE_CUSTOM_0 = 7'b0001011; // RISC-V Custom-0 opcode space

    localparam logic [2:0] FUNCT3_PQ = 3'b000; // identifies the PQ instruction within Custom-0
    localparam logic [6:0] FUNCT7_PQ = 7'b0000000;

    localparam logic [6:0] FUNCT7_NORMAL = 7'b0000000; // Normal operations (ADD, SRL, SLL , ...)
    localparam logic [6:0] FUNCT7_SUB_SRA = 7'b0100000; // SUB, SRA, SRI 

    typedef enum logic [1:0] { // ALU left-side operand selection 
        ALU_A_RS1 = 2'd0, // R-type ALU operations, Immediate ALU operations, loads, stores, jalr
        ALU_A_PC = 2'd1, // AUIPC, JAL, Branch target calculation 
        ALU_A_ZERO = 2'd2 // When immediate is required, such as LUI - more for safety since alu_copy does exist 
    } alu_a_sel_t;

    typedef enum logic { // is rhs operand a register or immediate?
        ALU_B_RS2 = 1'b0, // ALU rhs = rs2_data (add x3, x1, x2)
        ALU_B_IMMEDIATE = 1'b1 //ALU lhs = immediate (addi x3, x1, 0x23)
    } alu_b_sel_t;

    typedef enum logic [1:0] { // which value is written into rd (none, from ALU, memory - load/store unit, or just PC + 4 - JAL(R))
        WB_NONE = 2'd0, 
        WB_ALU = 2'd1,
        WB_MEMORY = 2'd2,
        WB_PC_PLUS_4 = 2'd3
    } writeback_sel_t;

    typedef enum logic [2:0] { 
        BRANCH_NONE = 3'd0, // instruction is not a combinational branch 
        BRANCH_EQ = 3'd1, // rs1 == rs2 
        BRANCH_NE = 3'd2, // rs1 != rs2
        BRANCH_LT = 3'd3, // rs1 < rs2 signed 
        BRANCH_GE = 3'd4, // rs1 > rs2 signed 
        BRANCH_LTU = 3'd5, // unsigned ver of 3 
        BRANCH_GEU = 3'd6 // unsigned ver of 4
    } branch_op_t;

    typedef enum logic [1:0] {
        JUMP_NONE = 2'd0, // not an unconditional just 
        JUMP_JAL = 2'd1, // jump is PC - relative (PC + J-type Immediate)
        JUMP_JALR = 2'd2 // target uses a register 
    } jump_op_t;

    typedef enum logic [1:0] { // tells load store unit how many bits to access (0, 8, 16, 32 ) 
        MEMORY_NONE = 2'd0,
        MEMORY_BYTE = 2'd1,
        MEMORY_HALF = 2'd2,
        MEMORY_WORD = 2'd3
    } memory_size_t;

    typedef enum logic [1:0] { // different types of special operations currently in consideration 
        SPECIAL_NONE = 2'd0, // normal instruction 
        SPECIAL_FENCE = 2'd1, // Fence instruction 
        SPECIAL_ECALL = 2'd2, // call exception 
        SPECIAL_EBREAK = 2'd3 // breakpoint exception 
    } special_op_t;
    
    typedef enum logic [1:0] {
        FORWARD_NONE = 2'd0,
        FORWARD_MEM_WB = 2'd1,
        FORWARD_EX_MEM = 2'd2
    } forward_sel_t;
    

endpackage