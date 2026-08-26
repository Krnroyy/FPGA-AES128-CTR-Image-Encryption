`timescale 1ns / 1ps

module image_aes_bram_top_tb;

    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk;
    reg reset;
    reg start;


    // ============================================================
    // KEY INTERFACE
    // ============================================================

    reg        key_we;
    reg [3:0]  key_addr;
    reg [7:0]  key_data;


    // ============================================================
    // IMAGE BRAM WRITE INTERFACE
    // ============================================================

    reg        image_we;
    reg [11:0] image_addr;
    reg [7:0]  image_data;


    // ============================================================
    // NUMBER OF AES BLOCKS
    // ============================================================

    reg [7:0] last_block_addr;


    // ============================================================
    // CIPHERTEXT READ INTERFACE
    // ============================================================

    reg        cipher_re;
    reg [11:0] cipher_addr;

    wire [7:0] cipher_data;
    wire       cipher_valid;


    // ============================================================
    // STATUS
    // ============================================================

    wire busy;
    wire done;


    // ============================================================
    // TEST VARIABLES
    // ============================================================

    integer i;
    integer errors;
    integer cycle_count;

    reg [7:0] read_data;

    reg [7:0] expected_cipher [0:31];

    reg [7:0] key_bytes [0:15];


    // ============================================================
    // DUT
    // ============================================================

    image_aes_bram_top dut (

        .clk             (clk),
        .reset           (reset),
        .start           (start),

        .key_we          (key_we),
        .key_addr        (key_addr),
        .key_data        (key_data),

        .image_we        (image_we),
        .image_addr      (image_addr),
        .image_data      (image_data),

        .last_block_addr (last_block_addr),

        .cipher_re       (cipher_re),
        .cipher_addr     (cipher_addr),

        .cipher_data     (cipher_data),
        .cipher_valid    (cipher_valid),

        .busy            (busy),
        .done            (done)

    );


    // ============================================================
    // 100 MHz CLOCK
    //
    // Period = 10 ns
    // ============================================================

    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;


    // ============================================================
    // WRITE ONE BYTE TO IMAGE BRAM
    // ============================================================

    task write_image_byte;

        input [11:0] addr;
        input [7:0]  data;

        begin

            @(negedge clk);

            image_addr = addr;
            image_data = data;
            image_we   = 1'b1;

            // BRAM write occurs at next rising edge

            @(negedge clk);

            image_we = 1'b0;

        end

    endtask


    // ============================================================
    // WRITE ONE BYTE TO KEY REGISTER
    // ============================================================

    task write_key_byte;

        input [3:0] addr;
        input [7:0] data;

        begin

            @(negedge clk);

            key_addr = addr;
            key_data = data;
            key_we   = 1'b1;

            @(negedge clk);

            key_we = 1'b0;

        end

    endtask


    // ============================================================
    // READ ONE BYTE FROM CIPHERTEXT BRAM
    //
    // BRAM read is synchronous.
    // ============================================================

    task read_cipher_byte;

        input  [11:0] addr;
        output [7:0]  data;

        begin

            @(negedge clk);

            cipher_addr = addr;
            cipher_re   = 1'b1;

            // Data appears after next rising edge

            @(posedge clk);

            #1;

            data = cipher_data;

            if (cipher_valid !== 1'b1) begin

                $display(
                    "WARNING: cipher_valid not HIGH at address %0d",
                    addr
                );

            end

            @(negedge clk);

            cipher_re = 1'b0;

        end

    endtask


    // ============================================================
    // TEST
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // DEFAULT VALUES
        // --------------------------------------------------------

        reset = 1'b1;
        start = 1'b0;

        key_we   = 1'b0;
        key_addr = 4'd0;
        key_data = 8'h00;

        image_we   = 1'b0;
        image_addr = 12'd0;
        image_data = 8'h00;

        last_block_addr = 8'd1;

        cipher_re   = 1'b0;
        cipher_addr = 12'd0;

        errors      = 0;
        cycle_count = 0;


        // ========================================================
        // AES KEY
        //
        // 2B7E151628AED2A6ABF7158809CF4F3C
        // ========================================================

        key_bytes[0]  = 8'h2B;
        key_bytes[1]  = 8'h7E;
        key_bytes[2]  = 8'h15;
        key_bytes[3]  = 8'h16;

        key_bytes[4]  = 8'h28;
        key_bytes[5]  = 8'hAE;
        key_bytes[6]  = 8'hD2;
        key_bytes[7]  = 8'hA6;

        key_bytes[8]  = 8'hAB;
        key_bytes[9]  = 8'hF7;
        key_bytes[10] = 8'h15;
        key_bytes[11] = 8'h88;

        key_bytes[12] = 8'h09;
        key_bytes[13] = 8'hCF;
        key_bytes[14] = 8'h4F;
        key_bytes[15] = 8'h3C;


        // ========================================================
        // EXPECTED CIPHERTEXT
        //
        // Plaintext block 0:
        // 101112131415161718191A1B1C1D1E1F
        //
        // Plaintext block 1:
        // 202122232425262728292A2B2C2D2E2F
        //
        // Initial CTR:
        // F0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF
        // ========================================================

        // Block 0
        expected_cipher[0]  = 8'hFC;
        expected_cipher[1]  = 8'h9D;
        expected_cipher[2]  = 8'hCD;
        expected_cipher[3]  = 8'h60;

        expected_cipher[4]  = 8'h8C;
        expected_cipher[5]  = 8'h75;
        expected_cipher[6]  = 8'h6A;
        expected_cipher[7]  = 8'hA7;

        expected_cipher[8]  = 8'hEA;
        expected_cipher[9]  = 8'hCB;
        expected_cipher[10] = 8'h0C;
        expected_cipher[11] = 8'h6E;

        expected_cipher[12] = 8'hF6;
        expected_cipher[13] = 8'h83;
        expected_cipher[14] = 8'hBF;
        expected_cipher[15] = 8'hFB;


        // Block 1
        expected_cipher[16] = 8'h16;
        expected_cipher[17] = 8'h0A;
        expected_cipher[18] = 8'h5E;
        expected_cipher[19] = 8'h1F;

        expected_cipher[20] = 8'h43;
        expected_cipher[21] = 8'h56;
        expected_cipher[22] = 8'h77;
        expected_cipher[23] = 8'h44;

        expected_cipher[24] = 8'h30;
        expected_cipher[25] = 8'h89;
        expected_cipher[26] = 8'h5D;
        expected_cipher[27] = 8'hFC;

        expected_cipher[28] = 8'hD0;
        expected_cipher[29] = 8'h7D;
        expected_cipher[30] = 8'h5D;
        expected_cipher[31] = 8'h81;


        // ========================================================
        // RESET
        // ========================================================

        $display("");
        $display("============================================");
        $display(" AES-128 CTR BRAM ARCHITECTURE TEST");
        $display("============================================");
        $display("");

        repeat (5)
            @(posedge clk);

        @(negedge clk);

        reset = 1'b0;

        $display("Reset released.");


        // ========================================================
        // LOAD AES KEY BYTE-BY-BYTE
        // ========================================================

        $display("");
        $display("Loading AES-128 key...");

        for (i = 0; i < 16; i = i + 1) begin

            write_key_byte(
                i,
                key_bytes[i]
            );

        end

        $display("AES key loaded.");


        // ========================================================
        // LOAD TEST IMAGE
        //
        // Addresses 0...31
        // Data      10...2F
        // ========================================================

        $display("");
        $display("Loading 32-byte image into BRAM...");

        for (i = 0; i < 32; i = i + 1) begin

            write_image_byte(
                i,
                8'h10 + i
            );

        end

        $display("Image BRAM loading complete.");


        // ========================================================
        // TWO AES BLOCKS
        //
        // Block addresses:
        // 0 and 1
        // ========================================================

        last_block_addr = 8'd1;


        // ========================================================
        // START ENCRYPTION
        // ========================================================

        $display("");
        $display("Starting AES-128 CTR encryption...");

        @(negedge clk);

        start = 1'b1;

        // Start accepted here

        @(posedge clk);

        #1;

        @(negedge clk);

        start = 1'b0;


        // ========================================================
        // MEASURE START -> DONE LATENCY
        // ========================================================

        cycle_count = 0;

        while (done !== 1'b1) begin

            @(posedge clk);

            #1;

            cycle_count = cycle_count + 1;

            if (cycle_count > 5000) begin

                $display("");
                $display("ERROR: Simulation timeout.");
                $display("AES BRAM controller did not finish.");

                $finish;

            end

        end


        $display("");
        $display(
            "Encryption completed after %0d clock cycles.",
            cycle_count
        );

        $display(
            "At 100 MHz: latency = %0.2f us",
            cycle_count * 0.01
        );


        // ========================================================
        // READ CIPHERTEXT BRAM
        // ========================================================

        $display("");
        $display("Reading ciphertext BRAM...");
        $display("");


        for (i = 0; i < 32; i = i + 1) begin

            read_cipher_byte(
                i,
                read_data
            );


            if (read_data !== expected_cipher[i]) begin

                $display(
                    "FAIL addr=%0d expected=%02h actual=%02h",
                    i,
                    expected_cipher[i],
                    read_data
                );

                errors = errors + 1;

            end

            else begin

                $display(
                    "PASS addr=%0d data=%02h",
                    i,
                    read_data
                );

            end

        end


        // ========================================================
        // FINAL RESULT
        // ========================================================

        $display("");
        $display("============================================");

        if (errors == 0) begin

            $display(" BRAM AES-128 CTR TEST : PASS");
            $display(" All 32 ciphertext bytes matched.");
            $display(
                " Start-to-done latency: %0d cycles",
                cycle_count
            );

        end

        else begin

            $display(" BRAM AES-128 CTR TEST : FAIL");
            $display(
                " Number of mismatched bytes: %0d",
                errors
            );

        end

        $display("============================================");
        $display("");

        #100;

        $finish;

    end


endmodule