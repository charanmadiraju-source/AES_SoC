//-----------------------------------------------------------------------------
// AES-128 Key Expansion
// Generates all 11 round keys (K0-K10) from 128-bit cipher key
// Pre-computes all keys combinationally and stores in output registers
// for synchronous delivery with the pipelined datapath
//-----------------------------------------------------------------------------

module aes_key_expand (
    input          clk,
    input          rst_n,
    input  [127:0] key_in,
    input          key_valid,    // Pulse to load new key
    output [127:0] round_key_0,
    output [127:0] round_key_1,
    output [127:0] round_key_2,
    output [127:0] round_key_3,
    output [127:0] round_key_4,
    output [127:0] round_key_5,
    output [127:0] round_key_6,
    output [127:0] round_key_7,
    output [127:0] round_key_8,
    output [127:0] round_key_9,
    output [127:0] round_key_10
);

    //=========================================================================
    // Round constants (Rcon) for AES-128 (10 rounds)
    //=========================================================================
    wire [7:0] rcon [0:9];
    assign rcon[0] = 8'h01;
    assign rcon[1] = 8'h02;
    assign rcon[2] = 8'h04;
    assign rcon[3] = 8'h08;
    assign rcon[4] = 8'h10;
    assign rcon[5] = 8'h20;
    assign rcon[6] = 8'h40;
    assign rcon[7] = 8'h80;
    assign rcon[8] = 8'h1b;
    assign rcon[9] = 8'h36;

    //=========================================================================
    // S-Box instances for key expansion (4 per round = RotWord + SubWord)
    //=========================================================================
    // Each round needs SubWord(RotWord(W[i-1])) for every 4th word
    // RotWord rotates bytes: [a0,a1,a2,a3] -> [a1,a2,a3,a0]
    // SubWord applies S-Box to each byte

    // Wires for intermediate round keys (combinational)
    wire [127:0] rk [0:10];
    assign rk[0] = key_in;

    // Generate 10 rounds of key expansion
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : key_round
            // Extract the last word (W[4i+3]) from previous round key
            wire [31:0] prev_w3 = rk[i][31:0];

            // RotWord: [b0, b1, b2, b3] -> [b1, b2, b3, b0]
            wire [7:0] rot_b0 = prev_w3[23:16]; // was b1
            wire [7:0] rot_b1 = prev_w3[15:8];  // was b2
            wire [7:0] rot_b2 = prev_w3[7:0];   // was b3
            wire [7:0] rot_b3 = prev_w3[31:24]; // was b0

            // SubWord: apply S-Box to each byte
            wire [7:0] sub_b0, sub_b1, sub_b2, sub_b3;
            aes_sbox u_sb0 (.din(rot_b0), .dout(sub_b0));
            aes_sbox u_sb1 (.din(rot_b1), .dout(sub_b1));
            aes_sbox u_sb2 (.din(rot_b2), .dout(sub_b2));
            aes_sbox u_sb3 (.din(rot_b3), .dout(sub_b3));

            // XOR with Rcon (only first byte)
            wire [31:0] temp = {sub_b0 ^ rcon[i], sub_b1, sub_b2, sub_b3};

            // Generate new round key words
            wire [31:0] w0 = rk[i][127:96] ^ temp;
            wire [31:0] w1 = rk[i][95:64]  ^ w0;
            wire [31:0] w2 = rk[i][63:32]  ^ w1;
            wire [31:0] w3 = rk[i][31:0]   ^ w2;

            assign rk[i+1] = {w0, w1, w2, w3};
        end
    endgenerate

    //=========================================================================
    // Registered round keys
    //=========================================================================
    reg [127:0] rk_reg [0:10];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rk_reg[0]  <= 128'b0;
            rk_reg[1]  <= 128'b0;
            rk_reg[2]  <= 128'b0;
            rk_reg[3]  <= 128'b0;
            rk_reg[4]  <= 128'b0;
            rk_reg[5]  <= 128'b0;
            rk_reg[6]  <= 128'b0;
            rk_reg[7]  <= 128'b0;
            rk_reg[8]  <= 128'b0;
            rk_reg[9]  <= 128'b0;
            rk_reg[10] <= 128'b0;
        end else if (key_valid) begin
            rk_reg[0]  <= rk[0];
            rk_reg[1]  <= rk[1];
            rk_reg[2]  <= rk[2];
            rk_reg[3]  <= rk[3];
            rk_reg[4]  <= rk[4];
            rk_reg[5]  <= rk[5];
            rk_reg[6]  <= rk[6];
            rk_reg[7]  <= rk[7];
            rk_reg[8]  <= rk[8];
            rk_reg[9]  <= rk[9];
            rk_reg[10] <= rk[10];
        end
    end

    assign round_key_0  = rk_reg[0];
    assign round_key_1  = rk_reg[1];
    assign round_key_2  = rk_reg[2];
    assign round_key_3  = rk_reg[3];
    assign round_key_4  = rk_reg[4];
    assign round_key_5  = rk_reg[5];
    assign round_key_6  = rk_reg[6];
    assign round_key_7  = rk_reg[7];
    assign round_key_8  = rk_reg[8];
    assign round_key_9  = rk_reg[9];
    assign round_key_10 = rk_reg[10];

endmodule
