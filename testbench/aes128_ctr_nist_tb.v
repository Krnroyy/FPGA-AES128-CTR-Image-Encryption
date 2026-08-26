`timescale 1ns / 1ps

module aes128_ctr_nist_tb;

    // ============================================================
    // SIGNALS
    // ============================================================

    reg         clk;
    reg         reset;
    reg         start;

    reg [127:0] data_in;
    reg [127:0] key;
    reg [127:0] counter_in;

    wire [127:0] data_out;
    wire [127:0] counter_out;

    wire         busy;
    wire         done;


    // ============================================================
    // NIST SP 800-38A F.5.1 CTR-AES128.Encrypt
    // ============================================================

    localparam [127:0] NIST_KEY =
        128'h2B7E151628AED2A6ABF7158809CF4F3C;

    localparam [127:0] INITIAL_COUNTER =
        128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF;


    // ============================================================
    // NIST PLAINTEXT BLOCKS
    // ============================================================

    localparam [127:0] PLAINTEXT_BLOCK0 =
        128'h6BC1BEE22E409F96E93D7E117393172A;

    localparam [127:0] PLAINTEXT_BLOCK1 =
        128'hAE2D8A571E03AC9C9EB76FAC45AF8E51;

    localparam [127:0] PLAINTEXT_BLOCK2 =
        128'h30C81C46A35CE411E5FBC1191A0A52EF;

    localparam [127:0] PLAINTEXT_BLOCK3 =
        128'hF69F2445DF4F9B17AD2B417BE66C3710;


    // ============================================================
    // NIST EXPECTED CIPHERTEXT BLOCKS
    // ============================================================

    localparam [127:0] EXPECTED_BLOCK0 =
        128'h874D6191B620E3261BEF6864990DB6CE;

    localparam [127:0] EXPECTED_BLOCK1 =
    128'h9806F66B7970FDFF8617187BB9FFFDFF;

    localparam [127:0] EXPECTED_BLOCK2 =
        128'h5AE4DF3EDBD5D35E5B4F09020DB03EAB;

    localparam [127:0] EXPECTED_BLOCK3 =
        128'h1E031DDA2FBE03D1792170A0F3009CEE;


    // ============================================================
    // DUT
    // ============================================================

    aes128_ctr uut (

        .clk        (clk),
        .reset      (reset),
        .start      (start),

        .data_in    (data_in),
        .key        (key),
        .counter_in (counter_in),

        .data_out   (data_out),
        .counter_out(counter_out),

        .busy       (busy),
        .done       (done)

    );


    // ============================================================
    // CLOCK
    // ============================================================

    always #5 clk = ~clk;


    // ============================================================
    // TASK: TEST ONE NIST BLOCK
    // ============================================================

    task test_block;

        input [127:0] block_number;
        input [127:0] plaintext;
        input [127:0] expected_ciphertext;
        input [127:0] expected_counter;

        begin

            // ----------------------------------------------------
            // Apply plaintext
            // ----------------------------------------------------

            data_in = plaintext;

            // ----------------------------------------------------
            // Start one AES-CTR operation
            // ----------------------------------------------------

            start = 1'b1;

            #10;

            start = 1'b0;


            // ----------------------------------------------------
            // Wait for AES-CTR to finish
            // ----------------------------------------------------

            wait(done == 1'b1);

            #1;


            // ----------------------------------------------------
            // Display results
            // ----------------------------------------------------

            $display("");
            $display("-----------------------------------------------");
            $display("NIST BLOCK %0d", block_number);
            $display("-----------------------------------------------");

            $display("PLAINTEXT       = %h", plaintext);
            $display("COUNTER         = %h", counter_in);

            $display("ACTUAL          = %h", data_out);
            $display("EXPECTED        = %h", expected_ciphertext);

            $display("NEXT COUNTER    = %h", counter_out);
            $display("EXPECTED COUNTER= %h", expected_counter);


            // ----------------------------------------------------
            // Verify ciphertext
            // ----------------------------------------------------

            if (data_out === expected_ciphertext) begin

                $display("CIPHERTEXT      : PASS");

            end

            else begin

                $display("CIPHERTEXT      : FAIL");

            end


            // ----------------------------------------------------
            // Verify counter
            // ----------------------------------------------------

            if (counter_out === expected_counter) begin

                $display("COUNTER         : PASS");

            end

            else begin

                $display("COUNTER         : FAIL");

            end


            // ----------------------------------------------------
            // Prepare counter for next block
            // ----------------------------------------------------

            counter_in = expected_counter;

        end

    endtask


    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // Initial values
        // --------------------------------------------------------

        clk = 1'b0;

        reset = 1'b1;

        start = 1'b0;

        data_in = 128'b0;

        key = NIST_KEY;

        counter_in = INITIAL_COUNTER;


        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        #20;

        reset = 1'b0;


        // --------------------------------------------------------
        // Header
        // --------------------------------------------------------

        $display("");
        $display("================================================");
        $display("     NIST SP 800-38A F.5.1 AES-128 CTR");
        $display("              ENCRYPTION TEST");
        $display("================================================");

        $display("");

        $display("KEY             = %h", NIST_KEY);
        $display("INITIAL COUNTER = %h", INITIAL_COUNTER);


        // ========================================================
        // BLOCK 0
        // ========================================================

        test_block(
            128'd0,
            PLAINTEXT_BLOCK0,
            EXPECTED_BLOCK0,
            128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFF00
        );


        // ========================================================
        // BLOCK 1
        // ========================================================

        test_block(
            128'd1,
            PLAINTEXT_BLOCK1,
            EXPECTED_BLOCK1,
            128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFF01
        );


        // ========================================================
        // BLOCK 2
        // ========================================================

        test_block(
            128'd2,
            PLAINTEXT_BLOCK2,
            EXPECTED_BLOCK2,
            128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFF02
        );


        // ========================================================
        // BLOCK 3
        // ========================================================

        test_block(
            128'd3,
            PLAINTEXT_BLOCK3,
            EXPECTED_BLOCK3,
            128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFF03
        );


        // ========================================================
        // FINAL RESULT
        // ========================================================

        $display("");
        $display("================================================");
        $display("     NIST AES-128 CTR TEST COMPLETE");
        $display("================================================");

        $finish;

    end

endmodule