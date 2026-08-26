`timescale 1ns / 1ps

module tb_aes128_ctr_equivalence;

    reg clk;
    reg reset;
    reg start;

    reg [127:0] data_in;
    reg [127:0] key;
    reg [127:0] counter_in;

    wire [127:0] data_out_old;
    wire [127:0] counter_out_old;
    wire busy_old;
    wire done_old;

    wire [127:0] data_out_opt;
    wire [127:0] counter_out_opt;
    wire busy_opt;
    wire done_opt;


    // ============================================================
    // ORIGINAL VERIFIED MODULE
    // ============================================================

    aes128_ctr dut_old (
        .clk         (clk),
        .reset       (reset),
        .start       (start),
        .data_in     (data_in),
        .key         (key),
        .counter_in  (counter_in),
        .data_out    (data_out_old),
        .counter_out (counter_out_old),
        .busy        (busy_old),
        .done        (done_old)
    );


    // ============================================================
    // OPTIMIZED MODULE
    // ============================================================

    aes128_ctr_opt dut_opt (
        .clk         (clk),
        .reset       (reset),
        .start       (start),
        .data_in     (data_in),
        .key         (key),
        .counter_in  (counter_in),
        .data_out    (data_out_opt),
        .counter_out (counter_out_opt),
        .busy        (busy_opt),
        .done        (done_opt)
    );


    // ============================================================
    // CLOCK
    // ============================================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    // ============================================================
    // TEST TASK
    // ============================================================

    task run_test;

        input [127:0] test_data;
        input [127:0] test_counter;

        begin

            @(posedge clk);

            data_in    <= test_data;
            counter_in <= test_counter;
            start      <= 1'b1;

            @(posedge clk);

            start <= 1'b0;


            // Wait until both modules finish
            wait(done_old && done_opt);

            #1;


            $display("--------------------------------------------------");
            $display("INPUT COUNTER = %032h", test_counter);
            $display("OLD DATA OUT  = %032h", data_out_old);
            $display("OPT DATA OUT  = %032h", data_out_opt);

            $display("OLD COUNTER   = %032h", counter_out_old);
            $display("OPT COUNTER   = %032h", counter_out_opt);


            if (data_out_old !== data_out_opt) begin
                $display("FAIL: DATA OUTPUT MISMATCH");
                $finish;
            end


            if (counter_out_old !== counter_out_opt) begin
                $display("FAIL: COUNTER OUTPUT MISMATCH");
                $finish;
            end


            if (counter_out_opt !== (test_counter + 128'd1)) begin
                $display("FAIL: INCORRECT COUNTER INCREMENT");
                $finish;
            end


            $display("PASS");

            @(posedge clk);

        end

    endtask


    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin

        reset      = 1'b1;
        start      = 1'b0;
        data_in    = 128'b0;
        counter_in = 128'b0;

        key = 128'h2B7E151628AED2A6ABF7158809CF4F3C;


        repeat(4) @(posedge clk);

        reset = 1'b0;


        // --------------------------------------------------------
        // TEST 1
        // Normal NIST-style counter
        // --------------------------------------------------------

        run_test(
            128'h6BC1BEE22E409F96E93D7E117393172A,
            128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF
        );


        // --------------------------------------------------------
        // TEST 2
        // Carry across lower 32-bit boundary
        // --------------------------------------------------------

        run_test(
            128'h00112233445566778899AABBCCDDEEFF,
            128'h000000000000000000000000FFFFFFFF
        );


        // Expected next counter:
        //
        // 00000000000000000000000100000000


        // --------------------------------------------------------
        // TEST 3
        // Carry across 64-bit boundary
        // --------------------------------------------------------

        run_test(
            128'h112233445566778899AABBCCDDEEFF00,
            128'h0000000000000000FFFFFFFFFFFFFFFF
        );


        // Expected:
        //
        // 00000000000000010000000000000000


        // --------------------------------------------------------
        // TEST 4
        // Carry across 96-bit boundary
        // --------------------------------------------------------

        run_test(
            128'h0123456789ABCDEFFEDCBA9876543210,
            128'h00000000FFFFFFFFFFFFFFFFFFFFFFFF
        );


        // Expected:
        //
        // 00000001000000000000000000000000


        // --------------------------------------------------------
        // TEST 5
        // Full 128-bit rollover
        // --------------------------------------------------------

        run_test(
            128'hFFEEDDCCBBAA99887766554433221100,
            128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );


        // Expected:
        //
        // 00000000000000000000000000000000


        $display("");
        $display("==================================================");
        $display(" ALL ORIGINAL VS OPTIMIZED TESTS PASSED ");
        $display(" aes128_ctr_opt IS FUNCTIONALLY EQUIVALENT ");
        $display("==================================================");

        $finish;

    end

endmodule