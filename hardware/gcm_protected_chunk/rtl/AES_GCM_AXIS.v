`timescale 1ns / 1ps

// AES-128 GCM accelerator with AXI4-Lite control and 128-bit AXI4-Stream.
// Version 3 supports a 96-bit IV, one 0-to-16-byte AAD block, and arbitrary
// payload length through TKEEP/TLAST. The intended AAD block is the fixed
// 16-byte image metadata header used by the companion Vitis/Python software.
// GHASH is serialized between blocks to preserve authentication state and
// downstream backpressure is fully honored. MODE_AUTH_ONLY authenticates a
// ciphertext stream without ever asserting M_AXIS TVALID. Firmware uses this
// mode before a separate decrypt-and-release pass.
module AES_GCM_AXIS #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 7
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

localparam [6:0] REG_CONTROL       = 7'h00;
localparam [6:0] REG_STATUS        = 7'h04;
localparam [6:0] REG_BLOCKS        = 7'h08;
localparam [6:0] REG_MODE          = 7'h0C;
localparam [6:0] REG_KEY0          = 7'h10;
localparam [6:0] REG_KEY1          = 7'h14;
localparam [6:0] REG_KEY2          = 7'h18;
localparam [6:0] REG_KEY3          = 7'h1C;
localparam [6:0] REG_IV0           = 7'h20;
localparam [6:0] REG_IV1           = 7'h24;
localparam [6:0] REG_IV2           = 7'h28;
localparam [6:0] REG_TAG0          = 7'h30;
localparam [6:0] REG_TAG1          = 7'h34;
localparam [6:0] REG_TAG2          = 7'h38;
localparam [6:0] REG_TAG3          = 7'h3C;
localparam [6:0] REG_EXPECTED_TAG0 = 7'h40;
localparam [6:0] REG_EXPECTED_TAG1 = 7'h44;
localparam [6:0] REG_EXPECTED_TAG2 = 7'h48;
localparam [6:0] REG_EXPECTED_TAG3 = 7'h4C;
localparam [6:0] REG_BYTES         = 7'h50;
localparam [6:0] REG_AAD0          = 7'h54;
localparam [6:0] REG_AAD1          = 7'h58;
localparam [6:0] REG_AAD2          = 7'h5C;
localparam [6:0] REG_AAD3          = 7'h60;
localparam [6:0] REG_AAD_BYTES     = 7'h64;

localparam [2:0] SETUP_IDLE       = 3'd0;
localparam [2:0] SETUP_ISSUE_H    = 3'd1;
localparam [2:0] SETUP_ISSUE_MASK = 3'd2;
localparam [2:0] SETUP_WAIT       = 3'd3;
localparam [2:0] SETUP_READY      = 3'd4;

localparam [1:0] AUTH_IDLE        = 2'd0;
localparam [1:0] AUTH_WAIT_AAD    = 2'd1;
localparam [1:0] AUTH_WAIT_DATA   = 2'd2;
localparam [1:0] AUTH_WAIT_LENGTH = 2'd3;

reg [31:0] key_reg0, key_reg1, key_reg2, key_reg3;
reg [31:0] iv_reg0, iv_reg1, iv_reg2;
reg [31:0] expected_tag_reg0, expected_tag_reg1;
reg [31:0] expected_tag_reg2, expected_tag_reg3;
reg [31:0] aad_reg0, aad_reg1, aad_reg2, aad_reg3;
reg [4:0] aad_bytes_reg;
localparam [1:0] MODE_ENCRYPT   = 2'd0;
localparam [1:0] MODE_DECRYPT   = 2'd1;
localparam [1:0] MODE_AUTH_ONLY = 2'd2;

reg [1:0] operation_mode;
reg stream_enable;
reg load_iv_pulse;
reg soft_reset_pulse;
reg clear_done_pulse;

reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_hold;
reg [C_S_AXI_DATA_WIDTH-1:0] wdata_hold;
reg [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb_hold;
reg aw_hold_valid;
reg w_hold_valid;
reg axi_bvalid;
reg axi_rvalid;
reg [31:0] axi_rdata;

wire aw_accept = s_axi_ctrl_awvalid && s_axi_ctrl_awready;
wire w_accept  = s_axi_ctrl_wvalid && s_axi_ctrl_wready;
wire write_fire = !axi_bvalid && (aw_hold_valid || aw_accept) &&
                  (w_hold_valid || w_accept);
wire [C_S_AXI_ADDR_WIDTH-1:0] write_addr =
    aw_accept ? s_axi_ctrl_awaddr : awaddr_hold;
wire [C_S_AXI_DATA_WIDTH-1:0] write_data =
    w_accept ? s_axi_ctrl_wdata : wdata_hold;
wire [(C_S_AXI_DATA_WIDTH/8)-1:0] write_strb =
    w_accept ? s_axi_ctrl_wstrb : wstrb_hold;

assign s_axi_ctrl_awready = !aw_hold_valid && !axi_bvalid;
assign s_axi_ctrl_wready  = !w_hold_valid && !axi_bvalid;
assign s_axi_ctrl_bresp   = 2'b00;
assign s_axi_ctrl_bvalid  = axi_bvalid;
assign s_axi_ctrl_arready = !axi_rvalid;
assign s_axi_ctrl_rdata   = axi_rdata;
assign s_axi_ctrl_rresp   = 2'b00;
assign s_axi_ctrl_rvalid  = axi_rvalid;

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

wire [31:0] control_write_value = apply_wstrb(32'd0, write_data,
                                               write_strb);
wire [31:0] mode_write_value = apply_wstrb({30'd0, operation_mode},
                                            write_data, write_strb);

always @(posedge aclk)
begin
    if(!aresetn)
    begin
        key_reg0 <= 0; key_reg1 <= 0; key_reg2 <= 0; key_reg3 <= 0;
        iv_reg0 <= 0; iv_reg1 <= 0; iv_reg2 <= 0;
        expected_tag_reg0 <= 0; expected_tag_reg1 <= 0;
        expected_tag_reg2 <= 0; expected_tag_reg3 <= 0;
        aad_reg0 <= 0; aad_reg1 <= 0; aad_reg2 <= 0; aad_reg3 <= 0;
        aad_bytes_reg <= 5'd0;
        operation_mode <= MODE_ENCRYPT;
        stream_enable <= 1'b0;
        load_iv_pulse <= 1'b0;
        soft_reset_pulse <= 1'b0;
        clear_done_pulse <= 1'b0;
        awaddr_hold <= 0;
        wdata_hold <= 0;
        wstrb_hold <= 0;
        aw_hold_valid <= 1'b0;
        w_hold_valid <= 1'b0;
        axi_bvalid <= 1'b0;
    end
    else
    begin
        load_iv_pulse <= 1'b0;
        soft_reset_pulse <= 1'b0;
        clear_done_pulse <= 1'b0;

        if(aw_accept)
        begin
            awaddr_hold <= s_axi_ctrl_awaddr;
            aw_hold_valid <= 1'b1;
        end
        if(w_accept)
        begin
            wdata_hold <= s_axi_ctrl_wdata;
            wstrb_hold <= s_axi_ctrl_wstrb;
            w_hold_valid <= 1'b1;
        end

        if(write_fire)
        begin
            case(write_addr[6:0])
                REG_CONTROL:
                begin
                    stream_enable <= control_write_value[0];
                    load_iv_pulse <= control_write_value[1];
                    soft_reset_pulse <= control_write_value[2];
                    clear_done_pulse <= control_write_value[3];
                end
                REG_MODE:
                    operation_mode <= mode_write_value[1:0];
                REG_KEY0: key_reg0 <= apply_wstrb(key_reg0, write_data, write_strb);
                REG_KEY1: key_reg1 <= apply_wstrb(key_reg1, write_data, write_strb);
                REG_KEY2: key_reg2 <= apply_wstrb(key_reg2, write_data, write_strb);
                REG_KEY3: key_reg3 <= apply_wstrb(key_reg3, write_data, write_strb);
                REG_IV0: iv_reg0 <= apply_wstrb(iv_reg0, write_data, write_strb);
                REG_IV1: iv_reg1 <= apply_wstrb(iv_reg1, write_data, write_strb);
                REG_IV2: iv_reg2 <= apply_wstrb(iv_reg2, write_data, write_strb);
                REG_EXPECTED_TAG0:
                    expected_tag_reg0 <= apply_wstrb(expected_tag_reg0,
                                                     write_data, write_strb);
                REG_EXPECTED_TAG1:
                    expected_tag_reg1 <= apply_wstrb(expected_tag_reg1,
                                                     write_data, write_strb);
                REG_EXPECTED_TAG2:
                    expected_tag_reg2 <= apply_wstrb(expected_tag_reg2,
                                                     write_data, write_strb);
                REG_EXPECTED_TAG3:
                    expected_tag_reg3 <= apply_wstrb(expected_tag_reg3,
                                                     write_data, write_strb);
                REG_AAD0: aad_reg0 <= apply_wstrb(aad_reg0, write_data,
                                                  write_strb);
                REG_AAD1: aad_reg1 <= apply_wstrb(aad_reg1, write_data,
                                                  write_strb);
                REG_AAD2: aad_reg2 <= apply_wstrb(aad_reg2, write_data,
                                                  write_strb);
                REG_AAD3: aad_reg3 <= apply_wstrb(aad_reg3, write_data,
                                                  write_strb);
                REG_AAD_BYTES:
                    aad_bytes_reg <= (write_data[4:0] > 5'd16) ?
                                     5'd16 : write_data[4:0];
                default: ;
            endcase
            aw_hold_valid <= 1'b0;
            w_hold_valid <= 1'b0;
            axi_bvalid <= 1'b1;
        end
        else if(axi_bvalid && s_axi_ctrl_bready)
            axi_bvalid <= 1'b0;
    end
end

wire [127:0] key_value = {key_reg0, key_reg1, key_reg2, key_reg3};
wire [95:0] iv_value = {iv_reg0, iv_reg1, iv_reg2};
wire [127:0] expected_tag_value = {
    expected_tag_reg0, expected_tag_reg1,
    expected_tag_reg2, expected_tag_reg3
};
wire [127:0] aad_value = {aad_reg0, aad_reg1, aad_reg2, aad_reg3};
wire decrypt_mode = (operation_mode == MODE_DECRYPT);
wire auth_only_mode = (operation_mode == MODE_AUTH_ONLY);
wire ciphertext_input_mode = decrypt_mode || auth_only_mode;

reg [2:0] setup_state;
reg setup_response_count;
reg gcm_ready;
reg [127:0] hash_subkey;
reg [127:0] tag_mask;
reg [127:0] active_counter;

reg [127:0] input_hold;
reg [15:0] keep_hold;
reg last_hold;
reg stream_busy;
reg stream_done;
reg [31:0] block_count;
reg [31:0] byte_count;
reg [63:0] final_message_bits;

reg [127:0] output_data;
reg [15:0] output_keep;
reg output_last;
reg output_valid;

reg [127:0] ghash_state;
reg [1:0] auth_state;
reg auth_last;
reg [127:0] ghash_x;
reg [127:0] ghash_h;
reg ghash_start;
wire [127:0] ghash_result;
wire ghash_busy;
wire ghash_done;

reg [127:0] generated_tag;
reg tag_valid;
reg tag_match;
reg auth_fail;
reg final_auth_done;
reg last_output_consumed;

function [127:0] reverse_bytes;
    input [127:0] value;
    integer index;
    begin
        for(index = 0; index < 16; index = index + 1)
            reverse_bytes[127-index*8 -: 8] = value[index*8 +: 8];
    end
endfunction

function [4:0] count_keep_bytes;
    input [15:0] keep;
    integer index;
    begin
        count_keep_bytes = 5'd0;
        for(index = 0; index < 16; index = index + 1)
            count_keep_bytes = count_keep_bytes + keep[index];
    end
endfunction

function [127:0] mask_standard_bytes;
    input [127:0] value;
    input [15:0] keep;
    integer index;
    begin
        mask_standard_bytes = 128'd0;
        for(index = 0; index < 16; index = index + 1)
            if(keep[index])
                mask_standard_bytes[127-index*8 -: 8] =
                    value[127-index*8 -: 8];
    end
endfunction

function [15:0] keep_from_byte_count;
    input [4:0] byte_count_value;
    integer index;
    begin
        keep_from_byte_count = 16'd0;
        for(index = 0; index < 16; index = index + 1)
            if(index < byte_count_value)
                keep_from_byte_count[index] = 1'b1;
    end
endfunction

wire [15:0] aad_keep = keep_from_byte_count(aad_bytes_reg);
wire [127:0] masked_aad = mask_standard_bytes(aad_value, aad_keep);
wire [63:0] aad_length_bits = {59'd0, aad_bytes_reg} * 8;

wire input_fire = s_axis_tvalid && s_axis_tready;
wire output_fire = output_valid && m_axis_tready;
wire setup_issue_h = (setup_state == SETUP_ISSUE_H);
wire setup_issue_mask = (setup_state == SETUP_ISSUE_MASK);
wire aes_request_valid = setup_issue_h || setup_issue_mask || input_fire;
wire [127:0] aes_request_data = setup_issue_h ? 128'd0 :
                               setup_issue_mask ? {iv_value, 32'h00000001} :
                               active_counter;
wire aes_reset = !aresetn || soft_reset_pulse;
wire [1407:0] round_keys;
wire [127:0] aes_result;
wire aes_result_valid;
wire [127:0] payload_result = input_hold ^ aes_result;
wire [127:0] authenticated_ciphertext = mask_standard_bytes(
    ciphertext_input_mode ? input_hold : payload_result, keep_hold);
wire [127:0] completed_tag = tag_mask ^ ghash_result;

assign s_axis_tready = aresetn && stream_enable && gcm_ready &&
                       !stream_busy && !output_valid &&
                       (auth_state == AUTH_IDLE);
assign m_axis_tdata = output_data;
assign m_axis_tkeep = output_keep;
assign m_axis_tlast = output_last;
assign m_axis_tvalid = output_valid;

KeyExpansion u_key_expansion
(
    .key(key_value),
    .round_keys(round_keys)
);

AES_128_Core u_aes
(
    .clk(aclk),
    .rst(aes_reset),
    .data_valid(aes_request_valid),
    .round_keys(round_keys),
    .plaintext(aes_request_data),
    .ciphertext(aes_result),
    .cipher_valid(aes_result_valid)
);

GHASH_Mult32 u_ghash
(
    .clk(aclk),
    .rst(aes_reset),
    .start(ghash_start),
    .x(ghash_x),
    .h(ghash_h),
    .result(ghash_result),
    .busy(ghash_busy),
    .done(ghash_done)
);

always @(posedge aclk)
begin
    if(!aresetn)
    begin
        setup_state <= SETUP_IDLE;
        setup_response_count <= 1'b0;
        gcm_ready <= 1'b0;
        hash_subkey <= 128'd0;
        tag_mask <= 128'd0;
        active_counter <= 128'd0;
        input_hold <= 128'd0;
        keep_hold <= 16'd0;
        last_hold <= 1'b0;
        stream_busy <= 1'b0;
        stream_done <= 1'b0;
        block_count <= 32'd0;
        byte_count <= 32'd0;
        final_message_bits <= 64'd0;
        output_data <= 128'd0;
        output_keep <= 16'd0;
        output_last <= 1'b0;
        output_valid <= 1'b0;
        ghash_state <= 128'd0;
        auth_state <= AUTH_IDLE;
        auth_last <= 1'b0;
        ghash_x <= 128'd0;
        ghash_h <= 128'd0;
        ghash_start <= 1'b0;
        generated_tag <= 128'd0;
        tag_valid <= 1'b0;
        tag_match <= 1'b0;
        auth_fail <= 1'b0;
        final_auth_done <= 1'b0;
        last_output_consumed <= 1'b0;
    end
    else if(soft_reset_pulse)
    begin
        setup_state <= SETUP_IDLE;
        setup_response_count <= 1'b0;
        gcm_ready <= 1'b0;
        hash_subkey <= 128'd0;
        tag_mask <= 128'd0;
        active_counter <= 128'd0;
        input_hold <= 128'd0;
        keep_hold <= 16'd0;
        last_hold <= 1'b0;
        stream_busy <= 1'b0;
        stream_done <= 1'b0;
        block_count <= 32'd0;
        byte_count <= 32'd0;
        final_message_bits <= 64'd0;
        output_data <= 128'd0;
        output_keep <= 16'd0;
        output_last <= 1'b0;
        output_valid <= 1'b0;
        ghash_state <= 128'd0;
        auth_state <= AUTH_IDLE;
        auth_last <= 1'b0;
        ghash_x <= 128'd0;
        ghash_h <= 128'd0;
        ghash_start <= 1'b0;
        generated_tag <= 128'd0;
        tag_valid <= 1'b0;
        tag_match <= 1'b0;
        auth_fail <= 1'b0;
        final_auth_done <= 1'b0;
        last_output_consumed <= 1'b0;
    end
    else
    begin
        ghash_start <= 1'b0;

        if(load_iv_pulse)
        begin
            setup_state <= SETUP_ISSUE_H;
            setup_response_count <= 1'b0;
            gcm_ready <= 1'b0;
            active_counter <= {iv_value, 32'h00000002};
            stream_busy <= 1'b0;
            stream_done <= 1'b0;
            block_count <= 32'd0;
            byte_count <= 32'd0;
            final_message_bits <= 64'd0;
            output_valid <= 1'b0;
            ghash_state <= 128'd0;
            auth_state <= AUTH_IDLE;
            generated_tag <= 128'd0;
            tag_valid <= 1'b0;
            tag_match <= 1'b0;
            auth_fail <= 1'b0;
            final_auth_done <= 1'b0;
            last_output_consumed <= 1'b0;
        end
        else
        begin
            case(setup_state)
                SETUP_ISSUE_H:
                    setup_state <= SETUP_ISSUE_MASK;
                SETUP_ISSUE_MASK:
                    setup_state <= SETUP_WAIT;
                default: ;
            endcase

            if(aes_result_valid && setup_state == SETUP_WAIT)
            begin
                if(!setup_response_count)
                begin
                    hash_subkey <= aes_result;
                    setup_response_count <= 1'b1;
                end
                else
                begin
                    tag_mask <= aes_result;
                    if(aad_bytes_reg != 0)
                    begin
                        ghash_x <= masked_aad;
                        ghash_h <= hash_subkey;
                        ghash_start <= 1'b1;
                        auth_state <= AUTH_WAIT_AAD;
                    end
                    else
                    begin
                        gcm_ready <= 1'b1;
                        setup_state <= SETUP_READY;
                    end
                end
            end

            if(clear_done_pulse)
                stream_done <= 1'b0;

            if(input_fire)
            begin
                input_hold <= reverse_bytes(s_axis_tdata);
                keep_hold <= s_axis_tkeep;
                last_hold <= s_axis_tlast;
                auth_last <= s_axis_tlast;
                active_counter <= active_counter + 1'b1;
                stream_busy <= 1'b1;
                block_count <= block_count + 1'b1;
                byte_count <= byte_count + count_keep_bytes(s_axis_tkeep);
                if(s_axis_tlast)
                    final_message_bits <=
                        (byte_count + count_keep_bytes(s_axis_tkeep)) * 8;
            end

            if(aes_result_valid && setup_state == SETUP_READY && stream_busy &&
               auth_state == AUTH_IDLE)
            begin
                if(!auth_only_mode)
                begin
                    output_data <= reverse_bytes(payload_result);
                    output_keep <= keep_hold;
                    output_last <= last_hold;
                    output_valid <= 1'b1;
                end
                ghash_x <= ghash_state ^ authenticated_ciphertext;
                ghash_h <= hash_subkey;
                ghash_start <= 1'b1;
                auth_state <= AUTH_WAIT_DATA;
            end

            if(ghash_done)
            begin
                if(auth_state == AUTH_WAIT_AAD)
                begin
                    ghash_state <= ghash_result;
                    auth_state <= AUTH_IDLE;
                    gcm_ready <= 1'b1;
                    setup_state <= SETUP_READY;
                end
                else if(auth_state == AUTH_WAIT_DATA)
                begin
                    ghash_state <= ghash_result;
                    if(auth_last)
                    begin
                        ghash_x <= ghash_result ^
                                   {aad_length_bits, final_message_bits};
                        ghash_h <= hash_subkey;
                        ghash_start <= 1'b1;
                        auth_state <= AUTH_WAIT_LENGTH;
                    end
                    else
                    begin
                        auth_state <= AUTH_IDLE;
                        stream_busy <= 1'b0;
                    end
                end
                else if(auth_state == AUTH_WAIT_LENGTH)
                begin
                    ghash_state <= ghash_result;
                    generated_tag <= completed_tag;
                    tag_valid <= 1'b1;
                    if(ciphertext_input_mode)
                    begin
                        tag_match <= (completed_tag == expected_tag_value);
                        auth_fail <= (completed_tag != expected_tag_value);
                    end
                    else
                    begin
                        tag_match <= 1'b1;
                        auth_fail <= 1'b0;
                    end
                    final_auth_done <= 1'b1;
                    auth_state <= AUTH_IDLE;
                    stream_busy <= 1'b0;
                    if(auth_only_mode || last_output_consumed ||
                       (output_fire && output_last))
                        stream_done <= 1'b1;
                end
            end

            if(output_fire)
            begin
                output_valid <= 1'b0;
                if(output_last)
                begin
                    last_output_consumed <= 1'b1;
                    if(final_auth_done)
                        stream_done <= 1'b1;
                end
            end
        end
    end
end

reg [31:0] read_value;
always @(*)
begin
    case(s_axi_ctrl_araddr[6:0])
        REG_CONTROL: read_value = {31'd0, stream_enable};
        REG_STATUS: read_value = {
            23'd0, auth_only_mode, auth_fail, tag_match, tag_valid, gcm_ready,
            stream_enable, output_valid, stream_done, stream_busy
        };
        REG_BLOCKS: read_value = block_count;
        REG_MODE: read_value = {30'd0, operation_mode};
        REG_KEY0: read_value = key_reg0;
        REG_KEY1: read_value = key_reg1;
        REG_KEY2: read_value = key_reg2;
        REG_KEY3: read_value = key_reg3;
        REG_IV0: read_value = iv_reg0;
        REG_IV1: read_value = iv_reg1;
        REG_IV2: read_value = iv_reg2;
        REG_TAG0: read_value = generated_tag[127:96];
        REG_TAG1: read_value = generated_tag[95:64];
        REG_TAG2: read_value = generated_tag[63:32];
        REG_TAG3: read_value = generated_tag[31:0];
        REG_EXPECTED_TAG0: read_value = expected_tag_reg0;
        REG_EXPECTED_TAG1: read_value = expected_tag_reg1;
        REG_EXPECTED_TAG2: read_value = expected_tag_reg2;
        REG_EXPECTED_TAG3: read_value = expected_tag_reg3;
        REG_BYTES: read_value = byte_count;
        REG_AAD0: read_value = aad_reg0;
        REG_AAD1: read_value = aad_reg1;
        REG_AAD2: read_value = aad_reg2;
        REG_AAD3: read_value = aad_reg3;
        REG_AAD_BYTES: read_value = {27'd0, aad_bytes_reg};
        default: read_value = 32'd0;
    endcase
end

always @(posedge aclk)
begin
    if(!aresetn)
    begin
        axi_rvalid <= 1'b0;
        axi_rdata <= 32'd0;
    end
    else if(s_axi_ctrl_arvalid && s_axi_ctrl_arready)
    begin
        axi_rvalid <= 1'b1;
        axi_rdata <= read_value;
    end
    else if(axi_rvalid && s_axi_ctrl_rready)
        axi_rvalid <= 1'b0;
end

wire unused = &{1'b0, s_axi_ctrl_awprot, s_axi_ctrl_arprot,
                ghash_busy};

endmodule
