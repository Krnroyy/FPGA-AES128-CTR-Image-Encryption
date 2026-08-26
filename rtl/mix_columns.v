`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 13:52:57
// Design Name: 
// Module Name: mix_columns
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

module mix_columns (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);

    // ------------------------------------------------
    // Multiply by 2 in GF(2^8)
    // ------------------------------------------------

    function [7:0] xtime;
        input [7:0] a;

        begin
            if (a[7] == 1'b1)
                xtime = (a << 1) ^ 8'h1B;
            else
                xtime = a << 1;
        end
    endfunction


    // ------------------------------------------------
    // Multiply by 2
    // ------------------------------------------------

    function [7:0] mul2;
        input [7:0] a;

        begin
            mul2 = xtime(a);
        end
    endfunction


    // ------------------------------------------------
    // Multiply by 3
    // 3a = 2a XOR a
    // ------------------------------------------------

    function [7:0] mul3;
        input [7:0] a;

        begin
            mul3 = xtime(a) ^ a;
        end
    endfunction


    // =================================================
    // COLUMN 0
    // Input bytes:
    //
    // 63
    // 53
    // E0
    // 8C
    // =================================================

    assign state_out[127:120] =
        mul2(state_in[127:120]) ^
        mul3(state_in[119:112]) ^
        state_in[111:104] ^
        state_in[103:96];

    assign state_out[119:112] =
        state_in[127:120] ^
        mul2(state_in[119:112]) ^
        mul3(state_in[111:104]) ^
        state_in[103:96];

    assign state_out[111:104] =
        state_in[127:120] ^
        state_in[119:112] ^
        mul2(state_in[111:104]) ^
        mul3(state_in[103:96]);

    assign state_out[103:96] =
        mul3(state_in[127:120]) ^
        state_in[119:112] ^
        state_in[111:104] ^
        mul2(state_in[103:96]);


    // =================================================
    // COLUMN 1
    // =================================================

    assign state_out[95:88] =
        mul2(state_in[95:88]) ^
        mul3(state_in[87:80]) ^
        state_in[79:72] ^
        state_in[71:64];

    assign state_out[87:80] =
        state_in[95:88] ^
        mul2(state_in[87:80]) ^
        mul3(state_in[79:72]) ^
        state_in[71:64];

    assign state_out[79:72] =
        state_in[95:88] ^
        state_in[87:80] ^
        mul2(state_in[79:72]) ^
        mul3(state_in[71:64]);

    assign state_out[71:64] =
        mul3(state_in[95:88]) ^
        state_in[87:80] ^
        state_in[79:72] ^
        mul2(state_in[71:64]);


    // =================================================
    // COLUMN 2
    // =================================================

    assign state_out[63:56] =
        mul2(state_in[63:56]) ^
        mul3(state_in[55:48]) ^
        state_in[47:40] ^
        state_in[39:32];

    assign state_out[55:48] =
        state_in[63:56] ^
        mul2(state_in[55:48]) ^
        mul3(state_in[47:40]) ^
        state_in[39:32];

    assign state_out[47:40] =
        state_in[63:56] ^
        state_in[55:48] ^
        mul2(state_in[47:40]) ^
        mul3(state_in[39:32]);

    assign state_out[39:32] =
        mul3(state_in[63:56]) ^
        state_in[55:48] ^
        state_in[47:40] ^
        mul2(state_in[39:32]);


    // =================================================
    // COLUMN 3
    // =================================================

    assign state_out[31:24] =
        mul2(state_in[31:24]) ^
        mul3(state_in[23:16]) ^
        state_in[15:8] ^
        state_in[7:0];

    assign state_out[23:16] =
        state_in[31:24] ^
        mul2(state_in[23:16]) ^
        mul3(state_in[15:8]) ^
        state_in[7:0];

    assign state_out[15:8] =
        state_in[31:24] ^
        state_in[23:16] ^
        mul2(state_in[15:8]) ^
        mul3(state_in[7:0]);

    assign state_out[7:0] =
        mul3(state_in[31:24]) ^
        state_in[23:16] ^
        state_in[15:8] ^
        mul2(state_in[7:0]);

endmodule