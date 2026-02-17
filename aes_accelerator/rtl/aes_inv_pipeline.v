//-----------------------------------------------------------------------------
// AES-128 Fully Pipelined Decryption Core (Inverse Cipher)
// FIPS-197 Section 5.3 - Standard Inverse Cipher
//
// Structure:
//   Stage 0:  AddRoundKey with K10
//   Stages 1-9: InvShiftRows -> InvSubBytes -> AddRoundKey(Ki) -> InvMixColumns
//               using keys K9 down to K1
//   Stage 10: InvShiftRows -> InvSubBytes -> AddRoundKey(K0)
//
// Latency: 11 clock cycles
// Throughput: 1 block per clock cycle (after pipeline fills)
//-----------------------------------------------------------------------------

module aes_inv_pipeline (
    input          clk,
    input          rst_n,
    input  [127:0] ciphertext,
    input  [127:0] key,
    input          data_valid,
    output [127:0] plaintext,
    output         plain_valid
);

    //=========================================================================
    // Key Expansion: generate all 11 round keys (reuse forward key expand)
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
    // Initial AddRoundKey: XOR ciphertext with K10 and register
    //=========================================================================
    reg [127:0] state_0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_0 <= 128'b0;
        else
            state_0 <= ciphertext ^ rk10;
    end

    //=========================================================================
    // Inverse Rounds 1-9: using keys K9 down to K1
    // InvShiftRows -> InvSubBytes -> AddRoundKey -> InvMixColumns
    //=========================================================================
    wire [127:0] state_1, state_2, state_3, state_4, state_5;
    wire [127:0] state_6, state_7, state_8, state_9;

    aes_inv_round u_inv_round1 (.clk(clk), .rst_n(rst_n), .data_in(state_0), .round_key(rk9), .data_out(state_1));
    aes_inv_round u_inv_round2 (.clk(clk), .rst_n(rst_n), .data_in(state_1), .round_key(rk8), .data_out(state_2));
    aes_inv_round u_inv_round3 (.clk(clk), .rst_n(rst_n), .data_in(state_2), .round_key(rk7), .data_out(state_3));
    aes_inv_round u_inv_round4 (.clk(clk), .rst_n(rst_n), .data_in(state_3), .round_key(rk6), .data_out(state_4));
    aes_inv_round u_inv_round5 (.clk(clk), .rst_n(rst_n), .data_in(state_4), .round_key(rk5), .data_out(state_5));
    aes_inv_round u_inv_round6 (.clk(clk), .rst_n(rst_n), .data_in(state_5), .round_key(rk4), .data_out(state_6));
    aes_inv_round u_inv_round7 (.clk(clk), .rst_n(rst_n), .data_in(state_6), .round_key(rk3), .data_out(state_7));
    aes_inv_round u_inv_round8 (.clk(clk), .rst_n(rst_n), .data_in(state_7), .round_key(rk2), .data_out(state_8));
    aes_inv_round u_inv_round9 (.clk(clk), .rst_n(rst_n), .data_in(state_8), .round_key(rk1), .data_out(state_9));

    //=========================================================================
    // Inverse Final Round: using K0
    // InvShiftRows -> InvSubBytes -> AddRoundKey (no InvMixColumns)
    //=========================================================================
    wire [127:0] state_10;

    aes_inv_final_round u_inv_round10 (.clk(clk), .rst_n(rst_n), .data_in(state_9), .round_key(rk0), .data_out(state_10));

    assign plaintext = state_10;

    //=========================================================================
    // Valid signal pipeline
    //=========================================================================
    reg [10:0] valid_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_pipe <= 11'b0;
        else
            valid_pipe <= {valid_pipe[9:0], data_valid};
    end

    assign plain_valid = valid_pipe[10];

endmodule
