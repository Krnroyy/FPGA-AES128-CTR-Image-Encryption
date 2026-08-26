`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 13:08:01
// Design Name: 
// Module Name: sub_bytes_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module sub_bytes_tb;

    reg  [127:0] plaintext;
    reg  [127:0] key;

    reg  [127:0] state_after_addkey;

    wire [127:0] state_after_subbytes;

    // ------------------------------------------------
    // SubBytes module
    // ------------------------------------------------

    sub_bytes uut (
        .state_in(state_after_addkey),
        .state_out(state_after_subbytes)
    );

    initial begin

        // ---------------------------------------------
        // NIST AES-128 Test Vector
        // FIPS 197 Appendix C.1
        // ---------------------------------------------

        plaintext = 128'h00112233445566778899AABBCCDDEEFF;

        key = 128'h000102030405060708090A0B0C0D0E0F;

        // ---------------------------------------------
        // Initial AddRoundKey
        // ---------------------------------------------

        state_after_addkey = plaintext ^ key;

        #10;

        // ---------------------------------------------
        // Display results
        // ---------------------------------------------

        $display("==============================================");
        $display("       AES-128 NIST SUBBYTES TEST");
        $display("==============================================");

        $display("Plaintext          = %h", plaintext);
        $display("Key                = %h", key);
        $display("After AddRoundKey  = %h", state_after_addkey);
        $display("After SubBytes     = %h", state_after_subbytes);

        // ---------------------------------------------
        // Verify AddRoundKey
        // ---------------------------------------------

        if (state_after_addkey ===
            128'h00102030405060708090A0B0C0D0E0F0) begin

            $display("AddRoundKey: PASS");

        end
        else begin

            $display("AddRoundKey: FAIL");

        end

        // ---------------------------------------------
        // Verify SubBytes against NIST
        // ---------------------------------------------

        if (state_after_subbytes ===
            128'h63CAB7040953D051CD60E0E7BA70E18C) begin

            $display("SubBytes: PASS");

        end
        else begin

            $display("SubBytes: FAIL");

        end

        $display("==============================================");

        #10;

        $finish;

    end

endmodule