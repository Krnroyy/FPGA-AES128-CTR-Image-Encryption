`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.06.2026 17:02:34
// Design Name: 
// Module Name: MixColumns
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


module MixColumns
(
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);

////////////////////////////////////////////////////////////
// GF(2^8)
////////////////////////////////////////////////////////////

function [7:0] xtime;
input [7:0] x;
begin
    xtime = x[7] ? ((x<<1)^8'h1B) : (x<<1);
end
endfunction

function [7:0] mul3;
input [7:0] x;
begin
    mul3 = xtime(x)^x;
end
endfunction

////////////////////////////////////////////////////////////
// AES State (Column Major)
////////////////////////////////////////////////////////////

wire [7:0] s0  = state_in[127:120];
wire [7:0] s1  = state_in[119:112];
wire [7:0] s2  = state_in[111:104];
wire [7:0] s3  = state_in[103:96];

wire [7:0] s4  = state_in[95:88];
wire [7:0] s5  = state_in[87:80];
wire [7:0] s6  = state_in[79:72];
wire [7:0] s7  = state_in[71:64];

wire [7:0] s8  = state_in[63:56];
wire [7:0] s9  = state_in[55:48];
wire [7:0] s10 = state_in[47:40];
wire [7:0] s11 = state_in[39:32];

wire [7:0] s12 = state_in[31:24];
wire [7:0] s13 = state_in[23:16];
wire [7:0] s14 = state_in[15:8];
wire [7:0] s15 = state_in[7:0];

////////////////////////////////////////////////////////////
// One Column
////////////////////////////////////////////////////////////

function [31:0] mixcol;
input [31:0] c;

reg [7:0] a0,a1,a2,a3;

begin

a0 = c[31:24];
a1 = c[23:16];
a2 = c[15:8];
a3 = c[7:0];

mixcol =
{
    xtime(a0)^mul3(a1)^a2^a3,
    a0^xtime(a1)^mul3(a2)^a3,
    a0^a1^xtime(a2)^mul3(a3),
    mul3(a0)^a1^a2^xtime(a3)
};

end
endfunction

////////////////////////////////////////////////////////////
// Apply MixColumns
////////////////////////////////////////////////////////////

wire [31:0] mc0;
wire [31:0] mc1;
wire [31:0] mc2;
wire [31:0] mc3;

assign mc0 = mixcol({s0,s1,s2,s3});
assign mc1 = mixcol({s4,s5,s6,s7});
assign mc2 = mixcol({s8,s9,s10,s11});
assign mc3 = mixcol({s12,s13,s14,s15});

assign state_out =
{
    mc0,
    mc1,
    mc2,
    mc3
};

endmodule


