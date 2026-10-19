`timescale 1ns / 1ps

module tb_CommittedPacket;

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
reg [127:0] EXPECTED_TAG;

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

task select_fixture;
 input integer n;
 begin
 case(n)
 1: begin
 chunk_length=1; EXPECTED_TAG=128'hb3794b73bfb2dbce28b586dbd5ceaea9;
 ciphertext[0]=128'h04000000000000000000000000000000;
 end
 16: begin
 chunk_length=16; EXPECTED_TAG=128'h611fd7f08d43d860b663bdb8bfbf7e26;
 ciphertext[0]=128'h04ac9b901b2e16401c24ebff123263c2;
 end
 17: begin
 chunk_length=17; EXPECTED_TAG=128'h548ccdc4ead5602ceb23d14bb318ebed;
 ciphertext[0]=128'h04ac9b901b2e16401c24ebff123263c2;
 ciphertext[1]=128'h20000000000000000000000000000000;
 end
 21: begin
 chunk_length=21; EXPECTED_TAG=128'hefa5158e78f1f13a15d488738e8e74be;
 ciphertext[0]=128'h04ac9b901b2e16401c24ebff123263c2;
 ciphertext[1]=128'h2061bb85020000000000000000000000;
 end
 4096: begin
 chunk_length=4096; EXPECTED_TAG=128'h2cb824290c4e65306a22f1355d372038;
 ciphertext[0]=128'h04ac9b901b2e16401c24ebff123263c2;
 ciphertext[1]=128'h2061bb850223dc81482170e9a7dbac6a;
 ciphertext[2]=128'h87c6f0df554bc1a8af257f4ad3b396ba;
 ciphertext[3]=128'hbed913d7fa860c3f2402250a1a3385d8;
 ciphertext[4]=128'hcdbafc1b1336c073403d4d2f76e7df6b;
 ciphertext[5]=128'h828c1c751d6e551dd031da5d817c242a;
 ciphertext[6]=128'he5575950491d91421555056ee0635c44;
 ciphertext[7]=128'h849117be6d56191cf3d7a308ced8722a;
 ciphertext[8]=128'h59173bb96fe0c8dd3a24240d399d75c8;
 ciphertext[9]=128'h44085866ffc8025c43aef324dabbe0fa;
 ciphertext[10]=128'h7a552455c3148558219fe8f335bb3a3f;
 ciphertext[11]=128'h314e5c9bbc7f0d82ba29b849a712fea2;
 ciphertext[12]=128'ha7e648738d67d12bb422d179804351ef;
 ciphertext[13]=128'h308b5cea3cc8d43dc3796e70de9d8640;
 ciphertext[14]=128'h3f36e2a51b46cb301a63c9854a891162;
 ciphertext[15]=128'h3344cf72662e714976e1590b78535777;
 ciphertext[16]=128'hbb7a65ab623c082697bdf0aa68e78fe5;
 ciphertext[17]=128'hff447fd4ee35fce3950ad1c263d9ae49;
 ciphertext[18]=128'ha33dac4db925a3bf20c1e7c83815691b;
 ciphertext[19]=128'h9862fb17ee2fc210fbce720203510a26;
 ciphertext[20]=128'ha58619b09cf72e6edbf9ed36366024ad;
 ciphertext[21]=128'hea8c79061f9f269f3b9713850a565e0c;
 ciphertext[22]=128'h0e53cf49f4c019d75b77a808af25bfb2;
 ciphertext[23]=128'hd2306174cf628b03a724752982d2a9a8;
 ciphertext[24]=128'h9a264fd48dc61ee4d4e32f58bdef025b;
 ciphertext[25]=128'hda9943dba9692eb82bb4e0fcefe5c0f9;
 ciphertext[26]=128'ha63a01a87798c4685de443076fb9ebf8;
 ciphertext[27]=128'h9566716f46646f938016af087444d5d3;
 ciphertext[28]=128'h8f4c37b9e578296c6f0e61333f74d66b;
 ciphertext[29]=128'heef50ce468f1d11241ff609cb778296b;
 ciphertext[30]=128'h5d305aa3f083b6441666a582deffad97;
 ciphertext[31]=128'hf1f385960a8de6dca7a74edc4898cb1d;
 ciphertext[32]=128'h38e42f036f7ec02703842965b777af2c;
 ciphertext[33]=128'hc528f58eaed4fc89e486aceff1a3638d;
 ciphertext[34]=128'h0ae47817b711557525f2dbb668cdbf2b;
 ciphertext[35]=128'h3746d0daa7d643afeacfbe65256455ee;
 ciphertext[36]=128'hd5c06aaba5a9b5512d07fb4b15491471;
 ciphertext[37]=128'h965a19ca9c3c613163e65211d6a4abef;
 ciphertext[38]=128'hffa498bab61503cd68a9d8473bc9e3a2;
 ciphertext[39]=128'hb445e9ca8fba599dbfed1fe8038f639e;
 ciphertext[40]=128'h0285160e296cff56d3d849b9aad7321a;
 ciphertext[41]=128'he28e9689f48cc7dafb6e9a290f3073ee;
 ciphertext[42]=128'hbd34f314965a69ec43805f08dc473afd;
 ciphertext[43]=128'h408ab74115cd0a9d821228930950cc0d;
 ciphertext[44]=128'hdf768a6019017e1d302158114942cedc;
 ciphertext[45]=128'h73c3d0689f0af49f7fe007ef552c88a0;
 ciphertext[46]=128'h798a06926c1f526c64ffd5d1fc19ef6c;
 ciphertext[47]=128'ha53732815e6ffe840a75949eb3e8ce0c;
 ciphertext[48]=128'h963edaf4cb67cc8e98cd858f7c9d46a4;
 ciphertext[49]=128'hbe6897d3f3b769b983fb2d06e92ab711;
 ciphertext[50]=128'ha1300b6b5a76aad29af0cb3ed9830404;
 ciphertext[51]=128'h46465291810c98575b086334eed5e827;
 ciphertext[52]=128'heb86f15d69633bd81db1e8d87d55548d;
 ciphertext[53]=128'h59eb7bd39428d04432c15ed5420bfafc;
 ciphertext[54]=128'h55317cc9cba816856f906fe103e29b77;
 ciphertext[55]=128'h68dd5bd17fc80ae083894d64b9766825;
 ciphertext[56]=128'h06439c0c10bee51989954d82ba637a81;
 ciphertext[57]=128'h5fb9559d1053978a8e40285782b6f270;
 ciphertext[58]=128'ha4161264c1078019562bd25b88253366;
 ciphertext[59]=128'h06ffabe1bfff06057ab594df1a19aa27;
 ciphertext[60]=128'h79ed39eba6fbace222e89a1fd377cb94;
 ciphertext[61]=128'hcc7eb930bd9ed75503194f87ae3a1eab;
 ciphertext[62]=128'h3983ab6088c53b3b41bc7c18d05cf499;
 ciphertext[63]=128'h110e8cc9ad020227c52fb5dcb20424c1;
 ciphertext[64]=128'hbe84f9cce394a985f1a35d464e04613a;
 ciphertext[65]=128'hc110ee3736f3b0df796c29c66cc12789;
 ciphertext[66]=128'h00957d57d5629d933a71543cd26d03a7;
 ciphertext[67]=128'h510a8834a5606893a8a814742becfe2f;
 ciphertext[68]=128'h11450b2d7dca3bc9063f47d96ff9252d;
 ciphertext[69]=128'h53beddba0550b6140e2000074c5dad34;
 ciphertext[70]=128'h3a6f98452d3a50a639b309396e1a1dda;
 ciphertext[71]=128'h26802a9f656410d25a2daf2d321fe28f;
 ciphertext[72]=128'h2722fe02799528abb49322694d1c342a;
 ciphertext[73]=128'hd171dae8a9c39a6aa7df0ad8818a60db;
 ciphertext[74]=128'h545c5f701480d96486e896571755fab8;
 ciphertext[75]=128'he39c0ec2a4d2d36ce9cf1984a0836a3d;
 ciphertext[76]=128'h1872a766ec0cce2290a37d16d4de970a;
 ciphertext[77]=128'h85b8b2030514a8f4e04d59e17a1699cb;
 ciphertext[78]=128'heea060f5ff3be3134ffdced5d9af4313;
 ciphertext[79]=128'hc147bac42f1c1ea35582ac13f9a7987b;
 ciphertext[80]=128'h1a79a51080cfcc6539faf533f989d2e5;
 ciphertext[81]=128'h3780c2f191a1d63877e0e1767d00ca87;
 ciphertext[82]=128'hc7022cda0c3047bc0f0ff8c93d482d7a;
 ciphertext[83]=128'h29cf654ca1067ce1648d72f8951a54cb;
 ciphertext[84]=128'h7531f75b704fa138fd91317dde0c5119;
 ciphertext[85]=128'h4cf57986933bf9eec4dacbdfd809638c;
 ciphertext[86]=128'hd02ba2eccf01222a2aef257cfa93cd30;
 ciphertext[87]=128'h4d863800f38b726acd8ca9a6eb2ed00c;
 ciphertext[88]=128'h937eb3378409068e6757565bb3662804;
 ciphertext[89]=128'h1dc273ba7cbef2d829c0646cbe3f687c;
 ciphertext[90]=128'h659023321390acc8cd3658e9c5ed2a30;
 ciphertext[91]=128'h30f8ef29670b62eca19b294565327b8f;
 ciphertext[92]=128'h6cccc3d1ba38a497d8d0a039e71985f1;
 ciphertext[93]=128'h93f5727f4630c535e11ff68a10c4c99a;
 ciphertext[94]=128'h7c7e391f560858622a5598a37c02bf5a;
 ciphertext[95]=128'hd3aa11115f352055e21b45e6a3b1e7cd;
 ciphertext[96]=128'h7332ae59190208163246e14deacabad3;
 ciphertext[97]=128'h7a536e2851affff9c36a687064523978;
 ciphertext[98]=128'h8f0c53faf38dfcdc7d50f511d500b166;
 ciphertext[99]=128'h57661ed8fc75f503b4152a8e5ce85a20;
 ciphertext[100]=128'h5187140e52680214615edfbb5e94ad8d;
 ciphertext[101]=128'h6042c4f19d1dbc36cbcada3abde2984e;
 ciphertext[102]=128'h27eac0c4798acc3eda0f55729eeaebb0;
 ciphertext[103]=128'h5cbe5d1c91cbc2b98d7ce9264c21970d;
 ciphertext[104]=128'h9f5177066945d87760bbb8cf0ec80943;
 ciphertext[105]=128'h7192166f7dc3ad1cdd2458ab590bd3a7;
 ciphertext[106]=128'h778598fe25a1134da8ca816080bfd577;
 ciphertext[107]=128'hdb26b956cdbf23249f806714f389d677;
 ciphertext[108]=128'hc08159b910828f32ed200693feeadd7d;
 ciphertext[109]=128'h31efb59236e74d34d1561aaf6af64d74;
 ciphertext[110]=128'h14b629cf8395ecda4687788a6541fab8;
 ciphertext[111]=128'h3d2874e832de4e8bf5b187d19487976b;
 ciphertext[112]=128'h62b8ba4328c6eb9459ba8fd8f3659eed;
 ciphertext[113]=128'h48f8002a39c0c055c1b011bd2d7741a7;
 ciphertext[114]=128'h32cd02a20c08f6cf6e10d1088d2c5257;
 ciphertext[115]=128'h13abfdf4edc95da59eabec463c669cc5;
 ciphertext[116]=128'h34f8592eb18beb7aac2f29f84fd10c05;
 ciphertext[117]=128'h40781f04c436fc10be3c25b561099d01;
 ciphertext[118]=128'h744d2ff55da885a32b6c70a896287f79;
 ciphertext[119]=128'heb17e78f115c7c1c5b13e534294aaac3;
 ciphertext[120]=128'h57fa9dd0b4a67c4fb78fff3f05ef136e;
 ciphertext[121]=128'h5ed07eceedf7ba2cdc5d584db11113e3;
 ciphertext[122]=128'h6695626762d08bd6ac449bacbcadbe3a;
 ciphertext[123]=128'h28c40d4995ea6204828ffb178c1abdd3;
 ciphertext[124]=128'h1b393a668e3aa3e04be88801d89377ed;
 ciphertext[125]=128'ha32f230392c0370eceeffa9f16d564d0;
 ciphertext[126]=128'h98cd1961916fded2775f6fc75482f0b7;
 ciphertext[127]=128'hd7d9a32bb6f2818aa21d5dc05615d1e3;
 ciphertext[128]=128'hb61a7984bc4998776a257b6953444fa6;
 ciphertext[129]=128'h49d7091b334f6a4f58e032e8c2ceab21;
 ciphertext[130]=128'ha989723fda90d0cab8074a45fe243efd;
 ciphertext[131]=128'h9195d0599fd2e0648003f6b7ca9271d5;
 ciphertext[132]=128'hfebbdf9edde4667f394d8078ef241346;
 ciphertext[133]=128'hbf5db17e9a72ba67c0d9316b1945a4ef;
 ciphertext[134]=128'h322ffbe626dd722982592056445b4668;
 ciphertext[135]=128'h772ffc721f934f715cb5bb227091e87d;
 ciphertext[136]=128'hf8b5def22ab15a8eaeef3743faab2610;
 ciphertext[137]=128'h410d1feae730e6def9828afe949c846c;
 ciphertext[138]=128'h0207e90ddef6aa34c81b9aff2995e0a5;
 ciphertext[139]=128'h0361f11f43124ffed069c47c192c10b3;
 ciphertext[140]=128'hcd7a71cc5851be7c6cd3693756c47331;
 ciphertext[141]=128'hcd085e6e0d2a85193065e3caff1eeec4;
 ciphertext[142]=128'h85e802ea75dc3aa786e7daf57d7b81f1;
 ciphertext[143]=128'h96f26d887268da5bb416ec34c3b05ffb;
 ciphertext[144]=128'h59548f4d263890acb3fd01b20db4c520;
 ciphertext[145]=128'hed325f27b5e5ea584a01b2ed4f57b93d;
 ciphertext[146]=128'he3e82f06df2abb3c763f49842eae6900;
 ciphertext[147]=128'hdef506ddb6117f39cb83f807709569c8;
 ciphertext[148]=128'h93c5978bd1647f3c47f18185d30bea04;
 ciphertext[149]=128'hdb8adb3f50334c3300a6465322e8cc2a;
 ciphertext[150]=128'hb91d8c695bdb26dcbdb0ac56b7ca5b30;
 ciphertext[151]=128'hd1388ac18a0ddc3cc94f2e62b22248a1;
 ciphertext[152]=128'hc68f01abe1a7998c5c4b57e1250b5047;
 ciphertext[153]=128'h930e59698500b595cfe8e90eb558fd60;
 ciphertext[154]=128'h4f0997bb823c5a2d1a93fb4651856204;
 ciphertext[155]=128'hf2a9d4a449b8d93065e20624071ceb22;
 ciphertext[156]=128'h9c0db3c572347aaee41ab6521d62c673;
 ciphertext[157]=128'h5d3734929e9381bdc6009313304c1f0d;
 ciphertext[158]=128'heed44e62b6c131c5358726db23b9db1c;
 ciphertext[159]=128'h265b7cd7f392746fc213a81dd4bc543b;
 ciphertext[160]=128'ha5249f425a16245122f2a86dd99aa302;
 ciphertext[161]=128'h95efab691771b7930cfe87cdf6160ca6;
 ciphertext[162]=128'h5132c7b9b52e2141b78be0ed2872c98c;
 ciphertext[163]=128'hd8a8738b4c6d0a019065f789887414a1;
 ciphertext[164]=128'he3474f5bcc663cf5c655d94ea0906b2e;
 ciphertext[165]=128'h1f461da31723ba9f82c0feb079402946;
 ciphertext[166]=128'ha70015706cf63c559e1bf05b7810b7e0;
 ciphertext[167]=128'heeb21cbb06a647ffd8d58ace92a8f83f;
 ciphertext[168]=128'he91d8d264509db30b5d9666a842a32b7;
 ciphertext[169]=128'h86f42be5d578cbbe3d4a366c80a874b5;
 ciphertext[170]=128'h11bd21ba60cf87a2deb644518e3edb19;
 ciphertext[171]=128'hf128e22da331455bd2648fba075b09b5;
 ciphertext[172]=128'hea4eeb04b06238f972b3dab36b0fae57;
 ciphertext[173]=128'h7806dc3c50ccc03d673b93467193d1d2;
 ciphertext[174]=128'h9a90b6b7bb6bd773df3143d971b1bb89;
 ciphertext[175]=128'hf6c32c4b4e9b653641c9c7b158a53020;
 ciphertext[176]=128'hec6237761a99f44dbb62d92104ba4699;
 ciphertext[177]=128'h02f68ff4e36c9d5828b2c1556397aa2a;
 ciphertext[178]=128'hfbdd335eb33cd0f73e99f53bbeedfef7;
 ciphertext[179]=128'h1eb89cc98702845b24d9a309f4b50e42;
 ciphertext[180]=128'hb4aed79d6b8e25104c4ab3d81ef11130;
 ciphertext[181]=128'he911bea50d12600eeeef9ad791f7a0ef;
 ciphertext[182]=128'h3d4abfdae664c0be525004a9ce5faa40;
 ciphertext[183]=128'he9534ec0401a5564b121b24c17f99d41;
 ciphertext[184]=128'h9ea16a078ee1d51c23bab70990b5e63d;
 ciphertext[185]=128'h45a9a66d3745810d39690010a2f482df;
 ciphertext[186]=128'h2c6aeab49edc7a62a327777160c39d08;
 ciphertext[187]=128'h9dd3cdf8c92068164e7ec67e6b6098b1;
 ciphertext[188]=128'h7391a0b952de2ca2ae876fdf8b8685a7;
 ciphertext[189]=128'h68c075f871c4c214353b2c5e5603757f;
 ciphertext[190]=128'ha2a3787cec02af4bf35c770dc88220b5;
 ciphertext[191]=128'hab36e89d4a1f599b0de3b17d862b7578;
 ciphertext[192]=128'h52dc077f4ab259238fa258813aab499e;
 ciphertext[193]=128'h1edfbc2e66070f96c573128e5789ec30;
 ciphertext[194]=128'h6952664d82868f677e2dd2e6af936fc8;
 ciphertext[195]=128'h4f862e73a2101ed595e852b801baee5a;
 ciphertext[196]=128'hf6ac869a33d4c4e98e42858f18db9951;
 ciphertext[197]=128'h9f0dd9808f001b7c5d44ab2bfaebdc9d;
 ciphertext[198]=128'h24eaa1ecd912633e60dd0465b64e84e0;
 ciphertext[199]=128'h3931e2e962d3466fb95187ace0968bd7;
 ciphertext[200]=128'ha264e1f34a5bc53725e51a0eef557c35;
 ciphertext[201]=128'h5b9ec8ff8641e24553bd5a01417771ad;
 ciphertext[202]=128'hd99f5335be582f8bb7c73ae35411a8b3;
 ciphertext[203]=128'h24b3ed1cbb71aa692fcf696f1180758b;
 ciphertext[204]=128'h2b94c5b19bd619637333b94e98434f2b;
 ciphertext[205]=128'h1f73a28d272d29a04f5ac92d05234476;
 ciphertext[206]=128'hedf6c3692033db2f01507d6135d01238;
 ciphertext[207]=128'h3ed09818785e87544997f7df37f650c5;
 ciphertext[208]=128'h7f941f706ede1ef49125c6aea6df72ca;
 ciphertext[209]=128'h284a7eff61350e151f10333314d7c140;
 ciphertext[210]=128'hc4ec90b4922565605b714c7c174c3154;
 ciphertext[211]=128'he31135521941aa0259a460f2ab9f2564;
 ciphertext[212]=128'h51a549288a04fdc0f3705357e3c7b3d5;
 ciphertext[213]=128'h92722e58692ccc5a694e7a6f6d760af2;
 ciphertext[214]=128'h640ccc3da9bdf86a7693b72f741270c5;
 ciphertext[215]=128'h64638905f0db67f8894267ef88162abc;
 ciphertext[216]=128'haa5c9e80bdcebe4c2f73a0da08861cc5;
 ciphertext[217]=128'h102574453bf6e65fefecbcdf5acbce4a;
 ciphertext[218]=128'h05675af332469e04d231a311747ee822;
 ciphertext[219]=128'hd078e1f9075513c8818724e63d55b253;
 ciphertext[220]=128'h48186a9cf04f322bcef84fe78d40ce9b;
 ciphertext[221]=128'h39576c1ee4b148c07604ae3caac0814a;
 ciphertext[222]=128'h9fd47e28ab3275e8c2af214fc922efef;
 ciphertext[223]=128'h63f65fed14811f8d785d38de4083eba3;
 ciphertext[224]=128'h7249a6b5676bcbc4e76ea6a715531f76;
 ciphertext[225]=128'h9fb976075fc8541123c0f8798cfb19ee;
 ciphertext[226]=128'h0763e48da5758283bb17ee47ae7c6e83;
 ciphertext[227]=128'h76820822400c9290bfb5700483fc75c7;
 ciphertext[228]=128'h944f2d975cd58d2720e39c864b83f0cf;
 ciphertext[229]=128'h1363d67ba3f5cb545c2bf308941ef75a;
 ciphertext[230]=128'h1193542b4575be315b0b73016abc62c2;
 ciphertext[231]=128'h9d68eb870f21cf550aac98618dac8ec8;
 ciphertext[232]=128'hae50d424de703f9d9339b8acf6c244f0;
 ciphertext[233]=128'hc5191d6f04f6f2136ec64160e05ed2d6;
 ciphertext[234]=128'hed6880621a72534fda81bdec2b56ef23;
 ciphertext[235]=128'h5105b894028f00f3e6a128707bef3168;
 ciphertext[236]=128'h09649a91ab5e87c1e35003fd99538289;
 ciphertext[237]=128'h57dcd37922a74665cb39944a025e8f94;
 ciphertext[238]=128'h6bb2598fa07124542d15d126cd244ea6;
 ciphertext[239]=128'h5d7751a1b1371b01579762d8b217f8f3;
 ciphertext[240]=128'h4c1224056d561897d01258dcedcd5385;
 ciphertext[241]=128'h702815a7e90cb7d9d9bb737916d53758;
 ciphertext[242]=128'h9cb3b13ca603aca18da337451037bfa0;
 ciphertext[243]=128'h8643c7ef53214d6d2c10027cc2a6bc03;
 ciphertext[244]=128'hcafb224c6bdc567ce6d302d5684740ff;
 ciphertext[245]=128'h41c59870d29574152b0f5efc13a3dec9;
 ciphertext[246]=128'he30694200558cc02d02770b7d384a1b6;
 ciphertext[247]=128'hd5ba063180b917f08fb135715c56d9a1;
 ciphertext[248]=128'hef44b95406362b693259cf9819fc4f34;
 ciphertext[249]=128'h84db5b025f3b1f05c171d1e6a50d3975;
 ciphertext[250]=128'h17be714beff24c36f7e91431933aa8d3;
 ciphertext[251]=128'h9bc3a11621d93daec7ff7569cb64c520;
 ciphertext[252]=128'h643a88a7ad4ab7ed9a03c9b9b5df9579;
 ciphertext[253]=128'h60b90f17308e60ea5bb6b7b123c668aa;
 ciphertext[254]=128'h9cd26db76d78a4e23336dbb25dc90d66;
 ciphertext[255]=128'h7ee2ecd212207aafb1c3d0352a0a8ed5;
 end
 default: $fatal(1,"Unsupported fixture");
 endcase
 end
endtask

integer chunk_length;
reg [127:0] ciphertext [0:255];
integer lengths [0:4];
integer li, attack, cases_run=0;
integer expected_words;
integer counted_words=0;
integer byte_i;
reg check_output=0;
reg [127:0] want_word;
reg [15:0] want_keep;
reg [7:0] stall_lfsr=8'hb7;
reg stalled=0;
reg [127:0] last_data;
reg [15:0] last_keep;
reg last_flag;

function [127:0] expected_plaintext;
 input integer word_index;
 integer k, value;
 begin
    expected_plaintext=0;
    for(k=0;k<16;k=k+1) begin
        value=word_index*16+k;
        if(value<chunk_length)
            expected_plaintext[k*8 +: 8]=(value*29+7)&255;
    end
 end
endfunction
function [15:0] expected_keep;
 input integer word_index;
 integer k;
 begin
    expected_keep=0;
    for(k=0;k<16;k=k+1)
        if(word_index*16+k<chunk_length) expected_keep[k]=1;
 end
endfunction

task capture_ciphertext;
 input tampered;
 integer w;
 begin
    expected_words=(chunk_length+15)/16;
    buffer_write(8,chunk_length); buffer_write(0,1);
    for(w=0;w<expected_words;w=w+1)
        capture_word(ciphertext[w],expected_keep(w),w==expected_words-1);
    if(!protected_locked || protected_bytes!=chunk_length) $fatal(1,"Capture not locked");
 end
endtask
always @(posedge aclk) begin
    if(!aresetn) stalled<=0;
    else begin
        if(stalled && (!release_tvalid || release_tdata!==last_data ||
           release_tkeep!==last_keep || release_tlast!==last_flag))
            $fatal(1,"Strict AXIS stability failed");
        stalled<=release_tvalid && !release_tready;
        last_data<=release_tdata;last_keep<=release_tkeep;last_flag<=release_tlast;
        if(release_tvalid && !check_output) $fatal(1,"Unexpected plaintext outside release test");
        if(release_tvalid && release_tready) begin
            want_word=expected_plaintext(counted_words);
            want_keep=expected_keep(counted_words);
            if(counted_words>=expected_words ||
               (release_tdata & axis_keep_mask(want_keep))!==want_word ||
               release_tkeep!==want_keep ||
               release_tlast!==(counted_words==expected_words-1))
                $fatal(1,"Authenticated packet corrupted/duplicated n=%0d attack=%0d word=%0d",chunk_length,attack,counted_words);
            counted_words=counted_words+1;
        end
    end
end

task reset_fixture;
 begin
    @(negedge aclk); aresetn=0; release_tready=0;check_output=0;
    repeat(4) @(negedge aclk);
    aresetn=1;
    while(buffer.state!=0) @(negedge aclk);
    configure_gcm(); counted_words=0;
 end
endtask

initial begin
    lengths[0]=1; lengths[1]=16; lengths[2]=17; lengths[3]=21; lengths[4]=4096;
    for(li=0;li<5;li=li+1)
      for(attack=0;attack<9;attack=attack+1) begin
        reset_fixture(); select_fixture(lengths[li]);
        $display("PACKET_BEGIN n=%0d attack=%0d",chunk_length,attack); $fflush();
        authenticate_valid();
        check_output=1;
        begin_gcm(1,EXPECTED_TAG); buffer_write(0,2);
        while(!release_tvalid) @(negedge aclk);
        case(attack)
            0:gcm_write(7'h20,32'hbad);
            1:gcm_write(0,4);
            2:buffer_write(0,4);
            3:buffer_write(0,8);
            4:buffer_write(0,2);
            5:buffer_write(8,1);
            6:gcm_write(0,0);
            7:gcm_write(7'h10,32'hbad);
            8:gcm_write(0,32'h11);
        endcase
        gcm_read(7'h68,status);
        if(!status[9] || !status[8] || !protected_locked)
            $fatal(1,"Cancellation/lock status failed");
        // Attempt capture overwrite while committed; TREADY must stay low.
        @(negedge aclk);capture_tdata=128'hbad;capture_tkeep=16'hffff;
        capture_tvalid=1; capture_tlast=1;
        repeat(7) begin @(negedge aclk); if(capture_tready) $fatal(1,"Committed buffer accepted overwrite"); end
        capture_tvalid=0;
        while(buffer.state!=0) begin
            @(negedge aclk);
            stall_lfsr={stall_lfsr[6:0],stall_lfsr[7]^stall_lfsr[5]^stall_lfsr[4]^stall_lfsr[3]};
            release_tready=stall_lfsr[0] | stall_lfsr[1];
        end
        if(counted_words!=expected_words) $fatal(1,"Incomplete packet");
        check_output=0;
        repeat(10) @(negedge aclk);
        // Inspect the whole scrubbed memory, not merely its endpoints.
        for(byte_i=0;byte_i<256;byte_i=byte_i+1)
            if(buffer.protected_chunk_memory.memory[byte_i]!==0)
                $fatal(1,"Deferred scrub left memory at word %0d",byte_i);
        cases_run=cases_run+1;
        $display("PACKET_PASS bytes=%0d cancellation=%0d",chunk_length,attack);
      end
    if(cases_run!=45) $fatal(1,"Wrong case count");
    $display("COMMITTED_PACKET_PASS cases=45 strict_axis_violations=0");
    $finish;
end
initial begin #2000000; $fatal(1,"Packet test watchdog"); end
endmodule
