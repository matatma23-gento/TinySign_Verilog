`timescale 1ns/1ps
`default_nettype none
module mod_inv #(parameter integer WIDTH = 256) (
    input wire clk, input wire rst_n, input wire start,
    input wire [WIDTH-1:0] a, input wire [WIDTH-1:0] modulus,
    output reg [WIDTH-1:0] result, output wire busy,
    output reg done, output reg error
);
    localparam ST_IDLE = 2'd0, ST_LAUNCH = 2'd1, ST_WAIT = 2'd2;
    reg [1:0] state;
    reg [WIDTH-1:0] base_reg, exponent_reg, accumulator_reg, modulus_reg;
    reg [8:0] bit_count;
    reg mul_start;
    wire [WIDTH-1:0] square_result, product_result;
    wire square_busy, product_busy, square_done, product_done;
    wire square_error, product_error;
    wire [WIDTH-1:0] selected_result = exponent_reg[0] ? product_result : accumulator_reg;
    assign busy = (state != ST_IDLE);

    mod_mul #(.WIDTH(WIDTH)) u_square (
        .clk(clk), .rst_n(rst_n), .start(mul_start),
        .a(base_reg), .b(base_reg), .modulus(modulus_reg),
        .result(square_result), .busy(square_busy), .done(square_done), .error(square_error)
    );
    mod_mul #(.WIDTH(WIDTH)) u_product (
        .clk(clk), .rst_n(rst_n), .start(mul_start),
        .a(accumulator_reg), .b(base_reg), .modulus(modulus_reg),
        .result(product_result), .busy(product_busy), .done(product_done), .error(product_error)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE; base_reg <= 0; exponent_reg <= 0;
            accumulator_reg <= 0; modulus_reg <= 0; bit_count <= 0;
            mul_start <= 0; result <= 0; done <= 0; error <= 0;
        end else begin
            mul_start <= 0; done <= 0; error <= 0;
            case (state)
                ST_IDLE: if (start) begin
                    if (modulus < 3 || a == 0 || a >= modulus) begin
                        error <= 1;
                    end else begin
                        base_reg <= a; exponent_reg <= modulus - 2;
                        accumulator_reg <= {{(WIDTH-1){1'b0}}, 1'b1};
                        modulus_reg <= modulus; bit_count <= 0; state <= ST_LAUNCH;
                    end
                end
                ST_LAUNCH: begin
                    mul_start <= 1; state <= ST_WAIT;
                end
                ST_WAIT: begin
                    if (square_error || product_error) begin
                        error <= 1; state <= ST_IDLE;
                    end else if (square_done && product_done) begin
                        if (bit_count == WIDTH-1) begin
                            result <= selected_result; done <= 1; state <= ST_IDLE;
                        end else begin
                            accumulator_reg <= selected_result;
                            base_reg <= square_result;
                            exponent_reg <= exponent_reg >> 1;
                            bit_count <= bit_count + 1'b1; state <= ST_LAUNCH;
                        end
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
