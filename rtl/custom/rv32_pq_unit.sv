module rv32_pq_unit (
    input logic clk,
    input logic resetn,
    input logic start,

    input logic [31:0] alpha_values,
    input logic [31:0] beta_values,

    output logic busy,
    output logic stall,
    output logic done,
    output logic [31:0] power_result
);

    // Stage 1: registered forwarded operands
    logic stage_1_valid;
    logic [31:0] alpha_values_reg;
    logic [31:0] beta_values_reg;

    // Stage 2: multiplication and normalization
    logic stage_2_valid;

    logic signed [31:0] voltage_alpha_current_alpha;
    logic signed [31:0] voltage_beta_current_beta;
    logic signed [31:0] voltage_beta_current_alpha;
    logic signed [31:0] voltage_alpha_current_beta;

    logic signed [32:0] real_norm;
    logic signed [32:0] reactive_norm;

    // Stage 3: combinational scaling before EX/MEM
    logic signed [33:0] real_times_three;
    logic signed [33:0] reactive_times_three;

    logic start_accepted;

    // Only accept the PQ instruction once while ID/EX is being held
    assign start_accepted = resetn && start && !stage_1_valid && !stage_2_valid;

    // Include start_accepted because the unit becomes unavailable
    // immediately when it accepts a new operation.
    assign busy = start_accepted || stage_1_valid || stage_2_valid;

    // Hold the processor while capturing operands and calculating
    // the intermediate normalized values.
    assign stall = start_accepted || stage_1_valid;

    // The final result is valid while stage 2 contains an operation.
    assign done = stage_2_valid;

    // Stage 1: capture the forwarded rs1 and rs2 values
    always_ff @(posedge clk) begin
        if (!resetn) begin
            stage_1_valid <= 1'b0;
            alpha_values_reg <= 32'b0;
            beta_values_reg <= 32'b0;
        end
        else begin
            stage_1_valid <= start_accepted;

            if (start_accepted) begin
                alpha_values_reg <= alpha_values;
                beta_values_reg <= beta_values;
            end
        end
    end

    // va * ia
    assign voltage_alpha_current_alpha = $signed(alpha_values_reg[31:16]) * $signed(alpha_values_reg[15:0]);

    // vb * ib
    assign voltage_beta_current_beta = $signed(beta_values_reg[31:16]) * $signed(beta_values_reg[15:0]);

    // vb * ia
    assign voltage_beta_current_alpha = $signed(beta_values_reg[31:16]) * $signed(alpha_values_reg[15:0]);

    // va * ib
    assign voltage_alpha_current_beta = $signed(alpha_values_reg[31:16]) * $signed(beta_values_reg[15:0]);

    // Stage 2: register the normalized real and reactive calculations
    always_ff @(posedge clk) begin
        if (!resetn) begin
            stage_2_valid <= 1'b0;
            real_norm <= 33'b0;
            reactive_norm <= 33'b0;
        end
        else begin
            stage_2_valid <= stage_1_valid;

            if (stage_1_valid) begin
                // p_norm = va * ia + vb * ib
                real_norm <=
                    $signed({
                        voltage_alpha_current_alpha[31],
                        voltage_alpha_current_alpha
                    }) +
                    $signed({
                        voltage_beta_current_beta[31],
                        voltage_beta_current_beta
                    });

                // q_norm = vb * ia - va * ib
                reactive_norm <=
                    $signed({
                        voltage_beta_current_alpha[31],
                        voltage_beta_current_alpha
                    }) -
                    $signed({
                        voltage_alpha_current_beta[31],
                        voltage_alpha_current_beta
                    });
            end
        end
    end

    // Stage 3: multiply the normalized values by three
    // norm * 3 = norm + norm * 2
    assign real_times_three =
        $signed({
            real_norm[32],
            real_norm
        }) +
        ($signed({
            real_norm[32],
            real_norm
        }) <<< 1);

    assign reactive_times_three =
        $signed({
            reactive_norm[32],
            reactive_norm
        }) +
        ($signed({
            reactive_norm[32],
            reactive_norm
        }) <<< 1);

    // Q1.15 x Q1.15 produces a result with 30 fractional bits.
    // The output uses Q2.14, so 30 - 14 = 16 fractional bits must be removed.
    // The 3/2 power coefficient adds one more right shift for division by two.
    // Total right shift = (30 - 14) + 1 = 17 bits.
    // EX/MEM captures power_result when done is high, making EX/MEM
    // the third clocked stage of the PQ operation.
    assign power_result[15:0] = real_times_three >>> 17;
    assign power_result[31:16] = reactive_times_three >>> 17;

endmodule