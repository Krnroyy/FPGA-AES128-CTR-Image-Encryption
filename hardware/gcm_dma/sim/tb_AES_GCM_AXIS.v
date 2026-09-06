`timescale 1ns / 1ps

module tb_AES_GCM_AXIS;

reg aclk = 1'b0;
reg aresetn = 1'b0;
always #5 aclk = ~aclk;

reg [6:0] awaddr = 0;
reg [2:0] awprot = 0;
reg awvalid = 0;
wire awready;
reg [31:0] wdata = 0;
reg [3:0] wstrb = 0;
reg wvalid = 0;
wire wready;
wire [1:0] bresp;
wire bvalid;
reg bready = 1;
reg [6:0] araddr = 0;
reg [2:0] arprot = 0;
reg arvalid = 0;
wire arready;
wire [31:0] rdata;
wire [1:0] rresp;
wire rvalid;
reg rready = 1;

reg [127:0] s_tdata = 0;
reg [15:0] s_tkeep = 0;
reg s_tlast = 0;
reg s_tvalid = 0;
wire s_tready;
wire [127:0] m_tdata;
wire [15:0] m_tkeep;
wire m_tlast;
wire m_tvalid;
reg m_tready = 0;

reg [127:0] observed_tag;
reg [31:0] observed_status;
reg [31:0] observed_blocks;
reg [31:0] observed_bytes;

localparam [127:0] ZERO_CIPHERTEXT =
    128'h0388dace60b6a392f328c2b971b2fe78;
localparam [127:0] ZERO_TAG =
    128'hab6e47d42cec13bdf53a67b21257bddf;

AES_GCM_AXIS dut
(
    .aclk(aclk), .aresetn(aresetn),
    .s_axi_ctrl_awaddr(awaddr), .s_axi_ctrl_awprot(awprot),
    .s_axi_ctrl_awvalid(awvalid), .s_axi_ctrl_awready(awready),
    .s_axi_ctrl_wdata(wdata), .s_axi_ctrl_wstrb(wstrb),
    .s_axi_ctrl_wvalid(wvalid), .s_axi_ctrl_wready(wready),
    .s_axi_ctrl_bresp(bresp), .s_axi_ctrl_bvalid(bvalid),
    .s_axi_ctrl_bready(bready), .s_axi_ctrl_araddr(araddr),
    .s_axi_ctrl_arprot(arprot), .s_axi_ctrl_arvalid(arvalid),
    .s_axi_ctrl_arready(arready), .s_axi_ctrl_rdata(rdata),
    .s_axi_ctrl_rresp(rresp), .s_axi_ctrl_rvalid(rvalid),
    .s_axi_ctrl_rready(rready),
    .s_axis_tdata(s_tdata), .s_axis_tkeep(s_tkeep),
    .s_axis_tlast(s_tlast), .s_axis_tvalid(s_tvalid),
    .s_axis_tready(s_tready), .m_axis_tdata(m_tdata),
    .m_axis_tkeep(m_tkeep), .m_axis_tlast(m_tlast),
    .m_axis_tvalid(m_tvalid), .m_axis_tready(m_tready)
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

task axi_write;
    input [6:0] address;
    input [31:0] value;
    begin
        @(posedge aclk);
        awaddr <= address;
        awvalid <= 1'b1;
        wdata <= value;
        wstrb <= 4'hF;
        wvalid <= 1'b1;
        while(!(awready && wready))
            @(posedge aclk);
        @(posedge aclk);
        awvalid <= 1'b0;
        wvalid <= 1'b0;
        while(!bvalid)
            @(posedge aclk);
        @(posedge aclk);
    end
endtask

task axi_read;
    input [6:0] address;
    output [31:0] value;
    begin
        @(posedge aclk);
        araddr <= address;
        arvalid <= 1'b1;
        while(!arready)
            @(posedge aclk);
        @(posedge aclk);
        arvalid <= 1'b0;
        while(!rvalid)
            @(posedge aclk);
        value = rdata;
        @(posedge aclk);
    end
endtask

task read_tag;
    output [127:0] value;
    reg [31:0] word0, word1, word2, word3;
    begin
        axi_read(7'h30, word0);
        axi_read(7'h34, word1);
        axi_read(7'h38, word2);
        axi_read(7'h3C, word3);
        value = {word0, word1, word2, word3};
    end
endtask

task write_key;
    input [127:0] value;
    begin
        axi_write(7'h10, value[127:96]);
        axi_write(7'h14, value[95:64]);
        axi_write(7'h18, value[63:32]);
        axi_write(7'h1C, value[31:0]);
    end
endtask

task write_iv;
    input [95:0] value;
    begin
        axi_write(7'h20, value[95:64]);
        axi_write(7'h24, value[63:32]);
        axi_write(7'h28, value[31:0]);
    end
endtask

task write_expected_tag;
    input [127:0] value;
    begin
        axi_write(7'h40, value[127:96]);
        axi_write(7'h44, value[95:64]);
        axi_write(7'h48, value[63:32]);
        axi_write(7'h4C, value[31:0]);
    end
endtask

task begin_operation;
    input operation_decrypt;
    input [127:0] operation_expected_tag;
    begin
        axi_write(7'h0C, {31'd0, operation_decrypt});
        write_expected_tag(operation_expected_tag);
        axi_write(7'h00, 32'h00000004);
        repeat(3) @(posedge aclk);
        axi_write(7'h00, 32'h00000002);
        while(!dut.gcm_ready)
            @(posedge aclk);
        axi_write(7'h00, 32'h00000009);
    end
endtask

task send_and_check_block;
    input [127:0] standard_input;
    input [15:0] keep;
    input last;
    input [127:0] expected_standard_output;
    integer stall;
    begin
        while(!s_tready)
            @(negedge aclk);
        s_tdata = reverse_bytes(standard_input);
        s_tkeep = keep;
        s_tlast = last;
        s_tvalid = 1'b1;
        @(posedge aclk);
        @(negedge aclk);
        s_tvalid = 1'b0;

        while(!m_tvalid)
            @(negedge aclk);
        for(stall = 0; stall < 3; stall = stall + 1)
        begin
            if(!m_tvalid ||
               (m_tdata & axis_keep_mask(keep)) !==
               (reverse_bytes(expected_standard_output) & axis_keep_mask(keep)) ||
               m_tkeep !== keep || m_tlast !== last)
            begin
                $display("FAIL: AXI output mismatch during backpressure");
                $display("EXPECTED=%032h ACTUAL=%032h",
                         expected_standard_output, reverse_bytes(m_tdata));
                $finish;
            end
            @(posedge aclk);
        end
        @(negedge aclk);
        m_tready = 1'b1;
        @(posedge aclk);
        @(negedge aclk);
        m_tready = 1'b0;
    end
endtask

initial
begin
    repeat(8) @(posedge aclk);
    aresetn <= 1'b1;
    repeat(3) @(posedge aclk);

    // One-block NIST encryption.
    write_key(128'd0);
    write_iv(96'd0);
    begin_operation(1'b0, 128'd0);
    send_and_check_block(128'd0, 16'hFFFF, 1'b1, ZERO_CIPHERTEXT);
    while(!dut.stream_done)
        @(posedge aclk);
    read_tag(observed_tag);
    axi_read(7'h04, observed_status);
    if(observed_tag !== ZERO_TAG || observed_status[7:5] !== 3'b011)
    begin
        $display("FAIL: one-block encryption tag/status mismatch");
        $display("TAG expected=%032h actual=%032h STATUS=%08h",
                 ZERO_TAG, observed_tag, observed_status);
        $finish;
    end
    $display("PASS: AES_GCM_AXIS NIST encryption and tag");

    // Correct authenticated decryption.
    begin_operation(1'b1, ZERO_TAG);
    send_and_check_block(ZERO_CIPHERTEXT, 16'hFFFF, 1'b1, 128'd0);
    while(!dut.stream_done)
        @(posedge aclk);
    axi_read(7'h04, observed_status);
    if(!observed_status[6] || observed_status[7])
    begin
        $display("FAIL: correct GCM tag was not accepted STATUS=%08h",
                 observed_status);
        $finish;
    end
    $display("PASS: AES_GCM_AXIS correct tag accepted");

    // One-bit ciphertext modification must fail authentication.
    begin_operation(1'b1, ZERO_TAG);
    send_and_check_block(ZERO_CIPHERTEXT ^ 128'd1, 16'hFFFF, 1'b1,
                         128'd1);
    while(!dut.stream_done)
        @(posedge aclk);
    axi_read(7'h04, observed_status);
    if(observed_status[6] || !observed_status[7])
    begin
        $display("FAIL: modified ciphertext was accepted STATUS=%08h",
                 observed_status);
        $finish;
    end
    $display("PASS: AES_GCM_AXIS modified ciphertext rejected");

    // Four-block/60-byte NIST example validates chained GHASH and TKEEP.
    write_key(128'hfeffe9928665731c6d6a8f9467308308);
    write_iv(96'hcafebabefacedbaddecaf888);
    begin_operation(1'b0, 128'd0);
    send_and_check_block(
        128'hd9313225f88406e5a55909c5aff5269a, 16'hFFFF, 1'b0,
        128'h42831ec2217774244b7221b784d0d49c);
    send_and_check_block(
        128'h86a7a9531534f7da2e4c303d8a318a72, 16'hFFFF, 1'b0,
        128'he3aa212f2c02a4e035c17e2329aca12e);
    send_and_check_block(
        128'h1c3c0c95956809532fcf0e2449a6b525, 16'hFFFF, 1'b0,
        128'h21d514b25466931c7d8f6a5aac84aa05);
    send_and_check_block(
        128'hb16aedf5aa0de657ba637b3900000000, 16'h0FFF, 1'b1,
        128'h1ba30b396a0aac973d58e09100000000);
    while(!dut.stream_done)
        @(posedge aclk);
    read_tag(observed_tag);
    axi_read(7'h08, observed_blocks);
    axi_read(7'h50, observed_bytes);
    if(observed_tag !== 128'hcc15abcc191161501aabab46b8fbac85 ||
       observed_blocks !== 32'd4 || observed_bytes !== 32'd60)
    begin
        $display("FAIL: multi-block GCM result mismatch");
        $display("TAG=%032h BLOCKS=%0d BYTES=%0d", observed_tag,
                 observed_blocks, observed_bytes);
        $finish;
    end
    $display("PASS: AES_GCM_AXIS 60-byte chained GHASH and partial block");
    $display("PASS: AES_GCM_AXIS all validation tests");
    $finish;
end

initial
begin
    #100000;
    $display("FAIL: simulation timeout");
    $finish;
end

endmodule
