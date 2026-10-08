`timescale 1ns/1ps
`default_nettype none
module mod_mul #(parameter integer WIDTH = 256) (
    input wire clk, input wire rst_n, input wire start,
    input wire [WIDTH-1:0] a, input wire [WIDTH-1:0] b,
    input wire [WIDTH-1:0] modulus,
    output reg [WIDTH-1:0] result, output wire busy,
    output reg done, output reg error
);
    localparam ST_IDLE = 1'b0, ST_RUN = 1'b1;
    reg state;
    reg [WIDTH-1:0] base_reg, multiplier_reg, accumulator_reg, modulus_reg;
    reg [8:0] round_count;
    wire [WIDTH:0] addend = multiplier_reg[0] ? {1'b0, base_reg} : {(WIDTH+1){1'b0}};
    wire [WIDTH:0] acc_sum = {1'b0, accumulator_reg} + addend;
    wire [WIDTH:0] base_double = {1'b0, base_reg} << 1;
    wire [WIDTH:0] modulus_ext = {1'b0, modulus_reg};
    wire [WIDTH:0] acc_reduced = (acc_sum >= modulus_ext) ? (acc_sum - modulus_ext) : acc_sum;
    wire [WIDTH:0] base_reduced = (base_double >= modulus_ext) ? (base_double - modulus_ext) : base_double;
    assign busy = (state != ST_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE; base_reg <= 0; multiplier_reg <= 0;
            accumulator_reg <= 0; modulus_reg <= 0; round_count <= 0;
            result <= 0; done <= 0; error <= 0;
        end else begin
            done <= 0; error <= 0;
            case (state)
                ST_IDLE: if (start) begin
                    if (modulus < 3 || a >= modulus || b >= modulus) begin
                        error <= 1;
                    end else begin
                        base_reg <= a; multiplier_reg <= b; accumulator_reg <= 0;
                        modulus_reg <= modulus; round_count <= 0; state <= ST_RUN;
                    end
                end
                ST_RUN: begin
                    if (round_count == WIDTH-1) begin
                        result <= acc_reduced[WIDTH-1:0];
                        done <= 1; state <= ST_IDLE;
                    end else begin
                        accumulator_reg <= acc_reduced[WIDTH-1:0];
                        base_reg <= base_reduced[WIDTH-1:0];
                        multiplier_reg <= multiplier_reg >> 1;
                        round_count <= round_count + 1'b1;
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
