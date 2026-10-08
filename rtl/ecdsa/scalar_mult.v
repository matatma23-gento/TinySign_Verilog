`timescale 1ns/1ps
`default_nettype none
module scalar_mult #(
    parameter integer WIDTH=256,
    parameter integer OP_SLOT_CYCLES=14000
) (
    input wire clk, input wire rst_n, input wire start,
    input wire [WIDTH-1:0] scalar,
    input wire [WIDTH-1:0] x_in, input wire [WIDTH-1:0] y_in, input wire [WIDTH-1:0] z_in,
    output reg [WIDTH-1:0] x_out, output reg [WIDTH-1:0] y_out, output reg [WIDTH-1:0] z_out,
    output wire busy, output reg done, output reg error
);
    localparam [WIDTH-1:0] P=256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    // Constant function keeps this module compatible with Verilog-2001.
    function integer clog2;
        input integer value;
        integer remaining;
        begin
            remaining=value-1;
            for(clog2=0; remaining>0; clog2=clog2+1)
                remaining=remaining>>1;
            if(clog2==0) clog2=1;
        end
    endfunction
    localparam integer TIMER_WIDTH=clog2(OP_SLOT_CYCLES+1);
    localparam [2:0] ST_IDLE=3'd0, ST_ISSUE=3'd1, ST_WAIT=3'd2, ST_PAD=3'd3, ST_COMPLETE=3'd4;
    reg [2:0] state;
    reg [WIDTH-1:0] scalar_reg;
    reg [8:0] bit_index;
    reg op_phase; // 0: R0+R1, 1: double selected by this scalar bit
    reg [TIMER_WIDTH-1:0] slot_cycles;
    reg [WIDTH-1:0] r0x,r0y,r0z,r1x,r1y,r1z;
    reg [WIDTH-1:0] sumx,sumy,sumz,tmpx,tmpy,tmpz;
    reg point_start, point_do_double;
    reg [WIDTH-1:0] point_x1,point_y1,point_z1,point_x2,point_y2,point_z2;
    wire [WIDTH-1:0] point_x3,point_y3,point_z3;
    wire point_busy,point_done,point_error;
    assign busy=(state!=ST_IDLE);

    point_ops #(.WIDTH(WIDTH)) u_point_ops(
        .clk(clk),.rst_n(rst_n),.start(point_start),.do_double(point_do_double),
        .x1(point_x1),.y1(point_y1),.z1(point_z1),
        .x2(point_x2),.y2(point_y2),.z2(point_z2),
        .x3(point_x3),.y3(point_y3),.z3(point_z3),
        .busy(point_busy),.done(point_done),.error(point_error)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=ST_IDLE; scalar_reg<=0; bit_index<=0; op_phase<=0; slot_cycles<=0;
            r0x<=0; r0y<=1; r0z<=0; r1x<=0; r1y<=1; r1z<=0;
            sumx<=0; sumy<=1; sumz<=0; tmpx<=0; tmpy<=1; tmpz<=0;
            point_start<=0; point_do_double<=0;
            point_x1<=0; point_y1<=1; point_z1<=0;
            point_x2<=0; point_y2<=1; point_z2<=0;
            x_out<=0; y_out<=1; z_out<=0; done<=0; error<=0;
        end else begin
            point_start<=0; done<=0; error<=0;
            case (state)
                ST_IDLE: if (start) begin
                    if (x_in>=P || y_in>=P || z_in>=P) begin
                        error<=1;
                    end else begin
                        scalar_reg<=scalar; bit_index<=WIDTH-1; op_phase<=0;
                        r0x<=0; r0y<=1; r0z<=0;
                        r1x<=x_in; r1y<=y_in; r1z<=z_in;
                        state<=ST_ISSUE;
                    end
                end
                ST_ISSUE: begin
                    point_start<=1; slot_cycles<=0;
                    if (op_phase==0) begin
                        point_do_double<=0;
                        point_x1<=r0x; point_y1<=r0y; point_z1<=r0z;
                        point_x2<=r1x; point_y2<=r1y; point_z2<=r1z;
                    end else begin
                        point_do_double<=1;
                        if (scalar_reg[bit_index]==1'b0) begin
                            point_x1<=r0x; point_y1<=r0y; point_z1<=r0z;
                        end else begin
                            point_x1<=r1x; point_y1<=r1y; point_z1<=r1z;
                        end
                        point_x2<=0; point_y2<=1; point_z2<=0;
                    end
                    state<=ST_WAIT;
                end
                ST_WAIT: begin
                    if (point_error) begin
                        error<=1; state<=ST_IDLE;
                    end else if (point_done) begin
                        tmpx<=point_x3; tmpy<=point_y3; tmpz<=point_z3;
                        if (slot_cycles>=OP_SLOT_CYCLES-1) state<=ST_COMPLETE;
                        else begin slot_cycles<=slot_cycles+1'b1; state<=ST_PAD; end
                    end else if (slot_cycles>=OP_SLOT_CYCLES-1) begin
                        error<=1; state<=ST_IDLE;
                    end else slot_cycles<=slot_cycles+1'b1;
                end
                ST_PAD: begin
                    if (slot_cycles>=OP_SLOT_CYCLES-1) state<=ST_COMPLETE;
                    else slot_cycles<=slot_cycles+1'b1;
                end
                ST_COMPLETE: begin
                    if (op_phase==0) begin
                        sumx<=tmpx; sumy<=tmpy; sumz<=tmpz;
                        op_phase<=1; state<=ST_ISSUE;
                    end else begin
                        if (scalar_reg[bit_index]==1'b0) begin
                            r0x<=tmpx; r0y<=tmpy; r0z<=tmpz;
                            r1x<=sumx; r1y<=sumy; r1z<=sumz;
                        end else begin
                            r0x<=sumx; r0y<=sumy; r0z<=sumz;
                            r1x<=tmpx; r1y<=tmpy; r1z<=tmpz;
                        end
                        if (bit_index==0) begin
                            if (scalar_reg[bit_index]==1'b0) begin
                                x_out<=tmpx; y_out<=tmpy; z_out<=tmpz;
                            end else begin
                                x_out<=sumx; y_out<=sumy; z_out<=sumz;
                            end
                            done<=1; state<=ST_IDLE;
                        end else begin
                            bit_index<=bit_index-1'b1; op_phase<=0; state<=ST_ISSUE;
                        end
                    end
                end
                default: state<=ST_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
