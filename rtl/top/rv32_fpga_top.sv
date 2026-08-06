// PHASE 9 NEW MODULE: provide a clean boundary between ForgeRV and the Vivado block design.
module rv32_fpga_top #(
    parameter logic [31:0] RESET_VECTOR = 32'h00000100,
    parameter INSTRUCTION_MEMORY_DEPTH_WORDS = 256,
    parameter DATA_MEMORY_DEPTH_WORDS = 256
) (
    input logic clk,
    input logic resetn,
    input logic core_enable,

    // Receive the synchronous response from instruction Block RAM Port B.
    input logic [31:0] instruction_memory_read_data,

    // Drive instruction Block RAM Port B.
    output logic instruction_memory_enable,
    output logic [$clog2(INSTRUCTION_MEMORY_DEPTH_WORDS)-1:0] instruction_memory_address,

    // Select one internal processor value to expose through AXI.
    input logic [2:0] status_select,
    output logic [31:0] status_read_data
);

    // Required because memory_size_t is declared inside rv32_pkg.
    import rv32_pkg::*;

    // Internal processor signals are not exposed as separate top-level buses.
    logic [31:0] pc;
    logic [31:0] writeback_data;
    logic register_write_enable;
    logic pipeline_stalled;
    logic control_transfer_taken;
    logic core_fault;

    // Copies of the processor store path used by the status monitor.
    logic data_memory_write_commit;
    logic [31:0] data_memory_write_address;
    logic [31:0] data_memory_write_data;
    memory_size_t data_memory_write_size;

    // Program-result registers remain internal and are selected one at a time.
    logic program_complete;
    logic [31:0] program_status;
    logic [31:0] failure_code;
    logic [31:0] observed_value;
    logic [31:0] expected_value;

    rv32_pipeline_core #(
        .RESET_VECTOR(RESET_VECTOR),
        .INSTRUCTION_MEMORY_DEPTH_WORDS(INSTRUCTION_MEMORY_DEPTH_WORDS),
        .DATA_MEMORY_DEPTH_WORDS(DATA_MEMORY_DEPTH_WORDS)
    ) processor (
        .clk(clk),
        .resetn(resetn),
        .core_enable(core_enable),

        .instruction_memory_read_data(instruction_memory_read_data),
        .instruction_memory_enable(instruction_memory_enable),
        .instruction_memory_address(instruction_memory_address),

        // Observe the committed store path without changing the memory operation.
        .data_memory_write_commit(data_memory_write_commit),
        .data_memory_write_address(data_memory_write_address),
        .data_memory_write_data(data_memory_write_data),
        .data_memory_write_size(data_memory_write_size),

        .pc(pc),
        .writeback_data(writeback_data),
        .register_write_enable(register_write_enable),
        .pipeline_stalled(pipeline_stalled),
        .control_transfer_taken(control_transfer_taken),
        .core_fault(core_fault)
    );

    rv32_program_status program_status_monitor (
        .clk(clk),
        .resetn(resetn),

        .memory_write_commit(data_memory_write_commit),
        .memory_write_address(data_memory_write_address),
        .memory_write_data(data_memory_write_data),
        .memory_write_size(data_memory_write_size),

        .program_complete(program_complete),
        .program_status(program_status),
        .failure_code(failure_code),
        .observed_value(observed_value),
        .expected_value(expected_value)
    );

    // Return only one 32-bit internal value through the future AXI interface.
    always_comb begin
        case (status_select)
            3'd0: status_read_data = program_status;
            3'd1: status_read_data = failure_code;
            3'd2: status_read_data = observed_value;
            3'd3: status_read_data = expected_value;

            3'd4: status_read_data = {
                30'b0,
                core_fault,
                program_complete
            };

            3'd5: status_read_data = pc;

            3'd6: status_read_data = writeback_data;

            3'd7: status_read_data = {
                29'b0,
                control_transfer_taken,
                pipeline_stalled,
                register_write_enable
            };

            default: status_read_data = 32'b0;
        endcase
    end

endmodule