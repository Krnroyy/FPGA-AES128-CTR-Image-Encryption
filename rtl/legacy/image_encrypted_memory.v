`timescale 1ns / 1ps

module image_encrypted_memory (

    input  wire         clk,
    input  wire         reset,
    input  wire         start,

    input  wire [127:0] key,

    // ============================================================
    // ENCRYPTED MEMORY READ INTERFACE
    // ============================================================

    input  wire [1:0]   read_addr,
    output reg  [127:0] read_data,

    // ============================================================
    // STATUS
    // ============================================================

    output reg          busy,
    output reg          done

);


    // ============================================================
    // IMAGE MEMORY
    //
    // Four 128-bit image blocks
    //
    // Total:
    // 4 x 128 = 512 bits
    //
    // ============================================================

    reg [127:0] image_mem [0:3];


    // ============================================================
    // ENCRYPTED IMAGE MEMORY
    //
    // Ciphertext is stored here after AES-CTR encryption.
    //
    // ============================================================

    reg [127:0] encrypted_mem [0:3];


    // ============================================================
    // TEST IMAGE
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
    // AES-128 CTR
    //
    // This is our previously verified module.
    // DO NOT MODIFY aes128_ctr.
    //
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
    // INITIAL CTR VALUE
    // ============================================================

    localparam [127:0] INITIAL_COUNTER =
        128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF;


    // ============================================================
    // FSM
    // ============================================================

    localparam IDLE      = 3'd0;
    localparam LOAD      = 3'd1;
    localparam START_AES = 3'd2;
    localparam WAIT_AES  = 3'd3;
    localparam STORE     = 3'd4;
    localparam FINISH    = 3'd5;

    reg [2:0] state;


    // ============================================================
    // CURRENT BLOCK INDEX
    // ============================================================

    reg [1:0] block_index;


    // ============================================================
    // MEMORY READ
    //
    // The encrypted memory can be read using read_addr.
    //
    // read_addr:
    //
    // 00 → encrypted block 0
    // 01 → encrypted block 1
    // 10 → encrypted block 2
    // 11 → encrypted block 3
    //
    // ============================================================

    always @(*) begin

        case (read_addr)

            2'd0:
                read_data = encrypted_mem[0];

            2'd1:
                read_data = encrypted_mem[1];

            2'd2:
                read_data = encrypted_mem[2];

            2'd3:
                read_data = encrypted_mem[3];

            default:
                read_data = 128'b0;

        endcase

    end


    // ============================================================
    // MAIN ENCRYPTION CONTROLLER
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            state <= IDLE;

            block_index <= 2'd0;

            aes_start   <= 1'b0;
            aes_data_in <= 128'b0;
            aes_counter <= INITIAL_COUNTER;

            encrypted_mem[0] <= 128'b0;
            encrypted_mem[1] <= 128'b0;
            encrypted_mem[2] <= 128'b0;
            encrypted_mem[3] <= 128'b0;

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

                        // Start from block 0

                        block_index <= 2'd0;

                        // Initial CTR value

                        aes_counter <= INITIAL_COUNTER;

                        state <= LOAD;

                    end

                end


                // =================================================
                // LOAD IMAGE BLOCK
                // =================================================

                LOAD: begin

                    busy <= 1'b1;

                    // Read the selected image block

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
                // STORE CIPHERTEXT
                // =================================================

                STORE: begin

                    busy <= 1'b1;

                    // Store encrypted result into memory

                    case (block_index)

                        2'd0:
                            encrypted_mem[0] <= aes_data_out;

                        2'd1:
                            encrypted_mem[1] <= aes_data_out;

                        2'd2:
                            encrypted_mem[2] <= aes_data_out;

                        2'd3:
                            encrypted_mem[3] <= aes_data_out;

                        default:
                            ;

                    endcase


                    // Counter for next block

                    aes_counter <= aes_counter_out;


                    // ------------------------------------------------
                    // Check whether this is the final block
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