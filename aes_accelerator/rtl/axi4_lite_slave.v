//-----------------------------------------------------------------------------
// AXI4-Lite Slave Interface for AES Accelerator
// 
// Register Map (32-bit registers, byte-addressable):
// Offset  Name       R/W   Description
// 0x00    KEY0       W     Key bits [127:96]
// 0x04    KEY1       W     Key bits [95:64]
// 0x08    KEY2       W     Key bits [63:32]
// 0x0C    KEY3       W     Key bits [31:0]
// 0x10    IV0        W     IV bits [127:96]
// 0x14    IV1        W     IV bits [95:64]
// 0x18    IV2        W     IV bits [63:32]
// 0x1C    IV3        W     IV bits [31:0]
// 0x20    DIN0       W     Data input bits [127:96]
// 0x24    DIN1       W     Data input bits [95:64]
// 0x28    DIN2       W     Data input bits [63:32]
// 0x2C    DIN3       W     Data input bits [31:0]
// 0x30    DOUT0      R     Data output bits [127:96]
// 0x34    DOUT1      R     Data output bits [95:64]
// 0x38    DOUT2      R     Data output bits [63:32]
// 0x3C    DOUT3      R     Data output bits [31:0]
// 0x40    CTRL       R/W   bit0: start, bit1: encrypt(1)/decrypt(0), bit2: iv_load
// 0x44    STATUS     R     bit0: done, bit1: busy
// 0x48    KEY_CTRL   W     bit0: key_valid (pulse to load key)
//
// AXI4-Lite: 32-bit data bus, supports single-beat transactions only
//-----------------------------------------------------------------------------

module axi4_lite_slave #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 7    // 128 bytes address space
) (
    // AXI4-Lite Slave Interface
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN,
    // Write address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire [2:0]                        S_AXI_AWPROT,
    input  wire                              S_AXI_AWVALID,
    output wire                              S_AXI_AWREADY,
    // Write data channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0]   S_AXI_WSTRB,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,
    // Write response channel
    output wire [1:0]                        S_AXI_BRESP,
    output wire                              S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,
    // Read address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire [2:0]                        S_AXI_ARPROT,
    input  wire                              S_AXI_ARVALID,
    output wire                              S_AXI_ARREADY,
    // Read data channel
    output wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output wire [1:0]                        S_AXI_RRESP,
    output wire                              S_AXI_RVALID,
    input  wire                              S_AXI_RREADY,

    // AES Core Interface
    output reg  [127:0] aes_key,
    output reg          aes_key_valid,
    output reg  [127:0] aes_iv,
    output reg          aes_iv_load,
    output reg  [127:0] aes_din,
    output reg          aes_start,
    output reg          aes_encrypt,
    input  wire [127:0] aes_dout,
    input  wire         aes_done,
    input  wire         aes_busy
);

    //=========================================================================
    // Internal signals
    //=========================================================================
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg                          axi_awready;
    reg                          axi_wready;
    reg [1:0]                    axi_bresp;
    reg                          axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg                          axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0]                    axi_rresp;
    reg                          axi_rvalid;

    // Register file
    reg [31:0] reg_key   [0:3];
    reg [31:0] reg_iv    [0:3];
    reg [31:0] reg_din   [0:3];
    reg [31:0] reg_ctrl;

    // Latched done flag (sticky, cleared on CTRL write)
    reg        done_flag;

    //=========================================================================
    // AXI output assignments
    //=========================================================================
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    //=========================================================================
    // Write address channel handshake
    //=========================================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
            axi_awaddr  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID) begin
                axi_awready <= 1'b1;
                axi_awaddr  <= S_AXI_AWADDR;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    //=========================================================================
    // Write data channel handshake
    //=========================================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_wready <= 1'b0;
        end else begin
            if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end

    //=========================================================================
    // Write register logic
    //=========================================================================
    wire wr_en = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
    wire [6:0] wr_addr = axi_awaddr[6:0];

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            reg_key[0]    <= 32'b0;
            reg_key[1]    <= 32'b0;
            reg_key[2]    <= 32'b0;
            reg_key[3]    <= 32'b0;
            reg_iv[0]     <= 32'b0;
            reg_iv[1]     <= 32'b0;
            reg_iv[2]     <= 32'b0;
            reg_iv[3]     <= 32'b0;
            reg_din[0]    <= 32'b0;
            reg_din[1]    <= 32'b0;
            reg_din[2]    <= 32'b0;
            reg_din[3]    <= 32'b0;
            reg_ctrl      <= 32'b0;
            aes_start     <= 1'b0;
            aes_encrypt   <= 1'b1;
            aes_iv_load   <= 1'b0;
            aes_key_valid <= 1'b0;
        end else begin
            // Clear single-cycle pulses
            aes_start     <= 1'b0;
            aes_iv_load   <= 1'b0;
            aes_key_valid <= 1'b0;
            aes_encrypt   <= aes_encrypt;

            if (wr_en) begin
                case (wr_addr)
                    7'h00: reg_key[0] <= S_AXI_WDATA;
                    7'h04: reg_key[1] <= S_AXI_WDATA;
                    7'h08: reg_key[2] <= S_AXI_WDATA;
                    7'h0C: reg_key[3] <= S_AXI_WDATA;
                    7'h10: reg_iv[0]  <= S_AXI_WDATA;
                    7'h14: reg_iv[1]  <= S_AXI_WDATA;
                    7'h18: reg_iv[2]  <= S_AXI_WDATA;
                    7'h1C: reg_iv[3]  <= S_AXI_WDATA;
                    7'h20: reg_din[0] <= S_AXI_WDATA;
                    7'h24: reg_din[1] <= S_AXI_WDATA;
                    7'h28: reg_din[2] <= S_AXI_WDATA;
                    7'h2C: reg_din[3] <= S_AXI_WDATA;
                    7'h40: begin
                        reg_ctrl <= S_AXI_WDATA;
                        // Pulse start if bit 0 set
                        if (S_AXI_WDATA[0])
                            aes_start <= 1'b1;
                        // Bit 1: encrypt(1) / decrypt(0)
                        aes_encrypt <= S_AXI_WDATA[1];
                        // Pulse iv_load if bit 2 set
                        if (S_AXI_WDATA[2])
                            aes_iv_load <= 1'b1;
                    end
                    7'h48: begin
                        // Pulse key_valid if bit 0 set
                        if (S_AXI_WDATA[0])
                            aes_key_valid <= 1'b1;
                    end
                    default: ; // No action
                endcase
            end
        end
    end

    //=========================================================================
    // Write response channel
    //=========================================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end else begin
            if (wr_en && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b00; // OKAY
            end else if (S_AXI_BREADY && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    //=========================================================================
    // Read address channel handshake
    //=========================================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_araddr  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr  <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    //=========================================================================
    // Read data channel
    //=========================================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= 2'b00;
        end else begin
            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b00; // OKAY
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // Read mux
    wire [6:0] rd_addr = axi_araddr[6:0];

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rdata <= 32'b0;
        end else if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
            case (rd_addr)
                7'h00: axi_rdata <= reg_key[0];
                7'h04: axi_rdata <= reg_key[1];
                7'h08: axi_rdata <= reg_key[2];
                7'h0C: axi_rdata <= reg_key[3];
                7'h10: axi_rdata <= reg_iv[0];
                7'h14: axi_rdata <= reg_iv[1];
                7'h18: axi_rdata <= reg_iv[2];
                7'h1C: axi_rdata <= reg_iv[3];
                7'h20: axi_rdata <= reg_din[0];
                7'h24: axi_rdata <= reg_din[1];
                7'h28: axi_rdata <= reg_din[2];
                7'h2C: axi_rdata <= reg_din[3];
                7'h30: axi_rdata <= aes_dout[127:96];
                7'h34: axi_rdata <= aes_dout[95:64];
                7'h38: axi_rdata <= aes_dout[63:32];
                7'h3C: axi_rdata <= aes_dout[31:0];
                7'h40: axi_rdata <= reg_ctrl;
                7'h44: axi_rdata <= {30'b0, aes_busy, done_flag};
                default: axi_rdata <= 32'b0;
            endcase
        end
    end

    //=========================================================================
    // Done flag (sticky, cleared on start)
    //=========================================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            done_flag <= 1'b0;
        else if (aes_start)
            done_flag <= 1'b0;
        else if (aes_done)
            done_flag <= 1'b1;
    end

    //=========================================================================
    // Connect registers to AES core
    //=========================================================================
    always @(*) begin
        aes_key = {reg_key[0], reg_key[1], reg_key[2], reg_key[3]};
        aes_iv  = {reg_iv[0],  reg_iv[1],  reg_iv[2],  reg_iv[3]};
        aes_din = {reg_din[0], reg_din[1], reg_din[2], reg_din[3]};
    end

endmodule
