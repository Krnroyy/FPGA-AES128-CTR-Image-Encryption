`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.08.2026 15:10:25
// Design Name: 
// Module Name: aes128_encrypt
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


module aes128_encrypt (
    input  wire [127:0] plaintext,
    input  wire [127:0] key,
    output wire [127:0] ciphertext
);

    // ============================================================
    // Round Keys
    // ============================================================

    wire [127:0] key1;
    wire [127:0] key2;
    wire [127:0] key3;
    wire [127:0] key4;
    wire [127:0] key5;
    wire [127:0] key6;
    wire [127:0] key7;
    wire [127:0] key8;
    wire [127:0] key9;
    wire [127:0] key10;

    // ============================================================
    // States
    // ============================================================

    wire [127:0] state0;

    wire [127:0] state1;
    wire [127:0] state2;
    wire [127:0] state3;
    wire [127:0] state4;
    wire [127:0] state5;
    wire [127:0] state6;
    wire [127:0] state7;
    wire [127:0] state8;
    wire [127:0] state9;

    // ============================================================
    // Initial AddRoundKey
    // ============================================================

    add_round_key initial_add_round_key (
        .state_in  (plaintext),
        .round_key (key),
        .state_out (state0)
    );

    // ============================================================
    // Key Expansion
    // ============================================================

    key_expansion_128 key_exp1 (
        .key_in  (key),
        .rcon    (8'h01),
        .key_out (key1)
    );

    key_expansion_128 key_exp2 (
        .key_in  (key1),
        .rcon    (8'h02),
        .key_out (key2)
    );

    key_expansion_128 key_exp3 (
        .key_in  (key2),
        .rcon    (8'h04),
        .key_out (key3)
    );

    key_expansion_128 key_exp4 (
        .key_in  (key3),
        .rcon    (8'h08),
        .key_out (key4)
    );

    key_expansion_128 key_exp5 (
        .key_in  (key4),
        .rcon    (8'h10),
        .key_out (key5)
    );

    key_expansion_128 key_exp6 (
        .key_in  (key5),
        .rcon    (8'h20),
        .key_out (key6)
    );

    key_expansion_128 key_exp7 (
        .key_in  (key6),
        .rcon    (8'h40),
        .key_out (key7)
    );

    key_expansion_128 key_exp8 (
        .key_in  (key7),
        .rcon    (8'h80),
        .key_out (key8)
    );

    key_expansion_128 key_exp9 (
        .key_in  (key8),
        .rcon    (8'h1B),
        .key_out (key9)
    );

    key_expansion_128 key_exp10 (
        .key_in  (key9),
        .rcon    (8'h36),
        .key_out (key10)
    );

    // ============================================================
    // AES Rounds 1 - 9
    // ============================================================

    aes_round round1 (
        .state_in  (state0),
        .round_key (key1),
        .state_out (state1)
    );

    aes_round round2 (
        .state_in  (state1),
        .round_key (key2),
        .state_out (state2)
    );

    aes_round round3 (
        .state_in  (state2),
        .round_key (key3),
        .state_out (state3)
    );

    aes_round round4 (
        .state_in  (state3),
        .round_key (key4),
        .state_out (state4)
    );

    aes_round round5 (
        .state_in  (state4),
        .round_key (key5),
        .state_out (state5)
    );

    aes_round round6 (
        .state_in  (state5),
        .round_key (key6),
        .state_out (state6)
    );

    aes_round round7 (
        .state_in  (state6),
        .round_key (key7),
        .state_out (state7)
    );

    aes_round round8 (
        .state_in  (state7),
        .round_key (key8),
        .state_out (state8)
    );

    aes_round round9 (
        .state_in  (state8),
        .round_key (key9),
        .state_out (state9)
    );

    // ============================================================
    // Final Round 10
    // ============================================================

    aes_final_round final_round (
        .state_in  (state9),
        .round_key (key10),
        .state_out (ciphertext)
    );

endmodule