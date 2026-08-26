`timescale 1ns / 1ps

module aes128_ctr_decrypt (

    input  wire         clk,
    input  wire         reset,

    // Start decryption
    input  wire         start,

    // 128-bit ciphertext
    input  wire [127:0] ciphertext,

    // AES-128 key
    input  wire [127:0] key,

    // CTR counter
    input  wire [127:0] counter_in,

    // Recovered plaintext
    output wire [127:0] plaintext,

    // Counter for next block
    output wire [127:0] counter_out,

    // Status
    output wire         busy,
    output wire         done

);


    // ============================================================
    // CTR MODULE
    //
    // IMPORTANT:
    //
    // AES-CTR encryption and decryption are identical.
    //
    // Existing aes128_ctr performs:
    //
    // data_out = data_in XOR AES(Key, Counter)
    //
    // Therefore:
    //
    // Encryption:
    // plaintext XOR keystream = ciphertext
    //
    // Decryption:
    // ciphertext XOR keystream = plaintext
    //
    // ============================================================

    aes128_ctr aes_ctr (

        .clk         (clk),
        .reset       (reset),

        .start       (start),

        // IMPORTANT:
        // For decryption, ciphertext is the data input.
        .data_in     (ciphertext),

        .key         (key),

        .counter_in  (counter_in),

        // Output is recovered plaintext
        .data_out    (plaintext),

        .counter_out (counter_out),

        .busy        (busy),

        .done        (done)

    );

endmodule