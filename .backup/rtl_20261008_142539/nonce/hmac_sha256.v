`timescale 1ns/1ps
`default_nettype none
module hmac_sha256 (
    input wire clk,input wire rst_n,input wire start,
    input wire [255:0] key,input wire [1023:0] message,input wire [7:0] message_length,
    output reg [255:0] digest,output wire busy,output reg done,output reg error
);
    localparam ST_IDLE=3'd0,ST_INNER_LAUNCH=3'd1,ST_INNER_WAIT=3'd2,ST_OUTER_LAUNCH=3'd3,ST_OUTER_WAIT=3'd4;
    reg [2:0] state;
    reg [255:0] key_reg,inner_digest;
    reg [1023:0] message_reg;
    reg [7:0] length_reg;
    reg [1535:0] hash_message;
    reg [7:0] hash_length;
    reg hash_start;
    wire [255:0] hash_digest;
    wire hash_busy,hash_done,hash_error;
    integer i;
    reg [7:0] key_byte;
    assign busy=(state!=ST_IDLE);
    sha256_hash u_hash(.clk(clk),.rst_n(rst_n),.start(hash_start),.message(hash_message),.message_length(hash_length),.digest(hash_digest),.busy(hash_busy),.done(hash_done),.error(hash_error));

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=ST_IDLE;key_reg<=0;inner_digest<=0;message_reg<=0;length_reg<=0;
            hash_message<=0;hash_length<=0;hash_start<=0;digest<=0;done<=0;error<=0;
        end else begin
            hash_start<=0;done<=0;error<=0;
            case(state)
                ST_IDLE: if(start) begin
                    if(message_length>128) error<=1;
                    else begin
                        key_reg<=key;message_reg<=message;length_reg<=message_length;
                        hash_message<=0;
                        for(i=0;i<64;i=i+1) begin
                            if(i<32) key_byte=key[255-i*8 -:8]; else key_byte=0;
                            hash_message[1535-i*8 -:8]<=key_byte^8'h36;
                        end
                        for(i=0;i<128;i=i+1) if(i<message_length)
                            hash_message[1535-(64+i)*8 -:8]<=message[1023-i*8 -:8];
                        hash_length<=64+message_length;state<=ST_INNER_LAUNCH;
                    end
                end
                ST_INNER_LAUNCH: begin hash_start<=1;state<=ST_INNER_WAIT;end
                ST_INNER_WAIT: begin
                    if(hash_error) begin error<=1;state<=ST_IDLE;end
                    else if(hash_done) begin
                        inner_digest<=hash_digest;hash_message<=0;
                        for(i=0;i<64;i=i+1) begin
                            if(i<32) key_byte=key_reg[255-i*8 -:8]; else key_byte=0;
                            hash_message[1535-i*8 -:8]<=key_byte^8'h5c;
                        end
                        hash_message[1535-64*8 -:256]<=hash_digest;
                        hash_length<=96;state<=ST_OUTER_LAUNCH;
                    end
                end
                ST_OUTER_LAUNCH: begin hash_start<=1;state<=ST_OUTER_WAIT;end
                ST_OUTER_WAIT: begin
                    if(hash_error) begin error<=1;state<=ST_IDLE;end
                    else if(hash_done) begin digest<=hash_digest;done<=1;state<=ST_IDLE;end
                end
                default: state<=ST_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
