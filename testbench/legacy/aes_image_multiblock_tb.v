`timescale 1ns / 1ps

module aes_image_multiblock_tb;

    // ============================================================
    // SIGNALS
    // ============================================================

    reg clk;
    reg reset;
    reg start;

    reg [127:0] key;

    wire [127:0] encrypted_block0;
    wire [127:0] encrypted_block1;
    wire [127:0] encrypted_block2;
    wire [127:0] encrypted_block3;

    wire busy;
    wire done;


    // ============================================================
    // TEST KEY
    // ============================================================

    localparam [127:0] TEST_KEY =
        128'h000102030405060708090A0B0C0D0E0F;


    // ============================================================
    // ORIGINAL IMAGE BLOCKS
    // ============================================================

    localparam [127:0] ORIGINAL_BLOCK0 =
        128'h101112131415161718191A1B1C1D1E1F;

    localparam [127:0] ORIGINAL_BLOCK1 =
        128'h202122232425262728292A2B2C2D2E2F;

    localparam [127:0] ORIGINAL_BLOCK2 =
        128'h303132333435363738393A3B3C3D3E3F;

    localparam [127:0] ORIGINAL_BLOCK3 =
        128'h404142434445464748494A4B4C4D4E4F;


    // ============================================================
    // GOLDEN REFERENCE CIPHERTEXT
    //
    // These are independently verified AES-128-CTR results.
    // ============================================================

    localparam [127:0] EXPECTED_BLOCK0 =
        128'h76B6D5FB2047275F8F48C41C2F0BB3B2;

    localparam [127:0] EXPECTED_BLOCK1 =
        128'h92A0F52393BB1A8A8C84599042B131C5;

    localparam [127:0] EXPECTED_BLOCK2 =
        128'hE240A065486EDDAAC3B8B16273AF6B4E;

    localparam [127:0] EXPECTED_BLOCK3 =
        128'h3099241978FA1E001F244953032D79D5;


    // ============================================================
    // DUT
    // ============================================================

    aes_image_multiblock uut (

        .clk              (clk),
        .reset            (reset),
        .start            (start),

        .key              (key),

        .encrypted_block0 (encrypted_block0),
        .encrypted_block1 (encrypted_block1),
        .encrypted_block2 (encrypted_block2),
        .encrypted_block3 (encrypted_block3),

        .busy             (busy),
        .done             (done)

    );


    // ============================================================
    // CLOCK
    // ============================================================

    always #5 clk = ~clk;


    // ============================================================
    // TEST PROCEDURE
    // ============================================================

    initial begin

        clk   = 1'b0;
        reset = 1'b1;
        start = 1'b0;
        key   = TEST_KEY;


        // ========================================================
        // RESET
        // ========================================================

        #20;

        reset = 1'b0;


        // ========================================================
        // START
        // ========================================================

        #20;

        start = 1'b1;

        #10;

        start = 1'b0;


        // ========================================================
        // WAIT FOR COMPLETE IMAGE
        // ========================================================

        wait(done == 1'b1);

        #1;


        // ========================================================
        // HEADER
        // ========================================================

        $display("");
        $display("================================================");
        $display("       AES IMAGE 4-BLOCK GOLDEN VERIFICATION");
        $display("================================================");

        $display("");

        $display("KEY = %h", key);

        $display("");


        // ========================================================
        // BLOCK 0
        // ========================================================

        $display("BLOCK 0");
        $display("ORIGINAL = %h", ORIGINAL_BLOCK0);
        $display("ACTUAL   = %h", encrypted_block0);
        $display("EXPECTED = %h", EXPECTED_BLOCK0);

        if (encrypted_block0 === EXPECTED_BLOCK0) begin

            $display("BLOCK 0 : PASS");

        end

        else begin

            $display("BLOCK 0 : FAIL");

        end


        $display("");


        // ========================================================
        // BLOCK 1
        // ========================================================

        $display("BLOCK 1");
        $display("ORIGINAL = %h", ORIGINAL_BLOCK1);
        $display("ACTUAL   = %h", encrypted_block1);
        $display("EXPECTED = %h", EXPECTED_BLOCK1);

        if (encrypted_block1 === EXPECTED_BLOCK1) begin

            $display("BLOCK 1 : PASS");

        end

        else begin

            $display("BLOCK 1 : FAIL");

        end


        $display("");


        // ========================================================
        // BLOCK 2
        // ========================================================

        $display("BLOCK 2");
        $display("ORIGINAL = %h", ORIGINAL_BLOCK2);
        $display("ACTUAL   = %h", encrypted_block2);
        $display("EXPECTED = %h", EXPECTED_BLOCK2);

        if (encrypted_block2 === EXPECTED_BLOCK2) begin

            $display("BLOCK 2 : PASS");

        end

        else begin

            $display("BLOCK 2 : FAIL");

        end


        $display("");


        // ========================================================
        // BLOCK 3
        // ========================================================

        $display("BLOCK 3");
        $display("ORIGINAL = %h", ORIGINAL_BLOCK3);
        $display("ACTUAL   = %h", encrypted_block3);
        $display("EXPECTED = %h", EXPECTED_BLOCK3);

        if (encrypted_block3 === EXPECTED_BLOCK3) begin

            $display("BLOCK 3 : PASS");

        end

        else begin

            $display("BLOCK 3 : FAIL");

        end


        $display("");


        // ========================================================
        // FINAL VERIFICATION
        // ========================================================

        if ((encrypted_block0 === EXPECTED_BLOCK0) &&
            (encrypted_block1 === EXPECTED_BLOCK1) &&
            (encrypted_block2 === EXPECTED_BLOCK2) &&
            (encrypted_block3 === EXPECTED_BLOCK3)) begin

            $display("================================================");
            $display("       ALL 4 BLOCKS : PASS");
            $display("       AES IMAGE CTR VERIFICATION : PASS");
            $display("================================================");

        end

        else begin

            $display("================================================");
            $display("       AES IMAGE CTR VERIFICATION : FAIL");
            $display("================================================");

        end


        #20;

        $finish;

    end

endmodule