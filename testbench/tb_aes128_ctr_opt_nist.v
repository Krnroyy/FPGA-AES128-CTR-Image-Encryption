`timescale 1ns / 1ps

module tb_aes128_ctr_opt_nist;

    // ============================================================
    // TESTBENCH SIGNALS
    // ============================================================

    reg clk;
    reg reset;
    reg start;

    reg [127:0] data_in;
    reg [127:0] key;
    reg [127:0] counter_in;

    wire [127:0] data_out;
    wire [127:0] counter_out;
    wire busy;
    wire done;

    integer pass_count;
    integer fail_count;


    // ============================================================
    // OPTIMIZED AES-CTR MODULE
    // ============================================================

    aes128_ctr_opt dut (
        .clk         (clk),
        .reset       (reset),
        .start       (start),
        .data_in     (data_in),
        .key         (key),
        .counter_in  (counter_in),
        .data_out    (data_out),
        .counter_out (counter_out),
        .busy        (busy),
        .done        (done)
    );


    // ============================================================
    // CLOCK
    //
    // 100 MHz behavioral simulation clock
    // ============================================================

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end


    // ============================================================
    // RUN ONE AES-CTR BLOCK
    // ============================================================

    task run_block;

        input integer block_number;

        input [127:0] plaintext;
        input [127:0] expected_ciphertext;

        reg [127:0] current_counter;

        begin

            // Save the counter used for this block
            current_counter = counter_in;


            // Make sure previous operation has finished
            wait(done == 1'b0);
            wait(busy == 1'b0);


            // Apply data before start pulse
            @(negedge clk);

            data_in = plaintext;
            start   = 1'b1;


            // One-clock start pulse
            @(negedge clk);

            start = 1'b0;


            // Wait for AES-CTR completion
            wait(done == 1'b1);

            #1;


            $display("");
            $display("==================================================");
            $display("NIST AES-CTR BLOCK %0d", block_number);
            $display("==================================================");

            $display("Counter     = %032h", current_counter);

            $display("Plaintext   = %032h", plaintext);

            $display("Expected CT = %032h", expected_ciphertext);

            $display("Actual CT   = %032h", data_out);

            $display("Next Counter= %032h", counter_out);


            // ----------------------------------------------------
            // CIPHERTEXT CHECK
            // ----------------------------------------------------

            if (data_out === expected_ciphertext) begin

                $display("CIPHERTEXT : PASS");

                pass_count = pass_count + 1;

            end

            else begin

                $display("CIPHERTEXT : FAIL");

                fail_count = fail_count + 1;

            end


            // ----------------------------------------------------
            // COUNTER CHECK
            // ----------------------------------------------------

            if (counter_out === (current_counter + 128'd1)) begin

                $display("COUNTER    : PASS");

                pass_count = pass_count + 1;

            end

            else begin

                $display("COUNTER    : FAIL");

                $display(
                    "Expected Counter = %032h",
                    current_counter + 128'd1
                );

                fail_count = fail_count + 1;

            end


            // Use returned counter for next AES-CTR block
            counter_in = counter_out;


            // Allow done pulse to disappear
            @(posedge clk);
            #1;

        end

    endtask


    // ============================================================
    // MAIN TEST
    //
    // NIST SP 800-38A
    // AES-128 CTR
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // INITIAL VALUES
        // --------------------------------------------------------

        reset      = 1'b1;
        start      = 1'b0;

        data_in    = 128'b0;

        pass_count = 0;
        fail_count = 0;


        // --------------------------------------------------------
        // AES-128 NIST KEY
        // --------------------------------------------------------

        key =
        128'h2B7E151628AED2A6ABF7158809CF4F3C;


        // --------------------------------------------------------
        // NIST INITIAL COUNTER
        // --------------------------------------------------------

        counter_in =
        128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF;


        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------

        repeat(4) @(posedge clk);

        @(negedge clk);

        reset = 1'b0;


        // ========================================================
        // BLOCK 0
        // ========================================================

        run_block(

            0,

            128'h6BC1BEE22E409F96E93D7E117393172A,

            128'h874D6191B620E3261BEF6864990DB6CE

        );


        // ========================================================
        // BLOCK 1
        // ========================================================

        run_block(

            1,

            128'hAE2D8A571E03AC9C9EB76FAC45AF8E51,

            128'h9806F66B7970FDFF8617187BB9FFFDFF

        );


        // ========================================================
        // BLOCK 2
        // ========================================================

        run_block(

            2,

            128'h30C81C46A35CE411E5FBC1191A0A52EF,

            128'h5AE4DF3EDBD5D35E5B4F09020DB03EAB

        );


        // ========================================================
        // BLOCK 3
        // ========================================================

        run_block(

            3,

            128'hF69F2445DF4F9B17AD2B417BE66C3710,

            128'h1E031DDA2FBE03D1792170A0F3009CEE

        );


        // ========================================================
        // FINAL RESULT
        // ========================================================

        $display("");
        $display("==================================================");
        $display("        NIST AES-128 CTR FINAL RESULT");
        $display("==================================================");

        $display("PASS checks = %0d", pass_count);
        $display("FAIL checks = %0d", fail_count);


        if (fail_count == 0) begin

            $display("");
            $display("==============================================");
            $display("     ALL 4 NIST CTR BLOCKS PASSED");
            $display("     OPTIMIZED CTR VERIFIED");
            $display("==============================================");

        end

        else begin

            $display("");
            $display("==============================================");
            $display("        NIST CTR TEST FAILED");
            $display("==============================================");

        end


        #20;

        $finish;

    end


    // ============================================================
    // TIMEOUT PROTECTION
    // ============================================================

    initial begin

        #20000;

        $display("");
        $display("ERROR: SIMULATION TIMEOUT");

        $finish;

    end


endmodule