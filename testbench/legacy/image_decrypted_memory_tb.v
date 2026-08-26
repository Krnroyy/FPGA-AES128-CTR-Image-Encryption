`timescale 1ns / 1ps

module image_decrypted_memory_tb;


    // ============================================================
    // SIGNALS
    // ============================================================

    reg clk;
    reg reset;
    reg start;

    reg [127:0] key;

    reg [1:0] read_addr;

    wire [127:0] read_data;

    wire busy;
    wire done;


    // ============================================================
    // TEST KEY
    // ============================================================

    localparam [127:0] TEST_KEY =
        128'h000102030405060708090A0B0C0D0E0F;


    // ============================================================
    // EXPECTED ORIGINAL IMAGE
    // ============================================================

    localparam [127:0] EXPECTED_BLOCK0 =
        128'h101112131415161718191A1B1C1D1E1F;

    localparam [127:0] EXPECTED_BLOCK1 =
        128'h202122232425262728292A2B2C2D2E2F;

    localparam [127:0] EXPECTED_BLOCK2 =
        128'h303132333435363738393A3B3C3D3E3F;

    localparam [127:0] EXPECTED_BLOCK3 =
        128'h404142434445464748494A4B4C4D4E4F;


    // ============================================================
    // DUT
    // ============================================================

    image_decrypted_memory uut (

        .clk       (clk),
        .reset     (reset),
        .start     (start),

        .key       (key),

        .read_addr (read_addr),
        .read_data (read_data),

        .busy      (busy),
        .done      (done)

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

        start = 1'b0;

        key = TEST_KEY;

        read_addr = 2'd0;


        // ========================================================
        // RESET
        // ========================================================

        #20;

        reset = 1'b0;


        // ========================================================
        // START DECRYPTION
        // ========================================================

        #20;

        start = 1'b1;

        #10;

        start = 1'b0;


        // ========================================================
        // WAIT FOR COMPLETE DECRYPTION
        // ========================================================

        wait(done == 1'b1);

        #1;


        $display("");
        $display("================================================");
        $display("       AES IMAGE 4-BLOCK DECRYPTION");
        $display("================================================");

        $display("");

        $display("KEY = %h", key);

        $display("");


        // ========================================================
        // BLOCK 0
        // ========================================================

        read_addr = 2'd0;

        #1;

        $display("DECRYPTED BLOCK 0 = %h", read_data);
        $display("EXPECTED BLOCK 0  = %h", EXPECTED_BLOCK0);

        if (read_data === EXPECTED_BLOCK0) begin

            $display("BLOCK 0 : PASS");

        end

        else begin

            $display("BLOCK 0 : FAIL");

        end


        $display("");


        // ========================================================
        // BLOCK 1
        // ========================================================

        read_addr = 2'd1;

        #1;

        $display("DECRYPTED BLOCK 1 = %h", read_data);
        $display("EXPECTED BLOCK 1  = %h", EXPECTED_BLOCK1);

        if (read_data === EXPECTED_BLOCK1) begin

            $display("BLOCK 1 : PASS");

        end

        else begin

            $display("BLOCK 1 : FAIL");

        end


        $display("");


        // ========================================================
        // BLOCK 2
        // ========================================================

        read_addr = 2'd2;

        #1;

        $display("DECRYPTED BLOCK 2 = %h", read_data);
        $display("EXPECTED BLOCK 2  = %h", EXPECTED_BLOCK2);

        if (read_data === EXPECTED_BLOCK2) begin

            $display("BLOCK 2 : PASS");

        end

        else begin

            $display("BLOCK 2 : FAIL");

        end


        $display("");


        // ========================================================
        // BLOCK 3
        // ========================================================

        read_addr = 2'd3;

        #1;

        $display("DECRYPTED BLOCK 3 = %h", read_data);
        $display("EXPECTED BLOCK 3  = %h", EXPECTED_BLOCK3);

        if (read_data === EXPECTED_BLOCK3) begin

            $display("BLOCK 3 : PASS");

        end

        else begin

            $display("BLOCK 3 : FAIL");

        end


        $display("");


        // ========================================================
        // FINAL VERIFICATION
        // ========================================================

        read_addr = 2'd0;
        #1;

        if (read_data === EXPECTED_BLOCK0) begin

            read_addr = 2'd1;
            #1;

            if (read_data === EXPECTED_BLOCK1) begin

                read_addr = 2'd2;
                #1;

                if (read_data === EXPECTED_BLOCK2) begin

                    read_addr = 2'd3;
                    #1;

                    if (read_data === EXPECTED_BLOCK3) begin

                        $display("================================================");
                        $display("       ALL 4 BLOCKS DECRYPTED : PASS");
                        $display("       ORIGINAL IMAGE : RECOVERED");
                        $display("================================================");

                    end

                    else begin

                        $display("FINAL DECRYPTION CHECK : FAIL");

                    end

                end

                else begin

                    $display("FINAL DECRYPTION CHECK : FAIL");

                end

            end

            else begin

                $display("FINAL DECRYPTION CHECK : FAIL");

            end

        end

        else begin

            $display("FINAL DECRYPTION CHECK : FAIL");

        end


        #20;

        $finish;

    end

endmodule