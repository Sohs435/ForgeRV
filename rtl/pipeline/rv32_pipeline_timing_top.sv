module rv32_pipeline_timing_top #(
    parameter logic [31:0] RESET_VECTOR = 32'h00000100,
    parameter DATA_MEMORY_DEPTH_WORDS = 256
) (
    input logic clk,
    input logic resetn,
    input logic core_enable,
    input logic [31:0] instruction,
    input logic [2:0] debug_select,

    output logic [31:0] debug_data,
    output logic [7:0] debug_status
);

    logic [31:0] pc;
    logic [31:0] writeback_data;
    logic register_write_enable;
    logic pipeline_stalled;
    logic control_transfer_taken;
    logic core_fault;

    rv32_pipeline_core #(
        .RESET_VECTOR(RESET_VECTOR),
        .DATA_MEMORY_DEPTH_WORDS(DATA_MEMORY_DEPTH_WORDS)
    ) pipeline_core (
        .clk(clk),
        .resetn(resetn),
        .core_enable(core_enable),
        .instruction(instruction),

        .pc(pc),
        .writeback_data(writeback_data),
        .register_write_enable(register_write_enable),
        .pipeline_stalled(pipeline_stalled),
        .control_transfer_taken(control_transfer_taken),
        .core_fault(core_fault)
    );

    always_comb begin
        case(debug_select)
            3'd0: debug_data = pc;
            3'd1: debug_data = instruction;
            3'd2: debug_data = writeback_data;
            3'd3: debug_data = {31'b0, register_write_enable};
            3'd4: debug_data = {31'b0, pipeline_stalled};
            3'd5: debug_data = {31'b0, control_transfer_taken};
            3'd6: debug_data = {31'b0, core_fault};
            default: debug_data = 32'b0;
        endcase
    end

    assign debug_status = {
        core_enable,
        core_fault,
        pipeline_stalled,
        control_transfer_taken,
        register_write_enable,
        3'b0
    };

endmodule