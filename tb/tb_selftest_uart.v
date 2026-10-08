`timescale 1ns/1ps
`default_nettype none
module tb_selftest_uart;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,finished=0,passed=1;
    reg [7:0] failure_code=0;
    wire tx,sent;
    reg [223:0] expected;
    reg [7:0] received;
    integer i,j;
    selftest_uart_report #(.CLOCKS_PER_BIT(4)) dut(.clk(clk),.rst_n(rst_n),
        .finished(finished),.passed(passed),.failure_code(failure_code),
        .provision_cycles(32'h00123456),.sign_cycles(32'h00765432),.tx(tx),.sent(sent));
    task receive_report;
        begin
            for(i=0;i<28;i=i+1) begin
                @(negedge tx); #60;
                for(j=0;j<8;j=j+1) begin received[j]=tx;#40;end
                if(tx!==1'b1 || received!==expected[223-i*8 -:8]) begin
                    $display("FAIL: UART byte %0d got=%h",i,received);$stop;
                end
            end
            repeat(10) @(negedge clk);
            if(!sent) begin $display("FAIL: UART never completed");$stop;end
        end
    endtask
    initial begin
        expected={"TS1,P,00,00123456,00765432",8'h0d,8'h0a};
        #23;rst_n=1;finished=1;receive_report;
        rst_n=0;finished=0;#23;rst_n=1;passed=0;failure_code=8'hff;finished=1;
        expected={"TS1,F,FF,00123456,00765432",8'h0d,8'h0a};receive_report;
        $display("PASS: UART report framing, measured cycle fields, pass/fail, restart");$finish;
    end
    initial begin #100000; $display("FAIL: UART timeout");$stop;end
endmodule
`default_nettype wire
