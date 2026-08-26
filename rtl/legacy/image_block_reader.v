`timescale 1ns / 1ps

module image_block_reader (

    input  wire         clk,
    input  wire         reset,

    // Select image block
    // 0 = first 16 pixels
    // 1 = second 16 pixels
    input  wire         block_select,

    // Indicates that block_out is valid
    output reg          block_valid,

    // 128-bit image block
    output reg [127:0]  block_out

);

    // ============================================================
    // IMAGE MEMORY
    //
    // 32 grayscale pixels
    // 8 bits per pixel
    // Total = 256 bits = two AES-128 blocks
    // ============================================================

    reg [7:0] image_mem [0:31];


    // ============================================================
    // TEST IMAGE
    //
    // 4 x 8 grayscale image
    //
    // 10 11 12 13 14 15 16 17
    // 18 19 1A 1B 1C 1D 1E 1F
    // 20 21 22 23 24 25 26 27
    // 28 29 2A 2B 2C 2D 2E 2F
    // ============================================================

    initial begin

        image_mem[0]  = 8'h10;
        image_mem[1]  = 8'h11;
        image_mem[2]  = 8'h12;
        image_mem[3]  = 8'h13;
        image_mem[4]  = 8'h14;
        image_mem[5]  = 8'h15;
        image_mem[6]  = 8'h16;
        image_mem[7]  = 8'h17;

        image_mem[8]  = 8'h18;
        image_mem[9]  = 8'h19;
        image_mem[10] = 8'h1A;
        image_mem[11] = 8'h1B;
        image_mem[12] = 8'h1C;
        image_mem[13] = 8'h1D;
        image_mem[14] = 8'h1E;
        image_mem[15] = 8'h1F;

        image_mem[16] = 8'h20;
        image_mem[17] = 8'h21;
        image_mem[18] = 8'h22;
        image_mem[19] = 8'h23;
        image_mem[20] = 8'h24;
        image_mem[21] = 8'h25;
        image_mem[22] = 8'h26;
        image_mem[23] = 8'h27;

        image_mem[24] = 8'h28;
        image_mem[25] = 8'h29;
        image_mem[26] = 8'h2A;
        image_mem[27] = 8'h2B;
        image_mem[28] = 8'h2C;
        image_mem[29] = 8'h2D;
        image_mem[30] = 8'h2E;
        image_mem[31] = 8'h2F;

    end


    // ============================================================
    // IMAGE BLOCK READER
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            block_out   <= 128'b0;
            block_valid <= 1'b0;

        end

        else begin

            // Default
            block_valid <= 1'b0;

            // ----------------------------------------------------
            // BLOCK 0
            // ----------------------------------------------------

            if (block_select == 1'b0) begin

                block_out <= {
                    image_mem[0],
                    image_mem[1],
                    image_mem[2],
                    image_mem[3],
                    image_mem[4],
                    image_mem[5],
                    image_mem[6],
                    image_mem[7],
                    image_mem[8],
                    image_mem[9],
                    image_mem[10],
                    image_mem[11],
                    image_mem[12],
                    image_mem[13],
                    image_mem[14],
                    image_mem[15]
                };

                block_valid <= 1'b1;

            end

            // ----------------------------------------------------
            // BLOCK 1
            // ----------------------------------------------------

            else begin

                block_out <= {
                    image_mem[16],
                    image_mem[17],
                    image_mem[18],
                    image_mem[19],
                    image_mem[20],
                    image_mem[21],
                    image_mem[22],
                    image_mem[23],
                    image_mem[24],
                    image_mem[25],
                    image_mem[26],
                    image_mem[27],
                    image_mem[28],
                    image_mem[29],
                    image_mem[30],
                    image_mem[31]
                };

                block_valid <= 1'b1;

            end

        end

    end

endmodule