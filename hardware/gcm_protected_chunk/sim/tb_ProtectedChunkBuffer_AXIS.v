`timescale 1ns / 1ps

module tb_ProtectedChunkBuffer_AXIS;

reg aclk = 1'b0;
reg aresetn = 1'b0;
always #5 aclk = ~aclk;

reg [5:0] awaddr = 0;
reg [2:0] awprot = 0;
reg awvalid = 0;
wire awready;
reg [31:0] wdata = 0;
reg [3:0] wstrb = 0;
reg wvalid = 0;
wire wready;
wire [1:0] bresp;
wire bvalid;
reg bready = 0;
reg [5:0] araddr = 0;
reg [2:0] arprot = 0;
reg arvalid = 0;
wire arready;
wire [31:0] rdata;
wire [1:0] rresp;
wire rvalid;
reg rready = 0;

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

reg [31:0] status;
integer output_words = 0;
integer replay_number = 0;
reg output_error = 0;

localparam [127:0] WORD0 = 128'h00112233445566778899AABBCCDDEEFF;
localparam [127:0] WORD1 = 128'h10203040500000000000000000000000;

ProtectedChunkBuffer_AXIS dut (
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

task axi_write;
    input [5:0] address;
    input [31:0] value;
    begin
        @(negedge aclk);
        awaddr = address;
        awvalid = 1'b1;
        wdata = value;
        wstrb = 4'hF;
        wvalid = 1'b1;
        fork
            begin
                @(posedge aclk);
                while(!awready) @(posedge aclk);
                @(negedge aclk);
                awvalid = 1'b0;
            end
            begin
                @(posedge aclk);
                while(!wready) @(posedge aclk);
                @(negedge aclk);
                wvalid = 1'b0;
            end
        join
        while(!bvalid) @(posedge aclk);
        @(negedge aclk);
        bready = 1'b1;
        @(posedge aclk);
        @(negedge aclk);
        bready = 1'b0;
    end
endtask

task axi_read;
    input [5:0] address;
    output [31:0] value;
    begin
        @(negedge aclk);
        araddr = address;
        arvalid = 1'b1;
        @(posedge aclk);
        while(!arready) @(posedge aclk);
        @(negedge aclk);
        arvalid = 1'b0;
        while(!rvalid) @(posedge aclk);
        value = rdata;
        @(negedge aclk);
        rready = 1'b1;
        @(posedge aclk);
        @(negedge aclk);
        rready = 1'b0;
    end
endtask

task send_word;
    input [127:0] value;
    input [15:0] keep;
    input last;
    begin
        while(!s_tready)
            @(negedge aclk);
        s_tdata = value;
        s_tkeep = keep;
        s_tlast = last;
        s_tvalid = 1'b1;
        @(posedge aclk);
        @(negedge aclk);
        s_tvalid = 1'b0;
    end
endtask

always @(posedge aclk)
begin
    if(m_tvalid && m_tready)
    begin
        if(output_words == 0 &&
           (m_tdata !== WORD0 || m_tkeep !== 16'hFFFF || m_tlast))
            output_error <= 1'b1;
        if(output_words == 1 &&
           (m_tdata !== WORD1 || m_tkeep !== 16'h001F || !m_tlast))
            output_error <= 1'b1;
        output_words <= output_words + 1;
    end
end

task run_replay;
    begin
        output_words = 0;
        output_error = 0;
        m_tready = 1'b1;
        axi_write(6'h00, 32'h00000002);
        while(dut.state == 3'd3)
            @(posedge aclk);
        @(negedge aclk);
        m_tready = 1'b0;
        if(output_words != 2 || output_error)
        begin
            $display("FAIL: replay %0d data mismatch, words=%0d error=%0d",
                     replay_number, output_words, output_error);
            $finish;
        end
        replay_number = replay_number + 1;
    end
endtask

initial
begin
    repeat(8) @(posedge aclk);
    aresetn <= 1'b1;
    while(dut.state != 3'd0) @(posedge aclk);
    repeat(3) @(posedge aclk);

    axi_write(6'h08, 32'd21);
    axi_write(6'h00, 32'h00000001);
    send_word(WORD0, 16'hFFFF, 1'b0);
    send_word(WORD1, 16'h001F, 1'b1);
    axi_read(6'h04, status);
    if(!status[2] || !status[10] || status[8] ||
       dut.captured_bytes != 32'd21)
    begin
        $display("FAIL: capture/lock STATUS=%08h BYTES=%0d",
                 status, dut.captured_bytes);
        $finish;
    end
    $display("PASS: 21-byte non-aligned chunk captured and locked");

    // Any attempted write during the immutable window must be refused.
    s_tdata = 128'hDEADBEEF;
    s_tkeep = 16'hFFFF;
    s_tlast = 1'b1;
    s_tvalid = 1'b1;
    repeat(3) @(posedge aclk);
    if(s_tready)
    begin
        $display("FAIL: capture interface became ready while locked");
        $finish;
    end
    s_tvalid = 1'b0;
    axi_read(6'h04, status);
    if(!status[9])
    begin
        $display("FAIL: blocked write was not recorded STATUS=%08h", status);
        $finish;
    end
    $display("PASS: write attempt blocked while chunk locked");

    run_replay();
    run_replay();
    axi_read(6'h10, status);
    if(status != 32'd2)
    begin
        $display("FAIL: replay counter expected 2, got %0d", status);
        $finish;
    end
    $display("PASS: identical locked bytes replayed twice with backpressure");

    axi_write(6'h00, 32'h00000004);
    while(dut.state != 3'd0)
        @(posedge aclk);
    axi_read(6'h04, status);
    if(!status[0] || !status[6] ||
       dut.protected_chunk_memory.memory[0] !== 128'd0 ||
       dut.protected_chunk_memory.memory[1] !== 128'd0 ||
       dut.protected_chunk_memory.memory[255] !== 128'd0)
    begin
        $display("FAIL: zeroization result STATUS=%08h", status);
        $finish;
    end
    $display("PASS: all 4096 bytes zeroized before reuse");

    // A malformed final TKEEP/TLAST must lock with LENGTH_ERROR and cannot replay.
    axi_write(6'h08, 32'd21);
    axi_write(6'h00, 32'h00000001);
    send_word(WORD0, 16'hFFFF, 1'b0);
    send_word(WORD1, 16'h000F, 1'b1);
    axi_read(6'h04, status);
    if(!status[2] || !status[8])
    begin
        $display("FAIL: malformed final beat was not rejected STATUS=%08h", status);
        $finish;
    end
    axi_write(6'h00, 32'h00000002);
    repeat(5) @(posedge aclk);
    if(m_tvalid || dut.state != 3'd2)
    begin
        $display("FAIL: replay started after capture length error");
        $finish;
    end
    $display("PASS: malformed final chunk cannot be replayed");

    // Reset while locked must force a complete scrub before IDLE returns.
    aresetn = 1'b0;
    repeat(3) @(posedge aclk);
    aresetn = 1'b1;
    while(dut.state != 3'd0) @(posedge aclk);
    if(dut.protected_chunk_memory.memory[0] !== 128'd0 ||
       dut.protected_chunk_memory.memory[255] !== 128'd0)
    begin
        $display("FAIL: reset-triggered scrub did not clear protected storage");
        $finish;
    end
    $display("PASS: reset forces full protected-storage scrub");
    $display("PASS: PROTECTED CHUNK BUFFER RTL MILESTONE");
    $finish;
end

initial
begin
    #1000000;
    $display("FAIL: protected-buffer unit test timed out at %0t", $time);
    $finish;
end

endmodule
