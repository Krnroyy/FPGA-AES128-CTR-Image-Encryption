`timescale 1ns / 1ps

module aes128_ctr_tb;


    // ============================================================
    // CLOCK / CONTROL
    // ============================================================

    reg clk;
    reg reset;
    reg start;


    // ============================================================
    // INPUTS
    // ============================================================

    reg [127:0] data_in;
    reg [127:0] key;
    reg [127:0] counter_in;


    // ============================================================
    // OUTPUTS
    // ============================================================

    wire [127:0] data_out;
    wire [127:0] counter_out;

    wire busy;
    wire done;


    // ============================================================
    // EXPECTED VALUES
    //
    // NIST SP 800-38A AES-128 CTR test vector
    // ============================================================

    reg [127:0] expected1;
    reg [127:0] expected2;
    reg [127:0] expected3;
    reg [127:0] expected4;


    initial begin

        expected1 =
            128'h874D6191B620E3261BEF6864990DB6CE;

        expected2 =
            128'h9806F66B7970FDFF8617187BB9FFFDFF;

        expected3 =
            128'h5AE4DF3EDBD5D35E5B4F09020DB03EAB;

        expected4 =
            128'h1E031DDA2FBE03D1792170A0F3009CEE;

    end


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
    // 10 ns period
    // ============================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    // ============================================================
    // TEST
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // NIST AES-128 CTR test vector
        // --------------------------------------------------------

        key =
            128'h2B7E151628AED2A6ABF7158809CF4F3C;

        counter_in =
            128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF;


        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        reset = 1'b1;
        start = 1'b0;

        data_in = 128'b0;

        #20;

        reset = 1'b0;


        // ========================================================
        // BLOCK 1
        // ========================================================

        data_in =
            128'h6BC1BEE22E409F96E93D7E117393172A;

        #10;

        start = 1'b1;

        #10;

        start = 1'b0;

        wait(done == 1'b1);

        #1;

        $display("==============================================");
        $display("BLOCK 1");
        $display("Input    = %h", data_in);
        $display("Output   = %h", data_out);
        $display("Expected = %h", expected1);

        if (data_out == expected1)
            $display("BLOCK 1 PASSED");
        else
            $display("BLOCK 1 FAILED");


        // ========================================================
        // BLOCK 2
        // ========================================================

        counter_in = counter_out;

        data_in =
            128'hAE2D8A571E03AC9C9EB76FAC45AF8E51;

        #10;

        start = 1'b1;

        #10;

        start = 1'b0;

        wait(done == 1'b1);

        #1;

        $display("==============================================");
        $display("BLOCK 2");
        $display("Input    = %h", data_in);
        $display("Output   = %h", data_out);
        $display("Expected = %h", expected2);

        if (data_out == expected2)
            $display("BLOCK 2 PASSED");
        else
            $display("BLOCK 2 FAILED");


        // ========================================================
        // BLOCK 3
        // ========================================================

        counter_in = counter_out;

        data_in =
            128'h30C81C46A35CE411E5FBC1191A0A52EF;

        #10;

        start = 1'b1;

        #10;

        start = 1'b0;

        wait(done == 1'b1);

        #1;

        $display("==============================================");
        $display("BLOCK 3");
        $display("Input    = %h", data_in);
        $display("Output   = %h", data_out);
        $display("Expected = %h", expected3);

        if (data_out == expected3)
            $display("BLOCK 3 PASSED");
        else
            $display("BLOCK 3 FAILED");


        // ========================================================
        // BLOCK 4
        // ========================================================

        counter_in = counter_out;

        data_in =
            128'hF69F2445DF4F9B17AD2B417BE66C3710;

        #10;

        start = 1'b1;

        #10;

        start = 1'b0;

        wait(done == 1'b1);

        #1;

        $display("==============================================");
        $display("BLOCK 4");
        $display("Input    = %h", data_in);
        $display("Output   = %h", data_out);
        $display("Expected = %h", expected4);

        if (data_out == expected4)
            $display("BLOCK 4 PASSED");
        else
            $display("BLOCK 4 FAILED");


        // ========================================================
        // END
        // ========================================================

        #20;

        $display("==============================================");
        $display("AES-128 CTR MULTI-BLOCK TEST COMPLETE");
        $display("==============================================");

        $finish;

    end


endmodule