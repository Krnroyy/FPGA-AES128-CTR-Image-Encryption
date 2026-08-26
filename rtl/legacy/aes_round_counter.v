`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.08.2026 16:20:47
// Design Name: 
// Module Name: aes_round_counter
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

module aes_round_counter (
    input  wire       clk,
    input  wire       reset,
    input  wire       enable,

    output reg [3:0]  round
);

    always @(posedge clk) begin

        if (reset) begin
            round <= 4'd0;
        end

        else if (enable) begin

            if (round < 4'd10)
                round <= round + 4'd1;

            else
                round <= round;

        end

    end

endmodule
