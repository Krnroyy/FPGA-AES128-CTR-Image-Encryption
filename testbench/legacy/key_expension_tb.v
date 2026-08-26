`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 15:29:28
// Design Name: 
// Module Name: key_expension_tb
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


module key_expansion_128_tb;

    reg  [127:0] key_in;
    reg  [7:0]   rcon;

    wire [127:0] key_out;

    reg [127:0] expected_key;


    key_expansion_128 uut (
        .key_in(key_in),
        .rcon(rcon),
        .key_out(key_out)
    );


    initial begin

        // ---------------------------------------------
        // NIST AES-128 FIPS 197 Appendix C.1
        // Original AES-128 Key
        // ---------------------------------------------

        key_in =
        128'h000102030405060708090A0B0C0D0E0F;


        // ---------------------------------------------
        // Round 1 Rcon
        // ---------------------------------------------

        rcon = 8'h01;


        // ---------------------------------------------
        // Expected Round 1 Key
        // ---------------------------------------------

        expected_key =
        128'hD6AA74FDD2AF72FADAA678F1D6AB76FE;


        #10;


        $display("==============================================");
        $display("       AES-128 KEY EXPANSION TEST");
        $display("==============================================");

        $display("Input Key  = %h", key_in);
        $display("Rcon       = %h", rcon);
        $display("Output Key = %h", key_out);
        $display("Expected   = %h", expected_key);


        if (key_out === expected_key) begin

            $display("Key Expansion Round 1: PASS");

        end
        else begin

            $display("Key Expansion Round 1: FAIL");

        end


        $display("==============================================");

        #10;

        $finish;

    end

endmodule
