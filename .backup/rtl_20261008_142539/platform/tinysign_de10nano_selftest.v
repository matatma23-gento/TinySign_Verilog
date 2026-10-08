`timescale 1ns/1ps
`default_nettype none
// Standalone DEVELOPMENT test image; no HPS system is required.
// KEY0 resets/re-runs. UART is FPGA GPIO0[0], NOT the onboard HPS USB-UART.
module tinysign_de10nano_selftest (
    input wire FPGA_CLK1_50,input wire KEY0_N,
    output wire [3:0] LED,output wire GPIO0_TX
);
    // Asynchronous assertion, synchronous release. Hold KEY0 after programming.
    reg [1:0] reset_pipe=0;
    always @(posedge FPGA_CLK1_50 or negedge KEY0_N) begin
        if(!KEY0_N) reset_pipe<=0;
        else reset_pipe<={reset_pipe[0],1'b1};
    end
    wire rst_n=reset_pipe[1];
    reg [25:0] heartbeat;
    always @(posedge FPGA_CLK1_50 or negedge rst_n) begin
        if(!rst_n) heartbeat<=0;
        else heartbeat<=heartbeat+1'b1;
    end
    wire finished,passed,busy,sent;
    wire [7:0] failure_code,step;
    wire [31:0] provision_cycles,sign_cycles;
    tinysign_board_selftest u_test(.clk(FPGA_CLK1_50),.rst_n(rst_n),
        .finished(finished),.passed(passed),.failure_code(failure_code),
        .provision_cycles(provision_cycles),.sign_cycles(sign_cycles),.core_busy(busy),.step(step));
    selftest_uart_report u_report(.clk(FPGA_CLK1_50),.rst_n(rst_n),
        .finished(finished),.passed(passed),.failure_code(failure_code),
        .provision_cycles(provision_cycles),.sign_cycles(sign_cycles),.tx(GPIO0_TX),.sent(sent));
    assign LED={heartbeat[25],(finished&&!passed),(finished&&passed),!finished};
endmodule
`default_nettype wire
