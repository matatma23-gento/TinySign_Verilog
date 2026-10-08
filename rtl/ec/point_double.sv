`timescale 1ns/1ps
`default_nettype none
module point_double #(parameter integer WIDTH=256) (
    input wire clk, input wire rst_n, input wire start,
    input wire [WIDTH-1:0] x1, input wire [WIDTH-1:0] y1, input wire [WIDTH-1:0] z1,
    output wire [WIDTH-1:0] x3, output wire [WIDTH-1:0] y3, output wire [WIDTH-1:0] z3,
    output wire busy, output wire done, output wire error
);
    point_ops #(.WIDTH(WIDTH)) u_ops(.clk(clk),.rst_n(rst_n),.start(start),.do_double(1'b1),
        .x1(x1),.y1(y1),.z1(z1),.x2({WIDTH{1'b0}}),.y2({WIDTH{1'b0}}),.z2({WIDTH{1'b0}}),
        .x3(x3),.y3(y3),.z3(z3),.busy(busy),.done(done),.error(error));
endmodule
`default_nettype wire
