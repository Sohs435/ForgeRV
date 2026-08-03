module rv32_memory_stage #(
    parameter DEPTH_WORDS = 1024
) (
    input logic clk,
    input logic [31:0] address,
    input logic [31:0] store_data,
    input logic memory_read_enable,
    input logic memory_write_enable,
    input rv32_pkg::memory_size_t memory_size,
    input logic load_unsigned,

    output logic [31:0] load_data,
    output logic memory_access_misaligned
);

    logic [31:0] memory_address;
    logic [31:0] memory_write_data;
    logic [3:0] memory_write_strobe;
    logic memory_read_request;
    logic memory_write_request;
    logic [31:0] memory_read_data;

    rv32_load_store_unit load_store_unit (
        .address(address),
        .store_data(store_data),
        .memory_read_enable(memory_read_enable),
        .memory_write_enable(memory_write_enable),
        .memory_size(memory_size),
        .load_unsigned(load_unsigned),
        .memory_read_data(memory_read_data),

        .memory_address(memory_address),
        .memory_write_data(memory_write_data),
        .memory_write_strobe(memory_write_strobe),
        .memory_read_request(memory_read_request),
        .memory_write_request(memory_write_request),
        .load_data(load_data),
        .memory_access_misaligned(memory_access_misaligned)
    );

    rv32_data_memory #(
        .DEPTH_WORDS(DEPTH_WORDS)
    ) data_memory (
        .clk(clk),
        .memory_read_request(memory_read_request),
        .memory_write_request(memory_write_request),
        .memory_address(memory_address),
        .memory_write_data(memory_write_data),
        .memory_write_strobe(memory_write_strobe),

        .memory_read_data(memory_read_data)
    );

endmodule