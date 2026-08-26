`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 12:40:45
// Design Name: 
// Module Name: sbox_tb
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

module sbox_tb;

    reg  [7:0] in_byte;
    wire [7:0] out_byte;

    sbox uut (
        .in_byte(in_byte),
        .out_byte(out_byte)
    );

   initial begin

    in_byte = 8'h00;
    #10;

    in_byte = 8'h01;
    #10;

    in_byte = 8'h53;
    #10;

    in_byte = 8'hFF;
    #10;

    $finish;

end

endmodule