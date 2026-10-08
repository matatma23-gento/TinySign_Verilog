`timescale 1ns/1ps
`default_nettype none
module tb_ecdsa_signer;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,start=0;
    reg [255:0] private_key=0,digest=0;
    wire [255:0] r,s;
    wire busy,done,error;
    localparam [255:0] D=256'hC9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721;
    localparam [255:0] H=256'hAF2BDBE1AA9B6EC1E2ADE1D694F41FC71A831D0268E9891562113D8A62ADD1BF;
    localparam [255:0] EXPECTED_R=256'hEFD48B2AACB6A8FD1140DD9CD45E81D69D2C877B56AAF991C34D0EA84EAF3716;
    localparam [255:0] EXPECTED_S=256'hF7CB1C942D657C41D436C7A1B6E29F65F3E900DBB9AFF4064DC4AB2F843ACDA8;
    integer cycles;
    ecdsa_signer dut(.clk(clk),.rst_n(rst_n),.clear(1'b0),.start(start),.private_key(private_key),.digest(digest),.r(r),.s(s),.busy(busy),.done(done),.error(error));
    initial begin
        private_key=D;digest=H;#20;rst_n=1;
        @(negedge clk);start=1;@(negedge clk);start=0;cycles=0;
        while(done!==1'b1 && error!==1'b1 && cycles<4000000) begin @(negedge clk);cycles=cycles+1;end
        #1;if(error || !done || r!==EXPECTED_R || s!==EXPECTED_S)
            $fatal(1,"ECDSA P-256 signature mismatch/timeout cycles=%0d r=%h s=%h",cycles,r,s);
        $display("PASS: ECDSA P-256 RFC 6979 signature vector (%0d cycles)",cycles);
        @(negedge clk);private_key=0;start=1;@(negedge clk);start=0;#1;
        if(error!==1'b1)$fatal(1,"signer accepted zero private key");
        $display("PASS: ECDSA signer rejects zero private key");$finish;
    end
endmodule
`default_nettype wire
