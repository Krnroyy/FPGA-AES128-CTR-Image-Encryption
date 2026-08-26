`timescale 1ns / 1ps

module image_block_reader_tb;

    reg clk;
    reg reset;

    reg block_select;

    wire block_valid;
    wire [127:0] block_out;


    // ============================================================
    // DUT
    // ============================================================

    image_block_reader uut (

        .clk          (clk),
        .reset        (reset),

        .block_select (block_select),

        .block_valid  (block_valid),
        .block_out    (block_out)

    );


    // ============================================================
    // CLOCK
    // ============================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    // ============================================================
    // TEST
    // ============================================================

    initial begin

        reset = 1'b1;

        block_select = 1'b0;

        #20;

        reset = 1'b0;


        // ========================================================
        // BLOCK 0
        // ========================================================

        block_select = 1'b0;

        #20;

        $display("==============================================");
        $display("IMAGE BLOCK 0");
        $display("Block = %h", block_out);

        if (block_out ==
            128'h101112131415161718191A1B1C1D1E1F)

            $display("BLOCK 0 PASSED");

        else

            $display("BLOCK 0 FAILED");


        // ========================================================
        // BLOCK 1
        // ========================================================

        block_select = 1'b1;

        #20;

        $display("==============================================");
        $display("IMAGE BLOCK 1");
        $display("Block = %h", block_out);

        if (block_out ==
            128'h202122232425262728292A2B2C2D2E2F)

            $display("BLOCK 1 PASSED");

        else

            $display("BLOCK 1 FAILED");


        // ========================================================
        // FINISH
        // ========================================================

        #20;

        $display("==============================================");
        $display("IMAGE BLOCK READER TEST COMPLETE");
        $display("==============================================");

        $finish;

    end

endmodule