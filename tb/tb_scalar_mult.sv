`timescale 1ns/1ps
`default_nettype none
module tb_scalar_mult;
    localparam integer W=256;
    localparam integer SLOT=7000;
    localparam [W-1:0] P=256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    localparam [W-1:0] N=256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
    localparam [W-1:0] GX=256'h6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    localparam [W-1:0] GY=256'h4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;
    localparam [W-1:0] TWO_X=256'h7CF27B188D034F7E8A52380304B51AC3C08969E277F21B35A60B48FC47669978;
    localparam [W-1:0] TWO_Y=256'h07775510DB8ED040293D9AC69F7430DBBA7DADE63CE982299E04B79D227873D1;
    localparam [W-1:0] KEY=256'hC9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721;
    localparam [W-1:0] KEY_QX=256'h60FED4BA255A9D31C961EB74C6356D68C049B8923B61FA6CE669622E60F29FB6;
    localparam [W-1:0] KEY_QY=256'h7903FE1008B8BC99A41AE9E95628BC64F2F1B20C2D7E9F5177A3C294D4462299;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,start=0;
    reg [W-1:0] scalar=0;
    wire [W-1:0] x_out,y_out,z_out;
    wire busy,done,error;
    integer cycles;
    scalar_mult #(.WIDTH(W),.OP_SLOT_CYCLES(SLOT)) dut(
        .clk(clk),.rst_n(rst_n),.start(start),.scalar(scalar),
        .x_in(GX),.y_in(GY),.z_in(256'd1),.x_out(x_out),.y_out(y_out),.z_out(z_out),
        .busy(busy),.done(done),.error(error));

    function automatic projective_matches(input [W-1:0] x,input [W-1:0] y,input [W-1:0] z,
                                           input [W-1:0] qx,input [W-1:0] qy);
        reg [511:0] product;
        reg [W-1:0] z2,z3,cx,cy;
        begin
            if (z==0) projective_matches=0;
            else begin
                product={256'd0,z}*{256'd0,z}; z2=product%P;
                product={256'd0,z2}*{256'd0,z}; z3=product%P;
                product={256'd0,qx}*{256'd0,z2}; cx=product%P;
                product={256'd0,qy}*{256'd0,z3}; cy=product%P;
                projective_matches=(x==cx && y==cy);
            end
        end
    endfunction
    task automatic check_scalar(input [W-1:0] k,input [W-1:0] qx,input [W-1:0] qy,input integer infinity_expected);
        begin
            @(negedge clk); scalar=k; start=1;
            @(negedge clk); start=0; cycles=0;
            while(done!==1'b1 && error!==1'b1 && cycles<(SLOT*512+10000)) begin
                @(negedge clk); cycles=cycles+1;
            end
            #1;
            if(error!==1'b0 || done!==1'b1) $fatal(1,"scalar_mult timeout/error k=%h cycles=%0d",k,cycles);
            if(infinity_expected) begin
                if(z_out!==0) $fatal(1,"expected point at infinity for k=%h, got z=%h",k,z_out);
            end else if(!projective_matches(x_out,y_out,z_out,qx,qy)) begin
                $fatal(1,"scalar_mult mismatch k=%h output=(%h,%h,%h)",k,x_out,y_out,z_out);
            end
            $display("PASS scalar k=%h cycles=%0d",k,cycles);
        end
    endtask
    initial begin
        #20; rst_n=1;
        check_scalar(1,GX,GY,0);
        check_scalar(2,TWO_X,TWO_Y,0);
        check_scalar(N,0,0,1);
        check_scalar(KEY,KEY_QX,KEY_QY,0);
        $display("PASS: fixed-round Montgomery ladder scalar multiplication");
        $finish;
    end
endmodule
`default_nettype wire
