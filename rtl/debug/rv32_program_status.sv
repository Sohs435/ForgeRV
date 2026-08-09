module rv32_program_status #(
    parameter logic [31:0] STATUS_ADDRESS = 32'h00000040,
    parameter logic [31:0] FAILURE_CODE_ADDRESS = 32'h00000044,
    parameter logic [31:0] OBSERVED_VALUE_ADDRESS = 32'h00000048,
    parameter logic [31:0] EXPECTED_VALUE_ADDRESS = 32'h0000004C
) (
    input logic clk,
    input logic resetn,

    input logic memory_write_commit,
    input logic [31:0] memory_write_address,
    input logic [31:0] memory_write_data,
    input rv32_pkg::memory_size_t memory_write_size,

    output logic program_complete,
    output logic [31:0] program_status,
    output logic [31:0] failure_code,
    output logic [31:0] observed_value,
    output logic [31:0] expected_value
);

    import rv32_pkg::*;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            program_complete <= 1'b0;
            program_status <= 32'b0;
            failure_code <= 32'b0;
            observed_value <= 32'b0;
            expected_value <= 32'b0;
        end
        else if (memory_write_commit &&
                 (memory_write_size == MEMORY_WORD)) begin

            case (memory_write_address)
                STATUS_ADDRESS: begin
                    program_status <= memory_write_data;
                end

                FAILURE_CODE_ADDRESS: begin
                    failure_code <= memory_write_data;

                    // Passing program writes status = 1 before writing failure code = 0.
                    if (program_status == 32'h00000001)
                        program_complete <= 1'b1;
                end

                OBSERVED_VALUE_ADDRESS: begin
                    observed_value <= memory_write_data;
                end

                EXPECTED_VALUE_ADDRESS: begin
                    expected_value <= memory_write_data;

                    // Failing program writes the expected value last.
                    if (program_status == 32'hFFFFFFFF)
                        program_complete <= 1'b1;
                end

                default: begin
                end
            endcase
        end
    end

endmodule