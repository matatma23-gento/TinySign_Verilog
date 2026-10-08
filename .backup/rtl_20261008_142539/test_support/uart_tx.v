`timescale 1ns/1ps
`default_nettype none
// 8 data bits, no parity, one stop bit, LSB first; idle high.
module uart_tx #(parameter integer CLOCKS_PER_BIT=434) (
    input wire clk,input wire rst_n,input wire start,input wire [7:0] data,
    output reg tx,output reg busy
);
    reg [9:0] frame;
    reg [3:0] bit_index;
    integer ticks;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin tx<=1;busy<=0;frame<=10'h3ff;bit_index<=0;ticks<=0;end
        else if(!busy) begin
            tx<=1;
            if(start) begin
                frame<={1'b1,data,1'b0};tx<=0;busy<=1;bit_index<=0;ticks<=0;
            end
        end else if(ticks==CLOCKS_PER_BIT-1) begin
            ticks<=0;
            if(bit_index==9) begin tx<=1;busy<=0;end
            else begin frame<={1'b1,frame[9:1]};tx<=frame[1];bit_index<=bit_index+1'b1;end
        end else ticks<=ticks+1;
    end
endmodule
`default_nettype wire
