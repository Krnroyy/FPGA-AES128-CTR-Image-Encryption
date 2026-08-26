`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 15:28:45
// Design Name: 
// Module Name: key_expension_128
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


module key_expansion_128 (
    input  wire [127:0] key_in,
    input  wire [7:0]   rcon,
    output wire [127:0] key_out
);

    // ------------------------------------------------
    // Divide input key into four 32-bit words
    // ------------------------------------------------

    wire [31:0] w0;
    wire [31:0] w1;
    wire [31:0] w2;
    wire [31:0] w3;

    assign w0 = key_in[127:96];
    assign w1 = key_in[95:64];
    assign w2 = key_in[63:32];
    assign w3 = key_in[31:0];


    // ------------------------------------------------
    // RotWord
    //
    // W3 = 0C0D0E0F
    // RotWord = 0D0E0F0C
    // ------------------------------------------------

    wire [31:0] rot_word;

    assign rot_word = {
        w3[23:0],
        w3[31:24]
    };


    // ------------------------------------------------
    // SubWord
    //
    // Four bytes go through four S-boxes
    // ------------------------------------------------

    wire [7:0] sub0;
    wire [7:0] sub1;
    wire [7:0] sub2;
    wire [7:0] sub3;

    sbox sbox_key0 (
        .in_byte(rot_word[31:24]),
        .out_byte(sub0)
    );

    sbox sbox_key1 (
        .in_byte(rot_word[23:16]),
        .out_byte(sub1)
    );

    sbox sbox_key2 (
        .in_byte(rot_word[15:8]),
        .out_byte(sub2)
    );

    sbox sbox_key3 (
        .in_byte(rot_word[7:0]),
        .out_byte(sub3)
    );


    wire [31:0] sub_word;

    assign sub_word = {
        sub0,
        sub1,
        sub2,
        sub3
    };


    // ------------------------------------------------
    // XOR Rcon
    //
    // Rcon is applied only to the MSB byte
    // ------------------------------------------------

    wire [31:0] g_word;

    assign g_word =
        sub_word ^
        {rcon, 24'h000000};


    // ------------------------------------------------
    // Generate new words
    // ------------------------------------------------

    wire [31:0] w4;
    wire [31:0] w5;
    wire [31:0] w6;
    wire [31:0] w7;

    assign w4 = w0 ^ g_word;
    assign w5 = w1 ^ w4;
    assign w6 = w2 ^ w5;
    assign w7 = w3 ^ w6;


    // ------------------------------------------------
    // Construct next 128-bit round key
    // ------------------------------------------------

    assign key_out = {
        w4,
        w5,
        w6,
        w7
    };

endmodule