// PHASE 9 NEW MODULE: convert the byte-addressed PC into an instruction Block RAM word address.
module rv32_instruction_address #(
    parameter logic [31:0] RESET_VECTOR = 32'h00000100,
    parameter INSTRUCTION_MEMORY_DEPTH_WORDS = 256
) (
    input logic [31:0] pc,
    input logic fetch_request,

    output logic [$clog2(INSTRUCTION_MEMORY_DEPTH_WORDS)-1:0] instruction_memory_address,
    output logic instruction_memory_enable,
    output logic instruction_address_misaligned,
    output logic instruction_address_out_of_range
);

    localparam logic [31:0] INSTRUCTION_MEMORY_SIZE_BYTES = INSTRUCTION_MEMORY_DEPTH_WORDS * 4;

    logic [31:0] instruction_offset;

    // PHASE 9 NEW LOGIC: make RESET_VECTOR correspond to instruction word zero.
    assign instruction_offset = pc - RESET_VECTOR;

    // PHASE 9 NEW LOGIC: remove the two byte-offset bits instead of building a hardware divider.
    assign instruction_memory_address = instruction_offset[
        $clog2(INSTRUCTION_MEMORY_DEPTH_WORDS)+1:2
    ];

    // PHASE 9 NEW LOGIC: RV32I instructions must begin at a multiple-of-four byte address.
    assign instruction_address_misaligned = fetch_request &&
                                            (pc[1:0] != 2'b00);

    // PHASE 9 NEW LOGIC: prevent the PC from reading outside the implemented 1,024-byte memory.
    assign instruction_address_out_of_range = fetch_request &&
                                              ((pc < RESET_VECTOR) ||
                                              (pc >= RESET_VECTOR + INSTRUCTION_MEMORY_SIZE_BYTES));

    // PHASE 9 NEW LOGIC: only allow Block RAM to read a valid, aligned address.
    assign instruction_memory_enable = fetch_request &&
                                       !instruction_address_misaligned &&
                                       !instruction_address_out_of_range;

endmodule
