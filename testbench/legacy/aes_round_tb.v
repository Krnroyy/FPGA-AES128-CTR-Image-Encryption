`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 16:52:32
// Design Name: 
// Module Name: aes_round_tb
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


module aes_round_tb;

    reg  [127:0] state_in;
    reg  [127:0] round_key;

    wire [127:0] state_out;

    reg  [127:0] expected;


    // ------------------------------------------------
    // AES Round
    // ------------------------------------------------

    aes_round uut (
        .state_in  (state_in),
        .round_key (round_key),
        .state_out (state_out)
    );


    // ------------------------------------------------
    // NIST AES-128 Round 1 Test
    // ------------------------------------------------

    initial begin

        // State after initial AddRoundKey
        state_in =
        128'h00102030405060708090A0B0C0D0E0F0;


        // Round 1 Key
        round_key =
        128'hD6AA74FDD2AF72FADAA678F1D6AB76FE;


        // Expected result after:
        // SubBytes
        // ShiftRows
        // MixColumns
        // AddRoundKey

        expected =
        128'h89D810E8855ACE682D1843D8CB128FE;


        #10;


        $display("");
        $display("==============================================");
        $display("          AES ROUND 1 TEST");
        $display("==============================================");

        $display("State Input = %h", state_in);

        $display("Round Key   = %h", round_key);

        $display("State Out   = %h", state_out);

        $display("Expected    = %h", expected);


        if (state_out === expected) begin

            $display("");
            $display("**********************************************");
            $display("*        AES ROUND 1 : PASS                 *");
            $display("*        NIST VECTOR MATCH                  *");
            $display("**********************************************");

        end
        else begin

            $display("");
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            $display("!        AES ROUND 1 : FAIL                 !");
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

        end


        #10;

        $finish;

    end

endmodule