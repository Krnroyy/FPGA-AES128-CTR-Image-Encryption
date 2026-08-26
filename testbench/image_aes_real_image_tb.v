`timescale 1ns / 1ps

module image_aes_real_image_tb;

    reg clk;
    reg reset;

    reg start_encrypt;
    reg start_decrypt;

    reg key_we;
    reg [3:0] key_addr;
    reg [7:0] key_data;

    reg image_we;
    reg [11:0] image_addr;
    reg [7:0] image_data;

    reg [7:0] last_block_addr;

    reg cipher_re;
    reg [11:0] cipher_addr;
    wire [7:0] cipher_data;
    wire cipher_valid;

    reg recovered_re;
    reg [11:0] recovered_addr;
    wire [7:0] recovered_data;
    wire recovered_valid;

    wire busy;
    wire encrypt_done;
    wire decrypt_done;

    // 64 x 64 grayscale image = 4096 bytes
    reg [7:0] image_bytes [0:4095];

    integer i;
    integer cipher_file;
    integer recovered_file;
    integer errors;


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
    // CLOCK
    // 100 MHz
    // ============================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin

        reset = 1'b1;

        start_encrypt = 1'b0;
        start_decrypt = 1'b0;

        key_we   = 1'b0;
        key_addr = 4'd0;
        key_data = 8'd0;

        image_we   = 1'b0;
        image_addr = 12'd0;
        image_data = 8'd0;

        // 256 AES blocks:
        // block numbers 0 through 255
        last_block_addr = 8'd255;

        cipher_re   = 1'b0;
        cipher_addr = 12'd0;

        recovered_re   = 1'b0;
        recovered_addr = 12'd0;

        errors = 0;


        // ========================================================
        // LOAD REAL IMAGE HEX FILE
        // ========================================================

        $readmemh(
            "C:/Users/ASUS/OneDrive/Desktop/AES_real_image_demo/image_input.hex",
            image_bytes
        );


        $display("");
        $display("======================================================");
        $display("     REAL IMAGE AES-128 CTR FPGA TEST");
        $display("======================================================");
        $display(" Image size      : 64 x 64 grayscale");
        $display(" Image bytes     : 4096");
        $display(" AES blocks      : 256");
        $display(" Last block      : 255");
        $display("======================================================");
        $display("");


        // ========================================================
        // RESET
        // ========================================================

        repeat(5) @(posedge clk);

        @(negedge clk);
        reset = 1'b0;

        repeat(2) @(posedge clk);

        $display("Reset released.");


        // ========================================================
        // LOAD AES-128 KEY
        //
        // 2B7E151628AED2A6ABF7158809CF4F3C
        // ========================================================

        $display("");
        $display("Loading AES-128 key...");

        key_we = 1'b1;


        @(negedge clk);
        key_addr = 4'd0;
        key_data = 8'h2B;

        @(negedge clk);
        key_addr = 4'd1;
        key_data = 8'h7E;

        @(negedge clk);
        key_addr = 4'd2;
        key_data = 8'h15;

        @(negedge clk);
        key_addr = 4'd3;
        key_data = 8'h16;

        @(negedge clk);
        key_addr = 4'd4;
        key_data = 8'h28;

        @(negedge clk);
        key_addr = 4'd5;
        key_data = 8'hAE;

        @(negedge clk);
        key_addr = 4'd6;
        key_data = 8'hD2;

        @(negedge clk);
        key_addr = 4'd7;
        key_data = 8'hA6;

        @(negedge clk);
        key_addr = 4'd8;
        key_data = 8'hAB;

        @(negedge clk);
        key_addr = 4'd9;
        key_data = 8'hF7;

        @(negedge clk);
        key_addr = 4'd10;
        key_data = 8'h15;

        @(negedge clk);
        key_addr = 4'd11;
        key_data = 8'h88;

        @(negedge clk);
        key_addr = 4'd12;
        key_data = 8'h09;

        @(negedge clk);
        key_addr = 4'd13;
        key_data = 8'hCF;

        @(negedge clk);
        key_addr = 4'd14;
        key_data = 8'h4F;

        @(negedge clk);
        key_addr = 4'd15;
        key_data = 8'h3C;


        @(posedge clk);

        @(negedge clk);
        key_we = 1'b0;

        $display("AES-128 key loaded.");


        // ========================================================
        // LOAD 4096 IMAGE BYTES INTO IMAGE BRAM
        // ========================================================

        $display("");
        $display("Loading 4096 image bytes into Image BRAM...");

        image_we = 1'b1;


        for (i = 0; i < 4096; i = i + 1) begin

            @(negedge clk);

            image_addr = i;
            image_data = image_bytes[i];

        end


        @(posedge clk);

        @(negedge clk);

        image_we = 1'b0;

        $display("Image BRAM loading complete.");


        // ========================================================
        // START ENCRYPTION
        // ========================================================

        repeat(3) @(posedge clk);

        $display("");
        $display("Starting AES-128 CTR encryption...");


        @(negedge clk);

        start_encrypt = 1'b1;


        @(negedge clk);

        start_encrypt = 1'b0;


        // Wait until all 256 blocks are encrypted
        wait(encrypt_done == 1'b1);

        #1;

        $display("Encryption complete.");


        // ========================================================
        // WRITE CIPHER BRAM TO HEX FILE
        // ========================================================

        repeat(3) @(posedge clk);


        cipher_file = $fopen(
            "C:/Users/ASUS/OneDrive/Desktop/AES_real_image_demo/cipher_output.hex",
            "w"
        );


        if (cipher_file == 0) begin

            $display("");
            $display("ERROR: Could not create cipher_output.hex");

            $finish;

        end


        for (i = 0; i < 4096; i = i + 1) begin

            $fwrite(
                cipher_file,
                "%02x\n",
                dut.cipher_bram.mem[i]
            );

        end


        $fclose(cipher_file);

        $display("cipher_output.hex created successfully.");


        // ========================================================
        // START DECRYPTION
        // ========================================================

        repeat(3) @(posedge clk);

        $display("");
        $display("Starting AES-128 CTR decryption...");


        @(negedge clk);

        start_decrypt = 1'b1;


        @(negedge clk);

        start_decrypt = 1'b0;


        wait(decrypt_done == 1'b1);

        #1;

        $display("Decryption complete.");


        // ========================================================
        // WRITE RECOVERED BRAM TO HEX FILE
        // ========================================================

        repeat(3) @(posedge clk);


        recovered_file = $fopen(
            "C:/Users/ASUS/OneDrive/Desktop/AES_real_image_demo/recovered_output.hex",
            "w"
        );


        if (recovered_file == 0) begin

            $display("");
            $display("ERROR: Could not create recovered_output.hex");

            $finish;

        end


        for (i = 0; i < 4096; i = i + 1) begin

            $fwrite(
                recovered_file,
                "%02x\n",
                dut.recovered_bram.mem[i]
            );

        end


        $fclose(recovered_file);

        $display("recovered_output.hex created successfully.");


        // ========================================================
        // VERIFY ORIGINAL IMAGE == RECOVERED IMAGE
        // ========================================================

        $display("");
        $display("Checking original and recovered image...");


        errors = 0;


        for (i = 0; i < 4096; i = i + 1) begin

            if (dut.recovered_bram.mem[i] !== image_bytes[i]) begin

                errors = errors + 1;


                // Print only first 10 errors
                if (errors <= 10) begin

                    $display(
                        "MISMATCH addr=%0d original=%02x recovered=%02x",
                        i,
                        image_bytes[i],
                        dut.recovered_bram.mem[i]
                    );

                end

            end

        end


        // ========================================================
        // FINAL RESULT
        // ========================================================

        $display("");
        $display("======================================================");
        $display("            REAL IMAGE FINAL RESULT");
        $display("======================================================");


        if (errors == 0) begin

            $display(" Encryption                 : COMPLETE");
            $display(" Decryption                 : COMPLETE");
            $display(" Recovered byte mismatches  : 0");
            $display("");
            $display(" Original Image == Recovered Image : YES");
            $display("");
            $display(" REAL IMAGE AES-128 CTR TEST : PASS");

        end

        else begin

            $display(" REAL IMAGE AES-128 CTR TEST : FAIL");
            $display(" Total mismatches = %0d", errors);

        end


        $display("======================================================");


        #100;

        $finish;

    end


    // ============================================================
    // TIMEOUT PROTECTION
    //
    // 2 ms timeout
    // ============================================================

    initial begin

        #2000000;

        $display("");
        $display("======================================================");
        $display("ERROR: REAL IMAGE SIMULATION TIMEOUT");
        $display("======================================================");

        $finish;

    end


endmodule