`timescale 1ns/1ps
`default_nettype none
module tb_tinysign_de10nano;
    reg clk=0;always #10 clk=~clk;
    reg reset_n=0,avs_read=0,avs_write=0;
    reg [7:0] avs_address=0;
    reg [31:0] avs_writedata=0;
    reg [3:0] avs_byteenable=4'hF;
    wire [31:0] avs_readdata;
    wire avs_waitrequest;
    tinysign_de10nano dut(.clk(clk),.reset_n(reset_n),.avs_address(avs_address),.avs_read(avs_read),.avs_write(avs_write),
        .avs_writedata(avs_writedata),.avs_byteenable(avs_byteenable),.avs_readdata(avs_readdata),.avs_waitrequest(avs_waitrequest));
    initial begin
        #25;reset_n=1;@(negedge clk);avs_address=8'h04;avs_read=1;#1;
        if(avs_waitrequest||avs_readdata[0]!==1'b1)begin $display("FAIL: Avalon ready/status read failed"); $stop; end
        avs_read=0;avs_address=8'h00;avs_writedata=32'hDEADBEEF;avs_write=1;@(negedge clk);avs_write=0;
        avs_address=8'h08;#1;if(avs_readdata[7:0]!==8'h01)begin $display("FAIL: Avalon write did not report unknown command"); $stop; end
        avs_address=8'h00;avs_writedata=0;avs_byteenable=4'h1;avs_write=1;@(negedge clk);avs_write=0;avs_byteenable=4'hF;
        avs_address=8'h08;#1;if(avs_readdata[7:0]!==8'h04)begin $display("FAIL: Avalon byte-enable rejection failed"); $stop; end
        $display("PASS: DE10-Nano Avalon-MM shell elaboration, status read, command write and byte enables");$finish;
    end
endmodule
`default_nettype wire
