`timescale 1ns / 1ps

module image_aes_ctr_roundtrip_tb;

    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk;
    reg reset;


    // ============================================================
    // AES KEY
    // ============================================================

    reg [127:0] key;


    // ============================================================
    // ORIGINAL IMAGE BLOCKS
    // ============================================================

    localparam [127:0] ORIGINAL_BLOCK0 =
        128'h101112131415161718191A1B1C1D1E1F;

    localparam [127:0] ORIGINAL_BLOCK1 =
        128'h202122232425262728292A2B2C2D2E2F;


    // ============================================================
    // ENCRYPTED IMAGE BLOCKS
    // ============================================================

    localparam [127:0] ENCRYPTED_BLOCK0 =
        128'h76B6D5FB2047275F8F48C41C2F0BB3B2;

    localparam [127:0] ENCRYPTED_BLOCK1 =
        128'h92A0F52393BB1A8A8C84599042B131C5;


    // ============================================================
    // COUNTERS
    // ============================================================

    localparam [127:0] COUNTER0 =
        128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF;

    localparam [127:0] COUNTER1 =
        128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFF00;


    // ============================================================
    // DECRYPTION SIGNALS
    // ============================================================

    reg         start0;
    reg         start1;

    reg [127:0] ciphertext0;
    reg [127:0] ciphertext1;

    reg [127:0] counter0;
    reg [127:0] counter1;

    wire [127:0] plaintext0;
    wire [127:0] plaintext1;

    wire [127:0] next_counter0;
    wire [127:0] next_counter1;

    wire busy0;
    wire busy1;

    wire done0;
    wire done1;


    // ============================================================
    // DECRYPT BLOCK 0
    // ============================================================

    aes128_ctr_decrypt decrypt_block0 (

        .clk        (clk),
        .reset      (reset),

        .start      (start0),

        .ciphertext (ciphertext0),

        .key        (key),

        .counter_in (counter0),

        .plaintext  (plaintext0),

        .counter_out(next_counter0),

        .busy       (busy0),

        .done       (done0)

    );


    // ============================================================
    // DECRYPT BLOCK 1
    // ============================================================

    aes128_ctr_decrypt decrypt_block1 (

        .clk        (clk),
        .reset      (reset),

        .start      (start1),

        .ciphertext (ciphertext1),

        .key        (key),

        .counter_in (counter1),

        .plaintext  (plaintext1),

        .counter_out(next_counter1),

        .busy       (busy1),

        .done       (done1)

    );


    // ============================================================
    // CLOCK
    // ============================================================

    always #5 clk = ~clk;


    // ============================================================
    // TEST
    // ============================================================

    initial begin

        clk = 1'b0;

        reset = 1'b1;

        start0 = 1'b0;
        start1 = 1'b0;

        key =
            128'h000102030405060708090A0B0C0D0E0F;

        ciphertext0 =
            ENCRYPTED_BLOCK0;

        ciphertext1 =
            ENCRYPTED_BLOCK1;

        counter0 =
            COUNTER0;

        counter1 =
            COUNTER1;


        // ========================================================
        // RESET
        // ========================================================

        #20;

        reset = 1'b0;


        // ========================================================
        // START BLOCK 0 DECRYPTION
        // ========================================================

        #20;

        start0 = 1'b1;

        #10;

        start0 = 1'b0;


        // ========================================================
        // WAIT FOR BLOCK 0
        // ========================================================

        wait(done0 == 1'b1);

        #1;


        // ========================================================
        // START BLOCK 1
        // ========================================================

        #20;

        start1 = 1'b1;

        #10;

        start1 = 1'b0;


        // ========================================================
        // WAIT FOR BLOCK 1
        // ========================================================

        wait(done1 == 1'b1);

        #1;


        // ========================================================
        // DISPLAY RESULTS
        // ========================================================

        $display("");
        $display("================================================");
        $display("       AES-CTR COMPLETE ROUND-TRIP TEST");
        $display("================================================");

        $display("");

        $display("KEY = %h", key);

        $display("");

        $display("ORIGINAL BLOCK 0  = %h", ORIGINAL_BLOCK0);
        $display("ENCRYPTED BLOCK 0 = %h", ENCRYPTED_BLOCK0);
        $display("DECRYPTED BLOCK 0 = %h", plaintext0);

        $display("");

        $display("ORIGINAL BLOCK 1  = %h", ORIGINAL_BLOCK1);
        $display("ENCRYPTED BLOCK 1 = %h", ENCRYPTED_BLOCK1);
        $display("DECRYPTED BLOCK 1 = %h", plaintext1);

        $display("");

        $display("COUNTER 0         = %h", counter0);
        $display("NEXT COUNTER 0    = %h", next_counter0);

        $display("");

        $display("COUNTER 1         = %h", counter1);
        $display("NEXT COUNTER 1    = %h", next_counter1);

        $display("");


        // ========================================================
        // BLOCK 0 VERIFICATION
        // ========================================================

        if (plaintext0 === ORIGINAL_BLOCK0) begin

            $display("BLOCK 0 ROUND-TRIP : PASS");

        end

        else begin

            $display("BLOCK 0 ROUND-TRIP : FAIL");

            $display("ACTUAL   = %h", plaintext0);
            $display("EXPECTED = %h", ORIGINAL_BLOCK0);

        end


        // ========================================================
        // BLOCK 1 VERIFICATION
        // ========================================================

        if (plaintext1 === ORIGINAL_BLOCK1) begin

            $display("BLOCK 1 ROUND-TRIP : PASS");

        end

        else begin

            $display("BLOCK 1 ROUND-TRIP : FAIL");

            $display("ACTUAL   = %h", plaintext1);
            $display("EXPECTED = %h", ORIGINAL_BLOCK1);

        end


        // ========================================================
        // COMPLETE IMAGE VERIFICATION
        // ========================================================

        if ((plaintext0 === ORIGINAL_BLOCK0) &&
            (plaintext1 === ORIGINAL_BLOCK1)) begin

            $display("");
            $display("================================================");
            $display("       COMPLETE IMAGE ROUND-TRIP : PASS");
            $display("================================================");
            $display("");

        end

        else begin

            $display("");
            $display("================================================");
            $display("       COMPLETE IMAGE ROUND-TRIP : FAIL");
            $display("================================================");
            $display("");

        end


        #20;

        $finish;

    end

endmodule