`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.08.2026 16:21:47
// Design Name: 
// Module Name: aes_round_counter_tb
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


module aes_round_counter_tb;

    reg clk;
    reg reset;
    reg enable;

    wire [3:0] round;


    aes_round_counter uut (
        .clk    (clk),
        .reset  (reset),
        .enable (enable),
        .round  (round)
    );


    // 10 ns clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    initial begin

        // Reset
        reset  = 1'b1;
        enable = 1'b0;

        #12;

        // Release reset
        reset = 1'b0;

        // Start counting
        enable = 1'b1;

        #120;

        // Stop counting
        enable = 1'b0;

        #20;

        $finish;

    end

endmodule