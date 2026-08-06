// PHASE 9 NEW MODULE: align a one-cycle synchronous Block RAM response with its original PC.
module rv32_instruction_fetch #(
    parameter logic [31:0] RESET_VECTOR = 32'h00000100,
    parameter INSTRUCTION_MEMORY_DEPTH_WORDS = 256
) (
    input logic clk,
    input logic resetn,
    input logic fetch_enable,
    input logic flush,

    input logic [31:0] pc,
    input logic [31:0] pc_plus_4,

    input logic [31:0] instruction_memory_read_data,

    output logic instruction_memory_enable,
    output logic [$clog2(INSTRUCTION_MEMORY_DEPTH_WORDS)-1:0] instruction_memory_address,

    output logic valid_out,
    output logic [31:0] pc_out,
    output logic [31:0] pc_plus_4_out,
    output logic [31:0] instruction_out,

    output logic instruction_address_misaligned,
    output logic instruction_address_out_of_range
);

    logic fetch_request;

    // PHASE 9 NEW LOGIC: reset and flush suppress requests that must not enter the pipeline.
    assign fetch_request = resetn &&
                           fetch_enable &&
                           !flush;

    rv32_instruction_address #(
        .RESET_VECTOR(RESET_VECTOR),
        .INSTRUCTION_MEMORY_DEPTH_WORDS(INSTRUCTION_MEMORY_DEPTH_WORDS)
    ) instruction_address (
        .pc(pc),
        .fetch_request(fetch_request),

        .instruction_memory_address(instruction_memory_address),
        .instruction_memory_enable(instruction_memory_enable),
        .instruction_address_misaligned(instruction_address_misaligned),
        .instruction_address_out_of_range(instruction_address_out_of_range)
    );

    // PHASE 9 NEW LOGIC: register the metadata at the same edge where Block RAM accepts its address.
    always_ff @(posedge clk) begin
        if (!resetn || flush) begin
            valid_out <= 1'b0;
            pc_out <= 32'b0;
            pc_plus_4_out <= 32'b0;
        end
        else if (fetch_enable) begin
            valid_out <= instruction_memory_enable;
            pc_out <= pc;
            pc_plus_4_out <= pc_plus_4;
        end
    end

    // PHASE 9 NEW LOGIC: Block RAM already supplies the synchronous data response, so no extra register is added.
    assign instruction_out = instruction_memory_read_data;

endmodule
