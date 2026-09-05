`timescale 1ns / 1ps

// AES-128 CTR block accelerator controlled through a 32-bit AXI4-Lite slave.
// Encryption and decryption use the same operation: output = input XOR AES(counter).
module AES_CTR_AXI_LITE #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 7
)
(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 S_AXI_ACLK CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET s_axi_aresetn" *)
    input  wire                             s_axi_aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 S_AXI_ARESETN RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire                             s_axi_aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)
    input  wire [2:0]                       s_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input  wire                             s_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output wire                             s_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input  wire [C_S_AXI_DATA_WIDTH-1:0]    s_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input  wire                             s_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output wire                             s_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output wire [1:0]                       s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output wire                             s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input  wire                             s_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
    input  wire [2:0]                       s_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input  wire                             s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output wire                             s_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output wire [C_S_AXI_DATA_WIDTH-1:0]    s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output wire [1:0]                       s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output wire                             s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input  wire                             s_axi_rready
);

// Register addresses
localparam [6:0] REG_CONTROL = 7'h00;
localparam [6:0] REG_STATUS  = 7'h04;
localparam [6:0] REG_KEY0    = 7'h10;
localparam [6:0] REG_KEY1    = 7'h14;
localparam [6:0] REG_KEY2    = 7'h18;
localparam [6:0] REG_KEY3    = 7'h1C;
localparam [6:0] REG_CTR0    = 7'h20;
localparam [6:0] REG_CTR1    = 7'h24;
localparam [6:0] REG_CTR2    = 7'h28;
localparam [6:0] REG_CTR3    = 7'h2C;
localparam [6:0] REG_DIN0    = 7'h30;
localparam [6:0] REG_DIN1    = 7'h34;
localparam [6:0] REG_DIN2    = 7'h38;
localparam [6:0] REG_DIN3    = 7'h3C;
localparam [6:0] REG_DOUT0   = 7'h40;
localparam [6:0] REG_DOUT1   = 7'h44;
localparam [6:0] REG_DOUT2   = 7'h48;
localparam [6:0] REG_DOUT3   = 7'h4C;

reg [31:0] key_reg0, key_reg1, key_reg2, key_reg3;
reg [31:0] ctr_reg0, ctr_reg1, ctr_reg2, ctr_reg3;
reg [31:0] din_reg0, din_reg1, din_reg2, din_reg3;
reg [127:0] active_counter;
reg [127:0] input_hold;
reg [127:0] output_hold;
reg accel_busy;
reg accel_done;
reg start_pulse;
reg load_counter_pulse;
reg soft_reset_pulse;
reg clear_done_pulse;

reg axi_bvalid;
reg axi_rvalid;
reg [31:0] axi_rdata;
reg [31:0] read_value;

wire write_fire = s_axi_awvalid && s_axi_wvalid && !axi_bvalid;
wire read_fire  = s_axi_arvalid && !axi_rvalid;

assign s_axi_awready = write_fire;
assign s_axi_wready  = write_fire;
assign s_axi_bresp   = 2'b00;
assign s_axi_bvalid  = axi_bvalid;
assign s_axi_arready = read_fire;
assign s_axi_rdata   = axi_rdata;
assign s_axi_rresp   = 2'b00;
assign s_axi_rvalid  = axi_rvalid;

integer byte_index;
reg [31:0] write_value;

always @(*)
begin
    write_value = 32'd0;
    for(byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
        if(s_axi_wstrb[byte_index])
            write_value[byte_index*8 +: 8] = s_axi_wdata[byte_index*8 +: 8];
end

always @(posedge s_axi_aclk)
begin
    if(!s_axi_aresetn)
    begin
        key_reg0 <= 0; key_reg1 <= 0; key_reg2 <= 0; key_reg3 <= 0;
        ctr_reg0 <= 0; ctr_reg1 <= 0; ctr_reg2 <= 0; ctr_reg3 <= 0;
        din_reg0 <= 0; din_reg1 <= 0; din_reg2 <= 0; din_reg3 <= 0;
        start_pulse <= 0;
        load_counter_pulse <= 0;
        soft_reset_pulse <= 0;
        clear_done_pulse <= 0;
        axi_bvalid <= 0;
    end
    else
    begin
        start_pulse <= 0;
        load_counter_pulse <= 0;
        soft_reset_pulse <= 0;
        clear_done_pulse <= 0;

        if(write_fire)
        begin
            case(s_axi_awaddr[6:0])
                REG_CONTROL:
                begin
                    start_pulse        <= write_value[0];
                    load_counter_pulse <= write_value[1];
                    soft_reset_pulse   <= write_value[2];
                    clear_done_pulse   <= write_value[3];
                end
                REG_KEY0: key_reg0 <= write_value;
                REG_KEY1: key_reg1 <= write_value;
                REG_KEY2: key_reg2 <= write_value;
                REG_KEY3: key_reg3 <= write_value;
                REG_CTR0: ctr_reg0 <= write_value;
                REG_CTR1: ctr_reg1 <= write_value;
                REG_CTR2: ctr_reg2 <= write_value;
                REG_CTR3: ctr_reg3 <= write_value;
                REG_DIN0: din_reg0 <= write_value;
                REG_DIN1: din_reg1 <= write_value;
                REG_DIN2: din_reg2 <= write_value;
                REG_DIN3: din_reg3 <= write_value;
                default: ;
            endcase
            axi_bvalid <= 1'b1;
        end
        else if(axi_bvalid && s_axi_bready)
            axi_bvalid <= 1'b0;
    end
end

always @(*)
begin
    case(s_axi_araddr[6:0])
        REG_STATUS: read_value = {30'd0, accel_done, accel_busy};
        REG_KEY0:   read_value = key_reg0;
        REG_KEY1:   read_value = key_reg1;
        REG_KEY2:   read_value = key_reg2;
        REG_KEY3:   read_value = key_reg3;
        REG_CTR0:   read_value = ctr_reg0;
        REG_CTR1:   read_value = ctr_reg1;
        REG_CTR2:   read_value = ctr_reg2;
        REG_CTR3:   read_value = ctr_reg3;
        REG_DIN0:   read_value = din_reg0;
        REG_DIN1:   read_value = din_reg1;
        REG_DIN2:   read_value = din_reg2;
        REG_DIN3:   read_value = din_reg3;
        REG_DOUT0:  read_value = output_hold[127:96];
        REG_DOUT1:  read_value = output_hold[95:64];
        REG_DOUT2:  read_value = output_hold[63:32];
        REG_DOUT3:  read_value = output_hold[31:0];
        default:    read_value = 32'd0;
    endcase
end

always @(posedge s_axi_aclk)
begin
    if(!s_axi_aresetn)
    begin
        axi_rvalid <= 1'b0;
        axi_rdata <= 32'd0;
    end
    else if(read_fire)
    begin
        axi_rvalid <= 1'b1;
        axi_rdata <= read_value;
    end
    else if(axi_rvalid && s_axi_rready)
        axi_rvalid <= 1'b0;
end

wire [127:0] key_value = {key_reg0, key_reg1, key_reg2, key_reg3};
wire [127:0] counter_value = {ctr_reg0, ctr_reg1, ctr_reg2, ctr_reg3};
wire [127:0] input_value = {din_reg0, din_reg1, din_reg2, din_reg3};
wire [1407:0] round_keys;
wire [127:0] aes_keystream;
wire aes_valid;
wire aes_reset = !s_axi_aresetn || soft_reset_pulse;
wire aes_start = start_pulse && !accel_busy;

KeyExpansion u_key_expansion
(
    .key(key_value),
    .round_keys(round_keys)
);

AES_128_Core u_aes
(
    .clk(s_axi_aclk),
    .rst(aes_reset),
    .data_valid(aes_start),
    .round_keys(round_keys),
    .plaintext(active_counter),
    .ciphertext(aes_keystream),
    .cipher_valid(aes_valid)
);

always @(posedge s_axi_aclk)
begin
    if(!s_axi_aresetn)
    begin
        active_counter <= 128'd0;
        input_hold <= 128'd0;
        output_hold <= 128'd0;
        accel_busy <= 1'b0;
        accel_done <= 1'b0;
    end
    else if(soft_reset_pulse)
    begin
        active_counter <= counter_value;
        input_hold <= 128'd0;
        output_hold <= 128'd0;
        accel_busy <= 1'b0;
        accel_done <= 1'b0;
    end
    else
    begin
        if(load_counter_pulse)
        begin
            active_counter <= counter_value;
            accel_done <= 1'b0;
        end

        if(clear_done_pulse)
            accel_done <= 1'b0;

        if(aes_start)
        begin
            input_hold <= input_value;
            active_counter <= active_counter + 1'b1;
            accel_busy <= 1'b1;
            accel_done <= 1'b0;
        end

        if(aes_valid)
        begin
            output_hold <= input_hold ^ aes_keystream;
            accel_busy <= 1'b0;
            accel_done <= 1'b1;
        end
    end
end

endmodule
