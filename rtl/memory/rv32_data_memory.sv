module rv32_data_memory #(
    parameter DEPTH_WORDS = 1024
) (
    input logic clk,
    input logic memory_read_request,
    input logic memory_write_request,
    input logic [31:0] memory_address,
    input logic [31:0] memory_write_data,
    input logic [3:0] memory_write_strobe,

    output logic [31:0] memory_read_data
);

    localparam ADDRESS_WIDTH = $clog2(DEPTH_WORDS);

    logic [31:0] memory [0:DEPTH_WORDS-1];
    logic [ADDRESS_WIDTH-1:0] word_address;

    assign word_address = memory_address[ADDRESS_WIDTH+1:2];

    always_comb begin
        if (memory_read_request) memory_read_data = memory[word_address];
        else memory_read_data = 32'b0;
    end

    always_ff @(posedge clk) begin
        if (memory_write_request) begin
            if (memory_write_strobe[0]) memory[word_address][7:0] <= memory_write_data[7:0];
            if (memory_write_strobe[1]) memory[word_address][15:8] <= memory_write_data[15:8];
            if (memory_write_strobe[2]) memory[word_address][23:16] <= memory_write_data[23:16];
            if (memory_write_strobe[3]) memory[word_address][31:24] <= memory_write_data[31:24];
        end
    end

endmodule