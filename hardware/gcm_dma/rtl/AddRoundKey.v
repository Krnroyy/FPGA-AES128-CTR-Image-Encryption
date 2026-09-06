`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.06.2026 17:01:31
// Design Name: 
// Module Name: AddRoundKey
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


module AddRoundKey
(
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,

    output wire [127:0] state_out
);

////////////////////////////////////////////////////////////
// AddRoundKey Operation
////////////////////////////////////////////////////////////

assign state_out = state_in ^ round_key;

endmodule

