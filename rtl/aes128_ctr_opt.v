`timescale 1ns / 1ps

module aes128_ctr_opt (
    input  wire         clk,
    input  wire         reset,

    // Start processing one 128-bit block
    input  wire         start,

    // 128-bit plaintext/ciphertext block
    input  wire [127:0] data_in,

    // AES-128 key
    input  wire [127:0] key,

    // Initial/current counter value
    input  wire [127:0] counter_in,

    // Output encrypted/decrypted block
    output reg  [127:0] data_out,

    // Counter value for next block
    output reg  [127:0] counter_out,

    // Status signals
    output reg          busy,
    output reg          done
);


    // ============================================================
    // INTERNAL REGISTERS
    // ============================================================

    reg [127:0] data_reg;
    reg [127:0] counter_reg;
    reg [127:0] key_reg;

    reg aes_start;


    // ============================================================
    // AES CORE SIGNALS
    // ============================================================

    wire [127:0] aes_ciphertext;
    wire         aes_busy;
    wire         aes_done;


    // ============================================================
    // STATE MACHINE
    // ============================================================

    localparam IDLE = 2'd0;
    localparam WAIT = 2'd1;
    localparam OUT  = 2'd2;

    reg [1:0] state;


    // ============================================================
    // OPTIMIZED 128-BIT COUNTER INCREMENTER
    //
    // Instead of one continuous:
    //
    // counter_reg + 128'd1
    //
    // the counter is divided into four 32-bit sections.
    //
    // Each section computes +1 locally in parallel.
    // Carry propagation between sections is handled separately.
    //
    // Functional result remains exactly:
    //
    // counter_next = counter_reg + 1
    // ============================================================

    wire [31:0] ctr0;
    wire [31:0] ctr1;
    wire [31:0] ctr2;
    wire [31:0] ctr3;

    assign ctr0 = counter_reg[31:0];
    assign ctr1 = counter_reg[63:32];
    assign ctr2 = counter_reg[95:64];
    assign ctr3 = counter_reg[127:96];


    // Parallel local increments
    wire [31:0] ctr0_inc;
    wire [31:0] ctr1_inc;
    wire [31:0] ctr2_inc;
    wire [31:0] ctr3_inc;

    assign ctr0_inc = ctr0 + 32'd1;
    assign ctr1_inc = ctr1 + 32'd1;
    assign ctr2_inc = ctr2 + 32'd1;
    assign ctr3_inc = ctr3 + 32'd1;


    // Carry generation
    wire carry0;
    wire carry1;
    wire carry2;

    // Carry from bits [31:0]
    assign carry0 = &ctr0;

    // Carry from bits [63:0]
    assign carry1 = carry0 & (&ctr1);

    // Carry from bits [95:0]
    assign carry2 = carry1 & (&ctr2);


    // Select incremented or unchanged upper words
    wire [31:0] next0;
    wire [31:0] next1;
    wire [31:0] next2;
    wire [31:0] next3;

    assign next0 = ctr0_inc;

    assign next1 = carry0 ?
                   ctr1_inc :
                   ctr1;

    assign next2 = carry1 ?
                   ctr2_inc :
                   ctr2;

    assign next3 = carry2 ?
                   ctr3_inc :
                   ctr3;


    wire [127:0] counter_next;

    assign counter_next = {
        next3,
        next2,
        next1,
        next0
    };


    // ============================================================
    // AES-128 CORE
    //
    // Encrypt counter value.
    //
    // AES(counter) = keystream
    // ============================================================

    aes128_core aes_core (

        .clk        (clk),
        .reset      (reset),

        .start      (aes_start),

        .plaintext  (counter_reg),
        .key        (key_reg),

        .ciphertext (aes_ciphertext),

        .busy       (aes_busy),
        .done       (aes_done),

        // Debug outputs not required
        .debug_state     (),
        .debug_round     (),
        .debug_state_reg (),
        .debug_round_key ()

    );


    // ============================================================
    // CTR CONTROLLER
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            state       <= IDLE;

            data_reg    <= 128'b0;
            counter_reg <= 128'b0;
            key_reg     <= 128'b0;

            data_out    <= 128'b0;
            counter_out <= 128'b0;

            aes_start   <= 1'b0;

            busy        <= 1'b0;
            done        <= 1'b0;

        end

        else begin

            // done is a one-clock pulse
            done <= 1'b0;

            // AES start is also a one-clock pulse
            aes_start <= 1'b0;


            case (state)


                // =================================================
                // IDLE
                // =================================================

                IDLE: begin

                    busy <= 1'b0;

                    if (start) begin

                        // Store input block
                        data_reg <= data_in;

                        // Store counter
                        counter_reg <= counter_in;

                        // Store key
                        key_reg <= key;

                        // Start AES(counter)
                        aes_start <= 1'b1;

                        busy <= 1'b1;

                        state <= WAIT;

                    end

                end


                // =================================================
                // WAIT FOR AES
                // =================================================

                WAIT: begin

                    busy <= 1'b1;

                    if (aes_done) begin

                        state <= OUT;

                    end

                end


                // =================================================
                // OUTPUT
                // =================================================

                OUT: begin

                    // CTR encryption/decryption:
                    //
                    // data_out = data_in XOR AES(counter)

                    data_out <= data_reg ^ aes_ciphertext;


                    // Optimized but functionally identical
                    // 128-bit counter increment

                    counter_out <= counter_next;


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