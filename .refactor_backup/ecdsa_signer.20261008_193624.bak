`timescale 1ns/1ps
`default_nettype none
module ecdsa_signer #(
    parameter integer WIDTH=256,
    parameter integer OP_SLOT_CYCLES=14000
) (
    input wire clk,input wire rst_n,input wire clear,input wire start,
    input wire [WIDTH-1:0] private_key,input wire [WIDTH-1:0] digest,
    output reg [WIDTH-1:0] r,output reg [WIDTH-1:0] s,
    output wire busy,output reg done,output reg error
);
    localparam [WIDTH-1:0] P=256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    localparam [WIDTH-1:0] N=256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
    localparam [WIDTH-1:0] GX=256'h6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    localparam [WIDTH-1:0] GY=256'h4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;
    localparam [4:0] ST_IDLE=0,ST_NONCE_LAUNCH=1,ST_NONCE_WAIT=2,
        ST_SCALAR_LAUNCH=3,ST_SCALAR_WAIT=4,ST_ZINV_LAUNCH=5,ST_ZINV_WAIT=6,
        ST_Z2_LAUNCH=7,ST_Z2_WAIT=8,ST_X_LAUNCH=9,ST_X_WAIT=10,
        ST_KINV_LAUNCH=11,ST_KINV_WAIT=12,ST_RD_LAUNCH=13,ST_RD_WAIT=14,
        ST_SUM_LAUNCH=15,ST_SUM_WAIT=16,ST_S_LAUNCH=17,ST_S_WAIT=18;
    reg [4:0] state;
    reg [WIDTH-1:0] d_reg,z_reg,k_reg,x_reg,z_point_reg,zinv_reg,z2_reg,r_reg,kinv_reg,rd_reg,sum_reg;
    reg nonce_start,scalar_start,inv_start,mul_start,add_start;
    wire [WIDTH-1:0] nonce_value;
    wire nonce_busy,nonce_done,nonce_error;
    wire [WIDTH-1:0] px,py,pz;
    wire scalar_busy,scalar_done,scalar_error;
    wire [WIDTH-1:0] inv_result,mul_result,add_result;
    wire inv_busy,inv_done,inv_error,mul_busy,mul_done,mul_error,add_busy,add_done,add_error;
    reg [WIDTH-1:0] inv_a,mul_a,mul_b,add_a,add_b;
    wire core_rst_n=rst_n&&!clear;
    assign busy=(state!=ST_IDLE);

    rfc6979 #(.WIDTH(WIDTH)) u_nonce(.clk(clk),.rst_n(core_rst_n),.start(nonce_start),.private_key(d_reg),.digest(z_reg),.nonce(nonce_value),.busy(nonce_busy),.done(nonce_done),.error(nonce_error));
    scalar_mult #(.WIDTH(WIDTH),.OP_SLOT_CYCLES(OP_SLOT_CYCLES)) u_scalar(
        .clk(clk),.rst_n(core_rst_n),.start(scalar_start),.scalar(k_reg),.x_in(GX),.y_in(GY),.z_in({{(WIDTH-1){1'b0}},1'b1}),
        .x_out(px),.y_out(py),.z_out(pz),.busy(scalar_busy),.done(scalar_done),.error(scalar_error));
    mod_inv #(.WIDTH(WIDTH)) u_inverse(.clk(clk),.rst_n(core_rst_n),.start(inv_start),.a(inv_a),.modulus((state==ST_ZINV_LAUNCH||state==ST_ZINV_WAIT)?P:N),.result(inv_result),.busy(inv_busy),.done(inv_done),.error(inv_error));
    mod_mul #(.WIDTH(WIDTH)) u_multiply(.clk(clk),.rst_n(core_rst_n),.start(mul_start),.a(mul_a),.b(mul_b),.modulus((state==ST_Z2_LAUNCH||state==ST_Z2_WAIT||state==ST_X_LAUNCH||state==ST_X_WAIT)?P:N),.result(mul_result),.busy(mul_busy),.done(mul_done),.error(mul_error));
    mod_add #(.WIDTH(WIDTH)) u_add(.clk(clk),.rst_n(core_rst_n),.start(add_start),.a(add_a),.b(add_b),.modulus(N),.result(add_result),.busy(add_busy),.done(add_done),.error(add_error));

    task fail_transaction;
        begin error<=1;r<=0;s<=0;d_reg<=0;k_reg<=0;state<=ST_IDLE;end
    endtask

    always @(posedge clk or negedge core_rst_n) begin
        if(!core_rst_n) begin
            state<=ST_IDLE;d_reg<=0;z_reg<=0;k_reg<=0;x_reg<=0;z_point_reg<=0;
            zinv_reg<=0;z2_reg<=0;r_reg<=0;kinv_reg<=0;rd_reg<=0;sum_reg<=0;
            nonce_start<=0;scalar_start<=0;inv_start<=0;mul_start<=0;add_start<=0;
            inv_a<=0;mul_a<=0;mul_b<=0;add_a<=0;add_b<=0;
            r<=0;s<=0;done<=0;error<=0;
        end else begin
            nonce_start<=0;scalar_start<=0;inv_start<=0;mul_start<=0;add_start<=0;done<=0;error<=0;
            case(state)
                ST_IDLE: if(start) begin
                    r<=0;s<=0;
                    if(private_key==0||private_key>=N) error<=1;
                    else begin
                        d_reg<=private_key;z_reg<=(digest>=N)?digest-N:digest;
                        nonce_start<=1;state<=ST_NONCE_WAIT;
                    end
                end
                ST_NONCE_WAIT: begin
                    if(nonce_error) fail_transaction;
                    else if(nonce_done) begin k_reg<=nonce_value;scalar_start<=1;state<=ST_SCALAR_WAIT;end
                end
                ST_SCALAR_WAIT: begin
                    if(scalar_error) fail_transaction;
                    else if(scalar_done) begin x_reg<=px;z_point_reg<=pz;inv_a<=pz;inv_start<=1;state<=ST_ZINV_WAIT;end
                end
                ST_ZINV_WAIT: begin
                    if(inv_error) fail_transaction;
                    else if(inv_done) begin zinv_reg<=inv_result;mul_a<=inv_result;mul_b<=inv_result;mul_start<=1;state<=ST_Z2_WAIT;end
                end
                ST_Z2_WAIT: begin
                    if(mul_error) fail_transaction;
                    else if(mul_done) begin z2_reg<=mul_result;mul_a<=x_reg;mul_b<=mul_result;mul_start<=1;state<=ST_X_WAIT;end
                end
                ST_X_WAIT: begin
                    if(mul_error) fail_transaction;
                    else if(mul_done) begin
                        r_reg<=(mul_result>=N)?mul_result-N:mul_result;
                        if(((mul_result>=N)?mul_result-N:mul_result)==0) fail_transaction;
                        else begin inv_a<=k_reg;inv_start<=1;state<=ST_KINV_WAIT;end
                    end
                end
                ST_KINV_WAIT: begin
                    if(inv_error) fail_transaction;
                    else if(inv_done) begin kinv_reg<=inv_result;mul_a<=r_reg;mul_b<=d_reg;mul_start<=1;state<=ST_RD_WAIT;end
                end
                ST_RD_WAIT: begin
                    if(mul_error) fail_transaction;
                    else if(mul_done) begin rd_reg<=mul_result;add_a<=z_reg;add_b<=mul_result;add_start<=1;state<=ST_SUM_WAIT;end
                end
                ST_SUM_WAIT: begin
                    if(add_error) fail_transaction;
                    else if(add_done) begin sum_reg<=add_result;mul_a<=kinv_reg;mul_b<=add_result;mul_start<=1;state<=ST_S_WAIT;end
                end
                ST_S_WAIT: begin
                    if(mul_error) fail_transaction;
                    else if(mul_done) begin
                        if(mul_result==0) fail_transaction;
                        else begin r<=r_reg;s<=mul_result;d_reg<=0;k_reg<=0;done<=1;state<=ST_IDLE;end
                    end
                end
                default: begin error<=1;state<=ST_IDLE;d_reg<=0;k_reg<=0;end
            endcase
        end
    end
endmodule
`default_nettype wire
