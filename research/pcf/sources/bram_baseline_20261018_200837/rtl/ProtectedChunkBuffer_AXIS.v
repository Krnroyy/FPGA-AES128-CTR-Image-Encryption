`timescale 1ns / 1ps

// 4096-byte write-once, replayable AXI4-Stream buffer.
//
// Security purpose:
//   1. Capture one ciphertext chunk from an untrusted/external source.
//   2. Lock the on-chip copy.
//   3. Replay the exact same locked bytes for AES-GCM authentication.
//   4. Replay them again for decryption only after authentication succeeds.
//   5. Zeroize all storage before accepting another chunk.
//
// The module deliberately refuses capture traffic while LOCKED or REPLAYING.
// A blocked write attempt is latched in STATUS.WRITE_BLOCKED so firmware and
// simulation can verify that the immutable window was enforced.
module ProtectedChunkBuffer_AXIS #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer CHUNK_BYTES = 4096
)
(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 ACLK CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI_CTRL:S_AXIS:M_AXIS, ASSOCIATED_RESET aresetn, FREQ_HZ 75000000" *)
    input  wire                              aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 ARESETN RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire                              aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWADDR" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_ctrl_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWPROT" *)
    input  wire [2:0]                        s_axi_ctrl_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWVALID" *)
    input  wire                              s_axi_ctrl_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWREADY" *)
    output wire                              s_axi_ctrl_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WDATA" *)
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_ctrl_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WSTRB" *)
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_ctrl_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WVALID" *)
    input  wire                              s_axi_ctrl_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WREADY" *)
    output wire                              s_axi_ctrl_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL BRESP" *)
    output wire [1:0]                        s_axi_ctrl_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL BVALID" *)
    output wire                              s_axi_ctrl_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL BREADY" *)
    input  wire                              s_axi_ctrl_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARADDR" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_ctrl_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARPROT" *)
    input  wire [2:0]                        s_axi_ctrl_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARVALID" *)
    input  wire                              s_axi_ctrl_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARREADY" *)
    output wire                              s_axi_ctrl_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RDATA" *)
    output wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_ctrl_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RRESP" *)
    output wire [1:0]                        s_axi_ctrl_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RVALID" *)
    output wire                              s_axi_ctrl_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RREADY" *)
    input  wire                              s_axi_ctrl_rready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TDATA" *)
    input  wire [127:0]                      s_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TKEEP" *)
    input  wire [15:0]                       s_axis_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TLAST" *)
    input  wire                              s_axis_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TVALID" *)
    input  wire                              s_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TREADY" *)
    output wire                              s_axis_tready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA" *)
    output wire [127:0]                      m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TKEEP" *)
    output wire [15:0]                       m_axis_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TLAST" *)
    output wire                              m_axis_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *)
    output wire                              m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *)
    input  wire                              m_axis_tready
);

localparam integer WORD_BYTES = 16;
localparam integer MAX_WORDS = CHUNK_BYTES / WORD_BYTES;
localparam integer WORD_INDEX_WIDTH = $clog2(MAX_WORDS);

localparam [5:0] REG_CONTROL      = 6'h00;
localparam [5:0] REG_STATUS       = 6'h04;
localparam [5:0] REG_EXPECT_BYTES = 6'h08;
localparam [5:0] REG_CAPTURED     = 6'h0C;
localparam [5:0] REG_REPLAYS      = 6'h10;
localparam [5:0] REG_CAPACITY     = 6'h14;

localparam [2:0] STATE_IDLE       = 3'd0;
localparam [2:0] STATE_CAPTURE    = 3'd1;
localparam [2:0] STATE_LOCKED     = 3'd2;
localparam [2:0] STATE_REPLAY     = 3'd3;
localparam [2:0] STATE_ZEROIZE    = 3'd4;

reg [2:0] state;
reg [31:0] expected_bytes;
reg [31:0] captured_bytes;
reg [31:0] replay_count;
reg [WORD_INDEX_WIDTH:0] capture_word;
reg [WORD_INDEX_WIDTH:0] replay_word;
reg [WORD_INDEX_WIDTH-1:0] zeroize_word;

reg capture_done;
reg replay_done;
reg zeroize_done;
reg overflow_error;
reg length_error;
reg write_blocked;

reg [127:0] replay_data;
reg [15:0] replay_keep;
reg replay_last;
reg replay_valid;
reg replay_read_pending;
reg [WORD_INDEX_WIDTH-1:0] replay_issue_word;

wire [31:0] expected_words = (expected_bytes + 32'd15) >> 4;
wire [4:0] final_byte_count = expected_bytes[3:0] == 4'd0 ?
                              5'd16 : {1'b0, expected_bytes[3:0]};

wire capture_write = (state == STATE_CAPTURE) &&
                     s_axis_tvalid && s_axis_tready;
wire zeroize_write = (state == STATE_ZEROIZE);
wire memory_write_en = capture_write || zeroize_write;
wire [WORD_INDEX_WIDTH-1:0] memory_write_addr =
    zeroize_write ? zeroize_word : capture_word[WORD_INDEX_WIDTH-1:0];
wire [127:0] memory_write_data =
    zeroize_write ? 128'd0 : s_axis_tdata;
wire memory_read_en = (state == STATE_REPLAY) &&
                      !replay_valid && !replay_read_pending &&
                      (replay_word < expected_words);
wire [WORD_INDEX_WIDTH-1:0] memory_read_addr =
    replay_word[WORD_INDEX_WIDTH-1:0];
wire [127:0] memory_read_data;

ProtectedChunkMemory_BRAM #(
    .DATA_WIDTH(128),
    .ADDR_WIDTH(WORD_INDEX_WIDTH),
    .DEPTH(MAX_WORDS)
) protected_chunk_memory (
    .clk        (aclk),
    .write_en   (memory_write_en),
    .write_addr (memory_write_addr),
    .write_data (memory_write_data),
    .read_en    (memory_read_en),
    .read_addr  (memory_read_addr),
    .read_data  (memory_read_data)
);

reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_hold;
reg [C_S_AXI_DATA_WIDTH-1:0] wdata_hold;
reg [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb_hold;
reg aw_hold_valid;
reg w_hold_valid;
reg axi_bvalid;
reg axi_rvalid;
reg [31:0] axi_rdata;

wire aw_accept = s_axi_ctrl_awvalid && s_axi_ctrl_awready;
wire w_accept = s_axi_ctrl_wvalid && s_axi_ctrl_wready;
wire write_fire = !axi_bvalid && (aw_hold_valid || aw_accept) &&
                  (w_hold_valid || w_accept);
wire [C_S_AXI_ADDR_WIDTH-1:0] write_addr =
    aw_accept ? s_axi_ctrl_awaddr : awaddr_hold;
wire [C_S_AXI_DATA_WIDTH-1:0] write_data =
    w_accept ? s_axi_ctrl_wdata : wdata_hold;
wire [(C_S_AXI_DATA_WIDTH/8)-1:0] write_strb =
    w_accept ? s_axi_ctrl_wstrb : wstrb_hold;

function [15:0] keep_for_bytes;
    input [4:0] byte_count;
    begin
        if(byte_count >= 5'd16)
            keep_for_bytes = 16'hFFFF;
        else
            keep_for_bytes = (16'h0001 << byte_count) - 16'h0001;
    end
endfunction

function [31:0] apply_wstrb;
    input [31:0] old_value;
    input [31:0] new_value;
    input [3:0] byte_enable;
    integer index;
    begin
        apply_wstrb = old_value;
        for(index = 0; index < 4; index = index + 1)
            if(byte_enable[index])
                apply_wstrb[index*8 +: 8] = new_value[index*8 +: 8];
    end
endfunction

assign s_axi_ctrl_awready = !aw_hold_valid && !axi_bvalid;
assign s_axi_ctrl_wready = !w_hold_valid && !axi_bvalid;
assign s_axi_ctrl_bresp = 2'b00;
assign s_axi_ctrl_bvalid = axi_bvalid;
assign s_axi_ctrl_arready = !axi_rvalid;
assign s_axi_ctrl_rdata = axi_rdata;
assign s_axi_ctrl_rresp = 2'b00;
assign s_axi_ctrl_rvalid = axi_rvalid;

assign s_axis_tready = (state == STATE_CAPTURE) &&
                       (capture_word < expected_words) &&
                       (capture_word < MAX_WORDS);
assign m_axis_tdata = replay_data;
assign m_axis_tkeep = replay_keep;
assign m_axis_tlast = replay_last;
assign m_axis_tvalid = replay_valid;

wire [31:0] status_word = {
    20'd0,
    (state == STATE_IDLE),       // bit 11
    capture_done,                // bit 10
    write_blocked,               // bit 9
    length_error,                // bit 8
    overflow_error,              // bit 7
    zeroize_done,                // bit 6
    (state == STATE_ZEROIZE),    // bit 5
    replay_done,                 // bit 4
    (state == STATE_REPLAY),     // bit 3
    (state == STATE_LOCKED),     // bit 2
    (state == STATE_CAPTURE),    // bit 1
    (state == STATE_IDLE)        // bit 0
};

always @(posedge aclk)
begin
    if(!aresetn)
    begin
        // Every reset enters a full constant-time scrub before the buffer can
        // be armed again. This also covers reset during capture or replay.
        state <= STATE_ZEROIZE;
        expected_bytes <= 32'd0;
        captured_bytes <= 32'd0;
        replay_count <= 32'd0;
        capture_word <= 0;
        replay_word <= 0;
        zeroize_word <= 0;
        capture_done <= 1'b0;
        replay_done <= 1'b0;
        zeroize_done <= 1'b0;
        overflow_error <= 1'b0;
        length_error <= 1'b0;
        write_blocked <= 1'b0;
        replay_data <= 128'd0;
        replay_keep <= 16'd0;
        replay_last <= 1'b0;
        replay_valid <= 1'b0;
        replay_read_pending <= 1'b0;
        replay_issue_word <= 0;
        awaddr_hold <= 0;
        wdata_hold <= 0;
        wstrb_hold <= 0;
        aw_hold_valid <= 1'b0;
        w_hold_valid <= 1'b0;
        axi_bvalid <= 1'b0;
        axi_rvalid <= 1'b0;
        axi_rdata <= 32'd0;
    end
    else
    begin
        if(aw_accept && !write_fire)
        begin
            awaddr_hold <= s_axi_ctrl_awaddr;
            aw_hold_valid <= 1'b1;
        end
        if(w_accept && !write_fire)
        begin
            wdata_hold <= s_axi_ctrl_wdata;
            wstrb_hold <= s_axi_ctrl_wstrb;
            w_hold_valid <= 1'b1;
        end
        if(write_fire)
        begin
            aw_hold_valid <= 1'b0;
            w_hold_valid <= 1'b0;
            axi_bvalid <= 1'b1;

            if(write_addr[5:0] == REG_EXPECT_BYTES && state == STATE_IDLE)
                expected_bytes <= apply_wstrb(expected_bytes,
                                              write_data, write_strb);

            if(write_addr[5:0] == REG_CONTROL && write_strb[0])
            begin
                if(write_data[3])
                begin
                    capture_done <= 1'b0;
                    replay_done <= 1'b0;
                    zeroize_done <= 1'b0;
                    overflow_error <= 1'b0;
                    length_error <= 1'b0;
                    write_blocked <= 1'b0;
                end
                if(write_data[0] && state == STATE_IDLE)
                begin
                    captured_bytes <= 32'd0;
                    capture_word <= 0;
                    capture_done <= 1'b0;
                    replay_done <= 1'b0;
                    zeroize_done <= 1'b0;
                    overflow_error <= (expected_bytes == 0 ||
                                       expected_bytes > CHUNK_BYTES);
                    length_error <= 1'b0;
                    write_blocked <= 1'b0;
                    if(expected_bytes != 0 && expected_bytes <= CHUNK_BYTES)
                        state <= STATE_CAPTURE;
                end
                if(write_data[1] && state == STATE_LOCKED && !length_error)
                begin
                    replay_word <= 0;
                    replay_valid <= 1'b0;
                    replay_read_pending <= 1'b0;
                    replay_done <= 1'b0;
                    state <= STATE_REPLAY;
                end
                if(write_data[2] && state == STATE_LOCKED)
                begin
                    replay_valid <= 1'b0;
                    replay_read_pending <= 1'b0;
                    zeroize_word <= 0;
                    zeroize_done <= 1'b0;
                    state <= STATE_ZEROIZE;
                end
            end
        end
        if(axi_bvalid && s_axi_ctrl_bready)
            axi_bvalid <= 1'b0;

        if(s_axi_ctrl_arvalid && s_axi_ctrl_arready)
        begin
            case(s_axi_ctrl_araddr[5:0])
            REG_CONTROL:      axi_rdata <= 32'd0;
            REG_STATUS:       axi_rdata <= status_word;
            REG_EXPECT_BYTES: axi_rdata <= expected_bytes;
            REG_CAPTURED:     axi_rdata <= captured_bytes;
            REG_REPLAYS:      axi_rdata <= replay_count;
            REG_CAPACITY:     axi_rdata <= CHUNK_BYTES;
            default:          axi_rdata <= 32'd0;
            endcase
            axi_rvalid <= 1'b1;
        end
        if(axi_rvalid && s_axi_ctrl_rready)
            axi_rvalid <= 1'b0;

        if((state == STATE_LOCKED || state == STATE_REPLAY) && s_axis_tvalid)
            write_blocked <= 1'b1;

        if(state == STATE_CAPTURE && s_axis_tvalid && s_axis_tready)
        begin
            captured_bytes <= captured_bytes +
                              (capture_word + 1 == expected_words ?
                               final_byte_count : 5'd16);

            if(capture_word + 1 == expected_words)
            begin
                if(!s_axis_tlast || s_axis_tkeep != keep_for_bytes(final_byte_count))
                    length_error <= 1'b1;
                capture_done <= 1'b1;
                state <= STATE_LOCKED;
            end
            else
            begin
                if(s_axis_tlast || s_axis_tkeep != 16'hFFFF)
                    length_error <= 1'b1;
                capture_word <= capture_word + 1'b1;
            end
        end

        if(state == STATE_REPLAY)
        begin
            // The memory has a synchronous read port.  Issue a read first,
            // then move the returned word into the AXI output register on the
            // following cycle.  This deliberately inserts a one-cycle bubble
            // between words, preserving correctness while making the storage
            // infer as block RAM.
            if(!replay_valid)
            begin
                if(replay_read_pending)
                begin
                    replay_data <= memory_read_data;
                    replay_keep <= (replay_issue_word + 1 == expected_words) ?
                                   keep_for_bytes(final_byte_count) : 16'hFFFF;
                    replay_last <= (replay_issue_word + 1 == expected_words);
                    replay_valid <= 1'b1;
                    replay_read_pending <= 1'b0;
                end
                else if(replay_word < expected_words)
                begin
                    replay_issue_word <= replay_word[WORD_INDEX_WIDTH-1:0];
                    replay_word <= replay_word + 1'b1;
                    replay_read_pending <= 1'b1;
                end
                else
                begin
                    replay_valid <= 1'b0;
                    replay_last <= 1'b0;
                    replay_done <= 1'b1;
                    replay_count <= replay_count + 1'b1;
                    state <= STATE_LOCKED;
                end
            end
            else if(m_axis_tready)
                replay_valid <= 1'b0;
        end

        if(state == STATE_ZEROIZE)
        begin
            if(zeroize_word == MAX_WORDS-1)
            begin
                expected_bytes <= 32'd0;
                captured_bytes <= 32'd0;
                capture_word <= 0;
                replay_word <= 0;
                replay_data <= 128'd0;
                replay_keep <= 16'd0;
                replay_last <= 1'b0;
                replay_valid <= 1'b0;
                replay_read_pending <= 1'b0;
                replay_issue_word <= 0;
                capture_done <= 1'b0;
                zeroize_done <= 1'b1;
                state <= STATE_IDLE;
            end
            else
                zeroize_word <= zeroize_word + 1'b1;
        end
    end
end

endmodule
