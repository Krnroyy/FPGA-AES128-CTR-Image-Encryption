`timescale 1ns / 1ps

module image_aes_fpga_top (

    input  wire        clk,
    input  wire        reset,
    input  wire        start,

    // ============================================================
    // SMALL RUNTIME KEY INTERFACE
    //
    // Load AES key one byte at a time.
    // key_addr = 0 -> key[127:120]
    // key_addr = 15 -> key[7:0]
    // ============================================================
    input  wire        key_we,
    input  wire [3:0]  key_addr,
    input  wire [7:0]  key_data,

    // ============================================================
    // CIPHERTEXT READ INTERFACE
    //
    // read_addr = 0..15  -> encrypted block 0
    // read_addr = 16..31 -> encrypted block 1
    // ============================================================
    input  wire [4:0]  read_addr,
    output reg  [7:0]  cipher_byte,

    // Status
    output wire        busy,
    output wire        done

);


    // ============================================================
    // AES-128 KEY REGISTER
    //
    // Reset value is our existing NIST key.
    // Unlike the previous localparam, this key can now be changed
    // at run time. Therefore Vivado cannot pre-compute AES.
    // ============================================================

    reg [127:0] key_reg;


    always @(posedge clk) begin

        if (reset) begin

            key_reg <= 128'h2B7E151628AED2A6ABF7158809CF4F3C;

        end

        else if (key_we) begin

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

                default: key_reg <= key_reg;

            endcase

        end

    end


    // ============================================================
    // INTERNAL ENCRYPTED BLOCKS
    // ============================================================

    wire [127:0] encrypted_block0;
    wire [127:0] encrypted_block1;


    // ============================================================
    // DEBUG CONNECTIONS
    //
    // Remain internal. They are NOT FPGA I/O pins.
    // ============================================================

    wire [127:0] debug_image_block;
    wire [127:0] debug_aes_data_in;
    wire [127:0] debug_aes_counter;
    wire [127:0] debug_aes_data_out;


    // ============================================================
    // EXISTING VERIFIED IMAGE AES-CTR DESIGN
    //
    // IMPORTANT:
    // image_aes_ctr and aes128_ctr are NOT modified.
    // ============================================================

    image_aes_ctr image_encryptor (

        .clk                (clk),
        .reset              (reset),
        .start              (start),

        .key                (key_reg),

        .encrypted_block0   (encrypted_block0),
        .encrypted_block1   (encrypted_block1),

        .busy               (busy),
        .done               (done),

        .debug_image_block  (debug_image_block),
        .debug_aes_data_in  (debug_aes_data_in),
        .debug_aes_counter  (debug_aes_counter),
        .debug_aes_data_out (debug_aes_data_out)

    );


    // ============================================================
    // 8-BIT CIPHERTEXT READ MUX
    //
    // Because read_addr is a runtime input, every ciphertext byte
    // is externally observable. Vivado cannot simply delete the
    // complete encrypted result.
    // ============================================================

    always @(*) begin

        case (read_addr)

            // ----------------------------------------------------
            // ENCRYPTED BLOCK 0
            // ----------------------------------------------------

            5'd0:  cipher_byte = encrypted_block0[127:120];
            5'd1:  cipher_byte = encrypted_block0[119:112];
            5'd2:  cipher_byte = encrypted_block0[111:104];
            5'd3:  cipher_byte = encrypted_block0[103:96];

            5'd4:  cipher_byte = encrypted_block0[95:88];
            5'd5:  cipher_byte = encrypted_block0[87:80];
            5'd6:  cipher_byte = encrypted_block0[79:72];
            5'd7:  cipher_byte = encrypted_block0[71:64];

            5'd8:  cipher_byte = encrypted_block0[63:56];
            5'd9:  cipher_byte = encrypted_block0[55:48];
            5'd10: cipher_byte = encrypted_block0[47:40];
            5'd11: cipher_byte = encrypted_block0[39:32];

            5'd12: cipher_byte = encrypted_block0[31:24];
            5'd13: cipher_byte = encrypted_block0[23:16];
            5'd14: cipher_byte = encrypted_block0[15:8];
            5'd15: cipher_byte = encrypted_block0[7:0];


            // ----------------------------------------------------
            // ENCRYPTED BLOCK 1
            // ----------------------------------------------------

            5'd16: cipher_byte = encrypted_block1[127:120];
            5'd17: cipher_byte = encrypted_block1[119:112];
            5'd18: cipher_byte = encrypted_block1[111:104];
            5'd19: cipher_byte = encrypted_block1[103:96];

            5'd20: cipher_byte = encrypted_block1[95:88];
            5'd21: cipher_byte = encrypted_block1[87:80];
            5'd22: cipher_byte = encrypted_block1[79:72];
            5'd23: cipher_byte = encrypted_block1[71:64];

            5'd24: cipher_byte = encrypted_block1[63:56];
            5'd25: cipher_byte = encrypted_block1[55:48];
            5'd26: cipher_byte = encrypted_block1[47:40];
            5'd27: cipher_byte = encrypted_block1[39:32];

            5'd28: cipher_byte = encrypted_block1[31:24];
            5'd29: cipher_byte = encrypted_block1[23:16];
            5'd30: cipher_byte = encrypted_block1[15:8];
            5'd31: cipher_byte = encrypted_block1[7:0];

            default: cipher_byte = 8'h00;

        endcase

    end


endmodule