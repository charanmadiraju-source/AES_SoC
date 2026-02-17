//-----------------------------------------------------------------------------
// Testbench: AES-128 CBC Top Level with AXI4-Lite Interface
// Full system test: write key, IV, data via AXI4-Lite, trigger
// encryption/decryption, poll status, read result
// Uses NIST SP 800-38A CBC test vectors (F.2.1 encrypt, F.2.2 decrypt)
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_aes_top;

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam C_S_AXI_DATA_WIDTH = 32;
    localparam C_S_AXI_ADDR_WIDTH = 7;
    localparam CLK_PERIOD = 10; // 100 MHz

    // Register offsets
    localparam ADDR_KEY0     = 7'h00;
    localparam ADDR_KEY1     = 7'h04;
    localparam ADDR_KEY2     = 7'h08;
    localparam ADDR_KEY3     = 7'h0C;
    localparam ADDR_IV0      = 7'h10;
    localparam ADDR_IV1      = 7'h14;
    localparam ADDR_IV2      = 7'h18;
    localparam ADDR_IV3      = 7'h1C;
    localparam ADDR_DIN0     = 7'h20;
    localparam ADDR_DIN1     = 7'h24;
    localparam ADDR_DIN2     = 7'h28;
    localparam ADDR_DIN3     = 7'h2C;
    localparam ADDR_DOUT0    = 7'h30;
    localparam ADDR_DOUT1    = 7'h34;
    localparam ADDR_DOUT2    = 7'h38;
    localparam ADDR_DOUT3    = 7'h3C;
    localparam ADDR_CTRL     = 7'h40;
    localparam ADDR_STATUS   = 7'h44;
    localparam ADDR_KEY_CTRL = 7'h48;

    //=========================================================================
    // Signals
    //=========================================================================
    reg                              clk;
    reg                              rst_n;
    reg  [C_S_AXI_ADDR_WIDTH-1:0]   awaddr;
    reg  [2:0]                       awprot;
    reg                              awvalid;
    wire                             awready;
    reg  [C_S_AXI_DATA_WIDTH-1:0]    wdata;
    reg  [C_S_AXI_DATA_WIDTH/8-1:0]  wstrb;
    reg                              wvalid;
    wire                             wready;
    wire [1:0]                       bresp;
    wire                             bvalid;
    reg                              bready;
    reg  [C_S_AXI_ADDR_WIDTH-1:0]   araddr;
    reg  [2:0]                       arprot;
    reg                              arvalid;
    wire                             arready;
    wire [C_S_AXI_DATA_WIDTH-1:0]   rdata;
    wire [1:0]                       rresp;
    wire                             rvalid;
    reg                              rready;

    //=========================================================================
    // DUT
    //=========================================================================
    aes_top #(
        .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH)
    ) u_dut (
        .S_AXI_ACLK    (clk),
        .S_AXI_ARESETN (rst_n),
        .S_AXI_AWADDR  (awaddr),
        .S_AXI_AWPROT  (awprot),
        .S_AXI_AWVALID (awvalid),
        .S_AXI_AWREADY (awready),
        .S_AXI_WDATA   (wdata),
        .S_AXI_WSTRB   (wstrb),
        .S_AXI_WVALID  (wvalid),
        .S_AXI_WREADY  (wready),
        .S_AXI_BRESP   (bresp),
        .S_AXI_BVALID  (bvalid),
        .S_AXI_BREADY  (bready),
        .S_AXI_ARADDR  (araddr),
        .S_AXI_ARPROT  (arprot),
        .S_AXI_ARVALID (arvalid),
        .S_AXI_ARREADY (arready),
        .S_AXI_RDATA   (rdata),
        .S_AXI_RRESP   (rresp),
        .S_AXI_RVALID  (rvalid),
        .S_AXI_RREADY  (rready)
    );

    //=========================================================================
    // Clock generation
    //=========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //=========================================================================
    // AXI4-Lite write task
    //=========================================================================
    task axi_write;
        input [C_S_AXI_ADDR_WIDTH-1:0] addr;
        input [C_S_AXI_DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            awaddr  = addr;
            awprot  = 3'b000;
            awvalid = 1;
            wdata   = data;
            wstrb   = 4'hF;
            wvalid  = 1;
            bready  = 1;

            // Wait for both address and data handshakes
            wait (awready && wready);
            @(posedge clk);
            awvalid = 0;
            wvalid  = 0;

            // Wait for write response
            if (!bvalid) wait (bvalid);
            @(posedge clk);
            bready = 0;
        end
    endtask

    //=========================================================================
    // AXI4-Lite read task
    //=========================================================================
    reg [31:0] read_data;

    task axi_read;
        input  [C_S_AXI_ADDR_WIDTH-1:0] addr;
        begin
            @(posedge clk);
            araddr  = addr;
            arprot  = 3'b000;
            arvalid = 1;
            rready  = 1;

            wait (arready);
            @(posedge clk);
            arvalid = 0;

            if (!rvalid) wait (rvalid);
            read_data = rdata;
            @(posedge clk);
            rready = 0;
        end
    endtask

    //=========================================================================
    // Test data: NIST SP 800-38A CBC-AES128 Encrypt
    //=========================================================================
    reg [127:0] exp_ct [0:3];
    reg [127:0] pt_blocks [0:3];
    integer i, pass_count, fail_count;
    reg [127:0] result;

    initial begin
        pt_blocks[0] = 128'h6bc1bee22e409f96e93d7e117393172a;
        pt_blocks[1] = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
        pt_blocks[2] = 128'h30c81c46a35ce411e5fbc1191a0a52ef;
        pt_blocks[3] = 128'hf69f2445df4f9b17ad2b417be66c3710;

        exp_ct[0]    = 128'h7649abac8119b246cee98e9b12e9197d;
        exp_ct[1]    = 128'h5086cb9b507219ee95db113a917678b2;
        exp_ct[2]    = 128'h73bed6b8e3c1743b7116e69e22229516;
        exp_ct[3]    = 128'h3ff1caa1681fac09120eca307586e1a7;
    end

    //=========================================================================
    // Test procedure
    //=========================================================================
    initial begin
        $dumpfile("tb_aes_top.vcd");
        $dumpvars(0, tb_aes_top);

        // Initialize signals
        rst_n   = 0;
        awaddr  = 0;
        awprot  = 0;
        awvalid = 0;
        wdata   = 0;
        wstrb   = 0;
        wvalid  = 0;
        bready  = 0;
        araddr  = 0;
        arprot  = 0;
        arvalid = 0;
        rready  = 0;
        pass_count = 0;
        fail_count = 0;

        $display("============================================================");
        $display("  AES-128 CBC Top (AXI4-Lite) Testbench");
        $display("  NIST SP 800-38A F.2.1 (Encrypt) & F.2.2 (Decrypt)");
        $display("============================================================");

        // Reset
        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        //---------------------------------------------------------------------
        // Write AES key
        //---------------------------------------------------------------------
        $display("\n  Writing AES key...");
        axi_write(ADDR_KEY0, 32'h2b7e1516);
        axi_write(ADDR_KEY1, 32'h28aed2a6);
        axi_write(ADDR_KEY2, 32'habf71588);
        axi_write(ADDR_KEY3, 32'h09cf4f3c);

        // Trigger key expansion
        axi_write(ADDR_KEY_CTRL, 32'h00000001);
        repeat (3) @(posedge clk);

        //---------------------------------------------------------------------
        // Write IV
        //---------------------------------------------------------------------
        $display("  Writing IV...");
        axi_write(ADDR_IV0, 32'h00010203);
        axi_write(ADDR_IV1, 32'h04050607);
        axi_write(ADDR_IV2, 32'h08090a0b);
        axi_write(ADDR_IV3, 32'h0c0d0e0f);

        // Trigger IV load
        axi_write(ADDR_CTRL, 32'h00000004); // bit 2 = iv_load
        repeat (3) @(posedge clk);

        //---------------------------------------------------------------------
        // Encrypt 4 blocks
        //---------------------------------------------------------------------
        for (i = 0; i < 4; i = i + 1) begin
            $display("\n  Encrypting Block %0d...", i+1);

            // Write plaintext
            axi_write(ADDR_DIN0, pt_blocks[i][127:96]);
            axi_write(ADDR_DIN1, pt_blocks[i][95:64]);
            axi_write(ADDR_DIN2, pt_blocks[i][63:32]);
            axi_write(ADDR_DIN3, pt_blocks[i][31:0]);

            // Start encryption (bit 0 = start, bit 1 = encrypt)
            axi_write(ADDR_CTRL, 32'h00000003);

            // Poll status until done
            read_data = 32'h0;
            while (!(read_data & 32'h1)) begin
                repeat (2) @(posedge clk);
                axi_read(ADDR_STATUS);
            end

            // Read ciphertext
            axi_read(ADDR_DOUT0);
            result[127:96] = read_data;
            axi_read(ADDR_DOUT1);
            result[95:64] = read_data;
            axi_read(ADDR_DOUT2);
            result[63:32] = read_data;
            axi_read(ADDR_DOUT3);
            result[31:0] = read_data;

            // Verify
            if (result === exp_ct[i]) begin
                $display("  [PASS] Encrypt Block %0d", i+1);
                $display("         CT = %h", result);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Encrypt Block %0d", i+1);
                $display("         Expected: %h", exp_ct[i]);
                $display("         Got:      %h", result);
                fail_count = fail_count + 1;
            end
        end

        //---------------------------------------------------------------------
        // CBC Decrypt – NIST SP 800-38A F.2.2
        // Re-key and re-load IV, then decrypt the known ciphertext blocks
        //---------------------------------------------------------------------
        $display("\n------------------------------------------------------------");
        $display("  CBC Decrypt Test (F.2.2)");
        $display("------------------------------------------------------------");

        // Re-load key (same key)
        $display("\n  Re-loading AES key...");
        axi_write(ADDR_KEY0, 32'h2b7e1516);
        axi_write(ADDR_KEY1, 32'h28aed2a6);
        axi_write(ADDR_KEY2, 32'habf71588);
        axi_write(ADDR_KEY3, 32'h09cf4f3c);
        axi_write(ADDR_KEY_CTRL, 32'h00000001);
        repeat (3) @(posedge clk);

        // Re-load IV (same IV)
        $display("  Re-loading IV...");
        axi_write(ADDR_IV0, 32'h00010203);
        axi_write(ADDR_IV1, 32'h04050607);
        axi_write(ADDR_IV2, 32'h08090a0b);
        axi_write(ADDR_IV3, 32'h0c0d0e0f);
        axi_write(ADDR_CTRL, 32'h00000004); // iv_load
        repeat (3) @(posedge clk);

        // Decrypt 4 blocks – feed ciphertext, expect plaintext
        for (i = 0; i < 4; i = i + 1) begin
            $display("\n  Decrypting Block %0d...", i+1);

            // Write ciphertext as data-in
            axi_write(ADDR_DIN0, exp_ct[i][127:96]);
            axi_write(ADDR_DIN1, exp_ct[i][95:64]);
            axi_write(ADDR_DIN2, exp_ct[i][63:32]);
            axi_write(ADDR_DIN3, exp_ct[i][31:0]);

            // Start decryption (bit 0 = start, bit 1 = 0 → decrypt)
            axi_write(ADDR_CTRL, 32'h00000001);

            // Poll status until done
            read_data = 32'h0;
            while (!(read_data & 32'h1)) begin
                repeat (2) @(posedge clk);
                axi_read(ADDR_STATUS);
            end

            // Read plaintext result
            axi_read(ADDR_DOUT0);
            result[127:96] = read_data;
            axi_read(ADDR_DOUT1);
            result[95:64] = read_data;
            axi_read(ADDR_DOUT2);
            result[63:32] = read_data;
            axi_read(ADDR_DOUT3);
            result[31:0] = read_data;

            // Verify
            if (result === pt_blocks[i]) begin
                $display("  [PASS] Decrypt Block %0d", i+1);
                $display("         PT = %h", result);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Decrypt Block %0d", i+1);
                $display("         Expected: %h", pt_blocks[i]);
                $display("         Got:      %h", result);
                fail_count = fail_count + 1;
            end
        end

        // Summary
        $display("\n============================================================");
        $display("  Results: %0d PASSED, %0d FAILED (of 8 total)", pass_count, fail_count);
        $display("============================================================");

        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");

        repeat (20) @(posedge clk);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #1000000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
