`timescale 1ns / 1ps

module image_aes_ctr (

    input  wire         clk,
    input  wire         reset,
    input  wire         start,

    // AES-128 key
    input  wire [127:0] key,

    // Encrypted image blocks
    output reg  [127:0] encrypted_block0,
    output reg  [127:0] encrypted_block1,

    // Status
    output reg          busy,
    output reg          done,

    // ============================================================
    // DEBUG OUTPUTS
    //
    // These are exposed as module outputs so that we can verify
    // the internal datapath directly in the waveform.
    // ============================================================

    output wire [127:0] debug_image_block,
    output wire [127:0] debug_aes_data_in,
    output wire [127:0] debug_aes_counter,
    output wire [127:0] debug_aes_data_out

);


    // ============================================================
    // IMAGE BLOCK READER
    // ============================================================

    reg          block_select;

    wire         block_valid;
    wire [127:0] image_block;


    image_block_reader image_reader (

        .clk          (clk),
        .reset        (reset),

        .block_select (block_select),

        .block_valid  (block_valid),
        .block_out    (image_block)

    );


    // ============================================================
    // AES-128 CTR SIGNALS
    // ============================================================

    reg          aes_start;

    reg [127:0]  aes_data_in;
    reg [127:0]  aes_counter;

    wire [127:0] aes_data_out;
    wire [127:0] aes_counter_out;

    wire         aes_busy;
    wire         aes_done;


    // ============================================================
    // AES-128 CTR CORE
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
    // DEBUG CONNECTIONS
    // ============================================================

    assign debug_image_block = image_block;

    assign debug_aes_data_in = aes_data_in;

    assign debug_aes_counter = aes_counter;

    assign debug_aes_data_out = aes_data_out;


    // ============================================================
    // FSM STATES
    // ============================================================

    localparam IDLE        = 3'd0;
    localparam READ_BLOCK  = 3'd1;
    localparam WAIT_BLOCK  = 3'd2;
    localparam START_AES   = 3'd3;
    localparam WAIT_AES    = 3'd4;
    localparam NEXT_BLOCK  = 3'd5;
    localparam FINISH      = 3'd6;

    reg [2:0] state;


    // ============================================================
    // INITIAL CTR VALUE
    // ============================================================

    localparam [127:0] INITIAL_COUNTER =
        128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF;


    // ============================================================
    // MAIN FSM
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            // ----------------------------------------------------
            // RESET
            // ----------------------------------------------------

            state <= IDLE;

            block_select <= 1'b0;

            aes_start    <= 1'b0;

            aes_data_in  <= 128'b0;

            aes_counter  <= INITIAL_COUNTER;

            encrypted_block0 <= 128'b0;

            encrypted_block1 <= 128'b0;

            busy <= 1'b0;

            done <= 1'b0;

        end

        else begin

            // ----------------------------------------------------
            // DEFAULT PULSE SIGNALS
            // ----------------------------------------------------

            aes_start <= 1'b0;

            done <= 1'b0;


            case (state)


                // =================================================
                // IDLE
                // =================================================

                IDLE: begin

                    busy <= 1'b0;

                    if (start) begin

                        busy <= 1'b1;

                        // Start with Block 0
                        block_select <= 1'b0;

                        // Reset counter
                        aes_counter <= INITIAL_COUNTER;

                        state <= READ_BLOCK;

                    end

                end


                // =================================================
                // REQUEST IMAGE BLOCK
                // =================================================

                READ_BLOCK: begin

                    busy <= 1'b1;

                    state <= WAIT_BLOCK;

                end


                // =================================================
                // WAIT FOR IMAGE BLOCK
                // =================================================

                WAIT_BLOCK: begin

                    busy <= 1'b1;

                    if (block_valid) begin

                        // Capture image block
                        aes_data_in <= image_block;

                        state <= START_AES;

                    end

                end


                // =================================================
                // START AES-CTR
                // =================================================

                START_AES: begin

                    busy <= 1'b1;

                    // One-clock AES start pulse
                    aes_start <= 1'b1;

                    state <= WAIT_AES;

                end


                // =================================================
                // WAIT FOR AES-CTR
                // =================================================

                WAIT_AES: begin

                    busy <= 1'b1;

                    if (aes_done) begin

                        // ------------------------------------------------
                        // Store encrypted block
                        // ------------------------------------------------

                        if (block_select == 1'b0) begin

                            encrypted_block0 <= aes_data_out;

                            state <= NEXT_BLOCK;

                        end

                        else begin

                            encrypted_block1 <= aes_data_out;

                            state <= FINISH;

                        end


                        // ------------------------------------------------
                        // Counter for next block
                        // ------------------------------------------------

                        aes_counter <= aes_counter_out;

                    end

                end


                // =================================================
                // MOVE TO BLOCK 1
                // =================================================

                NEXT_BLOCK: begin

                    busy <= 1'b1;

                    block_select <= 1'b1;

                    state <= READ_BLOCK;

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

                    done <= 1'b0;

                end

            endcase

        end

    end

endmodule