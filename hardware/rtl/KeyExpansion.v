`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.06.2026 17:01:09
// Design Name: 
// Module Name: KeyExpansion
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


module KeyExpansion
(
    input  wire [127:0] key,
    output wire [1407:0] round_keys
);

////////////////////////////////////////////////////////////
// Round Key Storage
////////////////////////////////////////////////////////////

reg [31:0] w [0:43];

integer i;

////////////////////////////////////////////////////////////
// Rcon Function
////////////////////////////////////////////////////////////

function [31:0] Rcon;
input [3:0] round;
begin
    case(round)
        4'd1  : Rcon = 32'h01000000;
        4'd2  : Rcon = 32'h02000000;
        4'd3  : Rcon = 32'h04000000;
        4'd4  : Rcon = 32'h08000000;
        4'd5  : Rcon = 32'h10000000;
        4'd6  : Rcon = 32'h20000000;
        4'd7  : Rcon = 32'h40000000;
        4'd8  : Rcon = 32'h80000000;
        4'd9  : Rcon = 32'h1B000000;
        4'd10 : Rcon = 32'h36000000;
        default : Rcon = 32'h00000000;
    endcase
end
endfunction

////////////////////////////////////////////////////////////
// RotWord
////////////////////////////////////////////////////////////

function [31:0] RotWord;
input [31:0] word;
begin
    RotWord = {word[23:0], word[31:24]};
end
endfunction

////////////////////////////////////////////////////////////
// SubWord
////////////////////////////////////////////////////////////

function [31:0] SubWord;
input [31:0] word;
begin

    SubWord = {
        aes_sbox(word[31:24]),
        aes_sbox(word[23:16]),
        aes_sbox(word[15:8]),
        aes_sbox(word[7:0])
    };

end
endfunction

////////////////////////////////////////////////////////////
// AES SBOX
////////////////////////////////////////////////////////////

function [7:0] aes_sbox;
input [7:0] in;
begin
    case(in)
        8'h00: aes_sbox = 8'h63;  8'h01: aes_sbox = 8'h7C;
        8'h02: aes_sbox = 8'h77;  8'h03: aes_sbox = 8'h7B;
        8'h04: aes_sbox = 8'hF2;  8'h05: aes_sbox = 8'h6B;
        8'h06: aes_sbox = 8'h6F;  8'h07: aes_sbox = 8'hC5;
        8'h08: aes_sbox = 8'h30;  8'h09: aes_sbox = 8'h01;
        8'h0A: aes_sbox = 8'h67;  8'h0B: aes_sbox = 8'h2B;
        8'h0C: aes_sbox = 8'hFE;  8'h0D: aes_sbox = 8'hD7;
        8'h0E: aes_sbox = 8'hAB;  8'h0F: aes_sbox = 8'h76;

        8'h10: aes_sbox = 8'hCA;  8'h11: aes_sbox = 8'h82;
        8'h12: aes_sbox = 8'hC9;  8'h13: aes_sbox = 8'h7D;
        8'h14: aes_sbox = 8'hFA;  8'h15: aes_sbox = 8'h59;
        8'h16: aes_sbox = 8'h47;  8'h17: aes_sbox = 8'hF0;
        8'h18: aes_sbox = 8'hAD;  8'h19: aes_sbox = 8'hD4;
        8'h1A: aes_sbox = 8'hA2;  8'h1B: aes_sbox = 8'hAF;
        8'h1C: aes_sbox = 8'h9C;  8'h1D: aes_sbox = 8'hA4;
        8'h1E: aes_sbox = 8'h72;  8'h1F: aes_sbox = 8'hC0;

        8'h20: aes_sbox = 8'hB7;  8'h21: aes_sbox = 8'hFD;
        8'h22: aes_sbox = 8'h93;  8'h23: aes_sbox = 8'h26;
        8'h24: aes_sbox = 8'h36;  8'h25: aes_sbox = 8'h3F;
        8'h26: aes_sbox = 8'hF7;  8'h27: aes_sbox = 8'hCC;
        8'h28: aes_sbox = 8'h34;  8'h29: aes_sbox = 8'hA5;
        8'h2A: aes_sbox = 8'hE5;  8'h2B: aes_sbox = 8'hF1;
        8'h2C: aes_sbox = 8'h71;  8'h2D: aes_sbox = 8'hD8;
        8'h2E: aes_sbox = 8'h31;  8'h2F: aes_sbox = 8'h15;

        8'h30: aes_sbox = 8'h04;  8'h31: aes_sbox = 8'hC7;
        8'h32: aes_sbox = 8'h23;  8'h33: aes_sbox = 8'hC3;
        8'h34: aes_sbox = 8'h18;  8'h35: aes_sbox = 8'h96;
        8'h36: aes_sbox = 8'h05;  8'h37: aes_sbox = 8'h9A;
        8'h38: aes_sbox = 8'h07;  8'h39: aes_sbox = 8'h12;
        8'h3A: aes_sbox = 8'h80;  8'h3B: aes_sbox = 8'hE2;
        8'h3C: aes_sbox = 8'hEB;  8'h3D: aes_sbox = 8'h27;
        8'h3E: aes_sbox = 8'hB2;  8'h3F: aes_sbox = 8'h75;

        8'h40: aes_sbox = 8'h09;  8'h41: aes_sbox = 8'h83;
        8'h42: aes_sbox = 8'h2C;  8'h43: aes_sbox = 8'h1A;
        8'h44: aes_sbox = 8'h1B;  8'h45: aes_sbox = 8'h6E;
        8'h46: aes_sbox = 8'h5A;  8'h47: aes_sbox = 8'hA0;
        8'h48: aes_sbox = 8'h52;  8'h49: aes_sbox = 8'h3B;
        8'h4A: aes_sbox = 8'hD6;  8'h4B: aes_sbox = 8'hB3;
        8'h4C: aes_sbox = 8'h29;  8'h4D: aes_sbox = 8'hE3;
        8'h4E: aes_sbox = 8'h2F;  8'h4F: aes_sbox = 8'h84;

        8'h50: aes_sbox = 8'h53;  8'h51: aes_sbox = 8'hD1;
        8'h52: aes_sbox = 8'h00;  8'h53: aes_sbox = 8'hED;
        8'h54: aes_sbox = 8'h20;  8'h55: aes_sbox = 8'hFC;
        8'h56: aes_sbox = 8'hB1;  8'h57: aes_sbox = 8'h5B;
        8'h58: aes_sbox = 8'h6A;  8'h59: aes_sbox = 8'hCB;
        8'h5A: aes_sbox = 8'hBE;  8'h5B: aes_sbox = 8'h39;
        8'h5C: aes_sbox = 8'h4A;  8'h5D: aes_sbox = 8'h4C;
        8'h5E: aes_sbox = 8'h58;  8'h5F: aes_sbox = 8'hCF;

        8'h60: aes_sbox = 8'hD0;  8'h61: aes_sbox = 8'hEF;
        8'h62: aes_sbox = 8'hAA;  8'h63: aes_sbox = 8'hFB;
        8'h64: aes_sbox = 8'h43;  8'h65: aes_sbox = 8'h4D;
        8'h66: aes_sbox = 8'h33;  8'h67: aes_sbox = 8'h85;
        8'h68: aes_sbox = 8'h45;  8'h69: aes_sbox = 8'hF9;
        8'h6A: aes_sbox = 8'h02;  8'h6B: aes_sbox = 8'h7F;
        8'h6C: aes_sbox = 8'h50;  8'h6D: aes_sbox = 8'h3C;
        8'h6E: aes_sbox = 8'h9F;  8'h6F: aes_sbox = 8'hA8;

        8'h70: aes_sbox = 8'h51;  8'h71: aes_sbox = 8'hA3;
        8'h72: aes_sbox = 8'h40;  8'h73: aes_sbox = 8'h8F;
        8'h74: aes_sbox = 8'h92;  8'h75: aes_sbox = 8'h9D;
        8'h76: aes_sbox = 8'h38;  8'h77: aes_sbox = 8'hF5;
        8'h78: aes_sbox = 8'hBC;  8'h79: aes_sbox = 8'hB6;
        8'h7A: aes_sbox = 8'hDA;  8'h7B: aes_sbox = 8'h21;
        8'h7C: aes_sbox = 8'h10;  8'h7D: aes_sbox = 8'hFF;
        8'h7E: aes_sbox = 8'hF3;  8'h7F: aes_sbox = 8'hD2;

        8'h80: aes_sbox = 8'hCD;  8'h81: aes_sbox = 8'h0C;
        8'h82: aes_sbox = 8'h13;  8'h83: aes_sbox = 8'hEC;
        8'h84: aes_sbox = 8'h5F;  8'h85: aes_sbox = 8'h97;
        8'h86: aes_sbox = 8'h44;  8'h87: aes_sbox = 8'h17;
        8'h88: aes_sbox = 8'hC4;  8'h89: aes_sbox = 8'hA7;
        8'h8A: aes_sbox = 8'h7E;  8'h8B: aes_sbox = 8'h3D;
        8'h8C: aes_sbox = 8'h64;  8'h8D: aes_sbox = 8'h5D;
        8'h8E: aes_sbox = 8'h19;  8'h8F: aes_sbox = 8'h73;

        8'h90: aes_sbox = 8'h60;  8'h91: aes_sbox = 8'h81;
        8'h92: aes_sbox = 8'h4F;  8'h93: aes_sbox = 8'hDC;
        8'h94: aes_sbox = 8'h22;  8'h95: aes_sbox = 8'h2A;
        8'h96: aes_sbox = 8'h90;  8'h97: aes_sbox = 8'h88;
        8'h98: aes_sbox = 8'h46;  8'h99: aes_sbox = 8'hEE;
        8'h9A: aes_sbox = 8'hB8;  8'h9B: aes_sbox = 8'h14;
        8'h9C: aes_sbox = 8'hDE;  8'h9D: aes_sbox = 8'h5E;
        8'h9E: aes_sbox = 8'h0B;  8'h9F: aes_sbox = 8'hDB;

        8'hA0: aes_sbox = 8'hE0;  8'hA1: aes_sbox = 8'h32;
        8'hA2: aes_sbox = 8'h3A;  8'hA3: aes_sbox = 8'h0A;
        8'hA4: aes_sbox = 8'h49;  8'hA5: aes_sbox = 8'h06;
        8'hA6: aes_sbox = 8'h24;  8'hA7: aes_sbox = 8'h5C;
        8'hA8: aes_sbox = 8'hC2;  8'hA9: aes_sbox = 8'hD3;
        8'hAA: aes_sbox = 8'hAC;  8'hAB: aes_sbox = 8'h62;
        8'hAC: aes_sbox = 8'h91;  8'hAD: aes_sbox = 8'h95;
        8'hAE: aes_sbox = 8'hE4;  8'hAF: aes_sbox = 8'h79;

        8'hB0: aes_sbox = 8'hE7;  8'hB1: aes_sbox = 8'hC8;
        8'hB2: aes_sbox = 8'h37;  8'hB3: aes_sbox = 8'h6D;
        8'hB4: aes_sbox = 8'h8D;  8'hB5: aes_sbox = 8'hD5;
        8'hB6: aes_sbox = 8'h4E;  8'hB7: aes_sbox = 8'hA9;
        8'hB8: aes_sbox = 8'h6C;  8'hB9: aes_sbox = 8'h56;
        8'hBA: aes_sbox = 8'hF4;  8'hBB: aes_sbox = 8'hEA;
        8'hBC: aes_sbox = 8'h65;  8'hBD: aes_sbox = 8'h7A;
        8'hBE: aes_sbox = 8'hAE;  8'hBF: aes_sbox = 8'h08;

        8'hC0: aes_sbox = 8'hBA;  8'hC1: aes_sbox = 8'h78;
        8'hC2: aes_sbox = 8'h25;  8'hC3: aes_sbox = 8'h2E;
        8'hC4: aes_sbox = 8'h1C;  8'hC5: aes_sbox = 8'hA6;
        8'hC6: aes_sbox = 8'hB4;  8'hC7: aes_sbox = 8'hC6;
        8'hC8: aes_sbox = 8'hE8;  8'hC9: aes_sbox = 8'hDD;
        8'hCA: aes_sbox = 8'h74;  8'hCB: aes_sbox = 8'h1F;
        8'hCC: aes_sbox = 8'h4B;  8'hCD: aes_sbox = 8'hBD;
        8'hCE: aes_sbox = 8'h8B;  8'hCF: aes_sbox = 8'h8A;

        8'hD0: aes_sbox = 8'h70;  8'hD1: aes_sbox = 8'h3E;
        8'hD2: aes_sbox = 8'hB5;  8'hD3: aes_sbox = 8'h66;
        8'hD4: aes_sbox = 8'h48;  8'hD5: aes_sbox = 8'h03;
        8'hD6: aes_sbox = 8'hF6;  8'hD7: aes_sbox = 8'h0E;
        8'hD8: aes_sbox = 8'h61;  8'hD9: aes_sbox = 8'h35;
        8'hDA: aes_sbox = 8'h57;  8'hDB: aes_sbox = 8'hB9;
        8'hDC: aes_sbox = 8'h86;  8'hDD: aes_sbox = 8'hC1;
        8'hDE: aes_sbox = 8'h1D;  8'hDF: aes_sbox = 8'h9E;

        8'hE0: aes_sbox = 8'hE1;  8'hE1: aes_sbox = 8'hF8;
        8'hE2: aes_sbox = 8'h98;  8'hE3: aes_sbox = 8'h11;
        8'hE4: aes_sbox = 8'h69;  8'hE5: aes_sbox = 8'hD9;
        8'hE6: aes_sbox = 8'h8E;  8'hE7: aes_sbox = 8'h94;
        8'hE8: aes_sbox = 8'h9B;  8'hE9: aes_sbox = 8'h1E;
        8'hEA: aes_sbox = 8'h87;  8'hEB: aes_sbox = 8'hE9;
        8'hEC: aes_sbox = 8'hCE;  8'hED: aes_sbox = 8'h55;
        8'hEE: aes_sbox = 8'h28;  8'hEF: aes_sbox = 8'hDF;

        8'hF0: aes_sbox = 8'h8C;  8'hF1: aes_sbox = 8'hA1;
        8'hF2: aes_sbox = 8'h89;  8'hF3: aes_sbox = 8'h0D;
        8'hF4: aes_sbox = 8'hBF;  8'hF5: aes_sbox = 8'hE6;
        8'hF6: aes_sbox = 8'h42;  8'hF7: aes_sbox = 8'h68;
        8'hF8: aes_sbox = 8'h41;  8'hF9: aes_sbox = 8'h99;
        8'hFA: aes_sbox = 8'h2D;  8'hFB: aes_sbox = 8'h0F;
        8'hFC: aes_sbox = 8'hB0;  8'hFD: aes_sbox = 8'h54;
        8'hFE: aes_sbox = 8'hBB;  8'hFF: aes_sbox = 8'h16;

        default: aes_sbox = 8'h00;
    endcase
end
endfunction

////////////////////////////////////////////////////////////
// Key Expansion Logic
////////////////////////////////////////////////////////////

always @(*)
begin

    // Original Key

    w[0] = key[127:96];
    w[1] = key[95:64];
    w[2] = key[63:32];
    w[3] = key[31:0];

    for(i=4; i<44; i=i+1)
    begin

        if(i % 4 == 0)
        begin
            w[i] =
                w[i-4] ^
                SubWord(RotWord(w[i-1])) ^
                Rcon(i/4);
        end
        else
        begin
            w[i] =
                w[i-4] ^
                w[i-1];
        end

    end

end

////////////////////////////////////////////////////////////
// Round Key Packing
////////////////////////////////////////////////////////////

assign round_keys = {

    w[0],  w[1],  w[2],  w[3],      // Round 0
    w[4],  w[5],  w[6],  w[7],      // Round 1
    w[8],  w[9],  w[10], w[11],     // Round 2
    w[12], w[13], w[14], w[15],     // Round 3
    w[16], w[17], w[18], w[19],     // Round 4
    w[20], w[21], w[22], w[23],     // Round 5
    w[24], w[25], w[26], w[27],     // Round 6
    w[28], w[29], w[30], w[31],     // Round 7
    w[32], w[33], w[34], w[35],     // Round 8
    w[36], w[37], w[38], w[39],     // Round 9
    w[40], w[41], w[42], w[43]      // Round 10

};

endmodule
