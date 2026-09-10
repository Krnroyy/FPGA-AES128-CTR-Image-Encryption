`timescale 1ns / 1ps

// NIST SP 800-38D GF(2^128) multiplier.
// Processes 32 input bits per clock, MSB first, and completes in four clocks.
module GHASH_Mult32
(
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire [127:0] x,
    input  wire [127:0] h,
    output reg  [127:0] result,
    output reg          busy,
    output reg          done
);

localparam [127:0] REDUCTION = 128'he1000000000000000000000000000000;

reg [127:0] x_reg;
reg [127:0] v_reg;
reg [127:0] z_reg;
reg [1:0] round_count;

reg [127:0] x_work;
reg [127:0] v_work;
reg [127:0] z_work;
integer bit_index;

always @(*)
begin
    x_work = x_reg;
    v_work = v_reg;
    z_work = z_reg;
    for(bit_index = 0; bit_index < 32; bit_index = bit_index + 1)
    begin
        if(x_work[127])
            z_work = z_work ^ v_work;
        x_work = {x_work[126:0], 1'b0};
        if(v_work[0])
            v_work = (v_work >> 1) ^ REDUCTION;
        else
            v_work = v_work >> 1;
    end
end

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        x_reg <= 128'd0;
        v_reg <= 128'd0;
        z_reg <= 128'd0;
        result <= 128'd0;
        round_count <= 2'd0;
        busy <= 1'b0;
        done <= 1'b0;
    end
    else
    begin
        done <= 1'b0;
        if(start && !busy)
        begin
            x_reg <= x;
            v_reg <= h;
            z_reg <= 128'd0;
            round_count <= 2'd0;
            busy <= 1'b1;
        end
        else if(busy)
        begin
            x_reg <= x_work;
            v_reg <= v_work;
            z_reg <= z_work;
            if(round_count == 2'd3)
            begin
                result <= z_work;
                busy <= 1'b0;
                done <= 1'b1;
            end
            else
                round_count <= round_count + 1'b1;
        end
    end
end

endmodule
