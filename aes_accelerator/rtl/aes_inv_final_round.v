//-----------------------------------------------------------------------------
// AES Inverse Final Round (for decryption, last round = round 0)
// InvShiftRows -> InvSubBytes -> AddRoundKey (NO InvMixColumns)
// Fully combinational with registered output for pipelining
//-----------------------------------------------------------------------------

module aes_inv_final_round (
    input         clk,
    input         rst_n,
    input  [127:0] data_in,
    input  [127:0] round_key,
    output reg [127:0] data_out
);

    // Extract input bytes
    wire [7:0] s00 = data_in[127:120];
    wire [7:0] s10 = data_in[119:112];
    wire [7:0] s20 = data_in[111:104];
    wire [7:0] s30 = data_in[103:96];
    wire [7:0] s01 = data_in[95:88];
    wire [7:0] s11 = data_in[87:80];
    wire [7:0] s21 = data_in[79:72];
    wire [7:0] s31 = data_in[71:64];
    wire [7:0] s02 = data_in[63:56];
    wire [7:0] s12 = data_in[55:48];
    wire [7:0] s22 = data_in[47:40];
    wire [7:0] s32 = data_in[39:32];
    wire [7:0] s03 = data_in[31:24];
    wire [7:0] s13 = data_in[23:16];
    wire [7:0] s23 = data_in[15:8];
    wire [7:0] s33 = data_in[7:0];

    //-------------------------------------------------------------------------
    // InvShiftRows: cyclic RIGHT-shift of rows
    //-------------------------------------------------------------------------
    wire [7:0] sr00 = s00, sr01 = s01, sr02 = s02, sr03 = s03; // Row 0: no shift
    wire [7:0] sr10 = s13, sr11 = s10, sr12 = s11, sr13 = s12; // Row 1: right 1
    wire [7:0] sr20 = s22, sr21 = s23, sr22 = s20, sr23 = s21; // Row 2: right 2
    wire [7:0] sr30 = s31, sr31 = s32, sr32 = s33, sr33 = s30; // Row 3: right 3

    //-------------------------------------------------------------------------
    // InvSubBytes: 16 parallel Inverse S-Box lookups
    //-------------------------------------------------------------------------
    wire [7:0] sb00, sb10, sb20, sb30;
    wire [7:0] sb01, sb11, sb21, sb31;
    wire [7:0] sb02, sb12, sb22, sb32;
    wire [7:0] sb03, sb13, sb23, sb33;

    aes_inv_sbox u_isb00 (.din(sr00), .dout(sb00));
    aes_inv_sbox u_isb10 (.din(sr10), .dout(sb10));
    aes_inv_sbox u_isb20 (.din(sr20), .dout(sb20));
    aes_inv_sbox u_isb30 (.din(sr30), .dout(sb30));
    aes_inv_sbox u_isb01 (.din(sr01), .dout(sb01));
    aes_inv_sbox u_isb11 (.din(sr11), .dout(sb11));
    aes_inv_sbox u_isb21 (.din(sr21), .dout(sb21));
    aes_inv_sbox u_isb31 (.din(sr31), .dout(sb31));
    aes_inv_sbox u_isb02 (.din(sr02), .dout(sb02));
    aes_inv_sbox u_isb12 (.din(sr12), .dout(sb12));
    aes_inv_sbox u_isb22 (.din(sr22), .dout(sb22));
    aes_inv_sbox u_isb32 (.din(sr32), .dout(sb32));
    aes_inv_sbox u_isb03 (.din(sr03), .dout(sb03));
    aes_inv_sbox u_isb13 (.din(sr13), .dout(sb13));
    aes_inv_sbox u_isb23 (.din(sr23), .dout(sb23));
    aes_inv_sbox u_isb33 (.din(sr33), .dout(sb33));

    //-------------------------------------------------------------------------
    // Reassemble after InvSubBytes (no InvMixColumns in final round)
    //-------------------------------------------------------------------------
    wire [127:0] after_isb = {sb00, sb10, sb20, sb30,
                               sb01, sb11, sb21, sb31,
                               sb02, sb12, sb22, sb32,
                               sb03, sb13, sb23, sb33};

    //-------------------------------------------------------------------------
    // AddRoundKey: XOR with round key (K0)
    //-------------------------------------------------------------------------
    wire [127:0] after_ark = after_isb ^ round_key;

    //-------------------------------------------------------------------------
    // Pipeline register
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 128'b0;
        else
            data_out <= after_ark;
    end

endmodule
