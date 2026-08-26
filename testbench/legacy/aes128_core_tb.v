`timescale 1ns / 1ps

module aes128_core_tb;


    // ============================================================
    // CLOCK AND CONTROL
    // ============================================================

    reg clk;
    reg reset;
    reg start;


    // ============================================================
    // AES INPUTS
    // ============================================================

    reg [127:0] plaintext;
    reg [127:0] key;


    // ============================================================
    // AES OUTPUTS
    // ============================================================

    wire [127:0] ciphertext;
    wire busy;
    wire done;


    // ============================================================
    // DEBUG OUTPUTS
    // ============================================================

    wire [2:0]   debug_state;
    wire [3:0]   debug_round;

    wire [127:0] debug_state_reg;
    wire [127:0] debug_round_key;


    // ============================================================
    // EXPECTED NIST / FIPS-197 RESULT
    // ============================================================

    reg [127:0] expected_ciphertext;

    initial begin

        expected_ciphertext =
            128'h69C4E0D86A7B0430D8CDB78070B4C55A;

    end


    // ============================================================
    // DUT - DEVICE UNDER TEST
    // ============================================================

    aes128_core uut (

        .clk       (clk),
        .reset     (reset),
        .start     (start),

        .plaintext (plaintext),
        .key       (key),

        .ciphertext(ciphertext),
        .busy      (busy),
        .done      (done),

        // Debug signals
        .debug_state     (debug_state),
        .debug_round     (debug_round),
        .debug_state_reg (debug_state_reg),
        .debug_round_key (debug_round_key)

    );


    // ============================================================
    // CLOCK GENERATION
    //
    // Clock period = 10 ns
    // ============================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    // ============================================================
    // TEST SEQUENCE
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // Initial values
        // --------------------------------------------------------

        reset = 1'b1;
        start = 1'b0;

        plaintext = 128'h00112233445566778899AABBCCDDEEFF;

        key = 128'h000102030405060708090A0B0C0D0E0F;


        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        #20;

        reset = 1'b0;


        // --------------------------------------------------------
        // Start AES encryption
        // --------------------------------------------------------

        #10;

        start = 1'b1;

        #10;

        start = 1'b0;


        // --------------------------------------------------------
        // Wait until encryption is completed
        // --------------------------------------------------------

        wait(done == 1'b1);


        // --------------------------------------------------------
        // Display final result
        // --------------------------------------------------------

        $display("==============================================");
        $display("        AES-128 ENCRYPTION RESULT");
        $display("==============================================");

        $display("Plaintext  = %h", plaintext);
        $display("Key        = %h", key);
        $display("Ciphertext = %h", ciphertext);
        $display("Expected   = %h", expected_ciphertext);


        // --------------------------------------------------------
        // Verify NIST test vector
        // --------------------------------------------------------

        if (ciphertext == expected_ciphertext) begin

            $display("==============================================");
            $display("             TEST PASSED");
            $display("Ciphertext matches NIST/FIPS-197 vector");
            $display("==============================================");

        end

        else begin

            $display("==============================================");
            $display("             TEST FAILED");
            $display("Ciphertext DOES NOT match expected value");
            $display("==============================================");

        end


        // --------------------------------------------------------
        // Allow waveform to show final DONE state
        // --------------------------------------------------------

        #20;

        $finish;

    end


    // ============================================================
    // DEBUG MONITOR
    //
    // This prints the internal AES operation.
    // ============================================================

    always @(posedge clk) begin

        if (!reset) begin

            $display(
                "TIME=%0t | STATE=%0d | ROUND=%0d | BUSY=%b | DONE=%b | STATE_REG=%h | ROUND_KEY=%h",
                $time,
                debug_state,
                debug_round,
                busy,
                done,
                debug_state_reg,
                debug_round_key
            );

        end

    end


endmodule