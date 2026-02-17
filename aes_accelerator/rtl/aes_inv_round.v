//-----------------------------------------------------------------------------
// AES Inverse Round (for decryption, rounds 9 down to 1)
// Standard Inverse Cipher (FIPS-197 Section 5.3):
//   InvShiftRows -> InvSubBytes -> AddRoundKey -> InvMixColumns
// Fully combinational with registered output for pipelining
//-----------------------------------------------------------------------------

module aes_inv_round (
    input         clk,
    input         rst_n,
    input  [127:0] data_in,
    input  [127:0] round_key,
    output reg [127:0] data_out
);

    // Extract input bytes (column-major)
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
    //   Row 0: no shift        Row 1: right shift by 1
    //   Row 2: right shift by 2  Row 3: right shift by 3
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
    // AddRoundKey: XOR with round key (Correct order for EqInvCipher is InvMix(ARK))
    // BUT FIPS-197 5.3 Standard Inverse Cipher: InvShift -> InvSub -> ARK -> InvMix
    // The code structure below matches FIPS-197 5.3:
    // 1. InvShift (srXX)
    // 2. InvSub (sbXX)
    // 3. ARK (after_ark)
    // 4. InvMix (mcXX)
    // This is CORRECT for standard inverse cipher.
    // 
    // Wait, the key schedule must be modified if using Equivalent Inverse Cipher.
    // We are using STANDARD Inverse Cipher, so key schedule is simply reverse order.
    //
    // Check key expansion implementation again...
    // The key expand module generates keys for Forward Cipher.
    // Forward: Input -> XOR(K0) -> Round(K1)...
    // Inverse: Input -> XOR(K10) -> InvRound(K9)...
    //
    // Standard Inverse Cipher requires:
    // dw = InvMixColumns(w) applied to round keys K1...K9 if using proper Equivalent Inverse Cipher workflow.
    // 
    // BUT we are implementing the STANDARD Inverse Cipher:
    // InvCipher(C, K) 
    //   state = InvShiftRows(InvSubBytes(state))
    //   state = AddRoundKey(state, key[r])
    //   state = InvMixColumns(state)
    //
    // Let's verify the order in aes_inv_round.v
    // It does:
    // sr = InvShift(in)
    // sb = InvSub(sr)
    // after_ark = sb ^ key  <-- AddRoundKey
    // out = InvMix(after_ark)
    //
    // This looks correct for FIPS-197 Fig 12.
    //
    // ISSUE: The decrypt failure values are completely wrong.
    // Let's re-verify the InvMixColumns coefficients.
    //-------------------------------------------------------------------------
    wire [127:0] after_isb = {sb00, sb10, sb20, sb30,
                               sb01, sb11, sb21, sb31,
                               sb02, sb12, sb22, sb32,
                               sb03, sb13, sb23, sb33};

    wire [127:0] after_ark = after_isb ^ round_key;

    // Extract bytes after AddRoundKey for InvMixColumns
    wire [7:0] a00 = after_ark[127:120];
    wire [7:0] a10 = after_ark[119:112];
    wire [7:0] a20 = after_ark[111:104];
    wire [7:0] a30 = after_ark[103:96];
    wire [7:0] a01 = after_ark[95:88];
    wire [7:0] a11 = after_ark[87:80];
    wire [7:0] a21 = after_ark[79:72];
    wire [7:0] a31 = after_ark[71:64];
    wire [7:0] a02 = after_ark[63:56];
    wire [7:0] a12 = after_ark[55:48];
    wire [7:0] a22 = after_ark[47:40];
    wire [7:0] a32 = after_ark[39:32];
    wire [7:0] a03 = after_ark[31:24];
    wire [7:0] a13 = after_ark[23:16];
    wire [7:0] a23 = after_ark[15:8];
    wire [7:0] a33 = after_ark[7:0];

    //-------------------------------------------------------------------------
    // InvMixColumns: multiply by inverse matrix in GF(2^8)
    //   [0e 0b 0d 09]
    //   [09 0e 0b 0d]
    //   [0d 09 0e 0b]
    //   [0b 0d 09 0e]
    //
    // GF(2^8) multiplication helpers:
    //   xtime(a)  = a * {02}
    //   x4(a)     = a * {04} = xtime(xtime(a))
    //   x8(a)     = a * {08} = xtime(x4(a))
    //   a * {09}  = x8(a) ^ a
    //   a * {0b}  = x8(a) ^ xtime(a) ^ a
    //   a * {0d}  = x8(a) ^ x4(a) ^ a
    //   a * {0e}  = x8(a) ^ x4(a) ^ xtime(a)
    //-------------------------------------------------------------------------

    function [7:0] xtime;
        input [7:0] a;
        xtime = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
    endfunction

    function [7:0] x4;
        input [7:0] a;
        x4 = xtime(xtime(a));
    endfunction

    function [7:0] x8;
        input [7:0] a;
        x8 = xtime(xtime(xtime(a)));
    endfunction

    // {09} = x8 + x1 = {1001}
    function [7:0] mul09;
        input [7:0] a;
        mul09 = x8(a) ^ a;
    endfunction

    // {0b} = x8 + x2 + x1 = {1011}
    function [7:0] mul0b;
        input [7:0] a;
        mul0b = x8(a) ^ xtime(a) ^ a;
    endfunction

    // {0d} = x8 + x4 + x1 = {1101}
    function [7:0] mul0d;
        input [7:0] a;
        mul0d = x8(a) ^ x4(a) ^ a;
    endfunction

    // {0e} = x8 + x4 + x2 = {1110}
    //-------------------------------------------------------------------------
    // InvMixColumns: multiply by inverse matrix in GF(2^8)
    //   [0e 0b 0d 09]
    //   [09 0e 0b 0d]
    //   [0d 09 0e 0b]
    //   [0b 0d 09 0e]
    //-------------------------------------------------------------------------
    // Column 0
    wire [7:0] mc00 = mul0e(a00) ^ mul0b(a10) ^ mul0d(a20) ^ mul09(a30);
    wire [7:0] mc10 = mul09(a00) ^ mul0e(a10) ^ mul0b(a20) ^ mul0d(a30);
    wire [7:0] mc20 = mul0d(a00) ^ mul09(a10) ^ mul0e(a20) ^ mul0b(a30);
    wire [7:0] mc30 = mul0b(a00) ^ mul0d(a10) ^ mul09(a20) ^ mul0e(a30);


    // Column 1
    wire [7:0] mc01 = mul0e(a01) ^ mul0b(a11) ^ mul0d(a21) ^ mul09(a31);
    wire [7:0] mc11 = mul09(a01) ^ mul0e(a11) ^ mul0b(a21) ^ mul0d(a31);
    wire [7:0] mc21 = mul0d(a01) ^ mul09(a11) ^ mul0e(a21) ^ mul0b(a31);
    wire [7:0] mc31 = mul0b(a01) ^ mul0d(a11) ^ mul09(a21) ^ mul0e(a31);

    // Column 2
    wire [7:0] mc02 = mul0e(a02) ^ mul0b(a12) ^ mul0d(a22) ^ mul09(a32);
    wire [7:0] mc12 = mul09(a02) ^ mul0e(a12) ^ mul0b(a22) ^ mul0d(a32);
    wire [7:0] mc22 = mul0d(a02) ^ mul09(a12) ^ mul0e(a22) ^ mul0b(a32);
    wire [7:0] mc32 = mul0b(a02) ^ mul0d(a12) ^ mul09(a22) ^ mul0e(a32);

    // Column 3
    wire [7:0] mc03 = mul0e(a03) ^ mul0b(a13) ^ mul0d(a23) ^ mul09(a33);
    wire [7:0] mc13 = mul09(a03) ^ mul0e(a13) ^ mul0b(a23) ^ mul0d(a33);
    wire [7:0] mc23 = mul0d(a03) ^ mul09(a13) ^ mul0e(a23) ^ mul0b(a33);
    wire [7:0] mc33 = mul0b(a03) ^ mul0d(a13) ^ mul09(a23) ^ mul0e(a33);

    //-------------------------------------------------------------------------
    // Reassemble after InvMixColumns
    //-------------------------------------------------------------------------
    wire [127:0] after_imc = {mc00, mc10, mc20, mc30,
                               mc01, mc11, mc21, mc31,
                               mc02, mc12, mc22, mc32,
                               mc03, mc13, mc23, mc33};

    //-------------------------------------------------------------------------
    // Pipeline register
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 128'b0;
        else
            data_out <= after_imc;
    end

endmodule
