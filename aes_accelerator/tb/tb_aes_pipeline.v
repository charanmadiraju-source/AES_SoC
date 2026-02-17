//-----------------------------------------------------------------------------
// Testbench: AES-128 Pipeline (Encryption only)
// Verifies against NIST FIPS-197 Appendix B test vector
// and additional NIST SP 800-38A ECB test vectors
//
// Test Vector 1 (FIPS-197 Appendix B):
//   Key:        2b7e1516 28aed2a6 abf71588 09cf4f3c
//   Plaintext:  3243f6a8 885a308d 313198a2 e0370734
//   Ciphertext: 3925841d 02dc09fb dc118597 196a0b32
//
// Test Vector 2 (NIST SP 800-38A ECB, Block 1):
//   Key:        2b7e1516 28aed2a6 abf71588 09cf4f3c
//   Plaintext:  6bc1bee2 2e409f96 e93d7e11 7393172a
//   Ciphertext: 3ad77bb4 0d7a3660 a89ecaf3 2466ef97
//
// Test Vector 3 (NIST SP 800-38A ECB, Block 2):
//   Key:        2b7e1516 28aed2a6 abf71588 09cf4f3c
//   Plaintext:  ae2d8a57 1e03ac9c 9eb76fac 45af8e51
//   Ciphertext: f5d3d585 03b9699d e785895a 96fdbaaf
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_aes_pipeline;

    //=========================================================================
    // Signals
    //=========================================================================
    reg          clk;
    reg          rst_n;
    reg  [127:0] plaintext;
    reg  [127:0] key;
    reg          data_valid;
    wire [127:0] ciphertext;
    wire         cipher_valid;

    //=========================================================================
    // DUT
    //=========================================================================
    aes_pipeline u_dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .plaintext    (plaintext),
        .key          (key),
        .data_valid   (data_valid),
        .ciphertext   (ciphertext),
        .cipher_valid (cipher_valid)
    );

    //=========================================================================
    // Clock generation: 100 MHz (10 ns period)
    //=========================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    //=========================================================================
    // Test vectors
    //=========================================================================
    reg [127:0] expected_ct [0:2];
    reg [127:0] test_pt     [0:2];
    integer     test_idx;
    integer     pass_count;
    integer     fail_count;

    initial begin
        // Key (same for all tests)
        key = 128'h2b7e151628aed2a6abf7158809cf4f3c;

        // Test vector 1: FIPS-197 Appendix B
        test_pt[0]     = 128'h3243f6a8885a308d313198a2e0370734;
        expected_ct[0] = 128'h3925841d02dc09fbdc118597196a0b32;

        // Test vector 2: SP 800-38A ECB Block 1
        test_pt[1]     = 128'h6bc1bee22e409f96e93d7e117393172a;
        expected_ct[1] = 128'h3ad77bb40d7a3660a89ecaf32466ef97;

        // Test vector 3: SP 800-38A ECB Block 2
        test_pt[2]     = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
        expected_ct[2] = 128'hf5d3d58503b9699de785895a96fdbaaf;
    end

    //=========================================================================
    // Test procedure
    //=========================================================================
    initial begin
        $dumpfile("tb_aes_pipeline.vcd");
        $dumpvars(0, tb_aes_pipeline);

        rst_n      = 0;
        data_valid = 0;
        plaintext  = 128'b0;
        pass_count = 0;
        fail_count = 0;
        test_idx   = 0;

        $display("============================================================");
        $display("  AES-128 Pipeline Testbench");
        $display("  NIST FIPS-197 & SP 800-38A Test Vectors");
        $display("============================================================");

        // Reset
        repeat (5) @(posedge clk);
        rst_n = 1;

        // Load key first (key_valid pulse occurs inside pipeline)
        @(posedge clk);
        data_valid = 1;
        plaintext  = test_pt[0];
        @(posedge clk);
        data_valid = 0;

        // Wait for result
        wait (cipher_valid);
        @(posedge clk);

        // Check result
        if (ciphertext === expected_ct[0]) begin
            $display("[PASS] Test 1 (FIPS-197 Appendix B)");
            $display("       CT = %h", ciphertext);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 1 (FIPS-197 Appendix B)");
            $display("       Expected: %h", expected_ct[0]);
            $display("       Got:      %h", ciphertext);
            fail_count = fail_count + 1;
        end

        // Wait a few cycles, then test 2
        repeat (5) @(posedge clk);
        plaintext  = test_pt[1];
        data_valid = 1;
        @(posedge clk);
        data_valid = 0;

        wait (cipher_valid);
        @(posedge clk);

        if (ciphertext === expected_ct[1]) begin
            $display("[PASS] Test 2 (SP 800-38A ECB Block 1)");
            $display("       CT = %h", ciphertext);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 2 (SP 800-38A ECB Block 1)");
            $display("       Expected: %h", expected_ct[1]);
            $display("       Got:      %h", ciphertext);
            fail_count = fail_count + 1;
        end

        // Test 3
        repeat (5) @(posedge clk);
        plaintext  = test_pt[2];
        data_valid = 1;
        @(posedge clk);
        data_valid = 0;

        wait (cipher_valid);
        @(posedge clk);

        if (ciphertext === expected_ct[2]) begin
            $display("[PASS] Test 3 (SP 800-38A ECB Block 2)");
            $display("       CT = %h", ciphertext);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 3 (SP 800-38A ECB Block 2)");
            $display("       Expected: %h", expected_ct[2]);
            $display("       Got:      %h", ciphertext);
            fail_count = fail_count + 1;
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
        #50000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
