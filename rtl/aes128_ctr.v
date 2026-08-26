`timescale 1ns / 1ps

module aes128_ctr (

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
    // AES-128 CORE
    //
    // We encrypt the counter value.
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

        // Debug outputs are not required here
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

            // AES start is also a pulse
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


                    // Increment counter for next block

                    counter_out <= counter_reg + 128'd1;


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