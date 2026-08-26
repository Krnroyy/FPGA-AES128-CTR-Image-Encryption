`timescale 1ns / 1ps

module image_encrypted_memory_tb;


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
    // EXPECTED ENCRYPTED IMAGE
    //
    // Independently verified golden values.
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

    image_encrypted_memory uut (

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
        // START IMAGE ENCRYPTION
        // ========================================================

        #20;

        start = 1'b1;

        #10;

        start = 1'b0;


        // ========================================================
        // WAIT FOR ENCRYPTION COMPLETE
        // ========================================================

        wait(done == 1'b1);

        #1;


        $display("");
        $display("================================================");
        $display("       ENCRYPTED IMAGE MEMORY VERIFICATION");
        $display("================================================");

        $display("");

        $display("KEY = %h", key);

        $display("");


        // ========================================================
        // READ BLOCK 0
        // ========================================================

        read_addr = 2'd0;

        #1;

        $display("MEMORY ADDRESS 0");
        $display("ACTUAL   = %h", read_data);
        $display("EXPECTED = %h", EXPECTED_BLOCK0);

        if (read_data === EXPECTED_BLOCK0) begin

            $display("BLOCK 0 MEMORY READ : PASS");

        end

        else begin

            $display("BLOCK 0 MEMORY READ : FAIL");

        end


        $display("");


        // ========================================================
        // READ BLOCK 1
        // ========================================================

        read_addr = 2'd1;

        #1;

        $display("MEMORY ADDRESS 1");
        $display("ACTUAL   = %h", read_data);
        $display("EXPECTED = %h", EXPECTED_BLOCK1);

        if (read_data === EXPECTED_BLOCK1) begin

            $display("BLOCK 1 MEMORY READ : PASS");

        end

        else begin

            $display("BLOCK 1 MEMORY READ : FAIL");

        end


        $display("");


        // ========================================================
        // READ BLOCK 2
        // ========================================================

        read_addr = 2'd2;

        #1;

        $display("MEMORY ADDRESS 2");
        $display("ACTUAL   = %h", read_data);
        $display("EXPECTED = %h", EXPECTED_BLOCK2);

        if (read_data === EXPECTED_BLOCK2) begin

            $display("BLOCK 2 MEMORY READ : PASS");

        end

        else begin

            $display("BLOCK 2 MEMORY READ : FAIL");

        end


        $display("");


        // ========================================================
        // READ BLOCK 3
        // ========================================================

        read_addr = 2'd3;

        #1;

        $display("MEMORY ADDRESS 3");
        $display("ACTUAL   = %h", read_data);
        $display("EXPECTED = %h", EXPECTED_BLOCK3);

        if (read_data === EXPECTED_BLOCK3) begin

            $display("BLOCK 3 MEMORY READ : PASS");

        end

        else begin

            $display("BLOCK 3 MEMORY READ : FAIL");

        end


        $display("");


        // ========================================================
        // FINAL CHECK
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
                        $display("       ALL MEMORY BLOCKS : PASS");
                        $display("       ENCRYPTED MEMORY : VERIFIED");
                        $display("================================================");

                    end

                    else begin

                        $display("FINAL MEMORY CHECK : FAIL");

                    end

                end

                else begin

                    $display("FINAL MEMORY CHECK : FAIL");

                end

            end

            else begin

                $display("FINAL MEMORY CHECK : FAIL");

            end

        end

        else begin

            $display("FINAL MEMORY CHECK : FAIL");

        end


        #20;

        $finish;

    end

endmodule