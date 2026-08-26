`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 14:14:56
// Design Name: 
// Module Name: add_round_tb
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

module add_round_key_tb;

    reg  [127:0] state_in;
    reg  [127:0] round_key;

    wire [127:0] state_out;

    reg [127:0] expected_out;

    // Instantiate AddRoundKey
    add_round_key uut (
        .state_in(state_in),
        .round_key(round_key),
        .state_out(state_out)
    );

    initial begin

        // ---------------------------------------------
        // NIST AES-128 FIPS 197 Appendix C.1
        // State after MixColumns
        // ---------------------------------------------

        state_in =
        128'h5F72641557F5BC92F7BE3B291DB9F91A;

        // ---------------------------------------------
        // NIST Round 1 Key
        // ---------------------------------------------

        round_key =
        128'hD6AA74FDD2AF72FADAA678F1D6AB76FE;

        // ---------------------------------------------
        // Expected result after AddRoundKey
        // ---------------------------------------------

        expected_out =
        128'h89D810E8855ACE682D1843D8CB128FE4;

        #10;

        $display("==============================================");
        $display("       AES-128 NIST ADDROUNDKEY TEST");
        $display("==============================================");

        $display("State      = %h", state_in);
        $display("Round Key  = %h", round_key);
        $display("Output     = %h", state_out);
        $display("Expected   = %h", expected_out);

        if (state_out === expected_out) begin
            $display("AddRoundKey: PASS");
        end
        else begin
            $display("AddRoundKey: FAIL");
        end

        $display("==============================================");

        #10;

        $finish;

    end

endmodule