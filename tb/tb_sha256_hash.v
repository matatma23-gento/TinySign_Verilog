`timescale 1ns/1ps
`default_nettype none
module tb_sha256_hash;
    localparam integer MAX_BYTES=192;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,start=0;
    reg [MAX_BYTES*8-1:0] message=0;
    reg [7:0] message_length=0;
    wire [255:0] digest;
    wire busy,done,error;
    integer cycles;

    sha256_hash #(.MAX_BYTES(MAX_BYTES)) dut(
        .clk(clk),.rst_n(rst_n),.start(start),.message(message),
        .message_length(message_length),.digest(digest),.busy(busy),
        .done(done),.error(error));

    task automatic check_hash(input [MAX_BYTES*8-1:0] msg,
                              input [7:0] msg_length,
                              input [255:0] expected);
        begin
            @(negedge clk); message=msg; message_length=msg_length; start=1;
            @(negedge clk); start=0; cycles=0;
            while(done!==1'b1 && error!==1'b1 && cycles<10000) begin
                @(negedge clk); cycles=cycles+1;
            end
            #1;
            if(error!==1'b0 || done!==1'b1 || digest!==expected) begin
                $display("FAIL SHA-256 len=%0d cycles=%0d expected=%h actual=%h",
                         msg_length,cycles,expected,digest);
                $stop;
            end
            $display("PASS SHA-256 len=%0d cycles=%0d",msg_length,cycles);
        end
    endtask

    initial begin
        #20; rst_n=1;
        check_hash(0,0,256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855);
        check_hash({24'h616263,{(MAX_BYTES*8-24){1'b0}}},3,
                   256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad);
        check_hash({448'h6162636462636465636465666465666765666768666768696768696a68696a6b696a6b6c6a6b6c6d6b6c6d6e6c6d6e6f6d6e6f706e6f7071,
                    {(MAX_BYTES*8-448){1'b0}}},56,
                   256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1);
        $display("PASS: SHA-256 empty, abc, and 56-byte standard vectors");
        $finish;
    end
endmodule
`default_nettype wire
