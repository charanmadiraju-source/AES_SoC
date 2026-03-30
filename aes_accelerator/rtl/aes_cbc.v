//-----------------------------------------------------------------------------
// AES-128 CBC Mode Wrapper
// Supports both encryption and decryption
//
// CBC Encrypt: C_i = AES_Encrypt(P_i XOR C_{i-1}),  C_0 = IV
//   - Serial dependency: must wait for ciphertext before next block
//   - Throughput: 1 block per 11 clock cycles
//
// CBC Decrypt: P_i = AES_Decrypt(C_i) XOR C_{i-1},  C_0 = IV
//   - No serial dependency on decrypt result (only on previous ciphertext
//     which is already known), but we still process one block at a time
//     due to register-based AXI4-Lite interface.
//
// Interface:
//   - Load key (key + key_valid pulse)
//   - Load IV  (iv  + iv_load pulse)
//   - Set mode (encrypt=1 / decrypt=0)
//   - Feed data blocks one at a time (din + start pulse)
//   - Wait for done, read result from dout
//-----------------------------------------------------------------------------

module aes_cbc (
    input          clk,
    input          rst_n,

    // Key interface
    input  [127:0] key,
    input          key_valid,

    // Control
    input  [127:0] iv,
    input          iv_load,
    input  [127:0] din,
    input          encrypt,     // 1 = encrypt, 0 = decrypt
    input          start,       // Start processing one 128-bit block
    output [127:0] dout,
    output reg     done,
    output reg     busy
);

    //=========================================================================
    // State machine
    //=========================================================================
    localparam IDLE    = 2'd0;
    localparam PROCESS = 2'd1;
    localparam DONE    = 2'd2;

    reg [1:0] state, next_state;

    // Latched mode for current operation
    reg encrypt_mode;

    //=========================================================================
    // CBC feedback register (stores previous ciphertext or IV)
    //=========================================================================
    reg [127:0] feedback;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            feedback <= 128'b0;
        else if (iv_load)
            feedback <= iv;
        else if (state == DONE) begin
            if (encrypt_mode)
                feedback <= enc_ciphertext_out; // Encrypt: feedback = produced ciphertext
            else
                feedback <= din_latched;        // Decrypt: feedback = input ciphertext
        end
    end

    //=========================================================================
    // Latch input data and mode on start
    //=========================================================================
    reg [127:0] din_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            din_latched  <= 128'b0;
            encrypt_mode <= 1'b1;
        end else if (start && state == IDLE) begin
            din_latched  <= din;
            encrypt_mode <= encrypt;
        end
    end

    //=========================================================================
    // ENCRYPT PATH
    // CBC Encrypt: AES_Encrypt(plaintext XOR feedback)
    //=========================================================================
    wire [127:0] enc_xor_input = din ^ feedback;

    reg          enc_pipe_valid;
    wire [127:0] enc_ciphertext_out;
    wire         enc_cipher_valid;

    aes_pipeline u_aes_enc_pipeline (
        .clk          (clk),
        .rst_n        (rst_n),
        .plaintext    (enc_xor_input),
        .key          (key),
        .data_valid   (enc_pipe_valid),
        .ciphertext   (enc_ciphertext_out),
        .cipher_valid (enc_cipher_valid)
    );

    //=========================================================================
    // DECRYPT PATH
    // CBC Decrypt: AES_Decrypt(ciphertext) XOR feedback
    //=========================================================================
    reg          dec_pipe_valid;
    wire [127:0] dec_plaintext_raw;
    wire         dec_plain_valid;

    aes_inv_pipeline u_aes_dec_pipeline (
        .clk          (clk),
        .rst_n        (rst_n),
        .ciphertext   (din),
        .key          (key),
        .data_valid   (dec_pipe_valid),
        .plaintext    (dec_plaintext_raw),
        .plain_valid  (dec_plain_valid)
    );

    // Register the encrypt ciphertext when the pipeline output is valid.
    // The encrypt pipeline runs continuously; latching the result on cipher_valid
    // prevents the output from being overwritten before the host reads it.
    reg [127:0] enc_result_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            enc_result_reg <= 128'b0;
        else if (enc_cipher_valid)
            enc_result_reg <= enc_ciphertext_out;
    end

    // Register the XOR of the decrypted block with feedback.
    // This must be captured when dec_plain_valid fires (state == PROCESS), before
    // the feedback register is updated at state == DONE, to avoid using the
    // already-updated feedback value for the current block's output.
    reg [127:0] dec_result_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            dec_result_reg <= 128'b0;
        else if (dec_plain_valid)
            dec_result_reg <= dec_plaintext_raw ^ feedback;
    end

    //=========================================================================
    // Output mux: select encrypt or decrypt result
    //=========================================================================
    assign dout = encrypt_mode ? enc_result_reg : dec_result_reg;

    // Combined valid from whichever pipeline is active
    wire result_valid = encrypt_mode ? enc_cipher_valid : dec_plain_valid;

    //=========================================================================
    // State machine
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS;
            end
            PROCESS: begin
                if (result_valid)
                    next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    //=========================================================================
    // Control signals
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enc_pipe_valid <= 1'b0;
            dec_pipe_valid <= 1'b0;
            done           <= 1'b0;
            busy           <= 1'b0;
        end else begin
            // Default
            enc_pipe_valid <= 1'b0;
            dec_pipe_valid <= 1'b0;
            done           <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        if (encrypt)
                            enc_pipe_valid <= 1'b1;
                        else
                            dec_pipe_valid <= 1'b1;
                        busy <= 1'b1;
                    end
                end
                PROCESS: begin
                    busy <= 1'b1;
                end
                DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                end
                default: begin
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule
