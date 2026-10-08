`timescale 1ns/1ps
`default_nettype none
module tb_point_ops;
    localparam [255:0] P=256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    localparam [255:0] GX=256'h6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    localparam [255:0] GY=256'h4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;
    localparam [255:0] TWO_X=256'h7CF27B188D034F7E8A52380304B51AC3C08969E277F21B35A60B48FC47669978;
    localparam [255:0] TWO_Y=256'h07775510DB8ED040293D9AC69F7430DBBA7DADE63CE982299E04B79D227873D1;
    localparam [255:0] D2X=256'h9A978F59ACD1B5AD570E7D52DCFCDE43804B42274F61DDCF1E7D848391D6C70F;
    localparam [255:0] D2Y=256'h4126885E7F786AF905338238E5346D5FE77FC46388668BD0FD59BE3190D2F5D1;
    localparam [255:0] D2Z=256'h9FC685C5FC34FF371DCFD694F81F3C2C579C66AED662BD9D976C80D06F7EA3EA;
    localparam [255:0] A3X=256'hB07647DEEF13EEB2C1639A8651FF2D3F7A08C5255B183A80B349E30974677826;
    localparam [255:0] A3Y=256'hC88A4E6DF014119A1CA89A76D508DCF0F69EEFDC954E8ADF81CB836843238E4C;
    localparam [255:0] A3Z=256'h11DAA925ABD70D369195511DA110D9D14985EC614A06E794B16A0FB66ECDD6E2;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, ds=0, as=0;
    reg [255:0] ax=GX, ay=GY, az=1, bx=TWO_X, by=TWO_Y, bz=1;
    wire [255:0] dx,dy,dz, ox,oy,oz;
    wire dbusy,ddone,derr, abusy,adone,aerr;
    point_double u_d(.clk(clk),.rst_n(rst_n),.start(ds),.x1(GX),.y1(GY),.z1(256'd1),.x3(dx),.y3(dy),.z3(dz),.busy(dbusy),.done(ddone),.error(derr));
    point_add u_a(.clk(clk),.rst_n(rst_n),.start(as),.x1(ax),.y1(ay),.z1(az),.x2(bx),.y2(by),.z2(bz),.x3(ox),.y3(oy),.z3(oz),.busy(abusy),.done(adone),.error(aerr));

    task automatic start_double;
        integer cycles;
        begin
            @(negedge clk); ds=1; @(negedge clk); ds=0; cycles=0;
            while(ddone!==1'b1 && cycles<15000) begin @(negedge clk); cycles=cycles+1; end
            #1; if(ddone!==1'b1 || derr || dx!==D2X || dy!==D2Y || dz!==D2Z)
                begin $display("FAIL: point_double G mismatch/timeout cycles=%0d x=%h y=%h z=%h",cycles,dx,dy,dz); $stop; end
            if(cycles>=14000) begin $display("FAIL: double exceeds scalar operation slot"); $stop; end
        end
    endtask
    task automatic start_add(input [255:0] x1v,input [255:0] y1v,input [255:0] z1v,
                             input [255:0] x2v,input [255:0] y2v,input [255:0] z2v,
                             input [255:0] ex,input [255:0] ey,input [255:0] ez);
        integer cycles;
        begin
            @(negedge clk); ax=x1v;ay=y1v;az=z1v;bx=x2v;by=y2v;bz=z2v;as=1;
            @(negedge clk); as=0; cycles=0;
            while(adone!==1'b1 && cycles<18000) begin @(negedge clk); cycles=cycles+1; end
            #1; if(adone!==1'b1 || aerr || ox!==ex || oy!==ey || oz!==ez)
                begin $display("FAIL: point_add mismatch/timeout cycles=%0d expected=(%h,%h,%h) actual=(%h,%h,%h)",cycles,ex,ey,ez,ox,oy,oz); $stop; end
            if(cycles>=14000) begin $display("FAIL: add exceeds scalar operation slot"); $stop; end
        end
    endtask
    initial begin
        #20; rst_n=1;
        start_double;
        start_add(GX,GY,1,GX,GY,1,D2X,D2Y,D2Z); // equal points dispatch to doubling
        start_add(GX,GY,1,TWO_X,TWO_Y,1,A3X,A3Y,A3Z);
        start_add(GX,GY,1,GX,P-GY,1,0,1,0); // inverse points give infinity
        $display("PASS: P-256 Jacobian point double/add, equality and inverse-point cases");
        $finish;
    end
endmodule
`default_nettype wire
