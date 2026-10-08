`timescale 1ns/1ps
`default_nettype none
// One report per reset: TS1,P|F,failure_hex,provision_hex,sign_hex\r\n
module selftest_uart_report #(parameter integer CLOCKS_PER_BIT=434) (
    input wire clk,input wire rst_n,input wire finished,input wire passed,
    input wire [7:0] failure_code,input wire [31:0] provision_cycles,sign_cycles,
    output wire tx,output reg sent
);
    reg [1:0] state;
    reg [5:0] index;
    reg send_start;
    wire tx_busy;
    reg [7:0] send_byte;
    reg saved_pass;
    reg [7:0] saved_code;
    reg [31:0] saved_provision,saved_sign;
    function [7:0] hex_digit;
        input [3:0] nibble;
        begin hex_digit=(nibble<10)?8'd48+nibble:8'd65+(nibble-10);end
    endfunction
    always @* begin
        send_byte=8'h3f;
        case(index)
            0:send_byte="T"; 1:send_byte="S"; 2:send_byte="1";
            3,5,8,17:send_byte=",";
            4:send_byte=saved_pass?"P":"F";
            6:send_byte=hex_digit(saved_code[7:4]);
            7:send_byte=hex_digit(saved_code[3:0]);
            26:send_byte=8'h0d; 27:send_byte=8'h0a;
            default: begin
                if(index>=9 && index<=16) send_byte=hex_digit(saved_provision[31-(index-9)*4 -:4]);
                else if(index>=18 && index<=25) send_byte=hex_digit(saved_sign[31-(index-18)*4 -:4]);
            end
        endcase
    end
    uart_tx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) u_tx(.clk(clk),.rst_n(rst_n),
        .start(send_start),.data(send_byte),.tx(tx),.busy(tx_busy));
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=0;index<=0;send_start<=0;sent<=0;
            saved_pass<=0;saved_code<=0;saved_provision<=0;saved_sign<=0;
        end else begin
            send_start<=0;
            case(state)
                0: if(finished && !sent) begin
                    saved_pass<=passed;saved_code<=failure_code;
                    saved_provision<=provision_cycles;saved_sign<=sign_cycles;state<=1;
                end
                1: if(!tx_busy) begin send_start<=1;state<=2;end
                2: if(tx_busy) state<=3;
                3: if(!tx_busy) begin
                    if(index==27) begin sent<=1;state<=0;end
                    else begin index<=index+1'b1;state<=1;end
                end
            endcase
        end
    end
endmodule
`default_nettype wire
