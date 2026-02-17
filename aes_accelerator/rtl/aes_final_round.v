//-----------------------------------------------------------------------------
// AES Final Encryption Round (Round 10)
// SubBytes -> ShiftRows -> AddRoundKey (NO MixColumns per FIPS-197)
// Fully combinational with registered output for pipelining
//-----------------------------------------------------------------------------

module aes_final_round (
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
    //-------------------------------------------------------------------------
    wire [7:0] sr00 = sb00, sr01 = sb01, sr02 = sb02, sr03 = sb03; // Row 0: no shift
    wire [7:0] sr10 = sb11, sr11 = sb12, sr12 = sb13, sr13 = sb10; // Row 1: shift 1
    wire [7:0] sr20 = sb22, sr21 = sb23, sr22 = sb20, sr23 = sb21; // Row 2: shift 2
    wire [7:0] sr30 = sb33, sr31 = sb30, sr32 = sb31, sr33 = sb32; // Row 3: shift 3

    //-------------------------------------------------------------------------
    // Reassemble after ShiftRows (NO MixColumns in final round)
    //-------------------------------------------------------------------------
    wire [127:0] after_sr = {sr00, sr10, sr20, sr30,
                              sr01, sr11, sr21, sr31,
                              sr02, sr12, sr22, sr32,
                              sr03, sr13, sr23, sr33};

    //-------------------------------------------------------------------------
    // AddRoundKey: XOR with round key
    //-------------------------------------------------------------------------
    wire [127:0] after_ark = after_sr ^ round_key;

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
