`timescale 1ns / 1ps

module aes128_core (
    input  wire         clk,
    input  wire         reset,
    input  wire         start,

    input  wire [127:0] plaintext,
    input  wire [127:0] key,

    output reg  [127:0] ciphertext,
    output reg          busy,
    output reg          done,

    // ============================================================
    // DEBUG OUTPUTS
    // These are only for simulation/verification
    // ============================================================

    output wire [2:0]   debug_state,
    output wire [3:0]   debug_round,
    output wire [127:0] debug_state_reg,
    output wire [127:0] debug_round_key
);


    // ============================================================
    // FSM STATE DEFINITIONS
    // ============================================================

    localparam IDLE  = 3'd0;
    localparam INIT  = 3'd1;
    localparam ROUND = 3'd2;
    localparam FINAL = 3'd3;
    localparam DONE  = 3'd4;


    // ============================================================
    // INTERNAL REGISTERS
    // ============================================================

    reg [2:0] current_state;

    reg [127:0] state_reg;
    reg [127:0] round_key_reg;

    reg [3:0] round;


    // ============================================================
    // DEBUG OUTPUT CONNECTIONS
    // ============================================================

    assign debug_state     = current_state;
    assign debug_round     = round;
    assign debug_state_reg = state_reg;
    assign debug_round_key = round_key_reg;


    // ============================================================
    // RCON
    //
    // Used to generate the NEXT round key.
    //
    // Round 1 -> Key 2 -> Rcon 02
    // Round 2 -> Key 3 -> Rcon 04
    // ...
    // Round 8 -> Key 9 -> Rcon 1B
    // Round 9 -> Key 10 -> Rcon 36
    // ============================================================

    reg [7:0] rcon;

    always @(*) begin

        case (round)

            4'd1:  rcon = 8'h02;
            4'd2:  rcon = 8'h04;
            4'd3:  rcon = 8'h08;
            4'd4:  rcon = 8'h10;
            4'd5:  rcon = 8'h20;
            4'd6:  rcon = 8'h40;
            4'd7:  rcon = 8'h80;
            4'd8:  rcon = 8'h1B;
            4'd9:  rcon = 8'h36;

            default:
                rcon = 8'h00;

        endcase

    end


    // ============================================================
    // ROUND KEY 1
    //
    // Original Key + Rcon 01 = Round Key 1
    // ============================================================

    wire [127:0] round_key_1;

    key_expansion_128 key_expand_first (

        .key_in  (key),
        .rcon    (8'h01),
        .key_out (round_key_1)

    );


    // ============================================================
    // NEXT ROUND KEY
    // ============================================================

    wire [127:0] next_round_key;

    key_expansion_128 key_expand_next (

        .key_in  (round_key_reg),
        .rcon    (rcon),
        .key_out (next_round_key)

    );


    // ============================================================
    // NORMAL AES ROUND
    // ============================================================

    wire [127:0] round_output;

    aes_round round_unit (

        .state_in  (state_reg),
        .round_key (round_key_reg),
        .state_out (round_output)

    );


    // ============================================================
    // FINAL AES ROUND
    //
    // Final round does NOT contain MixColumns.
    // ============================================================

    wire [127:0] final_output;

    aes_final_round final_round_unit (

        .state_in  (state_reg),
        .round_key (round_key_reg),
        .state_out (final_output)

    );


    // ============================================================
    // MAIN AES CONTROLLER
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            current_state <= IDLE;

            state_reg     <= 128'b0;
            round_key_reg <= 128'b0;

            round         <= 4'd0;

            ciphertext    <= 128'b0;

            busy          <= 1'b0;
            done          <= 1'b0;

        end

        else begin

            // done is a one-clock pulse
            done <= 1'b0;


            case (current_state)


                // =================================================
                // IDLE
                // =================================================

                IDLE: begin

                    busy <= 1'b0;

                    if (start) begin

                        busy <= 1'b1;

                        current_state <= INIT;

                    end

                end


                // =================================================
                // INITIAL ADDROUNDKEY
                // =================================================

                INIT: begin

                    // State = Plaintext XOR Original Key

                    state_reg <= plaintext ^ key;


                    // Generate Round Key 1

                    round_key_reg <= round_key_1;


                    // Start Round 1

                    round <= 4'd1;

                    current_state <= ROUND;

                end


                // =================================================
                // NORMAL ROUNDS 1 TO 9
                // =================================================

                ROUND: begin

                    // AES round transformation

                    state_reg <= round_output;


                    // Generate next round key

                    round_key_reg <= next_round_key;


                    if (round < 4'd9) begin

                        round <= round + 4'd1;

                    end

                    else begin

                        // Round 9 has completed.
                        //
                        // round_key_reg now becomes Key 10.
                        //
                        // Next state performs final round.

                        round <= 4'd10;

                        current_state <= FINAL;

                    end

                end


                // =================================================
                // FINAL ROUND - ROUND 10
                // =================================================

                FINAL: begin

                    state_reg <= final_output;

                    ciphertext <= final_output;

                    busy <= 1'b0;

                    done <= 1'b1;

                    current_state <= DONE;

                end


                // =================================================
                // DONE
                // =================================================

                DONE: begin

                    current_state <= IDLE;

                end


                // =================================================
                // DEFAULT
                // =================================================

                default: begin

                    current_state <= IDLE;

                    busy <= 1'b0;

                end

            endcase

        end

    end

endmodule