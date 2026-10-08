`timescale 1ns/1ps
`default_nettype none
module tinysign_de10nano_selftest (
    input  wire       FPGA_CLK1_50,
    input  wire       KEY0_N,
    output wire [3:0] LED,
    output wire       GPIO0_TX
);
    reg [1:0] reset_pipe;
    wire rst_n = reset_pipe[1];

    always @(posedge FPGA_CLK1_50 or negedge KEY0_N) begin
        if (!KEY0_N) reset_pipe <= 2'b00;
        else         reset_pipe <= {reset_pipe[0], 1'b1};
    end

    tinysign_board_selftest #(.TEST_CYCLES(50_000_000)) u_test (
        .clk  (FPGA_CLK1_50),
        .rst_n(rst_n),
        .led  (LED),
        .tx   (GPIO0_TX)
    );
endmodule
`default_nettype wire
