`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.08.2026 15:11:55
// Design Name: 
// Module Name: aes128_encrypt_tb
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


module aes128_encrypt_tb;

    reg [127:0] plaintext;
    reg [127:0] key;

    wire [127:0] ciphertext;

    reg [127:0] expected;


    // ============================================================
    // AES-128 Encryption Core
    // ============================================================

    aes128_encrypt uut (
        .plaintext  (plaintext),
        .key        (key),
        .ciphertext (ciphertext)
    );


    // ============================================================
    // NIST / FIPS-197 AES-128 Test Vector
    // ============================================================

    initial begin

        plaintext =
        128'h00112233445566778899AABBCCDDEEFF;

        key =
        128'h000102030405060708090A0B0C0D0E0F;

        expected =
        128'h69C4E0D86A7B0430D8CDB78070B4C55A;


        #20;


        $display("");
        $display("================================================");
        $display("             AES-128 FULL TEST");
        $display("================================================");

        $display("Plaintext  = %h", plaintext);
        $display("Key        = %h", key);
        $display("Ciphertext = %h", ciphertext);
        $display("Expected   = %h", expected);


        if (ciphertext === expected) begin

            $display("");
            $display("************************************************");
            $display("*          AES-128 ENCRYPTION PASS            *");
            $display("*          NIST VECTOR MATCH                  *");
            $display("************************************************");

        end
        else begin

            $display("");
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            $display("!          AES-128 ENCRYPTION FAIL            !");
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

        end


        #10;

        $finish;

    end

endmodule