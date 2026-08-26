`timescale 1ns / 1ps

module bram_8x4096 (

    input  wire        clk,

    // Write port
    input  wire        we,
    input  wire [11:0] waddr,
    input  wire [7:0]  wdata,

    // Read port
    input  wire        re,
    input  wire [11:0] raddr,
    output reg  [7:0]  rdata

);

    // ============================================================
    // 4096 x 8 = 32768 bits
    //
    // Force Vivado to infer Block RAM
    // ============================================================

    (* ram_style = "block" *)
    reg [7:0] mem [0:4095];


    // ============================================================
    // SIMPLE DUAL-PORT SYNCHRONOUS RAM
    // ============================================================

    always @(posedge clk) begin

        if (we)
            mem[waddr] <= wdata;

        if (re)
            rdata <= mem[raddr];

    end

endmodule