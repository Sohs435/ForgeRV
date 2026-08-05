module rv32_hazard_unit (
    input logic if_id_valid, // instruction in IF/ID is real
    input logic if_id_uses_rs1, // instruction in IF/ID reads rs1
    input logic if_id_uses_rs2, // instruction in IF/ID reads rs2
    input logic [4:0] if_id_rs1_address, // rs1 address of the younger instruction
    input logic [4:0] if_id_rs2_address, // rs2 address of the younger instruction

    input logic id_ex_valid, // instruction in ID/EX is real
    input logic id_ex_memory_read_enable, // ID/EX instruction is loading from memory
    input logic [4:0] id_ex_rd_address, // destination register of the older instruction

    output logic pipeline_stalled // stall request sent to the pipeline top
);

    logic rs1_hazard; // younger instruction needs the older instruction's rd as rs1
    logic rs2_hazard; // younger instruction needs the older instruction's rd as rs2
    logic load_use_hazard; // required load value is not available yet

    always_comb begin
        // Check whether the younger instruction actually reads rs1
        // and whether rs1 matches the older instruction's destination
        rs1_hazard = if_id_uses_rs1 &&
                     (if_id_rs1_address == id_ex_rd_address);

        // Check whether the younger instruction actually reads rs2
        // and whether rs2 matches the older instruction's destination
        rs2_hazard = if_id_uses_rs2 &&
                     (if_id_rs2_address == id_ex_rd_address);

        // Stall when:
        // 1. Both pipeline stages contain real instructions
        // 2. The older instruction is a load
        // 3. The load is not writing to x0
        // 4. The younger instruction needs the load's destination register
        load_use_hazard = if_id_valid &&
                          id_ex_valid &&
                          id_ex_memory_read_enable &&
                          (id_ex_rd_address != 5'd0) &&
                          (rs1_hazard || rs2_hazard);

        // The top module uses this signal to:
        // 1. Hold the PC
        // 2. Hold the IF/ID register
        // 3. Flush ID/EX to insert one bubble
        pipeline_stalled = load_use_hazard;
    end

endmodule