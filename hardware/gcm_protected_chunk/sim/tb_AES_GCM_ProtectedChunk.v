`timescale 1ns / 1ps

module tb_AES_GCM_ProtectedChunk;

reg aclk = 1'b0;
reg aresetn = 1'b0;
always #5 aclk = ~aclk;

// AES-GCM AXI4-Lite control bus.
reg [6:0] g_awaddr = 0;
reg [2:0] g_awprot = 0;
reg g_awvalid = 0;
wire g_awready;
reg [31:0] g_wdata = 0;
reg [3:0] g_wstrb = 0;
reg g_wvalid = 0;
wire g_wready;
wire [1:0] g_bresp;
wire g_bvalid;
reg g_bready = 0;
reg [6:0] g_araddr = 0;
reg [2:0] g_arprot = 0;
reg g_arvalid = 0;
wire g_arready;
wire [31:0] g_rdata;
wire [1:0] g_rresp;
wire g_rvalid;
reg g_rready = 0;

// Protected-buffer AXI4-Lite control bus.
reg [5:0] b_awaddr = 0;
reg [2:0] b_awprot = 0;
reg b_awvalid = 0;
wire b_awready;
reg [31:0] b_wdata = 0;
reg [3:0] b_wstrb = 0;
reg b_wvalid = 0;
wire b_wready;
wire [1:0] b_bresp;
wire b_bvalid;
reg b_bready = 0;
reg [5:0] b_araddr = 0;
reg [2:0] b_arprot = 0;
reg b_arvalid = 0;
wire b_arready;
wire [31:0] b_rdata;
wire [1:0] b_rresp;
wire b_rvalid;
reg b_rready = 0;

// DMA-facing capture stream.
reg [127:0] capture_tdata = 0;
reg [15:0] capture_tkeep = 0;
reg capture_tlast = 0;
reg capture_tvalid = 0;
wire capture_tready;

// Locked buffer -> AES-GCM internal stream.
wire [127:0] locked_tdata;
wire [15:0] locked_tkeep;
wire locked_tlast;
wire locked_tvalid;
wire locked_tready;

// AES-GCM release stream -> DMA.
wire [127:0] release_tdata;
wire [15:0] release_tkeep;
wire release_tlast;
wire release_tvalid;
reg release_tready = 0;

reg [31:0] status;
integer release_words = 0;
reg release_check_active = 0;
reg release_error = 0;
reg any_output_seen = 0;

localparam [127:0] TEST_AAD =
    128'h01010300000100070000001500000001;
localparam [127:0] PLAINTEXT_0 =
    128'h000102030405060708090a0b0c0d0e0f;
localparam [127:0] PLAINTEXT_1 =
    128'h10111213140000000000000000000000;
localparam [127:0] CIPHERTEXT_0 =
    128'h0389d8cd64b3a595fb21c8b27dbff077;
localparam [127:0] CIPHERTEXT_1 =
    128'he784b8b85d0000000000000000000000;
localparam [127:0] EXPECTED_TAG =
    128'hc562f330a2d904c0169d61a0dd0e85fa;

ProtectedChunkBuffer_AXIS buffer (
    .aclk(aclk), .aresetn(aresetn),
    .s_axi_ctrl_awaddr(b_awaddr), .s_axi_ctrl_awprot(b_awprot),
    .s_axi_ctrl_awvalid(b_awvalid), .s_axi_ctrl_awready(b_awready),
    .s_axi_ctrl_wdata(b_wdata), .s_axi_ctrl_wstrb(b_wstrb),
    .s_axi_ctrl_wvalid(b_wvalid), .s_axi_ctrl_wready(b_wready),
    .s_axi_ctrl_bresp(b_bresp), .s_axi_ctrl_bvalid(b_bvalid),
    .s_axi_ctrl_bready(b_bready), .s_axi_ctrl_araddr(b_araddr),
    .s_axi_ctrl_arprot(b_arprot), .s_axi_ctrl_arvalid(b_arvalid),
    .s_axi_ctrl_arready(b_arready), .s_axi_ctrl_rdata(b_rdata),
    .s_axi_ctrl_rresp(b_rresp), .s_axi_ctrl_rvalid(b_rvalid),
    .s_axi_ctrl_rready(b_rready),
    .s_axis_tdata(capture_tdata), .s_axis_tkeep(capture_tkeep),
    .s_axis_tlast(capture_tlast), .s_axis_tvalid(capture_tvalid),
    .s_axis_tready(capture_tready), .m_axis_tdata(locked_tdata),
    .m_axis_tkeep(locked_tkeep), .m_axis_tlast(locked_tlast),
    .m_axis_tvalid(locked_tvalid), .m_axis_tready(locked_tready)
);

AES_GCM_AXIS gcm (
    .aclk(aclk), .aresetn(aresetn),
    .s_axi_ctrl_awaddr(g_awaddr), .s_axi_ctrl_awprot(g_awprot),
    .s_axi_ctrl_awvalid(g_awvalid), .s_axi_ctrl_awready(g_awready),
    .s_axi_ctrl_wdata(g_wdata), .s_axi_ctrl_wstrb(g_wstrb),
    .s_axi_ctrl_wvalid(g_wvalid), .s_axi_ctrl_wready(g_wready),
    .s_axi_ctrl_bresp(g_bresp), .s_axi_ctrl_bvalid(g_bvalid),
    .s_axi_ctrl_bready(g_bready), .s_axi_ctrl_araddr(g_araddr),
    .s_axi_ctrl_arprot(g_arprot), .s_axi_ctrl_arvalid(g_arvalid),
    .s_axi_ctrl_arready(g_arready), .s_axi_ctrl_rdata(g_rdata),
    .s_axi_ctrl_rresp(g_rresp), .s_axi_ctrl_rvalid(g_rvalid),
    .s_axi_ctrl_rready(g_rready),
    .s_axis_tdata(locked_tdata), .s_axis_tkeep(locked_tkeep),
    .s_axis_tlast(locked_tlast), .s_axis_tvalid(locked_tvalid),
    .s_axis_tready(locked_tready), .m_axis_tdata(release_tdata),
    .m_axis_tkeep(release_tkeep), .m_axis_tlast(release_tlast),
    .m_axis_tvalid(release_tvalid), .m_axis_tready(release_tready)
);

function [127:0] reverse_bytes;
    input [127:0] value;
    integer index;
    begin
        for(index = 0; index < 16; index = index + 1)
            reverse_bytes[127-index*8 -: 8] = value[index*8 +: 8];
    end
endfunction

function [127:0] axis_keep_mask;
    input [15:0] keep;
    integer index;
    begin
        axis_keep_mask = 128'd0;
        for(index = 0; index < 16; index = index + 1)
            if(keep[index])
                axis_keep_mask[index*8 +: 8] = 8'hFF;
    end
endfunction

task gcm_write;
    input [6:0] address;
    input [31:0] value;
    begin
        @(negedge aclk);
        g_awaddr = address;
        g_awvalid = 1'b1;
        g_wdata = value;
        g_wstrb = 4'hF;
        g_wvalid = 1'b1;
        fork
            begin
                @(posedge aclk);
                while(!g_awready) @(posedge aclk);
                @(negedge aclk);
                g_awvalid = 1'b0;
            end
            begin
                @(posedge aclk);
                while(!g_wready) @(posedge aclk);
                @(negedge aclk);
                g_wvalid = 1'b0;
            end
        join
        while(!g_bvalid) @(posedge aclk);
        @(negedge aclk);
        g_bready = 1'b1;
        @(posedge aclk);
        @(negedge aclk);
        g_bready = 1'b0;
    end
endtask

task gcm_read;
    input [6:0] address;
    output [31:0] value;
    begin
        @(negedge aclk);
        g_araddr = address;
        g_arvalid = 1'b1;
        @(posedge aclk);
        while(!g_arready) @(posedge aclk);
        @(negedge aclk);
        g_arvalid = 1'b0;
        while(!g_rvalid) @(posedge aclk);
        value = g_rdata;
        @(negedge aclk);
        g_rready = 1'b1;
        @(posedge aclk);
        @(negedge aclk);
        g_rready = 1'b0;
    end
endtask

task buffer_write;
    input [5:0] address;
    input [31:0] value;
    begin
        @(negedge aclk);
        b_awaddr = address;
        b_awvalid = 1'b1;
        b_wdata = value;
        b_wstrb = 4'hF;
        b_wvalid = 1'b1;
        fork
            begin
                @(posedge aclk);
                while(!b_awready) @(posedge aclk);
                @(negedge aclk);
                b_awvalid = 1'b0;
            end
            begin
                @(posedge aclk);
                while(!b_wready) @(posedge aclk);
                @(negedge aclk);
                b_wvalid = 1'b0;
            end
        join
        while(!b_bvalid) @(posedge aclk);
        @(negedge aclk);
        b_bready = 1'b1;
        @(posedge aclk);
        @(negedge aclk);
        b_bready = 1'b0;
    end
endtask

task buffer_read;
    input [5:0] address;
    output [31:0] value;
    begin
        @(negedge aclk);
        b_araddr = address;
        b_arvalid = 1'b1;
        @(posedge aclk);
        while(!b_arready) @(posedge aclk);
        @(negedge aclk);
        b_arvalid = 1'b0;
        while(!b_rvalid) @(posedge aclk);
        value = b_rdata;
        @(negedge aclk);
        b_rready = 1'b1;
        @(posedge aclk);
        @(negedge aclk);
        b_rready = 1'b0;
    end
endtask

task configure_gcm;
    begin
        gcm_write(7'h10, 32'd0);
        gcm_write(7'h14, 32'd0);
        gcm_write(7'h18, 32'd0);
        gcm_write(7'h1C, 32'd0);
        gcm_write(7'h20, 32'd0);
        gcm_write(7'h24, 32'd0);
        gcm_write(7'h28, 32'd0);
        gcm_write(7'h54, TEST_AAD[127:96]);
        gcm_write(7'h58, TEST_AAD[95:64]);
        gcm_write(7'h5C, TEST_AAD[63:32]);
        gcm_write(7'h60, TEST_AAD[31:0]);
        gcm_write(7'h64, 32'd16);
    end
endtask

task begin_gcm;
    input [1:0] mode;
    input [127:0] expected_tag;
    begin
        gcm_write(7'h00, 32'h00000004);
        gcm_write(7'h0C, {30'd0, mode});
        gcm_write(7'h40, expected_tag[127:96]);
        gcm_write(7'h44, expected_tag[95:64]);
        gcm_write(7'h48, expected_tag[63:32]);
        gcm_write(7'h4C, expected_tag[31:0]);
        gcm_write(7'h00, 32'h00000002);
        while(!gcm.gcm_ready) @(posedge aclk);
        gcm_write(7'h00, 32'h00000009);
    end
endtask

task capture_word;
    input [127:0] standard_value;
    input [15:0] keep;
    input last;
    begin
        while(!capture_tready) @(negedge aclk);
        capture_tdata = reverse_bytes(standard_value);
        capture_tkeep = keep;
        capture_tlast = last;
        capture_tvalid = 1'b1;
        @(posedge aclk);
        @(negedge aclk);
        capture_tvalid = 1'b0;
    end
endtask

task capture_ciphertext;
    input tampered;
    begin
        buffer_write(6'h08, 32'd21);
        buffer_write(6'h00, 32'h00000001);
        capture_word(tampered ? (CIPHERTEXT_0 ^ 128'h1) : CIPHERTEXT_0,
                     16'hFFFF, 1'b0);
        capture_word(CIPHERTEXT_1, 16'h001F, 1'b1);
        buffer_read(6'h04, status);
        if(!status[2] || status[8])
        begin
            $display("FAIL: protected capture STATUS=%08h", status);
            $finish;
        end
    end
endtask

always @(posedge aclk)
begin
    if(release_tvalid)
        any_output_seen <= 1'b1;
    if(release_check_active && release_tvalid && release_tready)
    begin
        if(release_words == 0 &&
           (release_tdata !== reverse_bytes(PLAINTEXT_0) ||
            release_tkeep !== 16'hFFFF || release_tlast))
            release_error <= 1'b1;
        if(release_words == 1 &&
           ((release_tdata & axis_keep_mask(16'h001F)) !==
            (reverse_bytes(PLAINTEXT_1) & axis_keep_mask(16'h001F)) ||
            release_tkeep !== 16'h001F || !release_tlast))
            release_error <= 1'b1;
        release_words <= release_words + 1;
    end
end

initial
begin
    repeat(8) @(posedge aclk);
    aresetn <= 1'b1;
    while(buffer.state != 3'd0) @(posedge aclk);
    repeat(3) @(posedge aclk);
    configure_gcm();
    capture_ciphertext(1'b0);

    any_output_seen = 1'b0;
    release_tready = 1'b1;
    begin_gcm(2'd2, EXPECTED_TAG);
    buffer_write(6'h00, 32'h00000002);
    while(!gcm.stream_done) @(posedge aclk);
    gcm_read(7'h04, status);
    if(!status[8] || !status[6] || status[7] || any_output_seen)
    begin
        $display("FAIL: locked-buffer authentication STATUS=%08h OUTPUT=%0d",
                 status, any_output_seen);
        $finish;
    end
    $display("PASS: locked ciphertext authenticated with no plaintext output");

    // Try to overwrite the chunk after authentication but before release.
    capture_tdata = 128'hBAD0BAD0BAD0BAD0BAD0BAD0BAD0BAD0;
    capture_tkeep = 16'hFFFF;
    capture_tlast = 1'b1;
    capture_tvalid = 1'b1;
    repeat(3) @(posedge aclk);
    capture_tvalid = 1'b0;
    buffer_read(6'h04, status);
    if(capture_tready || !status[9])
    begin
        $display("FAIL: TOCTOU write was not blocked STATUS=%08h", status);
        $finish;
    end
    $display("PASS: post-authentication write blocked before release");

    release_words = 0;
    release_error = 0;
    release_check_active = 1'b1;
    begin_gcm(2'd1, EXPECTED_TAG);
    buffer_write(6'h00, 32'h00000002);
    while(!gcm.stream_done) @(posedge aclk);
    @(negedge aclk);
    release_check_active = 1'b0;
    gcm_read(7'h04, status);
    if(!status[6] || status[7] || release_words != 2 || release_error)
    begin
        $display("FAIL: authenticated release STATUS=%08h WORDS=%0d ERROR=%0d",
                 status, release_words, release_error);
        $finish;
    end
    $display("PASS: same locked bytes decrypted and released after authentication");

    buffer_write(6'h00, 32'h00000004);
    while(buffer.state != 3'd0) @(posedge aclk);
    capture_ciphertext(1'b1);
    any_output_seen = 1'b0;
    begin_gcm(2'd2, EXPECTED_TAG);
    buffer_write(6'h00, 32'h00000002);
    while(!gcm.stream_done) @(posedge aclk);
    gcm_read(7'h04, status);
    if(!status[8] || status[6] || !status[7] || any_output_seen)
    begin
        $display("FAIL: tampered locked chunk STATUS=%08h OUTPUT=%0d",
                 status, any_output_seen);
        $finish;
    end
    $display("PASS: tampered chunk rejected before any decrypt/release pass");

    buffer_write(6'h00, 32'h00000004);
    while(buffer.state != 3'd0) @(posedge aclk);
    if(buffer.protected_chunk_memory.memory[0] !== 128'd0 ||
       buffer.protected_chunk_memory.memory[255] !== 128'd0)
    begin
        $display("FAIL: protected storage not zeroized");
        $finish;
    end
    $display("PASS: rejected ciphertext zeroized from protected storage");
    $display("PASS: AES-GCM PROTECTED CHUNK INTEGRATION MILESTONE");
    $finish;
end

initial
begin
    #2000000;
    $display("FAIL: protected AES-GCM integration test timed out at %0t", $time);
    $finish;
end

endmodule
