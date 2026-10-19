`timescale 1ns / 1ps

module tb_ControllerRaces;

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

wire security_abort;
wire release_committed;
wire release_cancel_request;
wire protected_locked;
wire [31:0] protected_bytes;

// AES-GCM release stream -> DMA.
wire [127:0] release_tdata;
wire [15:0] release_tkeep;
wire release_tlast;
wire release_tvalid;
reg release_tready = 0;

reg [31:0] status;
reg [31:0] saved_config;
reg [6:0] config_addresses [0:16];
integer config_index;
reg [127:0] stalled_data;
reg [15:0] stalled_keep;
reg stalled_last;
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
    .protected_locked(protected_locked), .protected_bytes(protected_bytes),
    .security_abort(security_abort),
    .release_committed(release_committed), .release_cancel_request(release_cancel_request),
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
    .protected_locked(protected_locked), .protected_bytes(protected_bytes),
    .security_abort(security_abort),
    .release_committed(release_committed), .release_cancel_request(release_cancel_request),
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
        if(mode == 2'd1)
            gcm_write(7'h00, 32'h11);
        else
        begin
            gcm_write(7'h00, 32'h04);
            gcm_write(7'h0C, 32'd2);
            gcm_write(7'h40, expected_tag[127:96]);
            gcm_write(7'h44, expected_tag[95:64]);
            gcm_write(7'h48, expected_tag[63:32]);
            gcm_write(7'h4C, expected_tag[31:0]);
            gcm_write(7'h00, 32'h02);
        end
        while(!gcm.gcm_ready) @(posedge aclk);
        gcm_write(7'h00, 32'h09);
    end
endtask

task expect_denied;
    begin
        repeat(40) @(posedge aclk);
        gcm_read(7'h68, status);
        if(!status[8] || status[2] || any_output_seen)
            $fatal(1,"Denied operation leaked or retained grant: %08h",status);
    end
endtask

task authenticate_valid;
    begin
        while(buffer.state == 3'd4) @(posedge aclk);
        if(!protected_locked) capture_ciphertext(1'b0);
        any_output_seen = 0;
        begin_gcm(2'd2, EXPECTED_TAG);
        buffer_write(6'h00, 32'h2);
        while(!gcm.stream_done) @(posedge aclk);
        gcm_read(7'h68, status);
        if(!status[2] || status[8] || any_output_seen)
            $fatal(1,"Authentication did not create a silent one-use grant");
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
            $fatal(1,"Test failed");
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

always @(posedge aclk)
    if(aresetn && release_tvalid &&
       (!protected_locked || gcm.guard_phase != 3'd3))
        $fatal(1,"Output without matching locked transaction and release phase");

integer scenarios = 0;
integer race_kind;
integer skew;
integer final_kind;
integer collision_count = 0;
integer output_count = 0;
reg auth_history = 0;
reg release_history = 0;
reg monitor_started = 0;
reg [127:0] held_data;
reg [15:0] held_keep;
reg held_last;

// History monitor: observes successful crypto completion, accepted writes,
// lock loss and output handshakes; it does not use guard_phase to authorize output.
always @(posedge aclk) begin
    if (!aresetn || !protected_locked || security_abort || gcm.guard_soft_reset) begin
        auth_history <= 0;
        release_history <= 0;
        output_count <= 0;
    end else begin
        if (gcm.ghash_done && gcm.auth_state == gcm.AUTH_WAIT_LENGTH &&
            gcm.operation_mode == 2 && gcm.completed_tag == EXPECTED_TAG &&
            gcm.byte_count == 21 && protected_bytes == 21)
            auth_history <= 1;
        if (gcm.write_fire && gcm.write_addr == 0 &&
            gcm.control_write_value == 32'h11 && auth_history)
            release_history <= 1;
        if (release_tvalid && release_tready) begin
            if (!auth_history || !release_history)
                $fatal(1,"History monitor: output without prior authenticated release");
            if (output_count >= 2) $fatal(1,"History monitor: duplicate output");
            output_count <= output_count + 1;
            if (release_tlast) begin
                if (output_count != 1 || release_tkeep != 16'h001f)
                    $fatal(1,"History monitor: wrong final byte count");
                auth_history <= 0;
                release_history <= 0;
            end
        end
    end
end

integer axis_violations=0;
reg was_stalled=0;
reg [127:0] previous_data;
reg [15:0] previous_keep;
reg previous_last;
always @(posedge aclk) begin
    if(!aresetn) was_stalled <= 0;
    else begin
        if(was_stalled && (!release_tvalid || release_tdata!==previous_data ||
           release_tkeep!==previous_keep || release_tlast!==previous_last)) begin
            axis_violations=axis_violations+1;
            $display("AXIS_PROTOCOL_VIOLATION pending beat withdrawn/changed without interface reset at %0t",$time);
            if(1)
                $fatal(1,"AXIS stalled beat must remain valid/stable until handshake or reset");
        end
        was_stalled <= release_tvalid && !release_tready;
        previous_data <= release_tdata;
        previous_keep <= release_tkeep;
        previous_last <= release_tlast;
    end
end

task fresh;
    begin
        @(negedge aclk);
        aresetn=0; release_tready=0; release_check_active=0;
        g_awvalid=0; g_wvalid=0; g_bready=0;
        repeat(4) @(negedge aclk);
        aresetn=1;
        while(buffer.state != 0) @(negedge aclk);
        configure_gcm();
        any_output_seen=0;
    end
endtask

task start_auth;
    begin
        capture_ciphertext(0);
        begin_gcm(2,EXPECTED_TAG);
        buffer_write(0,2);
    end
endtask

task finish_response;
    begin
        @(negedge aclk); g_awvalid=0; g_wvalid=0;
        while(!g_bvalid) @(negedge aclk);
        // Exercise response backpressure as well as request-channel skew.
        repeat(7) @(negedge aclk);
        g_bready=1;
        @(negedge aclk); g_bready=0;
    end
endtask

// A pending address or data channel may arrive before authentication finishes.
// Complete the write when a real GHASH completion is pending for the next clock.
// Invalid writes may combinationally reset GHASH before that clock; this is
// intentional cancellation, not simultaneous successful tag consumption.
task collide_at_auth;
    input integer kind;
    input integer channel_skew; // -1: W first, 0: together, 1: AW first
    reg [6:0] address;
    reg [31:0] value;
    begin
        address=(kind==0 ? 7'h20 : 7'h00);
        value=(kind==0 ? 32'hbad : (kind==1 ? 32'h11 : 32'h04));
        @(negedge aclk);
        g_awaddr=address; g_wdata=value; g_wstrb=15;
        if(channel_skew==1) begin
            g_awvalid=1;
            @(posedge aclk); if(!g_awready) $fatal(1,"AW not accepted");
            @(negedge aclk); g_awvalid=0;
        end
        if(channel_skew==-1) begin
            g_wvalid=1;
            @(posedge aclk); if(!g_wready) $fatal(1,"W not accepted");
            @(negedge aclk); g_wvalid=0;
        end
        while(!(gcm.ghash_done && gcm.auth_state==gcm.AUTH_WAIT_LENGTH))
            @(negedge aclk);
        if(channel_skew!=1) g_awvalid=1;
        if(channel_skew!=-1) g_wvalid=1;
        @(posedge aclk);
        if(!gcm.write_fire)
            $fatal(1,"Collision missing fire=%b done=%b auth=%d awv=%b awr=%b wv=%b wr=%b holdAW=%b holdW=%b B=%b",gcm.write_fire,gcm.ghash_done,gcm.auth_state,g_awvalid,g_awready,g_wvalid,g_wready,gcm.aw_hold_valid,gcm.w_hold_valid,g_bvalid);
        collision_count=collision_count+1;
        finish_response();
        repeat(10) @(negedge aclk);
        gcm_read(7'h68,status);
        if(status[2] || status[3] || any_output_seen)
            $fatal(1,"Completion collision retained grant/output: %h",status);
        if(kind!=2 && !status[8]) $fatal(1,"Missing denial status");
    end
endtask

task positive_release;
    begin
        authenticate_valid();
        release_words=0; release_error=0; release_check_active=1;
        release_tready=0;
        begin_gcm(1,EXPECTED_TAG);
        buffer_write(0,2);
        while(!release_tvalid) @(negedge aclk);
        held_data=release_tdata; held_keep=release_tkeep; held_last=release_tlast;
        repeat(13) begin
            @(negedge aclk);
            if(!release_tvalid || release_tdata!==held_data ||
               release_tkeep!==held_keep || release_tlast!==held_last)
                $fatal(1,"First beat changed while stalled");
        end
        release_tready=1;
        @(posedge aclk);
        @(negedge aclk); release_tready=0;
        while(!release_tvalid || !release_tlast) @(negedge aclk);
        held_data=release_tdata; held_keep=release_tkeep;
        repeat(17) begin
            @(negedge aclk);
            if(!release_tvalid || !release_tlast || release_tdata!==held_data ||
               release_tkeep!==held_keep) $fatal(1,"Final beat changed while stalled");
        end
        release_tready=1;
        while(!gcm.stream_done) @(negedge aclk);
        repeat(3) @(negedge aclk);
        release_check_active=0;
        if(release_words!=2 || release_error) $fatal(1,"Positive exact bytes failed");
        any_output_seen=0;
        gcm_write(0,32'h11);
        expect_denied();
    end
endtask

initial begin
    // Nine pending tag-completion collisions, with three legal AXI channel orders.
    for(race_kind=0;race_kind<3;race_kind=race_kind+1)
        for(skew=-1;skew<=1;skew=skew+1) begin
            fresh(); start_auth(); collide_at_auth(race_kind,skew);
            scenarios=scenarios+1;
            $display("RACE_PASS AUTH_COMPLETION kind=%0d channel_order=%0d",race_kind,skew);
        end
    // Five cancellations after the first 16 bytes, while the last 5 bytes wait.
    for(final_kind=0;final_kind<5;final_kind=final_kind+1) begin
        fresh(); authenticate_valid();
        release_tready=0; begin_gcm(1,EXPECTED_TAG); buffer_write(0,2);
        while(!release_tvalid) @(negedge aclk);
        release_tready=1;
        @(posedge aclk);
        @(negedge aclk); release_tready=0;
        while(!release_tvalid || !release_tlast) @(negedge aclk);
        held_data=release_tdata; held_keep=release_tkeep;
        case(final_kind)
            0: begin aresetn=0; repeat(4) @(negedge aclk); aresetn=1; end
            1: gcm_write(0,4);
            2: gcm_write(7'h20,32'hbad);
            3: gcm_write(0,32'h11);
            4: buffer_write(0,4);
        endcase
        if(final_kind==0) begin
            repeat(5) @(negedge aclk);
            if(release_tvalid || release_tdata!==0)
                $fatal(1,"Hardware reset did not cancel output");
        end else begin
            repeat(9) begin
                @(negedge aclk);
                if(!release_tvalid || !release_tlast || release_tdata!==held_data ||
                   release_tkeep!==held_keep || !protected_locked)
                    $fatal(1,"Committed final beat changed on cancellation kind=%0d",final_kind);
            end
            gcm_read(7'h68,status);
            if(!status[9] || !status[8]) $fatal(1,"Deferred cancellation status missing");
            @(negedge aclk); release_tready=1;
            @(posedge aclk);
            @(negedge aclk); release_tready=0;
        end
        while(buffer.state!=0) @(negedge aclk);
        any_output_seen=0; release_tready=1;
        repeat(30) @(negedge aclk);
        if(any_output_seen) $fatal(1,"Output after completed drain/cleanup");
        // A fresh capture must not acquire the cancelled transaction's permission.
        capture_ciphertext(0); gcm_write(0,32'h11);
        repeat(10) @(negedge aclk);
        if(release_tvalid || any_output_seen) $fatal(1,"Permission survived recapture");
        scenarios=scenarios+1;
        $display("RACE_PASS FINAL_BEAT_CANCEL_OR_DRAIN kind=%0d",final_kind);
    end
    // Both control slaves accept these commands on the same edge. The buffer
    // must see release commitment immediately, before guard_phase is registered.
    fresh(); authenticate_valid();
    release_words=0; release_error=0; release_check_active=1; release_tready=0;
    fork
        gcm_write(0,32'h11);
        buffer_write(0,32'h4);
    join
    while(!gcm.gcm_ready) @(negedge aclk);
    gcm_read(7'h68,status);
    if(!status[9] || !protected_locked) $fatal(1,"Commit/cancel race lost capture");
    buffer_write(0,2);
    @(negedge aclk); release_tready=1;
    while(buffer.state!=0) @(negedge aclk);
    release_check_active=0;
    if(release_words!=2 || release_error) $fatal(1,"Commit/cancel race corrupted packet");
    scenarios=scenarios+1;
    $display("RACE_PASS SIMULTANEOUS_RELEASE_COMMIT_AND_BUFFER_SCRUB");
    fresh(); positive_release(); scenarios=scenarios+1;
    $display("RACE_PASS VALID_RELEASE_STALLS_AND_SINGLE_USE");
    if(scenarios!=16 || collision_count!=9) $fatal(1,"Coverage count mismatch");
    $display("AXIS_PROTOCOL_VIOLATIONS %0d",axis_violations);
    if(axis_violations!=0) $fatal(1,"AXIS protocol stability failed");
    $display("CANDIDATE_RACES_PASS scenarios=%0d pending_completion_collisions=%0d",scenarios,collision_count);
    $finish;
end
initial begin
    #3000000;
    $fatal(1,"Controller race test timeout");
end
endmodule
