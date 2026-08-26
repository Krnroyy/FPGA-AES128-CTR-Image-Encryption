`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.08.2026 16:29:03
// Design Name: 
// Module Name: aes_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module aes_controller (
    input  wire       clk,
    input  wire       reset,
    input  wire       start,

    input  wire [3:0] round,

    output reg [2:0] state
);

    // ============================================================
    // FSM STATES
    // ============================================================

    localparam IDLE  = 3'd0;
    localparam INIT  = 3'd1;
    localparam ROUND = 3'd2;
    localparam FINAL = 3'd3;
    localparam DONE  = 3'd4;


    // ============================================================
    // FSM REGISTER
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin
            state <= IDLE;
        end

        else begin

            case (state)

                IDLE: begin

                    if (start)
                        state <= INIT;

                    else
                        state <= IDLE;

                end


                INIT: begin

                    state <= ROUND;

                end


                ROUND: begin

                    if (round < 4'd9)
                        state <= ROUND;

                    else
                        state <= FINAL;

                end


                FINAL: begin

                    state <= DONE;

                end


                DONE: begin

                    state <= IDLE;

                end


                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule