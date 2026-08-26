`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 13:05:52
// Design Name: 
// Module Name: sub_bytes
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


module sub_bytes (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);

    sbox sbox0 (
        .in_byte(state_in[127:120]),
        .out_byte(state_out[127:120])
    );

    sbox sbox1 (
        .in_byte(state_in[119:112]),
        .out_byte(state_out[119:112])
    );

    sbox sbox2 (
        .in_byte(state_in[111:104]),
        .out_byte(state_out[111:104])
    );

    sbox sbox3 (
        .in_byte(state_in[103:96]),
        .out_byte(state_out[103:96])
    );

    sbox sbox4 (
        .in_byte(state_in[95:88]),
        .out_byte(state_out[95:88])
    );

    sbox sbox5 (
        .in_byte(state_in[87:80]),
        .out_byte(state_out[87:80])
    );

    sbox sbox6 (
        .in_byte(state_in[79:72]),
        .out_byte(state_out[79:72])
    );

    sbox sbox7 (
        .in_byte(state_in[71:64]),
        .out_byte(state_out[71:64])
    );

    sbox sbox8 (
        .in_byte(state_in[63:56]),
        .out_byte(state_out[63:56])
    );

    sbox sbox9 (
        .in_byte(state_in[55:48]),
        .out_byte(state_out[55:48])
    );

    sbox sbox10 (
        .in_byte(state_in[47:40]),
        .out_byte(state_out[47:40])
    );

    sbox sbox11 (
        .in_byte(state_in[39:32]),
        .out_byte(state_out[39:32])
    );

    sbox sbox12 (
        .in_byte(state_in[31:24]),
        .out_byte(state_out[31:24])
    );

    sbox sbox13 (
        .in_byte(state_in[23:16]),
        .out_byte(state_out[23:16])
    );

    sbox sbox14 (
        .in_byte(state_in[15:8]),
        .out_byte(state_out[15:8])
    );

    sbox sbox15 (
        .in_byte(state_in[7:0]),
        .out_byte(state_out[7:0])
    );

endmodule