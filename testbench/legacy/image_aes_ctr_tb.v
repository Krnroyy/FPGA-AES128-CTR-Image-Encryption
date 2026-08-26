`timescale 1ns / 1ps

module image_aes_ctr_tb;

    // ============================================================
    // SIGNALS
    // ============================================================

    reg         clk;
    reg         reset;
    reg         start;

    reg [127:0] key;

    wire [127:0] encrypted_block0;
    wire [127:0] encrypted_block1;

    wire         busy;
    wire         done;


    // ============================================================
    // DEBUG SIGNALS
    // ============================================================

    wire [127:0] debug_image_block;
    wire [127:0] debug_aes_data_in;
    wire [127:0] debug_aes_counter;
    wire [127:0] debug_aes_data_out;


    // ============================================================
    // EXPECTED VALUES
    // ============================================================

    localparam [127:0] EXPECTED_BLOCK0 =
    128'h76b6d5fb2047275f8f48c41c2f0bb3b2;

    localparam [127:0] EXPECTED_BLOCK1 =
        128'h92a0f52393bb1a8a8c84599042b131c5;


    // ============================================================
    // DUT
    // ============================================================

    image_aes_ctr uut (

        .clk              (clk),
        .reset            (reset),
        .start            (start),

        .key              (key),

        .encrypted_block0 (encrypted_block0),
        .encrypted_block1 (encrypted_block1),

        .busy             (busy),
        .done             (done),

        .debug_image_block (debug_image_block),
        .debug_aes_data_in (debug_aes_data_in),
        .debug_aes_counter (debug_aes_counter),
        .debug_aes_data_out(debug_aes_data_out)

    );


    // ============================================================
    // CLOCK
    // ============================================================

    always #5 clk = ~clk;


    // ============================================================
    // TEST
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // INITIAL VALUES
        // --------------------------------------------------------

        clk   = 1'b0;
        reset = 1'b1;
        start = 1'b0;

        key = 128'h000102030405060708090A0B0C0D0E0F;


        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------

        #20;

        reset = 1'b0;


        // --------------------------------------------------------
        // START
        // --------------------------------------------------------

        #20;

        start = 1'b1;

        #10;

        start = 1'b0;


        // --------------------------------------------------------
        // WAIT FOR COMPLETE ENCRYPTION
        // --------------------------------------------------------

        wait(done == 1'b1);

        #1;


        // ========================================================
        // FINAL OUTPUT
        // ========================================================

        $display("");
        $display("================================================");
        $display("       IMAGE AES-CTR VERIFICATION");
        $display("================================================");

        $display("");

        $display("KEY                = %h", key);

        $display("");

        $display("IMAGE BLOCK        = %h", debug_image_block);
        $display("AES DATA IN        = %h", debug_aes_data_in);
        $display("AES COUNTER        = %h", debug_aes_counter);
        $display("AES DATA OUT       = %h", debug_aes_data_out);

        $display("");

        $display("ENCRYPTED BLOCK 0  = %h", encrypted_block0);
        $display("EXPECTED BLOCK 0   = %h", EXPECTED_BLOCK0);

        $display("");

        $display("ENCRYPTED BLOCK 1  = %h", encrypted_block1);
        $display("EXPECTED BLOCK 1   = %h", EXPECTED_BLOCK1);

        $display("");


        // ========================================================
        // BLOCK 0
        // ========================================================

        if (encrypted_block0 === EXPECTED_BLOCK0) begin

            $display("BLOCK 0 : PASS");

        end

        else begin

            $display("BLOCK 0 : FAIL");

            $display("ACTUAL   = %h", encrypted_block0);
            $display("EXPECTED = %h", EXPECTED_BLOCK0);

        end


        // ========================================================
        // BLOCK 1
        // ========================================================

        if (encrypted_block1 === EXPECTED_BLOCK1) begin

            $display("BLOCK 1 : PASS");

        end

        else begin

            $display("BLOCK 1 : FAIL");

            $display("ACTUAL   = %h", encrypted_block1);
            $display("EXPECTED = %h", EXPECTED_BLOCK1);

        end


        // ========================================================
        // FINAL RESULT
        // ========================================================

        if ((encrypted_block0 === EXPECTED_BLOCK0) &&
            (encrypted_block1 === EXPECTED_BLOCK1)) begin

            $display("");
            $display("================================================");
            $display("       IMAGE AES-CTR TEST PASSED");
            $display("================================================");

        end

        else begin

            $display("");
            $display("================================================");
            $display("       IMAGE AES-CTR TEST FAILED");
            $display("================================================");

        end


        $display("");

        #20;

        $finish;

    end

endmodule