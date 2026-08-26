`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2026 15:38:51
// Design Name: 
// Module Name: key_expesion_all_tb
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

module key_expansion_all_tb;

    // ------------------------------------------------
    // Round keys
    // ------------------------------------------------

    wire [127:0] key0;
    wire [127:0] key1;
    wire [127:0] key2;
    wire [127:0] key3;
    wire [127:0] key4;
    wire [127:0] key5;
    wire [127:0] key6;
    wire [127:0] key7;
    wire [127:0] key8;
    wire [127:0] key9;
    wire [127:0] key10;


    // ------------------------------------------------
    // Original AES-128 key
    // ------------------------------------------------

    assign key0 =
        128'h000102030405060708090A0B0C0D0E0F;


    // ------------------------------------------------
    // Round 1
    // Rcon = 01
    // ------------------------------------------------

    key_expansion_128 round1 (
        .key_in(key0),
        .rcon(8'h01),
        .key_out(key1)
    );


    // ------------------------------------------------
    // Round 2
    // Rcon = 02
    // ------------------------------------------------

    key_expansion_128 round2 (
        .key_in(key1),
        .rcon(8'h02),
        .key_out(key2)
    );


    // ------------------------------------------------
    // Round 3
    // Rcon = 04
    // ------------------------------------------------

    key_expansion_128 round3 (
        .key_in(key2),
        .rcon(8'h04),
        .key_out(key3)
    );


    // ------------------------------------------------
    // Round 4
    // Rcon = 08
    // ------------------------------------------------

    key_expansion_128 round4 (
        .key_in(key3),
        .rcon(8'h08),
        .key_out(key4)
    );


    // ------------------------------------------------
    // Round 5
    // Rcon = 10
    // ------------------------------------------------

    key_expansion_128 round5 (
        .key_in(key4),
        .rcon(8'h10),
        .key_out(key5)
    );


    // ------------------------------------------------
    // Round 6
    // Rcon = 20
    // ------------------------------------------------

    key_expansion_128 round6 (
        .key_in(key5),
        .rcon(8'h20),
        .key_out(key6)
    );


    // ------------------------------------------------
    // Round 7
    // Rcon = 40
    // ------------------------------------------------

    key_expansion_128 round7 (
        .key_in(key6),
        .rcon(8'h40),
        .key_out(key7)
    );


    // ------------------------------------------------
    // Round 8
    // Rcon = 80
    // ------------------------------------------------

    key_expansion_128 round8 (
        .key_in(key7),
        .rcon(8'h80),
        .key_out(key8)
    );


    // ------------------------------------------------
    // Round 9
    // Rcon = 1B
    // ------------------------------------------------

    key_expansion_128 round9 (
        .key_in(key8),
        .rcon(8'h1B),
        .key_out(key9)
    );


    // ------------------------------------------------
    // Round 10
    // Rcon = 36
    // ------------------------------------------------

    key_expansion_128 round10 (
        .key_in(key9),
        .rcon(8'h36),
        .key_out(key10)
    );


    // ------------------------------------------------
    // Verification
    // ------------------------------------------------

    initial begin

        #10;

        $display("");
        $display("================================================");
        $display("       AES-128 COMPLETE KEY SCHEDULE TEST");
        $display("================================================");

        $display("Round 0  = %h", key0);
        $display("Expected = 000102030405060708090A0B0C0D0E0F");

        $display("");
        $display("Round 1  = %h", key1);
        $display("Expected = D6AA74FDD2AF72FADAA678F1D6AB76FE");

        $display("");
        $display("Round 2  = %h", key2);
        $display("Expected = B692CF0B643DBDF1BE9BC5006830B3FE");

        $display("");
        $display("Round 3  = %h", key3);
        $display("Expected = B6FF744ED2C2C9BF6C590CBF0469BF41");

        $display("");
        $display("Round 4  = %h", key4);
        $display("Expected = 47F7F7BC95353E03F96C32BCFD058DFD");

        $display("");
        $display("Round 5  = %h", key5);
        $display("Expected = 3CAAA3E8A99F9DEB50F3AF57ADF622AA");

        $display("");
        $display("Round 6  = %h", key6);
        $display("Expected = 5E390F7DF7A69296A7553DC10AA31F6B");

        $display("");
        $display("Round 7  = %h", key7);
        $display("Expected = 14F9701AE35FE28C440ADF4D4EA9C026");

        $display("");
        $display("Round 8  = %h", key8);
        $display("Expected = 47438735A41C65B9E016BAF4AEBF7AD2");

        $display("");
        $display("Round 9  = %h", key9);
        $display("Expected = 549932D1F08557681093ED9CBE2C974E");

        $display("");
        $display("Round 10 = %h", key10);
        $display("Expected = 13111D7FE3944A17F307A78B4D2B30C5");


        // ------------------------------------------------
        // Automatic verification
        // ------------------------------------------------

        if (
            key1  === 128'hD6AA74FDD2AF72FADAA678F1D6AB76FE &&
            key2  === 128'hB692CF0B643DBDF1BE9BC5006830B3FE &&
            key3  === 128'hB6FF744ED2C2C9BF6C590CBF0469BF41 &&
            key4  === 128'h47F7F7BC95353E03F96C32BCFD058DFD &&
            key5  === 128'h3CAAA3E8A99F9DEB50F3AF57ADF622AA &&
            key6  === 128'h5E390F7DF7A69296A7553DC10AA31F6B &&
            key7  === 128'h14F9701AE35FE28C440ADF4D4EA9C026 &&
            key8  === 128'h47438735A41C65B9E016BAF4AEBF7AD2 &&
            key9  === 128'h549932D1F08557681093ED9CBE2C974E &&
            key10 === 128'h13111D7FE3944A17F307A78B4D2B30C5
        ) begin

            $display("");
            $display("**********************************************");
            $display("*  COMPLETE KEY SCHEDULE: PASS              *");
            $display("*  ALL 10 ROUND KEYS MATCH NIST             *");
            $display("**********************************************");

        end
        else begin

            $display("");
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            $display("!  KEY SCHEDULE: FAIL                       !");
            $display("!  CHECK ROUND KEYS                         !");
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

        end

        $display("");

        #10;

        $finish;

    end

endmodule