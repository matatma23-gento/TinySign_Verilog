`timescale 1ns/1ps
`default_nettype none
// Platform Designer-facing Avalon-MM slave shell for DE10-Nano integration.
// Address is a byte offset in the TinySign register map.
module tinysign_de10nano #(
    parameter integer OP_SLOT_CYCLES=7000
) (
    input wire clk,input wire reset_n,
    input wire [7:0] avs_address,input wire avs_read,input wire avs_write,
    input wire [31:0] avs_writedata,input wire [3:0] avs_byteenable,
    output wire [31:0] avs_readdata,output wire avs_waitrequest
);
    wire [31:0] core_read_data;
    wire core_busy;
    assign avs_waitrequest=1'b0;
    assign avs_readdata=core_read_data;
    tinysign_core #(.OP_SLOT_CYCLES(OP_SLOT_CYCLES)) u_core(
        .clk(clk),.rst_n(reset_n),.bus_write(avs_write),.bus_address(avs_address),
        .bus_write_data(avs_writedata),.bus_byte_enable(avs_byteenable),.bus_read_data(core_read_data),.busy(core_busy));
    // Reads are combinational and never stall. Writes while BUSY are rejected
    // by the core, except ZEROIZE, which is allowed to abort an active command.
    wire unused_read=avs_read;
    wire unused_busy=core_busy;
endmodule
`default_nettype wire
