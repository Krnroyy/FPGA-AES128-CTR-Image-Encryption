`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.08.2026 15:21:30
// Design Name: 
// Module Name: aes_state_register_tb
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


module aes_state_register_tb;

    reg clk;
    reg reset;

    reg [127:0] state_in;

    wire [127:0] state_out;


    // ------------------------------------------------
    // Unit Under Test
    // ------------------------------------------------

    aes_state_register uut (
        .clk       (clk),
        .reset     (reset),
        .state_in  (state_in),
        .state_out (state_out)
    );


    // ------------------------------------------------
    // Clock Generation
    // 10 ns period
    // ------------------------------------------------

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end


    // ------------------------------------------------
    // Test
    // ------------------------------------------------

    initial begin

        reset   = 1'b1;
        state_in = 128'h00000000000000000000000000000000;

        #12;

        reset = 1'b0;

        state_in =
        128'h00112233445566778899AABBCCDDEEFF;

        #10;

        state_in =
        128'h112233445566778899AABBCCDDEEFF00;

        #10;

        state_in =
        128'hAABBCCDDEEFF00112233445566778899;

        #10;

        $finish;

    end

endmodule