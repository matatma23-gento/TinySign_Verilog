`timescale 1ns/1ps
`default_nettype none
// Ordinary modular product using the Montgomery engine.
// Convert b to bR mod m with WIDTH doublings, then Mont(a,bR)=a*b mod m.
// This avoids R^2 tables and keeps every caller in the ordinary residue domain.
// WIDTH >= 2; odd modulus >= 3; canonical operands a,b < modulus.
// Latency: 2*WIDTH+3 clocks after acceptance, independent of operand values.
module mod_mul #(parameter integer WIDTH = 256) (
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
            remaining=value-1;
            for (clog2=0; remaining>0; clog2=clog2+1)
                remaining=remaining>>1;
            if (clog2==0) clog2=1;
        end
    endfunction
    localparam integer COUNT_WIDTH=clog2(WIDTH);
    localparam [1:0] ST_IDLE=2'd0, ST_CONVERT=2'd1, ST_WAIT=2'd2;
    reg [1:0] state;
    reg [WIDTH-1:0] a_reg, b_mont, modulus_reg;
    reg [COUNT_WIDTH-1:0] round_count;
    reg mont_start;
    wire [WIDTH:0] doubled={b_mont, 1'b0};
    wire [WIDTH:0] converted=(doubled>={1'b0,modulus_reg}) ?
        doubled-{1'b0,modulus_reg} : doubled;
    wire [WIDTH-1:0] mont_result;
    wire mont_done, mont_error;
    assign busy=(state!=ST_IDLE);

    montgomery_mul #(.WIDTH(WIDTH)) u_montgomery (
        .clk(clk), .rst_n(rst_n), .start(mont_start),
        .a(a_reg), .b(b_mont), .modulus(modulus_reg),
        .result(mont_result), .busy(), .done(mont_done), .error(mont_error)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=ST_IDLE; a_reg<=0; b_mont<=0; modulus_reg<=0;
            round_count<=0; mont_start<=0; result<=0; done<=0; error<=0;
        end else begin
            mont_start<=0; done<=0; error<=0;
            case (state)
                ST_IDLE: if (start) begin
                    if (modulus<3 || !modulus[0] || a>=modulus || b>=modulus)
                        error<=1;
                    else begin
                        a_reg<=a; b_mont<=b; modulus_reg<=modulus;
                        round_count<=0; state<=ST_CONVERT;
                    end
                end
                ST_CONVERT: begin
                    b_mont<=converted[WIDTH-1:0];
                    if (round_count==WIDTH-1) begin
                        mont_start<=1; state<=ST_WAIT;
                    end else round_count<=round_count+1'b1;
                end
                ST_WAIT: begin
                    if (mont_error || mont_done) begin
                        if (mont_error) error<=1;
                        else begin result<=mont_result; done<=1; end
                        state<=ST_IDLE; a_reg<=0; b_mont<=0;
                        modulus_reg<=0; round_count<=0;
                    end
                end
                default: state<=ST_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
