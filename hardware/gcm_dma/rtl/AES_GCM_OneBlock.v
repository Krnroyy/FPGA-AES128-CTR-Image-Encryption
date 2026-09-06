`timescale 1ns / 1ps

// One-block AES-128 GCM validation core with no AAD and a 96-bit IV.
// This module establishes NIST encryption, decryption, and tag-rejection
// correctness before the authenticated engine is connected to AXI DMA.
module AES_GCM_OneBlock
(
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire         decrypt,
    input  wire [127:0] key,
    input  wire [95:0]  iv,
    input  wire [127:0] data_in,
    input  wire [127:0] expected_tag,
    output reg  [127:0] data_out,
    output reg  [127:0] tag_out,
    output reg          tag_valid,
    output reg          auth_ok,
    output reg          busy,
    output reg          done
);

localparam [3:0] STATE_IDLE              = 4'd0;
localparam [3:0] STATE_ISSUE_H           = 4'd1;
localparam [3:0] STATE_ISSUE_TAG_MASK    = 4'd2;
localparam [3:0] STATE_ISSUE_KEYSTREAM   = 4'd3;
localparam [3:0] STATE_WAIT_AES          = 4'd4;
localparam [3:0] STATE_WAIT_GHASH_DATA   = 4'd5;
localparam [3:0] STATE_WAIT_GHASH_LENGTH = 4'd6;

localparam [127:0] LENGTH_BLOCK = {64'd0, 64'd128};

reg [3:0] state;
reg decrypt_reg;
reg [95:0] iv_reg;
reg [127:0] data_reg;
reg [127:0] expected_tag_reg;
reg [1:0] aes_response_count;
reg [127:0] hash_subkey;
reg [127:0] tag_mask;

wire [1407:0] round_keys;
reg [127:0] aes_plaintext;
reg aes_data_valid;
wire [127:0] aes_ciphertext;
wire aes_cipher_valid;

reg [127:0] ghash_x;
reg [127:0] ghash_h;
reg ghash_start;
wire [127:0] ghash_result;
wire ghash_busy;
wire ghash_done;

wire [127:0] payload_result = data_reg ^ aes_ciphertext;
wire [127:0] authenticated_block = decrypt_reg ? data_reg : payload_result;
wire [127:0] completed_tag = tag_mask ^ ghash_result;

KeyExpansion u_key_expansion
(
    .key(key),
    .round_keys(round_keys)
);

AES_128_Core u_aes
(
    .clk(clk),
    .rst(rst),
    .data_valid(aes_data_valid),
    .round_keys(round_keys),
    .plaintext(aes_plaintext),
    .ciphertext(aes_ciphertext),
    .cipher_valid(aes_cipher_valid)
);

GHASH_Mult32 u_ghash_multiplier
(
    .clk(clk),
    .rst(rst),
    .start(ghash_start),
    .x(ghash_x),
    .h(ghash_h),
    .result(ghash_result),
    .busy(ghash_busy),
    .done(ghash_done)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state <= STATE_IDLE;
        decrypt_reg <= 1'b0;
        iv_reg <= 96'd0;
        data_reg <= 128'd0;
        expected_tag_reg <= 128'd0;
        aes_response_count <= 2'd0;
        hash_subkey <= 128'd0;
        tag_mask <= 128'd0;
        aes_plaintext <= 128'd0;
        aes_data_valid <= 1'b0;
        ghash_x <= 128'd0;
        ghash_h <= 128'd0;
        ghash_start <= 1'b0;
        data_out <= 128'd0;
        tag_out <= 128'd0;
        tag_valid <= 1'b0;
        auth_ok <= 1'b0;
        busy <= 1'b0;
        done <= 1'b0;
    end
    else
    begin
        aes_data_valid <= 1'b0;
        ghash_start <= 1'b0;
        done <= 1'b0;

        case(state)
            STATE_IDLE:
            begin
                if(start)
                begin
                    decrypt_reg <= decrypt;
                    iv_reg <= iv;
                    data_reg <= data_in;
                    expected_tag_reg <= expected_tag;
                    aes_response_count <= 2'd0;
                    hash_subkey <= 128'd0;
                    tag_mask <= 128'd0;
                    data_out <= 128'd0;
                    tag_out <= 128'd0;
                    tag_valid <= 1'b0;
                    auth_ok <= 1'b0;
                    busy <= 1'b1;
                    state <= STATE_ISSUE_H;
                end
            end

            STATE_ISSUE_H:
            begin
                aes_plaintext <= 128'd0;
                aes_data_valid <= 1'b1;
                state <= STATE_ISSUE_TAG_MASK;
            end

            STATE_ISSUE_TAG_MASK:
            begin
                aes_plaintext <= {iv_reg, 32'h00000001};
                aes_data_valid <= 1'b1;
                state <= STATE_ISSUE_KEYSTREAM;
            end

            STATE_ISSUE_KEYSTREAM:
            begin
                aes_plaintext <= {iv_reg, 32'h00000002};
                aes_data_valid <= 1'b1;
                state <= STATE_WAIT_AES;
            end

            STATE_WAIT_AES:
            begin
                if(aes_cipher_valid)
                begin
                    case(aes_response_count)
                        2'd0:
                        begin
                            hash_subkey <= aes_ciphertext;
                            aes_response_count <= 2'd1;
                        end
                        2'd1:
                        begin
                            tag_mask <= aes_ciphertext;
                            aes_response_count <= 2'd2;
                        end
                        default:
                        begin
                            data_out <= payload_result;
                            ghash_x <= authenticated_block;
                            ghash_h <= hash_subkey;
                            ghash_start <= 1'b1;
                            state <= STATE_WAIT_GHASH_DATA;
                        end
                    endcase
                end
            end

            STATE_WAIT_GHASH_DATA:
            begin
                if(ghash_done)
                begin
                    ghash_x <= ghash_result ^ LENGTH_BLOCK;
                    ghash_h <= hash_subkey;
                    ghash_start <= 1'b1;
                    state <= STATE_WAIT_GHASH_LENGTH;
                end
            end

            STATE_WAIT_GHASH_LENGTH:
            begin
                if(ghash_done)
                begin
                    tag_out <= completed_tag;
                    tag_valid <= 1'b1;
                    if(decrypt_reg)
                        auth_ok <= (completed_tag == expected_tag_reg);
                    else
                        auth_ok <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= STATE_IDLE;
                end
            end

            default:
                state <= STATE_IDLE;
        endcase
    end
end

wire unused_ghash_busy = ghash_busy;

endmodule
