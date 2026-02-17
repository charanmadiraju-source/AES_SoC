//-----------------------------------------------------------------------------
// AES-128 Fully Pipelined Encryption Core
// 10-stage pipeline: Initial AddRoundKey + 9 full rounds + 1 final round
// Latency: 11 clock cycles (10 round registers + 1 output register)
// Throughput: 1 block per clock cycle (after pipeline fills)
//-----------------------------------------------------------------------------

module aes_pipeline (
    input          clk,
    input          rst_n,
    input  [127:0] plaintext,
    input  [127:0] key,
    input          data_valid,   // Input data valid pulse
    output [127:0] ciphertext,
    output         cipher_valid  // Output valid (11 cycles after data_valid)
);

    //=========================================================================
    // Key Expansion: generate all 11 round keys
    //=========================================================================
    wire [127:0] rk0, rk1, rk2, rk3, rk4, rk5, rk6, rk7, rk8, rk9, rk10;

    aes_key_expand u_key_expand (
        .clk          (clk),
        .rst_n        (rst_n),
        .key_in       (key),
        .key_valid    (data_valid),
        .round_key_0  (rk0),
        .round_key_1  (rk1),
        .round_key_2  (rk2),
        .round_key_3  (rk3),
        .round_key_4  (rk4),
        .round_key_5  (rk5),
        .round_key_6  (rk6),
        .round_key_7  (rk7),
        .round_key_8  (rk8),
        .round_key_9  (rk9),
        .round_key_10 (rk10)
    );

    //=========================================================================
    // Initial AddRoundKey (XOR plaintext with K0 and register)
    //=========================================================================
    reg [127:0] state_0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_0 <= 128'b0;
        else
            state_0 <= plaintext ^ rk0;
    end

    //=========================================================================
    // Rounds 1-9: full AES rounds (SubBytes, ShiftRows, MixColumns, AddRoundKey)
    //=========================================================================
    wire [127:0] state_1, state_2, state_3, state_4, state_5;
    wire [127:0] state_6, state_7, state_8, state_9;

    aes_round u_round1 (.clk(clk), .rst_n(rst_n), .data_in(state_0), .round_key(rk1),  .data_out(state_1));
    aes_round u_round2 (.clk(clk), .rst_n(rst_n), .data_in(state_1), .round_key(rk2),  .data_out(state_2));
    aes_round u_round3 (.clk(clk), .rst_n(rst_n), .data_in(state_2), .round_key(rk3),  .data_out(state_3));
    aes_round u_round4 (.clk(clk), .rst_n(rst_n), .data_in(state_3), .round_key(rk4),  .data_out(state_4));
    aes_round u_round5 (.clk(clk), .rst_n(rst_n), .data_in(state_4), .round_key(rk5),  .data_out(state_5));
    aes_round u_round6 (.clk(clk), .rst_n(rst_n), .data_in(state_5), .round_key(rk6),  .data_out(state_6));
    aes_round u_round7 (.clk(clk), .rst_n(rst_n), .data_in(state_6), .round_key(rk7),  .data_out(state_7));
    aes_round u_round8 (.clk(clk), .rst_n(rst_n), .data_in(state_7), .round_key(rk8),  .data_out(state_8));
    aes_round u_round9 (.clk(clk), .rst_n(rst_n), .data_in(state_8), .round_key(rk9),  .data_out(state_9));

    //=========================================================================
    // Round 10: final round (no MixColumns)
    //=========================================================================
    wire [127:0] state_10;

    aes_final_round u_round10 (.clk(clk), .rst_n(rst_n), .data_in(state_9), .round_key(rk10), .data_out(state_10));

    assign ciphertext = state_10;

    //=========================================================================
    // Valid signal pipeline (tracks data through pipeline stages)
    //=========================================================================
    reg [10:0] valid_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_pipe <= 11'b0;
        else
            valid_pipe <= {valid_pipe[9:0], data_valid};
    end

    assign cipher_valid = valid_pipe[10];

endmodule
