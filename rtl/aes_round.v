`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 16:50:26
// Design Name: 
// Module Name: aes_round
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

module aes_round (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    output wire [127:0] state_out
);

    // ------------------------------------------------
    // Intermediate signals
    // ------------------------------------------------

    wire [127:0] sub_bytes_out;
    wire [127:0] shift_rows_out;
    wire [127:0] mix_columns_out;


    // ------------------------------------------------
    // 1. SubBytes
    // ------------------------------------------------

    sub_bytes u_sub_bytes (
        .state_in  (state_in),
        .state_out (sub_bytes_out)
    );


    // ------------------------------------------------
    // 2. ShiftRows
    // ------------------------------------------------

    shift_rows u_shift_rows (
        .state_in  (sub_bytes_out),
        .state_out (shift_rows_out)
    );


    // ------------------------------------------------
    // 3. MixColumns
    // ------------------------------------------------

    mix_columns u_mix_columns (
        .state_in  (shift_rows_out),
        .state_out (mix_columns_out)
    );


    // ------------------------------------------------
    // 4. AddRoundKey
    // ------------------------------------------------

    add_round_key u_add_round_key (
        .state_in  (mix_columns_out),
        .round_key (round_key),
        .state_out (state_out)
    );

endmodule