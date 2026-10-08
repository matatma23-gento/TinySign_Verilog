`timescale 1ns/1ps
`default_nettype none
module tb_hmac;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,start=0;
    reg [255:0] key=0;
    reg [1023:0] message=0;
    reg [7:0] message_length=0;
    wire [255:0] digest;
    wire busy,done,error;
    hmac_sha256 dut(.clk(clk),.rst_n(rst_n),.start(start),.key(key),.message(message),.message_length(message_length),.digest(digest),.busy(busy),.done(done),.error(error));
    localparam [255:0] EXPECTED=256'h5BDCC146BF60754E6A042426089575C75A003F089D2739839DEC58B964EC3843;
    localparam [255:0] LONG_EXPECTED=256'h122DB1DE98DAE4DFA33F2DA8E98494C80BFF807B479FD79261B37E25F267EE58;
    initial begin
        key[255:224]=32'h4A656665; // "Jefe", followed by zero padding
        message[1023 -:224]=224'h7768617420646f2079612077616e7420666f72206e6f7468696e673f;
        message_length=28;
        #20;rst_n=1;
        @(negedge clk);start=1;@(negedge clk);start=0;
        repeat(1000) begin
            @(negedge clk);
            if(done) begin
                #1;if(error || digest!==EXPECTED)$fatal(1,"HMAC-SHA-256 mismatch expected=%h actual=%h",EXPECTED,digest);
                $display("PASS: HMAC-SHA-256 RFC 4231 test case 2");
                key=0;
                message=0;
                message[1023 -:776]={256'h0101010101010101010101010101010101010101010101010101010101010101,8'h00,256'hC9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721,256'hAF2BDBE1AA9B6EC1E2ADE1D694F41FC71A831D0268E9891562113D8A62ADD1BF};
                message_length=97;
                @(negedge clk);start=1;@(negedge clk);start=0;
                repeat(1500) begin
                    @(negedge clk);
                    if(done) begin
                        #1;if(error || digest!==LONG_EXPECTED)$fatal(1,"long HMAC mismatch expected=%h actual=%h",LONG_EXPECTED,digest);
                        $display("PASS: HMAC-SHA-256 97-byte RFC 6979 inner vector");$finish;
                    end
                end
                $fatal(1,"long HMAC timeout");
            end
        end
        $fatal(1,"HMAC-SHA-256 timeout");
    end
endmodule
`default_nettype wire
