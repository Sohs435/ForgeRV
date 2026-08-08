module rv32_fpga_wrapper (
    input wire clk,
    input wire resetn,
    input wire core_enable,

    input wire [31:0] instruction_memory_read_data,

    output wire instruction_memory_enable,
    output wire [7:0] instruction_memory_address,

    input wire [2:0] status_select,
    output wire [31:0] status_read_data
);

    rv32_fpga_top #(
        .RESET_VECTOR(32'h00000100),
        .INSTRUCTION_MEMORY_DEPTH_WORDS(256),
        .DATA_MEMORY_DEPTH_WORDS(256)
    ) fpga_top (
        .clk(clk),
        .resetn(resetn),
        .core_enable(core_enable),

        .instruction_memory_read_data(
            instruction_memory_read_data
        ),

        .instruction_memory_enable(
            instruction_memory_enable
        ),

        .instruction_memory_address(
            instruction_memory_address
        ),

        .status_select(status_select),
        .status_read_data(status_read_data)
    );

endmodule