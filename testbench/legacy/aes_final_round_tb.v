`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.08.2026 14:10:36
// Design Name: 
// Module Name: aes_final_round_tb
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


module aes_final_round_tb;

    reg  [127:0] state_in;
    reg  [127:0] round_key;

    wire [127:0] state_out;

    reg [127:0] expected;


    // ------------------------------------------------
    // Final Round
    // ------------------------------------------------

    aes_final_round uut (
        .state_in  (state_in),
        .round_key (round_key),
        .state_out (state_out)
    );


    // ------------------------------------------------
    // NIST AES-128 Final Round Test
    // ------------------------------------------------

    initial begin

        // State entering Round 10
        state_in =
        128'hBD6E7C3DF2B5779E0B61216E8B10B689;


        // AES-128 Round 10 Key
        round_key =
        128'h13111D7FE3944A17F307A78B4D2B30C5;


        // Expected AES-128 ciphertext
        expected =
        128'h69C4E0D86A7B0430D8CDB78070B4C55A;


        #10;


        $display("");
        $display("==============================================");
        $display("          AES FINAL ROUND TEST");
        $display("==============================================");

        $display("State Input = %h", state_in);

        $display("Round Key   = %h", round_key);

        $display("State Out   = %h", state_out);

        $display("Expected    = %h", expected);


        if (state_out === expected) begin

            $display("");
            $display("**********************************************");
            $display("*        AES FINAL ROUND : PASS             *");
            $display("*        NIST VECTOR MATCH                  *");
            $display("**********************************************");

        end
        else begin

            $display("");
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            $display("!        AES FINAL ROUND : FAIL             !");
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

        end


        #10;

        $finish;

    end

endmodule