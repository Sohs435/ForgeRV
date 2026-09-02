module rv32_decoder (
    input logic [31:0] instruction,

    output rv32_pkg::imm_type_t immediate_type,
    output rv32_pkg::alu_op_t alu_operation,
    output rv32_pkg::alu_a_sel_t alu_a_select,
    output rv32_pkg::alu_b_sel_t alu_b_select,
    output rv32_pkg::writeback_sel_t writeback_select,
    output rv32_pkg::branch_op_t branch_operation,
    output rv32_pkg::jump_op_t jump_operation,
    output rv32_pkg::memory_size_t memory_size,
    output rv32_pkg::special_op_t special_operation,

    output logic register_write_enable,
    output logic memory_read_enable,
    output logic memory_write_enable,
    output logic load_unsigned,
    output logic illegal_instruction
);

    import rv32_pkg::*;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    always_comb begin
        immediate_type = IMM_NONE;
        alu_operation = ALU_ADD;
        alu_a_select = ALU_A_RS1;
        alu_b_select = ALU_B_RS2;
        writeback_select = WB_NONE;
        branch_operation = BRANCH_NONE;
        jump_operation = JUMP_NONE;
        memory_size = MEMORY_NONE;
        special_operation = SPECIAL_NONE;

        register_write_enable = 1'b0;
        memory_read_enable = 1'b0;
        memory_write_enable = 1'b0;
        load_unsigned = 1'b0;
        illegal_instruction = 1'b1;

        case (opcode)
            OPCODE_LUI: begin // rd = upper immediate, 12'b0
                immediate_type = IMM_U;
                alu_operation = ALU_COPY_B;
                alu_a_select = ALU_A_ZERO;
                alu_b_select = ALU_B_IMMEDIATE;
                writeback_select = WB_ALU;
                register_write_enable = 1'b1;
                illegal_instruction = 1'b0;
            end

            OPCODE_AUIPC: begin // rd = PC + U-type immediate
                immediate_type = IMM_U;
                alu_operation = ALU_ADD;
                alu_a_select = ALU_A_PC;
                alu_b_select = ALU_B_IMMEDIATE;
                writeback_select = WB_ALU;
                register_write_enable = 1'b1;
                illegal_instruction = 1'b0;
            end

            OPCODE_JAL: begin // target = PC + J-type immediate, rd = PC + 4
                immediate_type = IMM_J;
                alu_operation = ALU_ADD;
                alu_a_select = ALU_A_PC;
                alu_b_select = ALU_B_IMMEDIATE;
                writeback_select = WB_PC_PLUS_4;
                jump_operation = JUMP_JAL;
                register_write_enable = 1'b1;
                illegal_instruction = 1'b0;
            end

            OPCODE_JALR: begin // target = rs1 + I-type immediate with bit 0 cleared, rd = PC + 4
                if (funct3 == 3'b000) begin
                    immediate_type = IMM_I;
                    alu_operation = ALU_ADD;
                    alu_a_select = ALU_A_RS1;
                    alu_b_select = ALU_B_IMMEDIATE;
                    writeback_select = WB_PC_PLUS_4;
                    jump_operation = JUMP_JALR;
                    register_write_enable = 1'b1;
                    illegal_instruction = 1'b0;
                end
            end

            OPCODE_BRANCH: begin // target = PC + B-type immediate
                immediate_type = IMM_B;
                alu_operation = ALU_ADD;
                alu_a_select = ALU_A_PC;
                alu_b_select = ALU_B_IMMEDIATE;

                case (funct3)
                    3'b000: begin
                        branch_operation = BRANCH_EQ;
                        illegal_instruction = 1'b0;
                    end

                    3'b001: begin
                        branch_operation = BRANCH_NE;
                        illegal_instruction = 1'b0;
                    end

                    3'b100: begin
                        branch_operation = BRANCH_LT;
                        illegal_instruction = 1'b0;
                    end

                    3'b101: begin
                        branch_operation = BRANCH_GE;
                        illegal_instruction = 1'b0;
                    end

                    3'b110: begin
                        branch_operation = BRANCH_LTU;
                        illegal_instruction = 1'b0;
                    end

                    3'b111: begin
                        branch_operation = BRANCH_GEU;
                        illegal_instruction = 1'b0;
                    end

                    default: begin
                        
                    end
                endcase
            end

            OPCODE_LOAD: begin // address = rs1 + I-type immediate
                immediate_type = IMM_I;
                alu_operation = ALU_ADD;
                alu_a_select = ALU_A_RS1;
                alu_b_select = ALU_B_IMMEDIATE;

                case (funct3)
                    3'b000: begin // LB
                        memory_size = MEMORY_BYTE;
                        load_unsigned = 1'b0;
                        illegal_instruction = 1'b0;
                    end

                    3'b001: begin // LH
                        memory_size = MEMORY_HALF;
                        load_unsigned = 1'b0;
                        illegal_instruction = 1'b0;
                    end

                    3'b010: begin // LW
                        memory_size = MEMORY_WORD;
                        load_unsigned = 1'b0;
                        illegal_instruction = 1'b0;
                    end

                    3'b100: begin // LBU
                        memory_size = MEMORY_BYTE;
                        load_unsigned = 1'b1;
                        illegal_instruction = 1'b0;
                    end

                    3'b101: begin // LHU
                        memory_size = MEMORY_HALF;
                        load_unsigned = 1'b1;
                        illegal_instruction = 1'b0;
                    end

                    default: begin
                        
                    end
                endcase

                if (!illegal_instruction) begin
                    writeback_select = WB_MEMORY;
                    register_write_enable = 1'b1;
                    memory_read_enable = 1'b1;
                end
            end

            OPCODE_STORE: begin // address = rs1 + S-type immediate
                immediate_type = IMM_S;
                alu_operation = ALU_ADD;
                alu_a_select = ALU_A_RS1;
                alu_b_select = ALU_B_IMMEDIATE;

                case (funct3)
                    3'b000: begin // SB
                        memory_size = MEMORY_BYTE;
                        illegal_instruction = 1'b0;
                    end

                    3'b001: begin // SH
                        memory_size = MEMORY_HALF;
                        illegal_instruction = 1'b0;
                    end

                    3'b010: begin // SW
                        memory_size = MEMORY_WORD;
                        illegal_instruction = 1'b0;
                    end

                    default: begin
                        
                    end
                endcase

                if (!illegal_instruction) begin
                    memory_write_enable = 1'b1;
                end
            end

            OPCODE_OP_IMM: begin
                immediate_type = IMM_I;
                alu_a_select = ALU_A_RS1;
                alu_b_select = ALU_B_IMMEDIATE;

                case (funct3)
                    3'b000: begin // ADDI
                        alu_operation = ALU_ADD;
                        illegal_instruction = 1'b0;
                    end

                    3'b001: begin // SLLI
                        if (funct7 == FUNCT7_NORMAL) begin
                            alu_operation = ALU_SLL;
                            illegal_instruction = 1'b0;
                        end
                    end

                    3'b010: begin // SLTI
                        alu_operation = ALU_SLT;
                        illegal_instruction = 1'b0;
                    end

                    3'b011: begin // SLTIU
                        alu_operation = ALU_SLTU;
                        illegal_instruction = 1'b0;
                    end

                    3'b100: begin // XORI
                        alu_operation = ALU_XOR;
                        illegal_instruction = 1'b0;
                    end

                    3'b101: begin
                        if (funct7 == FUNCT7_NORMAL) begin // SRLI
                            alu_operation = ALU_SRL;
                            illegal_instruction = 1'b0;
                        end
                        else if (funct7 == FUNCT7_SUB_SRA) begin // SRAI
                            alu_operation = ALU_SRA;
                            illegal_instruction = 1'b0;
                        end
                    end

                    3'b110: begin // ORI
                        alu_operation = ALU_OR;
                        illegal_instruction = 1'b0;
                    end

                    3'b111: begin // ANDI
                        alu_operation = ALU_AND;
                        illegal_instruction = 1'b0;
                    end

                    default: begin
                        
                    end
                endcase

                if (!illegal_instruction) begin
                    writeback_select = WB_ALU;
                    register_write_enable = 1'b1;
                end
            end

            OPCODE_OP: begin
                immediate_type = IMM_NONE;
                alu_a_select = ALU_A_RS1;
                alu_b_select = ALU_B_RS2;

                case (funct3)
                    3'b000: begin
                        if (funct7 == FUNCT7_NORMAL) begin // ADD
                            alu_operation = ALU_ADD;
                            illegal_instruction = 1'b0;
                        end
                        else if (funct7 == FUNCT7_SUB_SRA) begin // SUB
                            alu_operation = ALU_SUB;
                            illegal_instruction = 1'b0;
                        end
                    end

                    3'b001: begin // SLL
                        if (funct7 == FUNCT7_NORMAL) begin
                            alu_operation = ALU_SLL;
                            illegal_instruction = 1'b0;
                        end
                    end

                    3'b010: begin // SLT
                        if (funct7 == FUNCT7_NORMAL) begin
                            alu_operation = ALU_SLT;
                            illegal_instruction = 1'b0;
                        end
                    end

                    3'b011: begin // SLTU
                        if (funct7 == FUNCT7_NORMAL) begin
                            alu_operation = ALU_SLTU;
                            illegal_instruction = 1'b0;
                        end
                    end

                    3'b100: begin // XOR
                        if (funct7 == FUNCT7_NORMAL) begin
                            alu_operation = ALU_XOR;
                            illegal_instruction = 1'b0;
                        end
                    end

                    3'b101: begin
                        if (funct7 == FUNCT7_NORMAL) begin // SRL
                            alu_operation = ALU_SRL;
                            illegal_instruction = 1'b0;
                        end
                        else if (funct7 == FUNCT7_SUB_SRA) begin // SRA
                            alu_operation = ALU_SRA;
                            illegal_instruction = 1'b0;
                        end
                    end

                    3'b110: begin // OR
                        if (funct7 == FUNCT7_NORMAL) begin
                            alu_operation = ALU_OR;
                            illegal_instruction = 1'b0;
                        end
                    end

                    3'b111: begin // AND
                        if (funct7 == FUNCT7_NORMAL) begin
                            alu_operation = ALU_AND;
                            illegal_instruction = 1'b0;
                        end
                    end

                    default: begin
                        
                    end
                endcase

                if (!illegal_instruction) begin
                    writeback_select = WB_ALU;
                    register_write_enable = 1'b1;
                end
            end

            OPCODE_MISC_MEM: begin
                if (funct3 == 3'b000) begin // FENCE
                    special_operation = SPECIAL_FENCE;
                    illegal_instruction = 1'b0;
                end
            end

            OPCODE_SYSTEM: begin
                if (instruction == 32'h00000073) begin // ECALL
                    special_operation = SPECIAL_ECALL;
                    illegal_instruction = 1'b0;
                end
                else if (instruction == 32'h00100073) begin // EBREAK
                    special_operation = SPECIAL_EBREAK;
                    illegal_instruction = 1'b0;
                end
            end
              
            OPCODE_CUSTOM_0: begin 
                case ({funct7, funct3})
                    //first custom instruction decoding: opcode = OPCODE_CUSTOM_0, func7 = FUNCT7_PQ, func3 = FUNCT3_PQ
                    {FUNCT7_PQ, FUNCT3_PQ}: begin 
                        immediate_type = IMM_NONE; // R type instruction
                        
                        alu_operation = ALU_PQ; // pq r3, r2, r1 format so a and b will be registers whose values need to be read 
                        alu_a_select = ALU_A_RS1;
                        alu_b_select = ALU_B_RS2;
                        
                        writeback_select = WB_ALU; // PQ instruction produces its result in the execuation stage 
                        
                        //branch_operation = BRANCH_NONE;
                        //jump_operation = JUMP_NONE;
                        //memory_size = MEMORY_NONE;
                        //special_operation = SPECIAL_NONE;
                        
                        register_write_enable = 1'b1; //need to write value of operation into register
                        //memory_read_enable = 1'b0; // no load operation
                        //memory_write_enable = 1'b0; //no store before
                        //load_unsigned = 1'b0;
                        
                        illegal_instruction = 1'b0;
                        
                            
                    end 
                    default: begin 
                        illegal_instruction = 1'b1;
                    end 
                endcase 
            end 
            default: begin
                
            end
        endcase
    end

endmodule