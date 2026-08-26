`timescale 1ns / 1ps

module image_aes_bram_encdec_tb;


    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk;
    reg reset;


    // ============================================================
    // CONTROL
    // ============================================================

    reg start_encrypt;
    reg start_decrypt;


    // ============================================================
    // AES KEY INTERFACE
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
    // BLOCK CONTROL
    //
    // last_block_addr = 3
    // means blocks 0,1,2,3
    // = 4 AES blocks
    // = 64 bytes
    // ============================================================

    reg [7:0] last_block_addr;


    // ============================================================
    // CIPHERTEXT BRAM READ INTERFACE
    // ============================================================

    reg        cipher_re;
    reg [11:0] cipher_addr;

    wire [7:0] cipher_data;
    wire       cipher_valid;


    // ============================================================
    // RECOVERED BRAM READ INTERFACE
    // ============================================================

    reg        recovered_re;
    reg [11:0] recovered_addr;

    wire [7:0] recovered_data;
    wire       recovered_valid;


    // ============================================================
    // STATUS
    // ============================================================

    wire busy;
    wire encrypt_done;
    wire decrypt_done;


    // ============================================================
    // TEST VARIABLES
    // ============================================================

    integer i;

    integer cipher_errors;
    integer recovered_errors;

    integer encrypt_cycles;
    integer decrypt_cycles;

    reg [7:0] read_data;


    // ============================================================
    // EXPECTED CIPHERTEXT
    // ============================================================

    reg [7:0] expected_cipher [0:63];


    // ============================================================
    // KEY BYTES
    // ============================================================

    reg [7:0] key_bytes [0:15];


    // ============================================================
    // DUT
    // ============================================================

    image_aes_bram_encdec_top dut (

        .clk             (clk),
        .reset           (reset),

        .start_encrypt   (start_encrypt),
        .start_decrypt   (start_decrypt),

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

        .recovered_re    (recovered_re),
        .recovered_addr  (recovered_addr),
        .recovered_data  (recovered_data),
        .recovered_valid (recovered_valid),

        .busy            (busy),
        .encrypt_done    (encrypt_done),
        .decrypt_done    (decrypt_done)

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
    // WRITE ONE AES KEY BYTE
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
    // WRITE ONE IMAGE BYTE
    // ============================================================

    task write_image_byte;

        input [11:0] addr;
        input [7:0]  data;

        begin

            @(negedge clk);

            image_addr = addr;
            image_data = data;
            image_we   = 1'b1;

            @(negedge clk);

            image_we = 1'b0;

        end

    endtask


    // ============================================================
    // READ ONE CIPHERTEXT BYTE
    //
    // IMPORTANT:
    //
    // This task deliberately waits an additional clock before
    // sampling the BRAM output.
    //
    // This makes it work correctly in:
    //
    // 1. Behavioral simulation
    // 2. Post-implementation timing simulation
    //
    // and prevents the one-address delayed result seen earlier.
    // ============================================================

    task read_cipher_byte;

        input  [11:0] addr;
        output [7:0]  data;

        begin

            // ----------------------------------------------------
            // Apply address + read enable
            // ----------------------------------------------------

            @(negedge clk);

            cipher_addr = addr;
            cipher_re   = 1'b1;


            // ----------------------------------------------------
            // First rising edge launches synchronous BRAM read
            // ----------------------------------------------------

            @(posedge clk);


            // ----------------------------------------------------
            // Remove read enable after request was accepted
            // ----------------------------------------------------

            @(negedge clk);

            cipher_re = 1'b0;


            // ----------------------------------------------------
            // Wait one more rising edge.
            //
            // BRAM output from requested address is now safely
            // available even with post-route propagation delays.
            // ----------------------------------------------------

            @(posedge clk);

            #1;

            data = cipher_data;

        end

    endtask


    // ============================================================
    // READ ONE RECOVERED BYTE
    //
    // Same timing-safe BRAM read method.
    // ============================================================

    task read_recovered_byte;

        input  [11:0] addr;
        output [7:0]  data;

        begin

            // ----------------------------------------------------
            // Apply address + read enable
            // ----------------------------------------------------

            @(negedge clk);

            recovered_addr = addr;
            recovered_re   = 1'b1;


            // ----------------------------------------------------
            // Launch synchronous BRAM read
            // ----------------------------------------------------

            @(posedge clk);


            // ----------------------------------------------------
            // Remove read enable
            // ----------------------------------------------------

            @(negedge clk);

            recovered_re = 1'b0;


            // ----------------------------------------------------
            // Wait extra clock before sampling
            // ----------------------------------------------------

            @(posedge clk);

            #1;

            data = recovered_data;

        end

    endtask


    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin


        // ========================================================
        // INITIAL VALUES
        // ========================================================

        reset = 1'b1;

        start_encrypt = 1'b0;
        start_decrypt = 1'b0;


        key_we   = 1'b0;
        key_addr = 4'd0;
        key_data = 8'h00;


        image_we   = 1'b0;
        image_addr = 12'd0;
        image_data = 8'h00;


        cipher_re   = 1'b0;
        cipher_addr = 12'd0;


        recovered_re   = 1'b0;
        recovered_addr = 12'd0;


        last_block_addr = 8'd3;


        cipher_errors    = 0;
        recovered_errors = 0;

        encrypt_cycles = 0;
        decrypt_cycles = 0;


        // ========================================================
        // AES-128 KEY
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
        // ========================================================


        // --------------------------------------------------------
        // BLOCK 0
        //
        // FC9DCD608C756AA7EACB0C6EF683BFFB
        // --------------------------------------------------------

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


        // --------------------------------------------------------
        // BLOCK 1
        //
        // 160A5E1F4356774430895DFCD07D5D81
        // --------------------------------------------------------

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


        // --------------------------------------------------------
        // BLOCK 2
        //
        // 5A1DF14B4CBC0178868DF2202B87527B
        // --------------------------------------------------------

        expected_cipher[32] = 8'h5A;
        expected_cipher[33] = 8'h1D;
        expected_cipher[34] = 8'hF1;
        expected_cipher[35] = 8'h4B;

        expected_cipher[36] = 8'h4C;
        expected_cipher[37] = 8'hBC;
        expected_cipher[38] = 8'h01;
        expected_cipher[39] = 8'h78;

        expected_cipher[40] = 8'h86;
        expected_cipher[41] = 8'h8D;
        expected_cipher[42] = 8'hF2;
        expected_cipher[43] = 8'h20;

        expected_cipher[44] = 8'h2B;
        expected_cipher[45] = 8'h87;
        expected_cipher[46] = 8'h52;
        expected_cipher[47] = 8'h7B;


        // --------------------------------------------------------
        // BLOCK 3
        //
        // A8DD7BDCB4B4DE819C437B905921E5B1
        // --------------------------------------------------------

        expected_cipher[48] = 8'hA8;
        expected_cipher[49] = 8'hDD;
        expected_cipher[50] = 8'h7B;
        expected_cipher[51] = 8'hDC;

        expected_cipher[52] = 8'hB4;
        expected_cipher[53] = 8'hB4;
        expected_cipher[54] = 8'hDE;
        expected_cipher[55] = 8'h81;

        expected_cipher[56] = 8'h9C;
        expected_cipher[57] = 8'h43;
        expected_cipher[58] = 8'h7B;
        expected_cipher[59] = 8'h90;

        expected_cipher[60] = 8'h59;
        expected_cipher[61] = 8'h21;
        expected_cipher[62] = 8'hE5;
        expected_cipher[63] = 8'hB1;


        // ========================================================
        // TEST HEADER
        // ========================================================

        $display("");
        $display("====================================================");
        $display(" AES-128 CTR BRAM ENCRYPTION + DECRYPTION TEST");
        $display("====================================================");
        $display("");


        // ========================================================
        // RESET
        // ========================================================

        repeat (5)
            @(posedge clk);


        @(negedge clk);

        reset = 1'b0;


        $display("Reset released.");


        // ========================================================
        // LOAD AES KEY
        // ========================================================

        $display("");
        $display("Loading AES-128 key...");


        for (i = 0; i < 16; i = i + 1) begin

            write_key_byte(
                i,
                key_bytes[i]
            );

        end


        $display("AES-128 key loaded.");


        // ========================================================
        // LOAD 64-BYTE IMAGE
        //
        // address 0  = 10
        // address 1  = 11
        // ...
        // address 63 = 4F
        // ========================================================

        $display("");
        $display(
            "Loading 64-byte original image into Image BRAM..."
        );


        for (i = 0; i < 64; i = i + 1) begin

            write_image_byte(
                i,
                8'h10 + i
            );

        end


        $display(
            "Original image loading complete."
        );


        // ========================================================
        // FOUR AES BLOCKS
        // ========================================================

        last_block_addr = 8'd3;


        // ========================================================
        // START ENCRYPTION
        // ========================================================

        $display("");
        $display(
            "Starting AES-128 CTR encryption..."
        );


        @(negedge clk);

        start_encrypt = 1'b1;


        @(posedge clk);

        #1;


        @(negedge clk);

        start_encrypt = 1'b0;


        // ========================================================
        // ENCRYPTION LATENCY
        // ========================================================

        encrypt_cycles = 0;


        while (encrypt_done !== 1'b1) begin

            @(posedge clk);

            #1;

            encrypt_cycles =
                encrypt_cycles + 1;


            if (encrypt_cycles > 10000) begin

                $display("");
                $display(
                    "ERROR: Encryption timeout."
                );

                $finish;

            end

        end


        $display("");

        $display(
            "Encryption completed after %0d cycles.",
            encrypt_cycles
        );


        $display(
            "Encryption latency at 100 MHz = %0.2f us",
            encrypt_cycles * 0.01
        );


        // --------------------------------------------------------
        // Wait for FINISH -> IDLE
        // --------------------------------------------------------

        @(posedge clk);

        #1;


        // ========================================================
        // VERIFY CIPHERTEXT BRAM
        // ========================================================

        $display("");
        $display(
            "Verifying Cipher BRAM..."
        );
        $display("");


        for (i = 0; i < 64; i = i + 1) begin


            read_cipher_byte(
                i,
                read_data
            );


            if (
                read_data !== expected_cipher[i]
            ) begin

                $display(
                    "CIPHER FAIL addr=%0d expected=%02h actual=%02h",
                    i,
                    expected_cipher[i],
                    read_data
                );


                cipher_errors =
                    cipher_errors + 1;

            end


            else begin

                $display(
                    "CIPHER PASS addr=%0d data=%02h",
                    i,
                    read_data
                );

            end

        end


        // ========================================================
        // ENCRYPTION VERIFICATION RESULT
        // ========================================================

        $display("");


        if (cipher_errors == 0) begin

            $display(
                "ENCRYPTION VERIFICATION : PASS"
            );

            $display(
                "All 64 ciphertext bytes matched."
            );

        end


        else begin

            $display(
                "ENCRYPTION VERIFICATION : FAIL"
            );

            $display(
                "Ciphertext errors = %0d",
                cipher_errors
            );

        end


        // ========================================================
        // START DECRYPTION
        // ========================================================

        $display("");

        $display(
            "--------------------------------------------"
        );

        $display(
            "Starting AES-128 CTR decryption..."
        );

        $display(
            "--------------------------------------------"
        );

        $display("");


        @(negedge clk);

        start_decrypt = 1'b1;


        @(posedge clk);

        #1;


        @(negedge clk);

        start_decrypt = 1'b0;


        // ========================================================
        // DECRYPTION LATENCY
        // ========================================================

        decrypt_cycles = 0;


        while (decrypt_done !== 1'b1) begin

            @(posedge clk);

            #1;

            decrypt_cycles =
                decrypt_cycles + 1;


            if (decrypt_cycles > 10000) begin

                $display("");

                $display(
                    "ERROR: Decryption timeout."
                );

                $finish;

            end

        end


        $display(
            "Decryption completed after %0d cycles.",
            decrypt_cycles
        );


        $display(
            "Decryption latency at 100 MHz = %0.2f us",
            decrypt_cycles * 0.01
        );


        // --------------------------------------------------------
        // Wait for FINISH -> IDLE
        // --------------------------------------------------------

        @(posedge clk);

        #1;


        // ========================================================
        // VERIFY RECOVERED IMAGE BRAM
        // ========================================================

        $display("");

        $display(
            "Verifying Recovered Image BRAM..."
        );

        $display("");


        for (i = 0; i < 64; i = i + 1) begin


            read_recovered_byte(
                i,
                read_data
            );


            if (
                read_data !== (8'h10 + i)
            ) begin

                $display(
                    "RECOVER FAIL addr=%0d expected=%02h actual=%02h",
                    i,
                    (8'h10 + i),
                    read_data
                );


                recovered_errors =
                    recovered_errors + 1;

            end


            else begin

                $display(
                    "RECOVER PASS addr=%0d data=%02h",
                    i,
                    read_data
                );

            end

        end


        // ========================================================
        // FINAL RESULT
        // ========================================================

        $display("");

        $display(
            "===================================================="
        );

        $display(
            " AES-128 CTR BRAM FULL SYSTEM RESULT"
        );

        $display(
            "===================================================="
        );


        if (cipher_errors == 0) begin

            $display(
                " Encryption verification : PASS"
            );

        end

        else begin

            $display(
                " Encryption verification : FAIL"
            );

        end


        if (recovered_errors == 0) begin

            $display(
                " Decryption verification : PASS"
            );

        end

        else begin

            $display(
                " Decryption verification : FAIL"
            );

        end


        $display("");


        $display(
            " Encryption latency : %0d cycles (%0.2f us)",
            encrypt_cycles,
            encrypt_cycles * 0.01
        );


        $display(
            " Decryption latency : %0d cycles (%0.2f us)",
            decrypt_cycles,
            decrypt_cycles * 0.01
        );


        $display("");


        if (
            (cipher_errors == 0) &&
            (recovered_errors == 0)
        ) begin

            $display(
                " Original Image == Recovered Image : YES"
            );

            $display("");

            $display(
                " FULL AES-128 CTR BRAM SYSTEM : PASS"
            );

        end


        else begin

            $display(
                " Original Image == Recovered Image : NO"
            );

            $display("");

            $display(
                " FULL AES-128 CTR BRAM SYSTEM : FAIL"
            );

        end


        $display(
            "===================================================="
        );

        $display("");


        // ========================================================
        // END SIMULATION
        // ========================================================

        #100;

        $finish;

    end


endmodule