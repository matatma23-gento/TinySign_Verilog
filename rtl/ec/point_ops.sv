`timescale 1ns/1ps
`default_nettype none
module point_ops #(parameter integer WIDTH=256) (
    input wire clk, input wire rst_n, input wire start, input wire do_double,
    input wire [WIDTH-1:0] x1, input wire [WIDTH-1:0] y1, input wire [WIDTH-1:0] z1,
    input wire [WIDTH-1:0] x2, input wire [WIDTH-1:0] y2, input wire [WIDTH-1:0] z2,
    output reg [WIDTH-1:0] x3, output reg [WIDTH-1:0] y3, output reg [WIDTH-1:0] z3,
    output wire busy, output reg done, output reg error
);
    localparam [WIDTH-1:0] P = 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    localparam [2:0] OP_END=3'd0, OP_ADD=3'd1, OP_SUB=3'd2, OP_MUL=3'd3;
    localparam [1:0] ST_IDLE=2'd0, ST_FETCH=2'd1, ST_WAIT=2'd2;
    reg [1:0] state;
    reg compute_double;
    reg [5:0] pc;
    reg [WIDTH-1:0] t [0:31];
    reg [4:0] src_a_idx, src_b_idx, dst_idx;
    reg [2:0] op_code;
    reg [WIDTH-1:0] add_a, add_b, sub_a, sub_b, mul_a, mul_b;
    reg add_start, sub_start, mul_start;
    wire [WIDTH-1:0] add_result, sub_result, mul_result;
    wire add_busy, sub_busy, mul_busy, add_done, sub_done, mul_done;
    wire add_error, sub_error, mul_error;
    wire [WIDTH-1:0] selected_result = (op_code==OP_ADD) ? add_result :
                                             (op_code==OP_SUB) ? sub_result : mul_result;
    assign busy = (state != ST_IDLE);

    mod_add #(.WIDTH(WIDTH)) u_add(.clk(clk),.rst_n(rst_n),.start(add_start),.a(add_a),.b(add_b),.modulus(P),.result(add_result),.busy(add_busy),.done(add_done),.error(add_error));
    mod_sub #(.WIDTH(WIDTH)) u_sub(.clk(clk),.rst_n(rst_n),.start(sub_start),.a(sub_a),.b(sub_b),.modulus(P),.result(sub_result),.busy(sub_busy),.done(sub_done),.error(sub_error));
    mod_mul #(.WIDTH(WIDTH)) u_mul(.clk(clk),.rst_n(rst_n),.start(mul_start),.a(mul_a),.b(mul_b),.modulus(P),.result(mul_result),.busy(mul_busy),.done(mul_done),.error(mul_error));

    always @* begin
        op_code=OP_END; src_a_idx=0; src_b_idx=0; dst_idx=0;
        if (compute_double) begin
            case (pc)
                0: begin op_code=OP_MUL; src_a_idx=2; src_b_idx=2; dst_idx=8; end // delta=Z^2
                1: begin op_code=OP_MUL; src_a_idx=1; src_b_idx=1; dst_idx=9; end // gamma=Y^2
                2: begin op_code=OP_MUL; src_a_idx=0; src_b_idx=9; dst_idx=10; end // beta=X*gamma
                3: begin op_code=OP_SUB; src_a_idx=0; src_b_idx=8; dst_idx=11; end
                4: begin op_code=OP_ADD; src_a_idx=0; src_b_idx=8; dst_idx=12; end
                5: begin op_code=OP_MUL; src_a_idx=11; src_b_idx=12; dst_idx=11; end
                6: begin op_code=OP_ADD; src_a_idx=11; src_b_idx=11; dst_idx=13; end
                7: begin op_code=OP_ADD; src_a_idx=13; src_b_idx=11; dst_idx=13; end // alpha=3(X-delta)(X+delta)
                8: begin op_code=OP_MUL; src_a_idx=13; src_b_idx=13; dst_idx=14; end // alpha^2
                9: begin op_code=OP_ADD; src_a_idx=10; src_b_idx=10; dst_idx=15; end
                10: begin op_code=OP_ADD; src_a_idx=15; src_b_idx=15; dst_idx=16; end
                11: begin op_code=OP_ADD; src_a_idx=16; src_b_idx=16; dst_idx=17; end // 8 beta
                12: begin op_code=OP_SUB; src_a_idx=14; src_b_idx=17; dst_idx=18; end // X3
                13: begin op_code=OP_MUL; src_a_idx=9; src_b_idx=9; dst_idx=19; end // gamma^2
                14: begin op_code=OP_ADD; src_a_idx=19; src_b_idx=19; dst_idx=20; end
                15: begin op_code=OP_ADD; src_a_idx=20; src_b_idx=20; dst_idx=21; end
                16: begin op_code=OP_ADD; src_a_idx=21; src_b_idx=21; dst_idx=22; end // 8 gamma^2
                17: begin op_code=OP_SUB; src_a_idx=16; src_b_idx=18; dst_idx=23; end // 4 beta-X3
                18: begin op_code=OP_MUL; src_a_idx=13; src_b_idx=23; dst_idx=24; end
                19: begin op_code=OP_SUB; src_a_idx=24; src_b_idx=22; dst_idx=25; end // Y3
                20: begin op_code=OP_MUL; src_a_idx=1; src_b_idx=2; dst_idx=26; end
                21: begin op_code=OP_ADD; src_a_idx=26; src_b_idx=26; dst_idx=27; end // Z3=2YZ
                default: op_code=OP_END;
            endcase
        end else begin
            case (pc)
                0: begin op_code=OP_MUL; src_a_idx=2; src_b_idx=2; dst_idx=8; end // Z1^2
                1: begin op_code=OP_MUL; src_a_idx=5; src_b_idx=5; dst_idx=9; end // Z2^2
                2: begin op_code=OP_MUL; src_a_idx=0; src_b_idx=9; dst_idx=10; end // U1
                3: begin op_code=OP_MUL; src_a_idx=3; src_b_idx=8; dst_idx=11; end // U2
                4: begin op_code=OP_MUL; src_a_idx=9; src_b_idx=5; dst_idx=12; end // Z2^3
                5: begin op_code=OP_MUL; src_a_idx=1; src_b_idx=12; dst_idx=13; end // S1
                6: begin op_code=OP_MUL; src_a_idx=8; src_b_idx=2; dst_idx=14; end // Z1^3
                7: begin op_code=OP_MUL; src_a_idx=4; src_b_idx=14; dst_idx=15; end // S2
                8: begin op_code=OP_SUB; src_a_idx=11; src_b_idx=10; dst_idx=16; end // H=U2-U1
                9: begin op_code=OP_SUB; src_a_idx=15; src_b_idx=13; dst_idx=17; end // R=S2-S1
                10: begin op_code=OP_MUL; src_a_idx=16; src_b_idx=16; dst_idx=18; end // H^2
                11: begin op_code=OP_MUL; src_a_idx=16; src_b_idx=18; dst_idx=19; end // H^3
                12: begin op_code=OP_MUL; src_a_idx=10; src_b_idx=18; dst_idx=20; end // V=U1*H^2
                13: begin op_code=OP_MUL; src_a_idx=17; src_b_idx=17; dst_idx=21; end // R^2
                14: begin op_code=OP_ADD; src_a_idx=20; src_b_idx=20; dst_idx=22; end // 2V
                15: begin op_code=OP_SUB; src_a_idx=21; src_b_idx=19; dst_idx=23; end
                16: begin op_code=OP_SUB; src_a_idx=23; src_b_idx=22; dst_idx=24; end // X3
                17: begin op_code=OP_SUB; src_a_idx=20; src_b_idx=24; dst_idx=25; end
                18: begin op_code=OP_MUL; src_a_idx=17; src_b_idx=25; dst_idx=26; end
                19: begin op_code=OP_MUL; src_a_idx=13; src_b_idx=19; dst_idx=27; end
                20: begin op_code=OP_SUB; src_a_idx=26; src_b_idx=27; dst_idx=29; end // Y3=R(V-X3)-S1*H^3
                21: begin op_code=OP_MUL; src_a_idx=2; src_b_idx=5; dst_idx=30; end
                22: begin op_code=OP_MUL; src_a_idx=30; src_b_idx=16; dst_idx=30; end // Z3=Z1*Z2*H
                default: op_code=OP_END;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=ST_IDLE; compute_double<=0; pc<=0;
            add_a<=0; add_b<=0; sub_a<=0; sub_b<=0; mul_a<=0; mul_b<=0;
            add_start<=0; sub_start<=0; mul_start<=0;
            x3<=0; y3<=1; z3<=0; done<=0; error<=0;
        end else begin
            add_start<=0; sub_start<=0; mul_start<=0; done<=0; error<=0;
            case (state)
                ST_IDLE: if (start) begin
                    if (x1>=P || y1>=P || z1>=P || x2>=P || y2>=P || z2>=P) begin
                        error<=1;
                    end else if (do_double && ((z1==0) || (y1==0))) begin
                        x3<=0; y3<=1; z3<=0; done<=1;
                    end else if (!do_double && z1==0) begin
                        x3<=x2; y3<=y2; z3<=z2; done<=1;
                    end else if (!do_double && z2==0) begin
                        x3<=x1; y3<=y1; z3<=z1; done<=1;
                    end else begin
                        t[0]<=x1; t[1]<=y1; t[2]<=z1;
                        t[3]<=x2; t[4]<=y2; t[5]<=z2;
                        compute_double<=do_double; pc<=0; state<=ST_FETCH;
                    end
                end
                ST_FETCH: begin
                    if (op_code==OP_END) begin
                        if (compute_double) begin
                            x3<=t[18]; y3<=t[25]; z3<=t[27]; done<=1; state<=ST_IDLE;
                        end else if (t[16]==0) begin
                            if (t[17]==0) begin
                                compute_double<=1; pc<=0;
                            end else begin
                                x3<=0; y3<=1; z3<=0; done<=1; state<=ST_IDLE;
                            end
                        end else begin
                            x3<=t[24]; y3<=t[29]; z3<=t[30]; done<=1; state<=ST_IDLE;
                        end
                    end else begin
                        if (op_code==OP_ADD) begin
                            add_a<=t[src_a_idx]; add_b<=t[src_b_idx]; add_start<=1;
                        end else if (op_code==OP_SUB) begin
                            sub_a<=t[src_a_idx]; sub_b<=t[src_b_idx]; sub_start<=1;
                        end else begin
                            mul_a<=t[src_a_idx]; mul_b<=t[src_b_idx]; mul_start<=1;
                        end
                        state<=ST_WAIT;
                    end
                end
                ST_WAIT: begin
                    if (add_error || sub_error || mul_error) begin
                        error<=1; state<=ST_IDLE;
                    end else if ((op_code==OP_ADD && add_done) ||
                                 (op_code==OP_SUB && sub_done) ||
                                 (op_code==OP_MUL && mul_done)) begin
                        t[dst_idx]<=selected_result; pc<=pc+1'b1; state<=ST_FETCH;
                    end
                end
                default: state<=ST_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
