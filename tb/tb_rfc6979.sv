`timescale 1ns/1ps
`default_nettype none
module tb_rfc6979;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,start=0;
    reg [255:0] private_key=0,digest=0;
    wire [255:0] nonce;
    wire busy,done,error;
    localparam [255:0] D=256'hC9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721;
    localparam [255:0] H=256'hAF2BDBE1AA9B6EC1E2ADE1D694F41FC71A831D0268E9891562113D8A62ADD1BF;
    localparam [255:0] EXPECTED=256'hA6E3C57DD01ABE90086538398355DD4C3B17AA873382B0F24D6129493D8AAD60;
    integer cycles;
    rfc6979 dut(.clk(clk),.rst_n(rst_n),.start(start),.private_key(private_key),.digest(digest),.nonce(nonce),.busy(busy),.done(done),.error(error));
    initial begin
        private_key=D;digest=H;#20;rst_n=1;
        @(negedge clk);start=1;@(negedge clk);start=0;cycles=0;
        while(done!==1'b1 && error!==1'b1 && cycles<10000) begin @(negedge clk);cycles=cycles+1;end
        #1;if(error || !done || nonce!==EXPECTED)$fatal(1,"RFC6979 mismatch/timeout cycles=%0d got=%h expected=%h",cycles,nonce,EXPECTED);
        $display("PASS: RFC 6979 P-256 SHA-256 nonce (%0d cycles)",cycles);
        @(negedge clk);private_key=0;start=1;@(negedge clk);start=0;#1;
        if(error!==1'b1)$fatal(1,"RFC6979 accepted zero private key");
        $display("PASS: RFC 6979 rejects zero private key");$finish;
    end
endmodule
`default_nettype wire
