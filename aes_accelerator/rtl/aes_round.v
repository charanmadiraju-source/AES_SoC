//-----------------------------------------------------------------------------
// AES Encryption Round (Rounds 1-9)
// SubBytes -> ShiftRows -> MixColumns -> AddRoundKey
// Fully combinational with registered output for pipelining
//-----------------------------------------------------------------------------

module aes_round (
    input         clk,
    input         rst_n,
    input  [127:0] data_in,
    input  [127:0] round_key,
    output reg [127:0] data_out
);

    //=========================================================================
    // AES state is 4x4 byte matrix stored column-major in 128-bit vector:
    //   state[127:120] = s[0][0],  state[119:112] = s[1][0],
    //   state[111:104] = s[2][0],  state[103:96]  = s[3][0],
    //   state[95:88]   = s[0][1],  state[87:80]   = s[1][1],
    //   state[79:72]   = s[2][1],  state[71:64]   = s[3][1],
    //   state[63:56]   = s[0][2],  state[55:48]   = s[1][2],
    //   state[47:40]   = s[2][2],  state[39:32]   = s[3][2],
    //   state[31:24]   = s[0][3],  state[23:16]   = s[1][3],
    //   state[15:8]    = s[2][3],  state[7:0]     = s[3][3]
    //=========================================================================

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
    // SubBytes: 16 parallel S-Box lookups
    //-------------------------------------------------------------------------
    wire [7:0] sb00, sb10, sb20, sb30;
    wire [7:0] sb01, sb11, sb21, sb31;
    wire [7:0] sb02, sb12, sb22, sb32;
    wire [7:0] sb03, sb13, sb23, sb33;

    aes_sbox u_sb00 (.din(s00), .dout(sb00));
    aes_sbox u_sb10 (.din(s10), .dout(sb10));
    aes_sbox u_sb20 (.din(s20), .dout(sb20));
    aes_sbox u_sb30 (.din(s30), .dout(sb30));
    aes_sbox u_sb01 (.din(s01), .dout(sb01));
    aes_sbox u_sb11 (.din(s11), .dout(sb11));
    aes_sbox u_sb21 (.din(s21), .dout(sb21));
    aes_sbox u_sb31 (.din(s31), .dout(sb31));
    aes_sbox u_sb02 (.din(s02), .dout(sb02));
    aes_sbox u_sb12 (.din(s12), .dout(sb12));
    aes_sbox u_sb22 (.din(s22), .dout(sb22));
    aes_sbox u_sb32 (.din(s32), .dout(sb32));
    aes_sbox u_sb03 (.din(s03), .dout(sb03));
    aes_sbox u_sb13 (.din(s13), .dout(sb13));
    aes_sbox u_sb23 (.din(s23), .dout(sb23));
    aes_sbox u_sb33 (.din(s33), .dout(sb33));

    //-------------------------------------------------------------------------
    // ShiftRows: cyclic left-shift of rows
    //   Row 0: no shift        Row 1: shift by 1
    //   Row 2: shift by 2      Row 3: shift by 3
    //-------------------------------------------------------------------------
    wire [7:0] sr00 = sb00, sr01 = sb01, sr02 = sb02, sr03 = sb03; // Row 0: no shift
    wire [7:0] sr10 = sb11, sr11 = sb12, sr12 = sb13, sr13 = sb10; // Row 1: shift 1
    wire [7:0] sr20 = sb22, sr21 = sb23, sr22 = sb20, sr23 = sb21; // Row 2: shift 2
    wire [7:0] sr30 = sb33, sr31 = sb30, sr32 = sb31, sr33 = sb32; // Row 3: shift 3

    //-------------------------------------------------------------------------
    // MixColumns: GF(2^8) matrix multiply
    // Each column: [2 3 1 1; 1 2 3 1; 1 1 2 3; 3 1 1 2] * column
    // xtime(a) = (a << 1) ^ (a[7] ? 8'h1b : 8'h00)  -- multiply by {02}
    //-------------------------------------------------------------------------
    function [7:0] xtime;
        input [7:0] a;
        xtime = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
    endfunction

    // Column 0
    wire [7:0] mc00 = xtime(sr00) ^ (xtime(sr10) ^ sr10) ^ sr20 ^ sr30;
    wire [7:0] mc10 = sr00 ^ xtime(sr10) ^ (xtime(sr20) ^ sr20) ^ sr30;
    wire [7:0] mc20 = sr00 ^ sr10 ^ xtime(sr20) ^ (xtime(sr30) ^ sr30);
    wire [7:0] mc30 = (xtime(sr00) ^ sr00) ^ sr10 ^ sr20 ^ xtime(sr30);

    // Column 1
    wire [7:0] mc01 = xtime(sr01) ^ (xtime(sr11) ^ sr11) ^ sr21 ^ sr31;
    wire [7:0] mc11 = sr01 ^ xtime(sr11) ^ (xtime(sr21) ^ sr21) ^ sr31;
    wire [7:0] mc21 = sr01 ^ sr11 ^ xtime(sr21) ^ (xtime(sr31) ^ sr31);
    wire [7:0] mc31 = (xtime(sr01) ^ sr01) ^ sr11 ^ sr21 ^ xtime(sr31);

    // Column 2
    wire [7:0] mc02 = xtime(sr02) ^ (xtime(sr12) ^ sr12) ^ sr22 ^ sr32;
    wire [7:0] mc12 = sr02 ^ xtime(sr12) ^ (xtime(sr22) ^ sr22) ^ sr32;
    wire [7:0] mc22 = sr02 ^ sr12 ^ xtime(sr22) ^ (xtime(sr32) ^ sr32);
    wire [7:0] mc32 = (xtime(sr02) ^ sr02) ^ sr12 ^ sr22 ^ xtime(sr32);

    // Column 3
    wire [7:0] mc03 = xtime(sr03) ^ (xtime(sr13) ^ sr13) ^ sr23 ^ sr33;
    wire [7:0] mc13 = sr03 ^ xtime(sr13) ^ (xtime(sr23) ^ sr23) ^ sr33;
    wire [7:0] mc23 = sr03 ^ sr13 ^ xtime(sr23) ^ (xtime(sr33) ^ sr33);
    wire [7:0] mc33 = (xtime(sr03) ^ sr03) ^ sr13 ^ sr23 ^ xtime(sr33);

    //-------------------------------------------------------------------------
    // Reassemble after MixColumns
    //-------------------------------------------------------------------------
    wire [127:0] after_mc = {mc00, mc10, mc20, mc30,
                              mc01, mc11, mc21, mc31,
                              mc02, mc12, mc22, mc32,
                              mc03, mc13, mc23, mc33};

    //-------------------------------------------------------------------------
    // AddRoundKey: XOR with round key
    //-------------------------------------------------------------------------
    wire [127:0] after_ark = after_mc ^ round_key;

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
