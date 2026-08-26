`timescale 1ns / 1ps

module aes_image_multiblock (

    input  wire         clk,
    input  wire         reset,
    input  wire         start,

    input  wire [127:0] key,

    // ============================================================
    // ENCRYPTED OUTPUT BLOCKS
    // ============================================================

    output reg [127:0] encrypted_block0,
    output reg [127:0] encrypted_block1,
    output reg [127:0] encrypted_block2,
    output reg [127:0] encrypted_block3,

    // ============================================================
    // STATUS
    // ============================================================

    output reg         busy,
    output reg         done

);


    // ============================================================
    // TEST IMAGE
    //
    // 4 x 128-bit blocks = 512 bits
    //
    // Block 0:
    // 10 11 12 13 14 15 16 17
    // 18 19 1A 1B 1C 1D 1E 1F
    //
    // Block 1:
    // 20 21 22 23 24 25 26 27
    // 28 29 2A 2B 2C 2D 2E 2F
    //
    // Block 2:
    // 30 31 32 33 34 35 36 37
    // 38 39 3A 3B 3C 3D 3E 3F
    //
    // Block 3:
    // 40 41 42 43 44 45 46 47
    // 48 49 4A 4B 4C 4D 4E 4F
    //
    // ============================================================

    reg [127:0] image_mem [0:3];


    // ============================================================
    // INITIAL IMAGE
    // ============================================================

    initial begin

        image_mem[0] =
            128'h101112131415161718191A1B1C1D1E1F;

        image_mem[1] =
            128'h202122232425262728292A2B2C2D2E2F;

        image_mem[2] =
            128'h303132333435363738393A3B3C3D3E3F;

        image_mem[3] =
            128'h404142434445464748494A4B4C4D4E4F;

    end


    // ============================================================
    // AES-CTR SIGNALS
    // ============================================================

    reg         aes_start;

    reg [127:0] aes_data_in;
    reg [127:0] aes_counter;

    wire [127:0] aes_data_out;
    wire [127:0] aes_counter_out;

    wire         aes_busy;
    wire         aes_done;


    // ============================================================
    // AES-CTR CORE
    // ============================================================

    aes128_ctr aes_ctr (

        .clk         (clk),
        .reset       (reset),

        .start       (aes_start),

        .data_in     (aes_data_in),

        .key         (key),

        .counter_in  (aes_counter),

        .data_out    (aes_data_out),

        .counter_out (aes_counter_out),

        .busy        (aes_busy),

        .done        (aes_done)

    );


    // ============================================================
    // INITIAL COUNTER
    //
    // IMPORTANT:
    //
    // Block 0 = ...FEFF
    // Block 1 = ...FF00
    // Block 2 = ...FF01
    // Block 3 = ...FF02
    //
    // ============================================================

    localparam [127:0] INITIAL_COUNTER =
        128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF;


    // ============================================================
    // FSM
    // ============================================================

    localparam IDLE       = 3'd0;
    localparam LOAD       = 3'd1;
    localparam START_AES  = 3'd2;
    localparam WAIT_AES   = 3'd3;
    localparam STORE      = 3'd4;
    localparam FINISH     = 3'd5;

    reg [2:0] state;


    // ============================================================
    // BLOCK INDEX
    //
    // 0 = block 0
    // 1 = block 1
    // 2 = block 2
    // 3 = block 3
    //
    // ============================================================

    reg [1:0] block_index;


    // ============================================================
    // MAIN CONTROLLER
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            state <= IDLE;

            block_index <= 2'd0;

            aes_start   <= 1'b0;
            aes_data_in <= 128'b0;
            aes_counter <= INITIAL_COUNTER;

            encrypted_block0 <= 128'b0;
            encrypted_block1 <= 128'b0;
            encrypted_block2 <= 128'b0;
            encrypted_block3 <= 128'b0;

            busy <= 1'b0;
            done <= 1'b0;

        end

        else begin

            // ----------------------------------------------------
            // Pulse signals
            // ----------------------------------------------------

            aes_start <= 1'b0;
            done      <= 1'b0;


            case (state)


                // =================================================
                // IDLE
                // =================================================

                IDLE: begin

                    busy <= 1'b0;

                    if (start) begin

                        busy <= 1'b1;

                        block_index <= 2'd0;

                        aes_counter <= INITIAL_COUNTER;

                        state <= LOAD;

                    end

                end


                // =================================================
                // LOAD CURRENT BLOCK
                // =================================================

                LOAD: begin

                    busy <= 1'b1;

                    // Select current image block

                    case (block_index)

                        2'd0:
                            aes_data_in <= image_mem[0];

                        2'd1:
                            aes_data_in <= image_mem[1];

                        2'd2:
                            aes_data_in <= image_mem[2];

                        2'd3:
                            aes_data_in <= image_mem[3];

                        default:
                            aes_data_in <= 128'b0;

                    endcase

                    state <= START_AES;

                end


                // =================================================
                // START AES
                // =================================================

                START_AES: begin

                    busy <= 1'b1;

                    aes_start <= 1'b1;

                    state <= WAIT_AES;

                end


                // =================================================
                // WAIT FOR AES
                // =================================================

                WAIT_AES: begin

                    busy <= 1'b1;

                    if (aes_done) begin

                        state <= STORE;

                    end

                end


                // =================================================
                // STORE ENCRYPTED BLOCK
                // =================================================

                STORE: begin

                    busy <= 1'b1;

                    case (block_index)

                        2'd0:
                            encrypted_block0 <= aes_data_out;

                        2'd1:
                            encrypted_block1 <= aes_data_out;

                        2'd2:
                            encrypted_block2 <= aes_data_out;

                        2'd3:
                            encrypted_block3 <= aes_data_out;

                        default:
                            ;

                    endcase


                    // Counter returned by AES-CTR
                    // becomes counter for next block.

                    aes_counter <= aes_counter_out;


                    // ------------------------------------------------
                    // Check whether this was the last block
                    // ------------------------------------------------

                    if (block_index == 2'd3) begin

                        state <= FINISH;

                    end

                    else begin

                        block_index <= block_index + 2'd1;

                        state <= LOAD;

                    end

                end


                // =================================================
                // FINISH
                // =================================================

                FINISH: begin

                    busy <= 1'b0;

                    done <= 1'b1;

                    state <= IDLE;

                end


                // =================================================
                // DEFAULT
                // =================================================

                default: begin

                    state <= IDLE;

                    busy <= 1'b0;

                end

            endcase

        end

    end

endmodule