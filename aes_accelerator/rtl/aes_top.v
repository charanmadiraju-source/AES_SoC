//-----------------------------------------------------------------------------
// AES-128 CBC Accelerator Top Level
// Integrates AXI4-Lite slave interface with AES-128 CBC encrypt/decrypt core
// Target: Xilinx Zynq-7000 XC7Z020CLG400-1
//
// Instantiate as AXI4-Lite peripheral in Vivado block design, connected
// to the Zynq PS via M_AXI_GP0 port.
//-----------------------------------------------------------------------------

module aes_top #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 7
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
    input  wire                              S_AXI_RREADY
);

    //=========================================================================
    // Internal wires between AXI slave and AES core
    //=========================================================================
    wire [127:0] aes_key;
    wire         aes_key_valid;
    wire [127:0] aes_iv;
    wire         aes_iv_load;
    wire [127:0] aes_din;
    wire         aes_start;
    wire         aes_encrypt;
    wire [127:0] aes_dout;
    wire         aes_done;
    wire         aes_busy;

    //=========================================================================
    // AXI4-Lite Slave Register Interface
    //=========================================================================
    axi4_lite_slave #(
        .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH)
    ) u_axi_slave (
        .S_AXI_ACLK    (S_AXI_ACLK),
        .S_AXI_ARESETN (S_AXI_ARESETN),
        .S_AXI_AWADDR  (S_AXI_AWADDR),
        .S_AXI_AWPROT  (S_AXI_AWPROT),
        .S_AXI_AWVALID (S_AXI_AWVALID),
        .S_AXI_AWREADY (S_AXI_AWREADY),
        .S_AXI_WDATA   (S_AXI_WDATA),
        .S_AXI_WSTRB   (S_AXI_WSTRB),
        .S_AXI_WVALID  (S_AXI_WVALID),
        .S_AXI_WREADY  (S_AXI_WREADY),
        .S_AXI_BRESP   (S_AXI_BRESP),
        .S_AXI_BVALID  (S_AXI_BVALID),
        .S_AXI_BREADY  (S_AXI_BREADY),
        .S_AXI_ARADDR  (S_AXI_ARADDR),
        .S_AXI_ARPROT  (S_AXI_ARPROT),
        .S_AXI_ARVALID (S_AXI_ARVALID),
        .S_AXI_ARREADY (S_AXI_ARREADY),
        .S_AXI_RDATA   (S_AXI_RDATA),
        .S_AXI_RRESP   (S_AXI_RRESP),
        .S_AXI_RVALID  (S_AXI_RVALID),
        .S_AXI_RREADY  (S_AXI_RREADY),
        // AES core interface
        .aes_key       (aes_key),
        .aes_key_valid (aes_key_valid),
        .aes_iv        (aes_iv),
        .aes_iv_load   (aes_iv_load),
        .aes_din       (aes_din),
        .aes_start     (aes_start),
        .aes_encrypt   (aes_encrypt),
        .aes_dout      (aes_dout),
        .aes_done      (aes_done),
        .aes_busy      (aes_busy)
    );

    //=========================================================================
    // AES-128 CBC Encrypt/Decrypt Core
    //=========================================================================
    aes_cbc u_aes_cbc (
        .clk       (S_AXI_ACLK),
        .rst_n     (S_AXI_ARESETN),
        .key       (aes_key),
        .key_valid (aes_key_valid),
        .iv        (aes_iv),
        .iv_load   (aes_iv_load),
        .din       (aes_din),
        .encrypt   (aes_encrypt),
        .start     (aes_start),
        .dout      (aes_dout),
        .done      (aes_done),
        .busy      (aes_busy)
    );

endmodule
