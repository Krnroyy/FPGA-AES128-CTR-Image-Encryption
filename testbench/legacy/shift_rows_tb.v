`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 13:46:42
// Design Name: 
// Module Name: shift_rows_tb
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


module shift_rows_tb;

    reg  [127:0] state_in;
    wire [127:0] state_out;

    reg [127:0] expected_out;

    shift_rows uut (
        .state_in(state_in),
        .state_out(state_out)
    );

    initial begin

        // NIST AES-128 FIPS 197 Appendix C.1
        // Input to ShiftRows = output of SubBytes

        state_in =
        128'h63CAB7040953D051CD60E0E7BA70E18C;

        expected_out =
        128'h6353E08C0960E104CD70B751BACAD0E7;

        #10;

        $display("==============================================");
        $display("       AES-128 NIST SHIFTROWS TEST");
        $display("==============================================");

        $display("Input    = %h", state_in);
        $display("Output   = %h", state_out);
        $display("Expected = %h", expected_out);

        if (state_out === expected_out) begin
            $display("ShiftRows: PASS");
        end
        else begin
            $display("ShiftRows: FAIL");
        end

        $display("==============================================");

        #10;

        $finish;

    end

endmodule