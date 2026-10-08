`timescale 1ns/1ps
`default_nettype none
module mod_add #(parameter integer WIDTH = 256) (
    input wire clk, input wire rst_n, input wire start,
    input wire [WIDTH-1:0] a, input wire [WIDTH-1:0] b,
    input wire [WIDTH-1:0] modulus,
    output reg [WIDTH-1:0] result, output wire busy,
    output reg done, output reg error
);
    localparam ST_IDLE = 1'b0, ST_CALC = 1'b1;
    reg state;
    reg [WIDTH-1:0] a_reg, b_reg, mod_reg;
    wire [WIDTH:0] sum = {1'b0, a_reg} + {1'b0, b_reg};
    wire [WIDTH:0] mod_ext = {1'b0, mod_reg};
    assign busy = (state != ST_IDLE);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE; a_reg <= 0; b_reg <= 0; mod_reg <= 0;
            result <= 0; done <= 0; error <= 0;
        end else begin
            done <= 0; error <= 0;
            case (state)
                ST_IDLE: if (start) begin
                    if (modulus < 3 || a >= modulus || b >= modulus) begin
                        error <= 1;
                    end else begin
                        a_reg <= a; b_reg <= b; mod_reg <= modulus;
                        state <= ST_CALC;
                    end
                end
                ST_CALC: begin
                    result <= (sum >= mod_ext) ? (sum - mod_ext) : sum[WIDTH-1:0];
                    done <= 1; state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
