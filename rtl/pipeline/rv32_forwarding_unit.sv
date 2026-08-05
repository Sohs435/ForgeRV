module rv32_forwarding_unit (
    input logic id_ex_valid, // current EX-stage instruction is real
    input logic [4:0] id_ex_rs1_address, // rs1 needed by current EX instruction
    input logic [4:0] id_ex_rs2_address, // rs2 needed by current EX instruction

    input logic ex_mem_valid, // EX/MEM contains a real older instruction
    input logic ex_mem_register_write_enable, // EX/MEM instruction will write rd
    input logic [4:0] ex_mem_rd_address, // destination of EX/MEM instruction
    input rv32_pkg::writeback_sel_t ex_mem_writeback_select, // type of result produced by EX/MEM

    input logic mem_wb_valid, // MEM/WB contains a real older instruction
    input logic mem_wb_register_write_enable, // MEM/WB instruction will write rd
    input logic [4:0] mem_wb_rd_address, // destination of MEM/WB instruction

    output rv32_pkg::forward_sel_t forward_a_select, // selects the value used for rs1
    output rv32_pkg::forward_sel_t forward_b_select // selects the value used for rs2
);

    import rv32_pkg::*;

    // Indicates whether the final result of the EX/MEM instruction
    // already exists and can be forwarded immediately.
    logic ex_mem_value_available;

    always_comb begin
        // An ALU instruction produces its final value during EX.
        // JAL and JALR also produce PC + 4 before reaching MEM.
        //
        // WB_MEMORY is deliberately excluded because a load's EX/MEM
        // ALU result is only its calculated memory address. The actual
        // loaded value will not be available until MEM/WB.
        ex_mem_value_available =
            (ex_mem_writeback_select == WB_ALU) ||
            (ex_mem_writeback_select == WB_PC_PLUS_4);

        // Normally use the values originally read from the register file.
        // These defaults are used when no matching newer result exists.
        forward_a_select = FORWARD_NONE;
        forward_b_select = FORWARD_NONE;

        // Do not forward anything into a bubble.
        // A bubble has valid=0 and does not represent a real instruction.
        if (id_ex_valid) begin

            // Check whether the immediately preceding instruction
            // produced the value required as rs1.
            if (ex_mem_valid &&
                ex_mem_register_write_enable &&
                ex_mem_value_available &&
                (ex_mem_rd_address != 5'd0) &&
                (ex_mem_rd_address == id_ex_rs1_address))
                forward_a_select = FORWARD_EX_MEM;

            // If EX/MEM does not have a matching available result,
            // check the older instruction in MEM/WB.
            //
            // Loads are allowed here because the memory read has already
            // completed and the loaded value now exists in writeback_data.
            else if (mem_wb_valid &&
                     mem_wb_register_write_enable &&
                     (mem_wb_rd_address != 5'd0) &&
                     (mem_wb_rd_address == id_ex_rs1_address))
                forward_a_select = FORWARD_MEM_WB;

            // Perform the same dependency check for rs2.
            if (ex_mem_valid &&
                ex_mem_register_write_enable &&
                ex_mem_value_available &&
                (ex_mem_rd_address != 5'd0) &&
                (ex_mem_rd_address == id_ex_rs2_address))
                forward_b_select = FORWARD_EX_MEM;

            // MEM/WB can forward ALU results, loaded values and PC + 4
            // because all of them are complete by the writeback stage.
            else if (mem_wb_valid &&
                     mem_wb_register_write_enable &&
                     (mem_wb_rd_address != 5'd0) &&
                     (mem_wb_rd_address == id_ex_rs2_address))
                forward_b_select = FORWARD_MEM_WB;
        end
    end

endmodule