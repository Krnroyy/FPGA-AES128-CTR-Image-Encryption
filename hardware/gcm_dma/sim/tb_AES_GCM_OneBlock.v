`timescale 1ns / 1ps

module tb_AES_GCM_OneBlock;

reg clk = 1'b0;
reg rst = 1'b1;
always #5 clk = ~clk;

reg start = 1'b0;
reg decrypt = 1'b0;
reg [127:0] key = 128'd0;
reg [95:0] iv = 96'd0;
reg [127:0] data_in = 128'd0;
reg [127:0] expected_tag = 128'd0;
wire [127:0] data_out;
wire [127:0] tag_out;
wire tag_valid;
wire auth_ok;
wire busy;
wire done;

localparam [127:0] NIST_PLAINTEXT =
    128'h00000000000000000000000000000000;
localparam [127:0] NIST_CIPHERTEXT =
    128'h0388dace60b6a392f328c2b971b2fe78;
localparam [127:0] NIST_TAG =
    128'hab6e47d42cec13bdf53a67b21257bddf;

AES_GCM_OneBlock dut
(
    .clk(clk),
    .rst(rst),
    .start(start),
    .decrypt(decrypt),
    .key(key),
    .iv(iv),
    .data_in(data_in),
    .expected_tag(expected_tag),
    .data_out(data_out),
    .tag_out(tag_out),
    .tag_valid(tag_valid),
    .auth_ok(auth_ok),
    .busy(busy),
    .done(done)
);

task run_operation;
    input operation_decrypt;
    input [127:0] operation_data;
    input [127:0] operation_tag;
    begin
        while(busy)
            @(posedge clk);
        @(posedge clk);
        decrypt <= operation_decrypt;
        data_in <= operation_data;
        expected_tag <= operation_tag;
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        while(!done)
            @(posedge clk);
        @(posedge clk);
    end
endtask

initial
begin
    repeat(6) @(posedge clk);
    rst <= 1'b0;
    repeat(2) @(posedge clk);

    // NIST SP 800-38D, zero key, zero 96-bit IV, one zero block.
    run_operation(1'b0, NIST_PLAINTEXT, 128'd0);
    if(data_out !== NIST_CIPHERTEXT || tag_out !== NIST_TAG ||
       !tag_valid || !auth_ok)
    begin
        $display("FAIL: GCM encryption mismatch");
        $display("DATA expected=%032h actual=%032h", NIST_CIPHERTEXT,
                 data_out);
        $display("TAG  expected=%032h actual=%032h", NIST_TAG, tag_out);
        $finish;
    end
    $display("PASS: NIST AES-GCM encryption ciphertext and tag");

    run_operation(1'b1, NIST_CIPHERTEXT, NIST_TAG);
    if(data_out !== NIST_PLAINTEXT || tag_out !== NIST_TAG ||
       !tag_valid || !auth_ok)
    begin
        $display("FAIL: authenticated GCM decryption mismatch");
        $finish;
    end
    $display("PASS: NIST AES-GCM authenticated decryption");

    // Flip one ciphertext bit but keep the original expected tag.
    run_operation(1'b1, NIST_CIPHERTEXT ^ 128'd1, NIST_TAG);
    if(data_out !== (NIST_PLAINTEXT ^ 128'd1))
    begin
        $display("FAIL: modified ciphertext did not propagate as expected");
        $finish;
    end
    if(!tag_valid || auth_ok)
    begin
        $display("FAIL: modified ciphertext was not rejected");
        $finish;
    end
    $display("PASS: modified ciphertext rejected by GCM tag verification");
    $display("PASS: AES_GCM_OneBlock all validation tests");
    $finish;
end

initial
begin
    #20000;
    $display("FAIL: simulation timeout");
    $finish;
end

endmodule
