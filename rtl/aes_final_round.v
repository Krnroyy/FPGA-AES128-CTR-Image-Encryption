`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.08.2026 14:09:33
// Design Name: 
// Module Name: aes_final_round
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

module aes_final_round (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    output wire [127:0] state_out
);

    // ------------------------------------------------
    // Intermediate signals
    // ------------------------------------------------

    wire [127:0] sub_bytes_out;
    wire [127:0] shift_rows_out;


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
    // 3. AddRoundKey
    //
    // IMPORTANT:
    // Round 10 does NOT use MixColumns.
    // ------------------------------------------------

    add_round_key u_add_round_key (
        .state_in  (shift_rows_out),
        .round_key (round_key),
        .state_out (state_out)
    );

endmodule