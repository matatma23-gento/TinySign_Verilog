`timescale 1ns/1ps
`default_nettype none
// Minimal DE10-Nano board bring-up test.
// This image deliberately excludes the TinySign cryptographic core so that
// clock, reset, LEDs, and UART can be validated on the 5CSEBA6U23I7 device.
module tinysign_board_selftest #(
    parameter integer CLOCKS_PER_BIT = 434,
    parameter integer TEST_CYCLES = 50_000_000
) (
    input  wire       clk,
    input  wire       rst_n,
    output reg  [3:0] led,
    output wire       tx
);
    reg [31:0] count;
    reg finished;
    reg passed;
    reg [7:0] failure_code;
    wire sent;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count        <= 32'd0;
            finished     <= 1'b0;
            passed       <= 1'b0;
            failure_code <= 8'h00;
            led          <= 4'b0001;
        end else if (!finished) begin
            count <= count + 1'b1;
            // Running pattern proves the clock and reset are alive.
            led <= {count[25], count[24], count[23], 1'b1};
            if (count == TEST_CYCLES - 1) begin
                finished <= 1'b1;
                passed   <= 1'b1;
                led      <= 4'b1100;
            end
        end
    end

    selftest_uart_report #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) u_report (
        .clk              (clk),
        .rst_n            (rst_n),
        .finished         (finished),
        .passed           (passed),
        .failure_code     (failure_code),
        .provision_cycles (32'd0),
        .sign_cycles      (32'd0),
        .tx               (tx),
        .sent             (sent)
    );
endmodule
`default_nettype wire
