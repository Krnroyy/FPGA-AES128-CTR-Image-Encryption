`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.08.2026 16:29:36
// Design Name: 
// Module Name: aes_controller_tb
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

module aes_controller_tb;

    reg clk;
    reg reset;
    reg start;

    reg [3:0] round;

    wire [2:0] state;


    // ============================================================
    // Unit Under Test
    // ============================================================

    aes_controller uut (
        .clk   (clk),
        .reset (reset),
        .start (start),
        .round (round),
        .state (state)
    );


    // ============================================================
    // Clock
    // ============================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // ============================================================
    // Test
    // ============================================================

    initial begin

        reset = 1'b1;
        start = 1'b0;
        round = 4'd0;

        #12;

        // Release reset
        reset = 1'b0;

        // Start AES
        start = 1'b1;

        #10;

        start = 1'b0;


        // INIT → ROUND
        #10;


        // Simulate rounds 1-9

        round = 4'd1;
        #10;

        round = 4'd2;
        #10;

        round = 4'd3;
        #10;

        round = 4'd4;
        #10;

        round = 4'd5;
        #10;

        round = 4'd6;
        #10;

        round = 4'd7;
        #10;

        round = 4'd8;
        #10;

        round = 4'd9;
        #10;


        // Final round

        round = 4'd10;

        #30;


        $finish;

    end

endmodule