`timescale 1ns / 1ps

// Synchronous simple-dual-port storage for one protected ciphertext chunk.
//
// Keeping the storage in a small, single-purpose module is intentional.  The
// previous implementation mixed capture, replay and scrub accesses with the
// AXI-stream state machine, which caused Vivado to map the array into LUT
// logic.  This module has one write port and one synchronous read port, the
// shape required for block-RAM inference on Zynq UltraScale+.
module ProtectedChunkMemory_BRAM #(
    parameter integer DATA_WIDTH = 128,
    parameter integer ADDR_WIDTH = 8,
    parameter integer DEPTH = 256
)(
    input  wire                   clk,
    input  wire                   write_en,
    input  wire [ADDR_WIDTH-1:0] write_addr,
    input  wire [DATA_WIDTH-1:0] write_data,
    input  wire                   read_en,
    input  wire [ADDR_WIDTH-1:0] read_addr,
    output reg  [DATA_WIDTH-1:0] read_data
);

// 256 x 128 = 32768 bits.  The synchronous read and isolated write port let
// Vivado infer simple-dual-port BRAM instead of distributed LUT storage.
(* ram_style = "block" *)
reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];

always @(posedge clk)
begin
    if(write_en)
        memory[write_addr] <= write_data;
    if(read_en)
        read_data <= memory[read_addr];
end

endmodule
