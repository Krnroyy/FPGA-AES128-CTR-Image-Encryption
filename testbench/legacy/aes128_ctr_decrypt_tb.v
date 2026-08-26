`timescale 1ns / 1ps

module aes128_ctr_decrypt_tb;

    // ============================================================
    // SIGNALS
    // ============================================================

    reg         clk;
    reg         reset;
    reg         start;

    reg [127:0] ciphertext;
    reg [127:0] key;
    reg [127:0] counter_in;

    wire [127:0] plaintext;
    wire [127:0] counter_out;

    wire         busy;
    wire         done;


    // ============================================================
    // EXPECTED PLAINTEXT - BLOCK 1
    // ============================================================

    localparam [127:0] EXPECTED_PLAINTEXT =
        128'h202122232425262728292A2B2C2D2E2F;


    // ============================================================
    // DUT
    // ============================================================

    aes128_ctr_decrypt uut (

        .clk         (clk),
        .reset       (reset),

        .start       (start),

        .ciphertext  (ciphertext),

        .key         (key),

        .counter_in  (counter_in),

        .plaintext   (plaintext),

        .counter_out (counter_out),

        .busy        (busy),

        .done        (done)

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

        clk = 1'b0;

        reset = 1'b1;

        start = 1'b0;

        // Block 1 ciphertext
        ciphertext =
            128'h92A0F52393BB1A8A8C84599042B131C5;

        // AES-128 key
        key =
            128'h000102030405060708090A0B0C0D0E0F;

        // Block 1 counter
        counter_in =
    128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFF00;


        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------

        #20;

        reset = 1'b0;


        // --------------------------------------------------------
        // START DECRYPTION
        // --------------------------------------------------------

        #20;

        start = 1'b1;

        #10;

        start = 1'b0;


        // --------------------------------------------------------
        // WAIT FOR DONE
        // --------------------------------------------------------

        wait(done == 1'b1);

        #1;


        // ========================================================
        // DISPLAY RESULTS
        // ========================================================

        $display("");
        $display("================================================");
        $display("      AES-CTR BLOCK 1 DECRYPTION VERIFICATION");
        $display("================================================");

        $display("");

        $display("KEY              = %h", key);

        $display("COUNTER          = %h", counter_in);

        $display("");

        $display("CIPHERTEXT       = %h", ciphertext);

        $display("DECRYPTED        = %h", plaintext);

        $display("EXPECTED         = %h", EXPECTED_PLAINTEXT);

        $display("NEXT COUNTER     = %h", counter_out);

        $display("");


        // ========================================================
        // VERIFICATION
        // ========================================================

        if (plaintext === EXPECTED_PLAINTEXT) begin

            $display("BLOCK 1 DECRYPTION : PASS");

            $display("");

            $display("================================================");
            $display("       AES-CTR BLOCK 1 TEST PASSED");
            $display("================================================");

        end

        else begin

            $display("BLOCK 1 DECRYPTION : FAIL");

            $display("");

            $display("ACTUAL      = %h", plaintext);

            $display("EXPECTED    = %h", EXPECTED_PLAINTEXT);

            $display("");

            $display("================================================");
            $display("       AES-CTR BLOCK 1 TEST FAILED");
            $display("================================================");

        end


        #20;

        $finish;

    end

endmodule