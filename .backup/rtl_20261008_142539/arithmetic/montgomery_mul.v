`timescale 1ns/1ps
`default_nettype none
// Radix-2 Montgomery product: result = a*b*R^-1 mod modulus, R=2^WIDTH.
// WIDTH >= 2; modulus must be odd and >= 3; a,b must be < modulus.
// Inputs are sampled only on start while idle. Starts while busy are ignored.
// Valid requests take WIDTH+1 clocks after acceptance; done/error pulse once.
module montgomery_mul #(parameter integer WIDTH = 256) (
    input wire clk, input wire rst_n, input wire start,
    input wire [WIDTH-1:0] a, input wire [WIDTH-1:0] b,
    input wire [WIDTH-1:0] modulus,
    output reg [WIDTH-1:0] result, output wire busy,
    output reg done, output reg error
);
    function integer clog2;
        input integer value;
        integer remaining;
        begin
            remaining = value-1;
            for (clog2=0; remaining>0; clog2=clog2+1)
                remaining = remaining >> 1;
            if (clog2==0) clog2=1;
        end
    endfunction
    localparam integer COUNT_WIDTH = clog2(WIDTH);
    localparam [1:0] ST_IDLE=2'd0, ST_RUN=2'd1, ST_REDUCE=2'd2;
    reg [1:0] state;
    reg [COUNT_WIDTH-1:0] round_count;
    reg [WIDTH-1:0] a_reg, b_reg, modulus_reg;
    // Accumulator stays below 2m; pre-shift sums need TWO guard bits.
    reg [WIDTH:0] accumulator;
    wire [WIDTH+1:0] partial_sum = {1'b0, accumulator} +
        (a_reg[0] ? {2'b00, b_reg} : {(WIDTH+2){1'b0}});
    wire [WIDTH+1:0] even_sum = partial_sum +
        (partial_sum[0] ? {2'b00, modulus_reg} : {(WIDTH+2){1'b0}});
    wire [WIDTH:0] reduced = (accumulator >= {1'b0, modulus_reg}) ?
        accumulator - {1'b0, modulus_reg} : accumulator;
    assign busy = (state != ST_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=ST_IDLE; round_count<=0; a_reg<=0; b_reg<=0;
            modulus_reg<=0; accumulator<=0; result<=0; done<=0; error<=0;
        end else begin
            done<=0; error<=0;
            case (state)
                ST_IDLE: if (start) begin
                    if (modulus<3 || !modulus[0] || a>=modulus || b>=modulus)
                        error<=1;
                    else begin
                        a_reg<=a; b_reg<=b; modulus_reg<=modulus;
                        accumulator<=0; round_count<=0; state<=ST_RUN;
                    end
                end
                ST_RUN: begin
                    accumulator<=even_sum[WIDTH+1:1];
                    a_reg<=a_reg>>1;
                    if (round_count==WIDTH-1) state<=ST_REDUCE;
                    else round_count<=round_count+1'b1;
                end
                ST_REDUCE: begin
                    result<=reduced[WIDTH-1:0]; done<=1; state<=ST_IDLE;
                    a_reg<=0; b_reg<=0; modulus_reg<=0; accumulator<=0;
                    round_count<=0;
                end
                default: state<=ST_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
