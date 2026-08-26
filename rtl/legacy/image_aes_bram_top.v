`timescale 1ns / 1ps

module image_aes_bram_top (

    input  wire        clk,
    input  wire        reset,
    input  wire        start,

    // ============================================================
    // AES KEY BYTE-WISE LOADING INTERFACE
    // ============================================================

    input  wire        key_we,
    input  wire [3:0]  key_addr,
    input  wire [7:0]  key_data,


    // ============================================================
    // IMAGE BRAM WRITE INTERFACE
    //
    // Allows image pixels to be written one byte at a time.
    // image_addr = 0 ... 4095
    // ============================================================

    input  wire        image_we,
    input  wire [11:0] image_addr,
    input  wire [7:0]  image_data,


    // ============================================================
    // NUMBER OF BLOCKS
    //
    // Encryption processes block address:
    //
    // 0 ... last_block_addr
    //
    // Example:
    // last_block_addr = 1
    // -> process 2 AES blocks
    // -> 32 image bytes
    // ============================================================

    input  wire [7:0]  last_block_addr,


    // ============================================================
    // CIPHERTEXT BRAM READ INTERFACE
    // ============================================================

    input  wire        cipher_re,
    input  wire [11:0] cipher_addr,

    output wire [7:0]  cipher_data,
    output reg         cipher_valid,


    // ============================================================
    // STATUS
    // ============================================================

    output wire        busy,
    output wire        done

);


    // ============================================================
    // AES KEY REGISTER
    // ============================================================

    reg [127:0] key_reg;


    // ============================================================
    // KEY BYTE LOADER
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            key_reg <=
                128'h2B7E151628AED2A6ABF7158809CF4F3C;

        end

        else if (key_we && !busy) begin

            case (key_addr)

                4'd0:  key_reg[127:120] <= key_data;
                4'd1:  key_reg[119:112] <= key_data;
                4'd2:  key_reg[111:104] <= key_data;
                4'd3:  key_reg[103:96]  <= key_data;

                4'd4:  key_reg[95:88]   <= key_data;
                4'd5:  key_reg[87:80]   <= key_data;
                4'd6:  key_reg[79:72]   <= key_data;
                4'd7:  key_reg[71:64]   <= key_data;

                4'd8:  key_reg[63:56]   <= key_data;
                4'd9:  key_reg[55:48]   <= key_data;
                4'd10: key_reg[47:40]   <= key_data;
                4'd11: key_reg[39:32]   <= key_data;

                4'd12: key_reg[31:24]   <= key_data;
                4'd13: key_reg[23:16]   <= key_data;
                4'd14: key_reg[15:8]    <= key_data;
                4'd15: key_reg[7:0]     <= key_data;

            endcase

        end

    end


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
    // BLOCK CONTROL
    // ============================================================

    reg [7:0] block_index;
    reg [7:0] last_block_reg;

    reg [3:0] byte_index;


    // ============================================================
    // 128-BIT PLAINTEXT BLOCK
    // ============================================================

    reg [127:0] plaintext_block;


    // ============================================================
    // 128-BIT CIPHERTEXT REGISTER
    // ============================================================

    reg [127:0] ciphertext_block;


    // ============================================================
    // INITIAL CTR VALUE
    // ============================================================

    localparam [127:0] INITIAL_COUNTER =
        128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF;

    reg [127:0] aes_counter;


    // ============================================================
    // IMAGE BRAM
    // ============================================================

    wire [11:0] image_read_addr;

    wire        image_read_enable;

    wire [7:0]  image_bram_data;


    assign image_read_addr =
        {block_index, byte_index};

    assign image_read_enable =
        (state == READ_REQ);


    // Don't permit host writes while encryption is active
    wire image_write_enable;

    assign image_write_enable =
        image_we && !busy;


    bram_8x4096 image_bram (

        .clk   (clk),

        .we    (image_write_enable),
        .waddr (image_addr),
        .wdata (image_data),

        .re    (image_read_enable),
        .raddr (image_read_addr),
        .rdata (image_bram_data)

    );


    // ============================================================
    // CIPHERTEXT BRAM
    // ============================================================

    wire        cipher_write_enable;
    wire [11:0] cipher_write_addr;
    reg  [7:0]  cipher_write_data;

    wire [7:0] cipher_bram_read_data;


    assign cipher_write_enable =
        (state == WRITE_BYTE);

    assign cipher_write_addr =
        {block_index, byte_index};


    bram_8x4096 cipher_bram (

        .clk   (clk),

        .we    (cipher_write_enable),
        .waddr (cipher_write_addr),
        .wdata (cipher_write_data),

        .re    (cipher_re),
        .raddr (cipher_addr),
        .rdata (cipher_bram_read_data)

    );


    assign cipher_data =
        cipher_bram_read_data;


    // ============================================================
    // CIPHERTEXT READ VALID
    // ============================================================

    always @(posedge clk) begin

        if (reset)
            cipher_valid <= 1'b0;

        else
            cipher_valid <= cipher_re;

    end


    // ============================================================
    // CIPHERTEXT BYTE SELECTION
    // ============================================================

    always @(*) begin

        case (byte_index)

            4'd0:
                cipher_write_data =
                    ciphertext_block[127:120];

            4'd1:
                cipher_write_data =
                    ciphertext_block[119:112];

            4'd2:
                cipher_write_data =
                    ciphertext_block[111:104];

            4'd3:
                cipher_write_data =
                    ciphertext_block[103:96];

            4'd4:
                cipher_write_data =
                    ciphertext_block[95:88];

            4'd5:
                cipher_write_data =
                    ciphertext_block[87:80];

            4'd6:
                cipher_write_data =
                    ciphertext_block[79:72];

            4'd7:
                cipher_write_data =
                    ciphertext_block[71:64];

            4'd8:
                cipher_write_data =
                    ciphertext_block[63:56];

            4'd9:
                cipher_write_data =
                    ciphertext_block[55:48];

            4'd10:
                cipher_write_data =
                    ciphertext_block[47:40];

            4'd11:
                cipher_write_data =
                    ciphertext_block[39:32];

            4'd12:
                cipher_write_data =
                    ciphertext_block[31:24];

            4'd13:
                cipher_write_data =
                    ciphertext_block[23:16];

            4'd14:
                cipher_write_data =
                    ciphertext_block[15:8];

            4'd15:
                cipher_write_data =
                    ciphertext_block[7:0];

            default:
                cipher_write_data = 8'h00;

        endcase

    end


    // ============================================================
    // AES-128 CTR CORE
    //
    // This is your EXISTING NIST-VERIFIED core.
    // No modification required.
    // ============================================================

    wire [127:0] aes_data_out;
    wire [127:0] aes_counter_out;

    wire aes_busy;
    wire aes_done;


    wire aes_start_signal;

    assign aes_start_signal =
        (state == AES_START);


    aes128_ctr aes_ctr (

        .clk         (clk),
        .reset       (reset),

        .start       (aes_start_signal),

        .data_in     (plaintext_block),

        .key         (key_reg),

        .counter_in  (aes_counter),

        .data_out    (aes_data_out),

        .counter_out (aes_counter_out),

        .busy        (aes_busy),
        .done        (aes_done)

    );


    // ============================================================
    // STATUS SIGNALS
    // ============================================================

    assign busy =
        (state != IDLE) &&
        (state != FINISH);

    assign done =
        (state == FINISH);


    // ============================================================
    // MAIN CONTROL FSM
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            state <= IDLE;

            block_index <= 8'd0;
            byte_index  <= 4'd0;

            last_block_reg <= 8'd0;

            plaintext_block <= 128'b0;
            ciphertext_block <= 128'b0;

            aes_counter <= INITIAL_COUNTER;

        end

        else begin

            case (state)


                // =================================================
                // IDLE
                // =================================================

                IDLE: begin

                    byte_index <= 4'd0;

                    if (start) begin

                        block_index <= 8'd0;

                        last_block_reg <=
                            last_block_addr;

                        aes_counter <=
                            INITIAL_COUNTER;

                        state <= READ_REQ;

                    end

                end


                // =================================================
                // REQUEST BYTE FROM IMAGE BRAM
                // =================================================

                READ_REQ: begin

                    state <= READ_CAPTURE;

                end


                // =================================================
                // CAPTURE BYTE FROM IMAGE BRAM
                // =================================================

                READ_CAPTURE: begin

                    case (byte_index)

                        4'd0:
                            plaintext_block[127:120]
                                <= image_bram_data;

                        4'd1:
                            plaintext_block[119:112]
                                <= image_bram_data;

                        4'd2:
                            plaintext_block[111:104]
                                <= image_bram_data;

                        4'd3:
                            plaintext_block[103:96]
                                <= image_bram_data;

                        4'd4:
                            plaintext_block[95:88]
                                <= image_bram_data;

                        4'd5:
                            plaintext_block[87:80]
                                <= image_bram_data;

                        4'd6:
                            plaintext_block[79:72]
                                <= image_bram_data;

                        4'd7:
                            plaintext_block[71:64]
                                <= image_bram_data;

                        4'd8:
                            plaintext_block[63:56]
                                <= image_bram_data;

                        4'd9:
                            plaintext_block[55:48]
                                <= image_bram_data;

                        4'd10:
                            plaintext_block[47:40]
                                <= image_bram_data;

                        4'd11:
                            plaintext_block[39:32]
                                <= image_bram_data;

                        4'd12:
                            plaintext_block[31:24]
                                <= image_bram_data;

                        4'd13:
                            plaintext_block[23:16]
                                <= image_bram_data;

                        4'd14:
                            plaintext_block[15:8]
                                <= image_bram_data;

                        4'd15:
                            plaintext_block[7:0]
                                <= image_bram_data;

                    endcase


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
                // START AES
                // =================================================

                AES_START: begin

                    state <= AES_WAIT;

                end


                // =================================================
                // WAIT FOR AES
                // =================================================

                AES_WAIT: begin

                    if (aes_done) begin

                        ciphertext_block <=
                            aes_data_out;

                        aes_counter <=
                            aes_counter_out;

                        byte_index <= 4'd0;

                        state <= WRITE_BYTE;

                    end

                end


                // =================================================
                // WRITE 16 CIPHERTEXT BYTES INTO BRAM
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

                        state <= READ_REQ;

                    end

                end


                // =================================================
                // COMPLETE
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