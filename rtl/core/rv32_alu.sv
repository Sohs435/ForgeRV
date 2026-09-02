module rv32_alu (
    input  logic [31:0]       lhs,
    input  logic [31:0]       rhs,
    input  rv32_pkg::alu_op_t operation,
    output logic [31:0]       result
);

    import rv32_pkg::*;

    always_comb begin
        case (operation)
            ALU_ADD:    result = lhs + rhs; //addition
            ALU_SUB:    result = lhs - rhs; //subtraction
            ALU_SLL:    result = lhs << rhs[4:0]; // logical left shift 
            ALU_SLT:    result = {31'b0, $signed(lhs) < $signed(rhs)}; //signed comparator
            ALU_SLTU:   result = {31'b0, lhs < rhs}; //unsigned comparator 
            ALU_XOR:    result = lhs ^ rhs; //XOR
            ALU_SRL:    result = lhs >> rhs[4:0]; // Logical right shift
            ALU_SRA:    result = $signed(lhs) >>> rhs[4:0]; // arithmetic right shift (preserve sign)
            ALU_OR:     result = lhs | rhs; //OR
            ALU_AND:    result = lhs & rhs; //AND
            ALU_COPY_B: result = rhs; //copy
            ALU_PQ: result = 32'b0;
            default:    result = 32'b0;
        endcase
    end

endmodule