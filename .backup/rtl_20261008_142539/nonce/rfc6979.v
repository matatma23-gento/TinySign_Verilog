`timescale 1ns/1ps
`default_nettype none
module rfc6979 #(parameter integer WIDTH=256) (
    input wire clk,input wire rst_n,input wire start,
    input wire [WIDTH-1:0] private_key,input wire [WIDTH-1:0] digest,
    output reg [WIDTH-1:0] nonce,output wire busy,output reg done,output reg error
);
    localparam [WIDTH-1:0] N=256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
    localparam [4:0] ST_IDLE=0,ST_K1_START=1,ST_K1_WAIT=2,ST_V1_START=3,ST_V1_WAIT=4,
                     ST_K2_START=5,ST_K2_WAIT=6,ST_V2_START=7,ST_V2_WAIT=8,
                     ST_CAND_START=9,ST_CAND_WAIT=10,ST_REJ_K_START=11,ST_REJ_K_WAIT=12,
                     ST_REJ_V_START=13,ST_REJ_V_WAIT=14;
    reg [4:0] state;
    reg [WIDTH-1:0] d_reg,z_octets,k_reg,v_reg;
    reg [255:0] hmac_key;
    wire [255:0] hmac_digest;
    reg [1023:0] hmac_message;
    reg [7:0] hmac_length;
    reg hmac_start;
    wire hmac_busy,hmac_done,hmac_error;
    assign busy=(state!=ST_IDLE);
    hmac_sha256 u_hmac(.clk(clk),.rst_n(rst_n),.start(hmac_start),.key(hmac_key),.message(hmac_message),.message_length(hmac_length),.digest(hmac_digest),.busy(hmac_busy),.done(hmac_done),.error(hmac_error));

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=ST_IDLE;d_reg<=0;z_octets<=0;k_reg<=0;v_reg<={WIDTH/8{8'h01}};
            hmac_key<=0;hmac_message<=0;hmac_length<=0;hmac_start<=0;nonce<=0;done<=0;error<=0;
        end else begin
            hmac_start<=0;done<=0;error<=0;
            case(state)
                ST_IDLE: if(start) begin
                    if(private_key==0 || private_key>=N) error<=1;
                    else begin
                        d_reg<=private_key;z_octets<=(digest>=N)?(digest-N):digest;
                        k_reg<=0;v_reg<={WIDTH/8{8'h01}};state<=ST_K1_START;
                    end
                end
                ST_K1_START: begin
                    hmac_key<=k_reg;hmac_message<={v_reg,8'h00,d_reg,z_octets,248'b0};hmac_length<=97;hmac_start<=1;state<=ST_K1_WAIT;
                end
                ST_K1_WAIT: if(hmac_error) begin error<=1;state<=ST_IDLE;end else if(hmac_done) begin k_reg<=hmac_digest;state<=ST_V1_START;end
                ST_V1_START: begin
                    hmac_key<=k_reg;hmac_message<={v_reg,768'b0};hmac_length<=32;hmac_start<=1;state<=ST_V1_WAIT;
                end
                ST_V1_WAIT: if(hmac_error) begin error<=1;state<=ST_IDLE;end else if(hmac_done) begin v_reg<=hmac_digest;state<=ST_K2_START;end
                ST_K2_START: begin
                    hmac_key<=k_reg;hmac_message<={v_reg,8'h01,d_reg,z_octets,248'b0};hmac_length<=97;hmac_start<=1;state<=ST_K2_WAIT;
                end
                ST_K2_WAIT: if(hmac_error) begin error<=1;state<=ST_IDLE;end else if(hmac_done) begin k_reg<=hmac_digest;state<=ST_V2_START;end
                ST_V2_START: begin
                    hmac_key<=k_reg;hmac_message<={v_reg,768'b0};hmac_length<=32;hmac_start<=1;state<=ST_V2_WAIT;
                end
                ST_V2_WAIT: if(hmac_error) begin error<=1;state<=ST_IDLE;end else if(hmac_done) begin v_reg<=hmac_digest;state<=ST_CAND_START;end
                ST_CAND_START: begin
                    hmac_key<=k_reg;hmac_message<={v_reg,768'b0};hmac_length<=32;hmac_start<=1;state<=ST_CAND_WAIT;
                end
                ST_CAND_WAIT: if(hmac_error) begin error<=1;state<=ST_IDLE;end else if(hmac_done) begin
                    if(hmac_digest!=0 && hmac_digest<N) begin nonce<=hmac_digest;done<=1;state<=ST_IDLE;end
                    else state<=ST_REJ_K_START;
                end
                ST_REJ_K_START: begin
                    hmac_key<=k_reg;hmac_message<={v_reg,8'h00,760'b0};hmac_length<=33;hmac_start<=1;state<=ST_REJ_K_WAIT;
                end
                ST_REJ_K_WAIT: if(hmac_error) begin error<=1;state<=ST_IDLE;end else if(hmac_done) begin k_reg<=hmac_digest;state<=ST_REJ_V_START;end
                ST_REJ_V_START: begin
                    hmac_key<=k_reg;hmac_message<={v_reg,768'b0};hmac_length<=32;hmac_start<=1;state<=ST_REJ_V_WAIT;
                end
                ST_REJ_V_WAIT: if(hmac_error) begin error<=1;state<=ST_IDLE;end else if(hmac_done) begin v_reg<=hmac_digest;state<=ST_CAND_START;end
                default: begin state<=ST_IDLE;error<=1;end
            endcase
        end
    end
endmodule
`default_nettype wire
