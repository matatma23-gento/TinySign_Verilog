`timescale 1ns/1ps
`default_nettype none
module key_manager #(
    parameter integer WIDTH=256,
    parameter integer OP_SLOT_CYCLES=14000,
    // Standalone defaults retain local engines; tinysign_core shares them.
    parameter integer SHARED_ENGINES=0
) (
    input wire clk,input wire rst_n,input wire zeroize,
    input wire key_word_write,input wire [2:0] key_word_index,input wire [31:0] key_word_data,
    input wire provision_start,input wire lock_start,
    output wire [WIDTH-1:0] signing_key,
    output reg [WIDTH-1:0] public_x,output reg [WIDTH-1:0] public_y,
    output reg key_valid,output reg key_locked,output wire busy,
    output reg done,output reg error,
    output wire engine_scalar_start,output wire [WIDTH-1:0] engine_scalar,
    input wire [WIDTH-1:0] engine_px,engine_py,engine_pz,
    input wire engine_scalar_done,engine_scalar_error,
    output wire engine_inv_start,output wire [WIDTH-1:0] engine_inv_a,engine_inv_modulus,
    input wire [WIDTH-1:0] engine_inv_result,input wire engine_inv_done,engine_inv_error,
    output wire engine_mul_start,output wire [WIDTH-1:0] engine_mul_a,engine_mul_b,engine_mul_modulus,
    input wire [WIDTH-1:0] engine_mul_result,input wire engine_mul_done,engine_mul_error
);
    localparam [WIDTH-1:0] P=256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    localparam [WIDTH-1:0] N=256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
    localparam [WIDTH-1:0] GX=256'h6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    localparam [WIDTH-1:0] GY=256'h4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;
    localparam [2:0] ST_IDLE=0,ST_SCALAR_WAIT=1,ST_ZINV_WAIT=2,ST_Z2_WAIT=3,
        ST_Z3_WAIT=4,ST_PUBX_WAIT=5,ST_PUBY_WAIT=6;
    reg [2:0] state;
    reg [WIDTH-1:0] staging_key,key_reg,point_x_reg,point_y_reg,point_z_reg,zinv_reg,z2_reg,z3_reg;
    reg [7:0] written_words;
    reg scalar_start,inv_start,mul_start;
    reg [WIDTH-1:0] inv_a,mul_a,mul_b;
    wire [WIDTH-1:0] px,py,pz,inv_result,mul_result;
    wire scalar_busy,scalar_done,scalar_error,inv_busy,inv_done,inv_error,mul_busy,mul_done,mul_error;
    wire core_rst_n=rst_n&&!zeroize;
    assign signing_key=key_reg;
    assign busy=(state!=ST_IDLE);

    assign engine_scalar_start=scalar_start;
    assign engine_scalar=staging_key;
    assign engine_inv_start=inv_start;
    assign engine_inv_a=inv_a;
    assign engine_inv_modulus=P;
    assign engine_mul_start=mul_start;
    assign engine_mul_a=mul_a;
    assign engine_mul_b=mul_b;
    assign engine_mul_modulus=P;

    generate if (SHARED_ENGINES) begin : g_shared
        assign px=engine_px; assign py=engine_py; assign pz=engine_pz;
        assign scalar_done=engine_scalar_done; assign scalar_error=engine_scalar_error;
        assign inv_result=engine_inv_result;
        assign inv_done=engine_inv_done; assign inv_error=engine_inv_error;
        assign mul_result=engine_mul_result;
        assign mul_done=engine_mul_done; assign mul_error=engine_mul_error;
        // Busy is represented by the controller's wait states.
        assign scalar_busy=1'b0; assign inv_busy=1'b0; assign mul_busy=1'b0;
    end else begin : g_local
    scalar_mult #(.WIDTH(WIDTH),.OP_SLOT_CYCLES(OP_SLOT_CYCLES)) u_scalar(
        .clk(clk),.rst_n(core_rst_n),.start(scalar_start),.scalar(staging_key),.x_in(GX),.y_in(GY),.z_in({{(WIDTH-1){1'b0}},1'b1}),
        .x_out(px),.y_out(py),.z_out(pz),.busy(scalar_busy),.done(scalar_done),.error(scalar_error));
    mod_inv #(.WIDTH(WIDTH)) u_inverse(.clk(clk),.rst_n(core_rst_n),.start(inv_start),.a(inv_a),.modulus(P),.result(inv_result),.busy(inv_busy),.done(inv_done),.error(inv_error));
    mod_mul #(.WIDTH(WIDTH)) u_multiply(.clk(clk),.rst_n(core_rst_n),.start(mul_start),.a(mul_a),.b(mul_b),.modulus(P),.result(mul_result),.busy(mul_busy),.done(mul_done),.error(mul_error));
    end endgenerate

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=ST_IDLE;staging_key<=0;key_reg<=0;written_words<=0;
            point_x_reg<=0;point_y_reg<=0;point_z_reg<=0;zinv_reg<=0;z2_reg<=0;z3_reg<=0;
            scalar_start<=0;inv_start<=0;mul_start<=0;inv_a<=0;mul_a<=0;mul_b<=0;
            public_x<=0;public_y<=0;key_valid<=0;key_locked<=0;done<=0;error<=0;
        end else begin
            scalar_start<=0;inv_start<=0;mul_start<=0;done<=0;error<=0;
            if(zeroize) begin
                state<=ST_IDLE;staging_key<=0;key_reg<=0;written_words<=0;
                point_x_reg<=0;point_y_reg<=0;point_z_reg<=0;zinv_reg<=0;z2_reg<=0;z3_reg<=0;
                inv_a<=0;mul_a<=0;mul_b<=0;public_x<=0;public_y<=0;
                key_valid<=0;key_locked<=0;done<=1;
            end else case(state)
                ST_IDLE: begin
                    if(key_word_write) begin
                        if(key_locked||key_valid) error<=1;
                        else begin
                            staging_key[WIDTH-1-key_word_index*32 -:32]<=key_word_data;
                            written_words[key_word_index]<=1'b1;
                        end
                    end else if(provision_start) begin
                        if(key_valid||written_words!=8'hFF||staging_key==0||staging_key>=N) error<=1;
                        else begin scalar_start<=1;state<=ST_SCALAR_WAIT;end
                    end else if(lock_start) begin
                        if(!key_valid) error<=1;
                        else begin key_locked<=1;done<=1;end
                    end
                end
                ST_SCALAR_WAIT: begin
                    if(scalar_error) begin error<=1;state<=ST_IDLE;end
                    else if(scalar_done) begin
                        point_x_reg<=px;point_y_reg<=py;point_z_reg<=pz;inv_a<=pz;inv_start<=1;state<=ST_ZINV_WAIT;
                    end
                end
                ST_ZINV_WAIT: begin
                    if(inv_error) begin error<=1;state<=ST_IDLE;end
                    else if(inv_done) begin zinv_reg<=inv_result;mul_a<=inv_result;mul_b<=inv_result;mul_start<=1;state<=ST_Z2_WAIT;end
                end
                ST_Z2_WAIT: begin
                    if(mul_error) begin error<=1;state<=ST_IDLE;end
                    else if(mul_done) begin z2_reg<=mul_result;mul_a<=mul_result;mul_b<=zinv_reg;mul_start<=1;state<=ST_Z3_WAIT;end
                end
                ST_Z3_WAIT: begin
                    if(mul_error) begin error<=1;state<=ST_IDLE;end
                    else if(mul_done) begin z3_reg<=mul_result;mul_a<=point_x_reg;mul_b<=z2_reg;mul_start<=1;state<=ST_PUBX_WAIT;end
                end
                ST_PUBX_WAIT: begin
                    if(mul_error) begin error<=1;state<=ST_IDLE;end
                    else if(mul_done) begin public_x<=mul_result;mul_a<=point_y_reg;mul_b<=z3_reg;mul_start<=1;state<=ST_PUBY_WAIT;end
                end
                ST_PUBY_WAIT: begin
                    if(mul_error) begin error<=1;state<=ST_IDLE;end
                    else if(mul_done) begin
                        public_y<=mul_result;key_reg<=staging_key;key_valid<=1;staging_key<=0;written_words<=0;
                        point_x_reg<=0;point_y_reg<=0;point_z_reg<=0;zinv_reg<=0;z2_reg<=0;z3_reg<=0;
                        done<=1;state<=ST_IDLE;
                    end
                end
                default: begin state<=ST_IDLE;error<=1;end
            endcase
        end
    end
endmodule
`default_nettype wire
