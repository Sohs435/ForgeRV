module rv32_pq_unit (
    input logic [31:0] alpha_values,
    input logic [31:0] beta_values,

    output logic [31:0] power_result
);

    logic signed [31:0] voltage_alpha_current_alpha;
    logic signed [31:0] voltage_beta_current_beta;
    logic signed [31:0] voltage_beta_current_alpha;
    logic signed [31:0] voltage_alpha_current_beta;

    logic signed [32:0] real_norm;
    logic signed [32:0] reactive_norm;

    logic signed [33:0] real_times_three;
    logic signed [33:0] reactive_times_three;
    
    // va * ia
    assign voltage_alpha_current_alpha =
        $signed(alpha_values[31:16]) *
        $signed(alpha_values[15:0]);
    // vb * ib
    assign voltage_beta_current_beta =
        $signed(beta_values[31:16]) *
        $signed(beta_values[15:0]);

    // vb * ia
    assign voltage_beta_current_alpha =
        $signed(beta_values[31:16]) *
        $signed(alpha_values[15:0]);

    // va * ib
    assign voltage_alpha_current_beta =
        $signed(alpha_values[31:16]) *
        $signed(beta_values[15:0]);

    // sign extended while keeping true magnitude same 
    assign real_norm =
        $signed({
            voltage_alpha_current_alpha[31],
            voltage_alpha_current_alpha
        }) +
        $signed({
            voltage_beta_current_beta[31],
            voltage_beta_current_beta
        });

    assign reactive_norm =
        $signed({
            voltage_beta_current_alpha[31],
            voltage_beta_current_alpha
        }) -
        $signed({
            voltage_alpha_current_beta[31],
            voltage_alpha_current_beta
        });

    // scale by 3 by adding normalised to normalised shifted by 1 bit to the left
    // so basically norm + norm * 2
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
    assign power_result[15:0] = real_times_three >>> 17;
    assign power_result[31:16] = reactive_times_three >>> 17;

endmodule