`timescale 1ns / 1ps

module image_aes_bram_encdec_power_tb;


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
    // BLOCK CONTROL
    // ============================================================

    reg [7:0] last_block_addr;


    // ============================================================
    // UNUSED EXTERNAL CIPHER READ PORT
    // ============================================================

    reg        cipher_re;
    reg [11:0] cipher_addr;

    wire [7:0] cipher_data;
    wire       cipher_valid;


    // ============================================================
    // UNUSED EXTERNAL RECOVERED READ PORT
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
    integer encrypt_cycles;
    integer decrypt_cycles;

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
    // WRITE ONE KEY BYTE
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
    // MAIN POWER-ACTIVITY TEST
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

        // External memory reads disabled.
        cipher_re   = 1'b0;
        cipher_addr = 12'd0;

        recovered_re   = 1'b0;
        recovered_addr = 12'd0;

        // Blocks 0,1,2,3 = 4 AES blocks = 64 bytes.
        last_block_addr = 8'd3;

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
        // HEADER
        // ========================================================

        $display("");
        $display("====================================================");
        $display(" AES-128 CTR BRAM POWER ACTIVITY TEST");
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
        // LOAD KEY
        // ========================================================

        $display("");
        $display("Loading AES-128 key...");

        for (i = 0; i < 16; i = i + 1) begin

            write_key_byte(
                i,
                key_bytes[i]
            );

        end

        $display("AES-128 key loading complete.");


        // ========================================================
        // LOAD 64-BYTE IMAGE
        //
        // 10,11,12,...,4F
        // ========================================================

        $display("");
        $display("Loading 64-byte image into Image BRAM...");

        for (i = 0; i < 64; i = i + 1) begin

            write_image_byte(
                i,
                8'h10 + i
            );

        end

        $display("Image BRAM loading complete.");


        // ========================================================
        // START ENCRYPTION
        // ========================================================

        $display("");
        $display("Starting AES-128 CTR encryption...");


        @(negedge clk);

        start_encrypt = 1'b1;


        @(posedge clk);

        #1;


        @(negedge clk);

        start_encrypt = 1'b0;


        // ========================================================
        // WAIT FOR ENCRYPTION
        // ========================================================

        encrypt_cycles = 0;


        while (encrypt_done !== 1'b1) begin

            @(posedge clk);

            #1;

            encrypt_cycles = encrypt_cycles + 1;


            if (encrypt_cycles > 10000) begin

                $display("");
                $display("ERROR: Encryption timeout.");

                $finish;

            end

        end


        $display("");

        $display(
            "Encryption complete after %0d cycles.",
            encrypt_cycles
        );


        $display(
            "Encryption latency = %0.2f us at 100 MHz",
            encrypt_cycles * 0.01
        );


        // ========================================================
        // WAIT UNTIL DUT RETURNS TO IDLE
        // ========================================================

        repeat (3)
            @(posedge clk);


        // ========================================================
        // START DECRYPTION
        // ========================================================

        $display("");
        $display("Starting AES-128 CTR decryption...");


        @(negedge clk);

        start_decrypt = 1'b1;


        @(posedge clk);

        #1;


        @(negedge clk);

        start_decrypt = 1'b0;


        // ========================================================
        // WAIT FOR DECRYPTION
        // ========================================================

        decrypt_cycles = 0;


        while (decrypt_done !== 1'b1) begin

            @(posedge clk);

            #1;

            decrypt_cycles = decrypt_cycles + 1;


            if (decrypt_cycles > 10000) begin

                $display("");
                $display("ERROR: Decryption timeout.");

                $finish;

            end

        end


        $display("");

        $display(
            "Decryption complete after %0d cycles.",
            decrypt_cycles
        );


        $display(
            "Decryption latency = %0.2f us at 100 MHz",
            decrypt_cycles * 0.01
        );


        // ========================================================
        // ADD A FEW IDLE CYCLES
        //
        // Allows final transitions to be captured in SAIF.
        // ========================================================

        repeat (10)
            @(posedge clk);


        // ========================================================
        // FINAL MESSAGE
        // ========================================================

        $display("");
        $display("====================================================");
        $display(" POWER ACTIVITY WORKLOAD COMPLETE");
        $display("====================================================");

        $display(
            " Encryption cycles : %0d",
            encrypt_cycles
        );

        $display(
            " Decryption cycles : %0d",
            decrypt_cycles
        );

        $display("");
        $display(
            " 64 bytes encrypted and decrypted."
        );

        $display(
            " SAIF workload generation complete."
        );

        $display("====================================================");
        $display("");


        #100;

        $finish;

    end


endmodule