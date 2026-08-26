`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.08.2026 15:19:29
// Design Name: 
// Module Name: aes_state_register
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


module aes_state_register (
    input  wire         clk,
    input  wire         reset,

    input  wire [127:0] state_in,

    output reg  [127:0] state_out
);

    always @(posedge clk) begin

        if (reset) begin

            state_out <= 128'b0;

        end
        else begin

            state_out <= state_in;

        end

    end

endmodule