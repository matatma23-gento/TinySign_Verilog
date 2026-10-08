`timescale 1ns/1ps
`default_nettype none
module sha256_hash #(parameter integer MAX_BYTES=192) (
    input wire clk,input wire rst_n,input wire start,
    input wire [MAX_BYTES*8-1:0] message,input wire [7:0] message_length,
    output reg [255:0] digest,output wire busy,output reg done,output reg error
);
    localparam ST_IDLE=2'd0,ST_LAUNCH=2'd1,ST_WAIT=2'd2;
    reg [1:0] state;
    reg [MAX_BYTES*8-1:0] message_reg;
    reg [7:0] length_reg;
    reg [2:0] block_index,block_count;
    reg [255:0] hash_state;
    reg compress_start;
    wire [511:0] block_value;
    wire [255:0] compress_result;
    wire compress_busy,compress_done;
    integer i,position;
    reg [511:0] built_block;
    localparam [255:0] IV={32'h6a09e667,32'hbb67ae85,32'h3c6ef372,32'ha54ff53a,32'h510e527f,32'h9b05688c,32'h1f83d9ab,32'h5be0cd19};
    assign busy=(state!=ST_IDLE);
    assign block_value=built_block;
    sha256_compress u_compress(.clk(clk),.rst_n(rst_n),.start(compress_start),.block(block_value),.hash_in(hash_state),.hash_out(compress_result),.busy(compress_busy),.done(compress_done));

    always @* begin
        built_block=0;
        for(i=0;i<64;i=i+1) begin
            position=block_index*64+i;
            if(position<length_reg) built_block[511-i*8 -:8]=message_reg[MAX_BYTES*8-1-position*8 -:8];
            else if(position==length_reg) built_block[511-i*8 -:8]=8'h80;
        end
        if(block_index==block_count-1) built_block[63:0]=length_reg*8;
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=ST_IDLE;message_reg<=0;length_reg<=0;block_index<=0;block_count<=0;
            hash_state<=0;digest<=0;compress_start<=0;done<=0;error<=0;
        end else begin
            compress_start<=0;done<=0;error<=0;
            case(state)
                ST_IDLE: if(start) begin
                    if(message_length>MAX_BYTES) error<=1;
                    else begin
                        message_reg<=message;length_reg<=message_length;
                        block_index<=0;block_count<=(message_length+72)>>6;hash_state<=IV;state<=ST_LAUNCH;
                    end
                end
                ST_LAUNCH: begin compress_start<=1;state<=ST_WAIT;end
                ST_WAIT: if(compress_done) begin
                    hash_state<=compress_result;
                    if(block_index+1==block_count) begin digest<=compress_result;done<=1;state<=ST_IDLE;end
                    else begin block_index<=block_index+1'b1;state<=ST_LAUNCH;end
                end
                default: state<=ST_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
