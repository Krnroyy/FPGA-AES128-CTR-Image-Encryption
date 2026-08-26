`timescale 1ns / 1ps

module image_aes_bram_encdec_top (

    input  wire        clk,
    input  wire        reset,

    // ============================================================
    // OPERATION CONTROL
    // ============================================================

    input  wire        start_encrypt,
    input  wire        start_decrypt,


    // ============================================================
    // AES-128 KEY BYTE-WISE LOADING
    //
    // key_addr = 0  -> key[127:120]
    // key_addr = 15 -> key[7:0]
    // ============================================================

    input  wire        key_we,
    input  wire [3:0]  key_addr,
    input  wire [7:0]  key_data,


    // ============================================================
    // ORIGINAL IMAGE BRAM WRITE INTERFACE
    //
    // 4096 bytes maximum
    // ============================================================

    input  wire        image_we,
    input  wire [11:0] image_addr,
    input  wire [7:0]  image_data,


    // ============================================================
    // LAST AES BLOCK ADDRESS
    //
    // 0 = one block
    // 1 = two blocks
    // 3 = four blocks
    //
    // Maximum = 255 -> 256 AES blocks -> 4096 bytes
    // ============================================================

    input  wire [7:0]  last_block_addr,


    // ============================================================
    // CIPHERTEXT BRAM EXTERNAL READ
    // ============================================================

    input  wire        cipher_re,
    input  wire [11:0] cipher_addr,

    output wire [7:0]  cipher_data,
    output reg         cipher_valid,


    // ============================================================
    // RECOVERED IMAGE BRAM EXTERNAL READ
    // ============================================================

    input  wire        recovered_re,
    input  wire [11:0] recovered_addr,

    output wire [7:0]  recovered_data,
    output reg         recovered_valid,


    // ============================================================
    // STATUS
    // ============================================================

    output wire        busy,
    output wire        encrypt_done,
    output wire        decrypt_done

);


    // ============================================================
    // AES KEY REGISTER
    // ============================================================

    reg [127:0] key_reg;


    always @(posedge clk) begin

        if (reset) begin

            // Default verified AES-128 key
            key_reg <=
                128'h2B7E151628AED2A6ABF7158809CF4F3C;

        end

        else if (key_we && !busy) begin

            case (key_addr)

                4'd0:
                    key_reg[127:120] <= key_data;

                4'd1:
                    key_reg[119:112] <= key_data;

                4'd2:
                    key_reg[111:104] <= key_data;

                4'd3:
                    key_reg[103:96] <= key_data;

                4'd4:
                    key_reg[95:88] <= key_data;

                4'd5:
                    key_reg[87:80] <= key_data;

                4'd6:
                    key_reg[79:72] <= key_data;

                4'd7:
                    key_reg[71:64] <= key_data;

                4'd8:
                    key_reg[63:56] <= key_data;

                4'd9:
                    key_reg[55:48] <= key_data;

                4'd10:
                    key_reg[47:40] <= key_data;

                4'd11:
                    key_reg[39:32] <= key_data;

                4'd12:
                    key_reg[31:24] <= key_data;

                4'd13:
                    key_reg[23:16] <= key_data;

                4'd14:
                    key_reg[15:8] <= key_data;

                4'd15:
                    key_reg[7:0] <= key_data;

            endcase

        end

    end


    // ============================================================
    // OPERATION MODE
    // ============================================================

    localparam MODE_ENCRYPT = 1'b0;
    localparam MODE_DECRYPT = 1'b1;

    reg mode;


    // ============================================================
    // FSM STATES
    // ============================================================

    localparam IDLE         = 4'd0;
    localparam READ_REQ     = 4'd1;
    localparam READ_CAPTURE = 4'd2;
    localparam AES_START    = 4'd3;
    localparam AES_WAIT     = 4'd4;
    localparam WRITE_BYTE   = 4'd5;
    localparam NEXT_BLOCK   = 4'd6;
    localparam FINISH       = 4'd7;

    reg [3:0] state;


    // ============================================================
    // BLOCK / BYTE ADDRESS CONTROL
    // ============================================================

    reg [7:0] block_index;
    reg [7:0] last_block_reg;

    reg [3:0] byte_index;


    // ============================================================
    // AES INPUT / OUTPUT BLOCK REGISTERS
    // ============================================================

    reg [127:0] input_block;
    reg [127:0] output_block;


    // ============================================================
    // AES CTR COUNTER
    // ============================================================

    localparam [127:0] INITIAL_COUNTER =
        128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF;

    reg [127:0] aes_counter;


    // ============================================================
    // COMMON INTERNAL MEMORY ADDRESS
    //
    // block_index * 16 + byte_index
    //
    // Concatenation automatically gives:
    //
    // block 0 -> addresses 0..15
    // block 1 -> addresses 16..31
    // block 2 -> addresses 32..47
    // ...
    // ============================================================

    wire [11:0] internal_addr;

    assign internal_addr =
        {block_index, byte_index};


    // ============================================================
    // IMAGE BRAM
    //
    // BRAM #1
    //
    // Host writes image.
    // Encryption controller reads image.
    // ============================================================

    wire image_internal_read_enable;

    wire [7:0] image_bram_read_data;


    assign image_internal_read_enable =
        (state == READ_REQ) &&
        (mode == MODE_ENCRYPT);


    wire image_write_enable;

    assign image_write_enable =
        image_we && !busy;


    bram_8x4096 image_bram (

        .clk   (clk),

        .we    (image_write_enable),
        .waddr (image_addr),
        .wdata (image_data),

        .re    (image_internal_read_enable),
        .raddr (internal_addr),

        .rdata (image_bram_read_data)

    );


    // ============================================================
    // CIPHERTEXT BRAM
    //
    // BRAM #2
    //
    // Encryption writes ciphertext.
    //
    // Decryption reads ciphertext.
    //
    // External interface can also read ciphertext while idle.
    // ============================================================

    wire       cipher_internal_write_enable;
    wire       cipher_internal_read_enable;

    wire [7:0] cipher_write_data;

    wire       cipher_bram_read_enable;
    wire [11:0] cipher_bram_read_addr;

    wire [7:0] cipher_bram_read_data;


    assign cipher_internal_write_enable =
        (state == WRITE_BYTE) &&
        (mode == MODE_ENCRYPT);


    assign cipher_internal_read_enable =
        (state == READ_REQ) &&
        (mode == MODE_DECRYPT);


    // Internal decryption gets priority over external read.
    assign cipher_bram_read_enable =
        cipher_internal_read_enable ||
        (cipher_re && !busy);


    assign cipher_bram_read_addr =
        cipher_internal_read_enable
        ? internal_addr
        : cipher_addr;


    bram_8x4096 cipher_bram (

        .clk   (clk),

        .we    (cipher_internal_write_enable),
        .waddr (internal_addr),
        .wdata (cipher_write_data),

        .re    (cipher_bram_read_enable),
        .raddr (cipher_bram_read_addr),

        .rdata (cipher_bram_read_data)

    );


    assign cipher_data =
        cipher_bram_read_data;


    // ============================================================
    // EXTERNAL CIPHERTEXT READ VALID
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            cipher_valid <= 1'b0;

        end

        else begin

            cipher_valid <=
                cipher_re && !busy;

        end

    end


    // ============================================================
    // RECOVERED IMAGE BRAM
    //
    // BRAM #3
    //
    // Decryption writes recovered plaintext.
    //
    // External interface reads recovered plaintext.
    // ============================================================

    wire recovered_internal_write_enable;

    wire [7:0] recovered_write_data;

    wire [7:0] recovered_bram_read_data;


    assign recovered_internal_write_enable =
        (state == WRITE_BYTE) &&
        (mode == MODE_DECRYPT);


    bram_8x4096 recovered_bram (

        .clk   (clk),

        .we    (recovered_internal_write_enable),
        .waddr (internal_addr),
        .wdata (recovered_write_data),

        .re    (recovered_re && !busy),
        .raddr (recovered_addr),

        .rdata (recovered_bram_read_data)

    );


    assign recovered_data =
        recovered_bram_read_data;


    // ============================================================
    // EXTERNAL RECOVERED DATA VALID
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            recovered_valid <= 1'b0;

        end

        else begin

            recovered_valid <=
                recovered_re && !busy;

        end

    end


    // ============================================================
    // SELECT INPUT BYTE
    //
    // ENCRYPT:
    // Image BRAM -> AES
    //
    // DECRYPT:
    // Cipher BRAM -> AES
    // ============================================================

    wire [7:0] selected_input_byte;

    assign selected_input_byte =
        (mode == MODE_ENCRYPT)
        ? image_bram_read_data
        : cipher_bram_read_data;


    // ============================================================
    // SELECT OUTPUT BYTE FROM 128-BIT AES RESULT
    // ============================================================

    reg [7:0] selected_output_byte;


    always @(*) begin

        case (byte_index)

            4'd0:
                selected_output_byte =
                    output_block[127:120];

            4'd1:
                selected_output_byte =
                    output_block[119:112];

            4'd2:
                selected_output_byte =
                    output_block[111:104];

            4'd3:
                selected_output_byte =
                    output_block[103:96];

            4'd4:
                selected_output_byte =
                    output_block[95:88];

            4'd5:
                selected_output_byte =
                    output_block[87:80];

            4'd6:
                selected_output_byte =
                    output_block[79:72];

            4'd7:
                selected_output_byte =
                    output_block[71:64];

            4'd8:
                selected_output_byte =
                    output_block[63:56];

            4'd9:
                selected_output_byte =
                    output_block[55:48];

            4'd10:
                selected_output_byte =
                    output_block[47:40];

            4'd11:
                selected_output_byte =
                    output_block[39:32];

            4'd12:
                selected_output_byte =
                    output_block[31:24];

            4'd13:
                selected_output_byte =
                    output_block[23:16];

            4'd14:
                selected_output_byte =
                    output_block[15:8];

            4'd15:
                selected_output_byte =
                    output_block[7:0];

            default:
                selected_output_byte =
                    8'h00;

        endcase

    end


    // Encryption writes AES output into cipher BRAM.
    assign cipher_write_data =
        selected_output_byte;


    // Decryption writes AES output into recovered BRAM.
    assign recovered_write_data =
        selected_output_byte;


    // ============================================================
    // AES-128 CTR CORE
    //
    // SAME VERIFIED CORE USED FOR BOTH ENCRYPTION AND DECRYPTION.
    //
    // CTR encryption:
    //
    // C = P XOR AES(Key, Counter)
    //
    // CTR decryption:
    //
    // P = C XOR AES(Key, Counter)
    //
    // Therefore NO inverse AES core is required.
    // ============================================================

    wire [127:0] aes_data_out;
    wire [127:0] aes_counter_out;

    wire aes_busy;
    wire aes_done;


    wire aes_start_signal;

    assign aes_start_signal =
        (state == AES_START);


   aes128_ctr_opt aes_ctr (

        .clk         (clk),
        .reset       (reset),

        .start       (aes_start_signal),

        .data_in     (input_block),

        .key         (key_reg),

        .counter_in  (aes_counter),

        .data_out    (aes_data_out),

        .counter_out (aes_counter_out),

        .busy        (aes_busy),
        .done        (aes_done)

    );


    // ============================================================
    // STATUS
    // ============================================================

    assign busy =
        (state != IDLE) &&
        (state != FINISH);


    assign encrypt_done =
        (state == FINISH) &&
        (mode == MODE_ENCRYPT);


    assign decrypt_done =
        (state == FINISH) &&
        (mode == MODE_DECRYPT);


    // ============================================================
    // MAIN ENCRYPTION / DECRYPTION FSM
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            state <= IDLE;

            mode <= MODE_ENCRYPT;

            block_index <= 8'd0;
            byte_index  <= 4'd0;

            last_block_reg <= 8'd0;

            input_block  <= 128'b0;
            output_block <= 128'b0;

            aes_counter <=
                INITIAL_COUNTER;

        end

        else begin

            case (state)


                // =================================================
                // IDLE
                // =================================================

                IDLE: begin

                    byte_index <= 4'd0;


                    // ---------------------------------------------
                    // START ENCRYPTION
                    // ---------------------------------------------

                    if (start_encrypt) begin

                        mode <= MODE_ENCRYPT;

                        block_index <= 8'd0;

                        byte_index <= 4'd0;

                        last_block_reg <=
                            last_block_addr;

                        aes_counter <=
                            INITIAL_COUNTER;

                        input_block <= 128'b0;

                        state <= READ_REQ;

                    end


                    // ---------------------------------------------
                    // START DECRYPTION
                    // ---------------------------------------------

                    else if (start_decrypt) begin

                        mode <= MODE_DECRYPT;

                        block_index <= 8'd0;

                        byte_index <= 4'd0;

                        last_block_reg <=
                            last_block_addr;

                        // CTR decryption MUST restart from same
                        // initial counter used for encryption.
                        aes_counter <=
                            INITIAL_COUNTER;

                        input_block <= 128'b0;

                        state <= READ_REQ;

                    end

                end


                // =================================================
                // REQUEST BYTE FROM BRAM
                // =================================================

                READ_REQ: begin

                    // BRAM is synchronous.
                    //
                    // Data becomes available for capture
                    // on the following cycle.

                    state <= READ_CAPTURE;

                end


                // =================================================
                // CAPTURE BYTE
                // =================================================

                READ_CAPTURE: begin

                    case (byte_index)

                        4'd0:
                            input_block[127:120]
                                <= selected_input_byte;

                        4'd1:
                            input_block[119:112]
                                <= selected_input_byte;

                        4'd2:
                            input_block[111:104]
                                <= selected_input_byte;

                        4'd3:
                            input_block[103:96]
                                <= selected_input_byte;

                        4'd4:
                            input_block[95:88]
                                <= selected_input_byte;

                        4'd5:
                            input_block[87:80]
                                <= selected_input_byte;

                        4'd6:
                            input_block[79:72]
                                <= selected_input_byte;

                        4'd7:
                            input_block[71:64]
                                <= selected_input_byte;

                        4'd8:
                            input_block[63:56]
                                <= selected_input_byte;

                        4'd9:
                            input_block[55:48]
                                <= selected_input_byte;

                        4'd10:
                            input_block[47:40]
                                <= selected_input_byte;

                        4'd11:
                            input_block[39:32]
                                <= selected_input_byte;

                        4'd12:
                            input_block[31:24]
                                <= selected_input_byte;

                        4'd13:
                            input_block[23:16]
                                <= selected_input_byte;

                        4'd14:
                            input_block[15:8]
                                <= selected_input_byte;

                        4'd15:
                            input_block[7:0]
                                <= selected_input_byte;

                    endcase


                    // ---------------------------------------------
                    // COMPLETE 128-BIT INPUT BLOCK
                    // ---------------------------------------------

                    if (byte_index == 4'd15) begin

                        byte_index <= 4'd0;

                        state <= AES_START;

                    end

                    else begin

                        byte_index <=
                            byte_index + 1'b1;

                        state <= READ_REQ;

                    end

                end


                // =================================================
                // START AES-CTR
                // =================================================

                AES_START: begin

                    // aes_start_signal becomes HIGH for
                    // this state only.

                    state <= AES_WAIT;

                end


                // =================================================
                // WAIT FOR AES-CTR
                // =================================================

                AES_WAIT: begin

                    if (aes_done) begin

                        // Capture encrypted/decrypted block.
                        output_block <=
                            aes_data_out;

                        // Advance CTR for next 128-bit block.
                        aes_counter <=
                            aes_counter_out;

                        byte_index <= 4'd0;

                        state <= WRITE_BYTE;

                    end

                end


                // =================================================
                // WRITE 16 OUTPUT BYTES
                //
                // ENCRYPT:
                // AES output -> Cipher BRAM
                //
                // DECRYPT:
                // AES output -> Recovered BRAM
                // =================================================

                WRITE_BYTE: begin

                    if (byte_index == 4'd15) begin

                        byte_index <= 4'd0;

                        state <= NEXT_BLOCK;

                    end

                    else begin

                        byte_index <=
                            byte_index + 1'b1;

                    end

                end


                // =================================================
                // NEXT AES BLOCK
                // =================================================

                NEXT_BLOCK: begin

                    if (block_index ==
                        last_block_reg) begin

                        state <= FINISH;

                    end

                    else begin

                        block_index <=
                            block_index + 1'b1;

                        byte_index <= 4'd0;

                        input_block <= 128'b0;

                        state <= READ_REQ;

                    end

                end


                // =================================================
                // FINISH
                //
                // encrypt_done or decrypt_done is HIGH for
                // this state.
                // =================================================

                FINISH: begin

                    state <= IDLE;

                end


                // =================================================
                // SAFETY
                // =================================================

                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end


endmodule