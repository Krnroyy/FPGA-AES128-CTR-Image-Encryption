`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.06.2026 16:58:09
// Design Name: 
// Module Name: AES_128_Core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module AES_128_Core
(
    input  wire         clk,
    input  wire         rst,

    input  wire         data_valid,

    input  wire [1407:0] round_keys,
    input  wire [127:0]  plaintext,

    output reg  [127:0] ciphertext,
    output reg          cipher_valid
);

//================================================
// PIPELINE REGISTERS
//================================================

reg [127:0] state0;
reg [127:0] state1;
reg [127:0] state2;
reg [127:0] state3;
reg [127:0] state4;
reg [127:0] state5;
reg [127:0] state6;
reg [127:0] state7;
reg [127:0] state8;
reg [127:0] state9;
reg [127:0] state10;

reg valid0;
reg valid1;
reg valid2;
reg valid3;
reg valid4;
reg valid5;
reg valid6;
reg valid7;
reg valid8;
reg valid9;
reg valid10;
//================================================
// ROUND WIRES
//================================================

// Round 1
wire [127:0] sb1,sr1,mc1,rk1;

// Round 2
wire [127:0] sb2,sr2,mc2,rk2;

// Round 3
wire [127:0] sb3,sr3,mc3,rk3;

// Round 4
wire [127:0] sb4,sr4,mc4,rk4;

// Round 5
wire [127:0] sb5,sr5,mc5,rk5;

// Round 6
wire [127:0] sb6,sr6,mc6,rk6;

// Round 7
wire [127:0] sb7,sr7,mc7,rk7;

// Round 8
wire [127:0] sb8,sr8,mc8,rk8;

// Round 9
wire [127:0] sb9,sr9,mc9,rk9;

// Round 10
wire [127:0] sb10,sr10,rk10;

//================================================
// INITIAL ROUND
//================================================

wire [127:0] init_state;

AddRoundKey ARK0
(
    .state_in(plaintext),
    .round_key(round_keys[1407:1280]),
    .state_out(init_state)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state0 <= 128'd0;
        valid0 <= 1'b0;
    end
    else
    begin
        state0 <= init_state;
        valid0 <= data_valid;
    end
end

//================================================
// ROUND 1
//================================================

SubBytes SB1(.state_in(state0), .state_out(sb1));
ShiftRows SR1(.state_in(sb1), .state_out(sr1));
MixColumns MC1(.state_in(sr1), .state_out(mc1));

AddRoundKey ARK1
(
    .state_in(mc1),
    .round_key(round_keys[1279:1152]),
    .state_out(rk1)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state1 <= 128'd0;
        valid1 <= 1'b0;
    end
    else
    begin
        state1 <= rk1;
        valid1 <= valid0;
    end
end

//================================================
// ROUND 2
//================================================

SubBytes SB2(.state_in(state1), .state_out(sb2));
ShiftRows SR2(.state_in(sb2), .state_out(sr2));
MixColumns MC2(.state_in(sr2), .state_out(mc2));

AddRoundKey ARK2
(
    .state_in(mc2),
    .round_key(round_keys[1151:1024]),
    .state_out(rk2)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state2 <= 128'd0;
        valid2 <= 1'b0;
    end
    else
    begin
        state2 <= rk2;
        valid2 <= valid1;
    end
end

//================================================
// ROUND 3
//================================================

SubBytes SB3(.state_in(state2), .state_out(sb3));
ShiftRows SR3(.state_in(sb3), .state_out(sr3));
MixColumns MC3(.state_in(sr3), .state_out(mc3));

AddRoundKey ARK3
(
    .state_in(mc3),
    .round_key(round_keys[1023:896]),
    .state_out(rk3)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state3 <= 128'd0;
        valid3 <= 1'b0;
    end
    else
    begin
        state3 <= rk3;
        valid3 <= valid2;
    end
end

//================================================
// ROUND 4
//================================================

SubBytes SB4(.state_in(state3), .state_out(sb4));
ShiftRows SR4(.state_in(sb4), .state_out(sr4));
MixColumns MC4(.state_in(sr4), .state_out(mc4));

AddRoundKey ARK4
(
    .state_in(mc4),
    .round_key(round_keys[895:768]),
    .state_out(rk4)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state4 <= 128'd0;
        valid4 <= 1'b0;
    end
    else
    begin
        state4 <= rk4;
        valid4 <= valid3;
    end
end

//================================================
// ROUND 5
//================================================

SubBytes SB5(.state_in(state4), .state_out(sb5));
ShiftRows SR5(.state_in(sb5), .state_out(sr5));
MixColumns MC5(.state_in(sr5), .state_out(mc5));

AddRoundKey ARK5
(
    .state_in(mc5),
    .round_key(round_keys[767:640]),
    .state_out(rk5)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state5 <= 128'd0;
        valid5 <= 1'b0;
    end
    else
    begin
        state5 <= rk5;
        valid5 <= valid4;
    end
end

//================================================
// ROUND 6
//================================================

SubBytes SB6(.state_in(state5), .state_out(sb6));
ShiftRows SR6(.state_in(sb6), .state_out(sr6));
MixColumns MC6(.state_in(sr6), .state_out(mc6));

AddRoundKey ARK6
(
    .state_in(mc6),
    .round_key(round_keys[639:512]),
    .state_out(rk6)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state6 <= 128'd0;
        valid6 <= 1'b0;
    end
    else
    begin
        state6 <= rk6;
        valid6 <= valid5;
    end
end

//================================================
// ROUND 7
//================================================

SubBytes SB7(.state_in(state6), .state_out(sb7));
ShiftRows SR7(.state_in(sb7), .state_out(sr7));
MixColumns MC7(.state_in(sr7), .state_out(mc7));

AddRoundKey ARK7
(
    .state_in(mc7),
    .round_key(round_keys[511:384]),
    .state_out(rk7)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state7 <= 128'd0;
        valid7 <= 1'b0;
    end
    else
    begin
        state7 <= rk7;
        valid7 <= valid6;
    end
end

//================================================
// ROUND 8
//================================================

SubBytes SB8(.state_in(state7), .state_out(sb8));
ShiftRows SR8(.state_in(sb8), .state_out(sr8));
MixColumns MC8(.state_in(sr8), .state_out(mc8));

AddRoundKey ARK8
(
    .state_in(mc8),
    .round_key(round_keys[383:256]),
    .state_out(rk8)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state8 <= 128'd0;
        valid8 <= 1'b0;
    end
    else
    begin
        state8 <= rk8;
        valid8 <= valid7;
    end
end

//================================================
// ROUND 9
//================================================

SubBytes SB9(.state_in(state8), .state_out(sb9));
ShiftRows SR9(.state_in(sb9), .state_out(sr9));
MixColumns MC9(.state_in(sr9), .state_out(mc9));

AddRoundKey ARK9
(
    .state_in(mc9),
    .round_key(round_keys[255:128]),
    .state_out(rk9)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state9 <= 128'd0;
        valid9 <= 1'b0;
    end
    else
    begin
        state9 <= rk9;
        valid9 <= valid8;
    end
end

//================================================
// FINAL ROUND (ROUND 10)
//================================================

SubBytes SB10(.state_in(state9), .state_out(sb10));
ShiftRows SR10(.state_in(sb10), .state_out(sr10));

AddRoundKey ARK10
(
    .state_in(sr10),
    .round_key(round_keys[127:0]),
    .state_out(rk10)
);

//////////////////////////////////////////////////////////////
// FINAL OUTPUT REGISTER
//////////////////////////////////////////////////////////////

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state10 <= 128'd0;
        valid10 <= 1'b0;

        ciphertext <= 128'd0;
        cipher_valid <= 1'b0;
    end
    else
    begin

        // Register final round
        state10 <= rk10;
        valid10 <= valid9;

        // Output
        cipher_valid <= valid9;

        if(valid9)
            ciphertext <= rk10;
        else
            cipher_valid <= 1'b0;

    end
end
endmodule

