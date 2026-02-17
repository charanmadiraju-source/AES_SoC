//-----------------------------------------------------------------------------
// Testbench: AES-128 CBC Mode Encryption & Decryption
// Verifies against NIST SP 800-38A Appendix F.2.1 (CBC-AES128 Encrypt)
// and Appendix F.2.2 (CBC-AES128 Decrypt)
//
// Key:        2b7e1516 28aed2a6 abf71588 09cf4f3c
// IV:         00010203 04050607 08090a0b 0c0d0e0f
//
// Block 1:
//   Plaintext:  6bc1bee2 2e409f96 e93d7e11 7393172a
//   Ciphertext: 7649abac 8119b246 cee98e9b 12e9197d
//
// Block 2:
//   Plaintext:  ae2d8a57 1e03ac9c 9eb76fac 45af8e51
//   Ciphertext: 5086cb9b 507219ee 95db113a 917678b2
//
// Block 3:
//   Plaintext:  30c81c46 a35ce411 e5fbc119 1a0a52ef
//   Ciphertext: 73bed6b8 e3c1743b 7116e69e 22229516
//
// Block 4:
//   Plaintext:  f69f2445 df4f9b17 ad2b417b e66c3710
//   Ciphertext: 3ff1caa1 681fac09 120eca30 7586e1a7
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_aes_cbc;

    //=========================================================================
    // Signals
    //=========================================================================
    reg          clk;
    reg          rst_n;
    reg  [127:0] key;
    reg          key_valid;
    reg  [127:0] iv;
    reg          iv_load;
    reg  [127:0] din;
    reg          encrypt;
    reg          start;
    wire [127:0] dout;
    wire         done;
    wire         busy;

    //=========================================================================
    // DUT
    //=========================================================================
    aes_cbc u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .key       (key),
        .key_valid (key_valid),
        .iv        (iv),
        .iv_load   (iv_load),
        .din       (din),
        .encrypt   (encrypt),
        .start     (start),
        .dout      (dout),
        .done      (done),
        .busy      (busy)
    );

    //=========================================================================
    // Clock generation: 100 MHz
    //=========================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    //=========================================================================
    // Test data
    //=========================================================================
    reg [127:0] pt_blocks  [0:3];
    reg [127:0] exp_ct     [0:3];
    integer     i;
    integer     pass_count;
    integer     fail_count;

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
        $dumpfile("tb_aes_cbc.vcd");
        $dumpvars(0, tb_aes_cbc);

        rst_n      = 0;
        key_valid  = 0;
        iv_load    = 0;
        start      = 0;
        encrypt    = 1;
        din        = 128'b0;
        key        = 128'b0;
        iv         = 128'b0;
        pass_count = 0;
        fail_count = 0;

        $display("============================================================");
        $display("  AES-128 CBC Testbench (Encrypt + Decrypt)");
        $display("  NIST SP 800-38A Appendix F.2.1 & F.2.2 Test Vectors");
        $display("============================================================");

        // Reset
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Load key
        key = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        key_valid = 1;
        @(posedge clk);
        key_valid = 0;
        repeat (2) @(posedge clk);

        // Load IV
        iv = 128'h000102030405060708090a0b0c0d0e0f;
        iv_load = 1;
        @(posedge clk);
        iv_load = 0;
        repeat (2) @(posedge clk);

        // Encrypt 4 blocks sequentially
        $display("\n--- CBC Encrypt ---");
        encrypt = 1;
        for (i = 0; i < 4; i = i + 1) begin
            din   = pt_blocks[i];
            start = 1;
            @(posedge clk);
            start = 0;

            // Wait for done
            wait (done);
            @(posedge clk);

            if (dout === exp_ct[i]) begin
                $display("[PASS] Encrypt Block %0d", i+1);
                $display("       CT = %h", dout);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Encrypt Block %0d", i+1);
                $display("       Expected: %h", exp_ct[i]);
                $display("       Got:      %h", dout);
                fail_count = fail_count + 1;
            end

            repeat (3) @(posedge clk);
        end

        //---------------------------------------------------------------------
        // CBC DECRYPT: Feed ciphertexts, expect original plaintexts
        // NIST SP 800-38A Appendix F.2.2
        //---------------------------------------------------------------------
        $display("\n--- CBC Decrypt ---");

        // Reload IV for decrypt
        iv = 128'h000102030405060708090a0b0c0d0e0f;
        iv_load = 1;
        @(posedge clk);
        iv_load = 0;
        repeat (2) @(posedge clk);

        // Reload key for decrypt pipeline
        key_valid = 1;
        @(posedge clk);
        key_valid = 0;
        repeat (2) @(posedge clk);

        encrypt = 0;
        for (i = 0; i < 4; i = i + 1) begin
            din   = exp_ct[i]; // Feed ciphertext
            start = 1;
            @(posedge clk);
            start = 0;

            // Wait for done
            wait (done);
            @(posedge clk);

            if (dout === pt_blocks[i]) begin
                $display("[PASS] Decrypt Block %0d", i+1);
                $display("       PT = %h", dout);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Decrypt Block %0d", i+1);
                $display("       Expected: %h", pt_blocks[i]);
                $display("       Got:      %h", dout);
                fail_count = fail_count + 1;
            end

            repeat (3) @(posedge clk);
        end

        // Summary
        $display("============================================================");
        $display("  Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("============================================================");

        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");

        repeat (10) @(posedge clk);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #200000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
