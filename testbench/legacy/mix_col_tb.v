`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 14:06:22
// Design Name: 
// Module Name: mix_col_tb
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


module mix_columns_tb;

    reg  [127:0] state_in;
    wire [127:0] state_out;

    reg [127:0] expected_out;

    mix_columns uut (
        .state_in(state_in),
        .state_out(state_out)
    );

    initial begin

        // ---------------------------------------------
        // NIST AES-128 FIPS 197 Appendix C.1
        // Input = output of ShiftRows
        // ---------------------------------------------

        state_in =
        128'h6353E08C0960E104CD70B751BACAD0E7;

        expected_out =
        128'h5F72641557F5BC92F7BE3B291DB9F91A;

        #10;

        $display("==============================================");
        $display("       AES-128 NIST MIXCOLUMNS TEST");
        $display("==============================================");

        $display("Input    = %h", state_in);
        $display("Output   = %h", state_out);
        $display("Expected = %h", expected_out);

        if (state_out === expected_out) begin
            $display("MixColumns: PASS");
        end
        else begin
            $display("MixColumns: FAIL");
        end

        $display("==============================================");

        #10;

        $finish;

    end

endmodule