`timescale 1ns/1ps
`default_nettype none
module tb_mod_arith;
    localparam integer W = 256;
    localparam [W-1:0] P256 = 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    localparam [W-1:0] N256 = 256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
    localparam [W-1:0] INV2P = (P256 + 1'b1) >> 1;
    localparam [W-1:0] INV2N = (N256 + 1'b1) >> 1;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg add_start = 0, sub_start = 0, mul_start = 0, inv_start = 0;
    reg [W-1:0] a = 0, b = 0, modulus = 0;
    reg [31:0] rand_seed, rand_a, rand_b;
    reg [63:0] random_product;
    integer j;
    wire [W-1:0] add_result, sub_result, mul_result, inv_result;
    wire add_busy, sub_busy, mul_busy, inv_busy;
    wire add_done, sub_done, mul_done, inv_done;
    wire add_error, sub_error, mul_error, inv_error;

    mod_add #(.WIDTH(W)) u_add(.clk(clk),.rst_n(rst_n),.start(add_start),.a(a),.b(b),.modulus(modulus),.result(add_result),.busy(add_busy),.done(add_done),.error(add_error));
    mod_sub #(.WIDTH(W)) u_sub(.clk(clk),.rst_n(rst_n),.start(sub_start),.a(a),.b(b),.modulus(modulus),.result(sub_result),.busy(sub_busy),.done(sub_done),.error(sub_error));
    mod_mul #(.WIDTH(W)) u_mul(.clk(clk),.rst_n(rst_n),.start(mul_start),.a(a),.b(b),.modulus(modulus),.result(mul_result),.busy(mul_busy),.done(mul_done),.error(mul_error));
    mod_inv #(.WIDTH(W)) u_inv(.clk(clk),.rst_n(rst_n),.start(inv_start),.a(a),.modulus(modulus),.result(inv_result),.busy(inv_busy),.done(inv_done),.error(inv_error));

    task automatic check_add(input [W-1:0] av, input [W-1:0] bv, input [W-1:0] m, input [W-1:0] expected);
        integer cycles;
        begin
            @(negedge clk); a=av; b=bv; modulus=m; add_start=1;
            @(negedge clk); add_start=0; cycles=0;
            while (add_done !== 1'b1 && cycles < 10) begin @(negedge clk); cycles=cycles+1; end
            #1; if (add_done !== 1'b1 || add_result !== expected) $fatal(1,"mod_add mismatch: a=%h b=%h m=%h expected=%h actual=%h",av,bv,m,expected,add_result);
        end
    endtask
    task automatic check_sub(input [W-1:0] av, input [W-1:0] bv, input [W-1:0] m, input [W-1:0] expected);
        integer cycles;
        begin
            @(negedge clk); a=av; b=bv; modulus=m; sub_start=1;
            @(negedge clk); sub_start=0; cycles=0;
            while (sub_done !== 1'b1 && cycles < 10) begin @(negedge clk); cycles=cycles+1; end
            #1; if (sub_done !== 1'b1 || sub_result !== expected) $fatal(1,"mod_sub mismatch: a=%h b=%h m=%h expected=%h actual=%h",av,bv,m,expected,sub_result);
        end
    endtask
    task automatic check_mul(input [W-1:0] av, input [W-1:0] bv, input [W-1:0] m, input [W-1:0] expected);
        integer cycles;
        begin
            @(negedge clk); a=av; b=bv; modulus=m; mul_start=1;
            @(negedge clk); mul_start=0; cycles=0;
            while (mul_done !== 1'b1 && cycles < W+8) begin @(negedge clk); cycles=cycles+1; end
            #1; if (mul_done !== 1'b1 || mul_result !== expected) $fatal(1,"mod_mul mismatch: a=%h b=%h m=%h expected=%h actual=%h",av,bv,m,expected,mul_result);
        end
    endtask
    task automatic check_inv(input [W-1:0] av, input [W-1:0] m, input [W-1:0] expected);
        integer cycles;
        begin
            @(negedge clk); a=av; modulus=m; inv_start=1;
            @(negedge clk); inv_start=0; cycles=0;
            while (inv_done !== 1'b1 && cycles < 70000) begin @(negedge clk); cycles=cycles+1; end
            #1; if (inv_done !== 1'b1 || inv_result !== expected) $fatal(1,"mod_inv mismatch/timeout: a=%h m=%h expected=%h actual=%h cycles=%0d",av,m,expected,inv_result,cycles);
        end
    endtask
    task automatic check_inv_zero_error(input [W-1:0] m);
        begin
            @(negedge clk); a=0; modulus=m; inv_start=1;
            @(negedge clk); inv_start=0;
            #1; if (inv_error !== 1'b1) $fatal(1,"mod_inv accepted zero input");
        end
    endtask

    initial begin
        #20; rst_n=1;
        check_add(0,0,P256,0);
        check_add(1,0,P256,1);
        check_add(P256-1'b1,P256-1'b1,P256,P256-2);
        check_add(N256-1'b1,1,N256,0);
        check_sub(0,0,P256,0);
        check_sub(1,1,P256,0);
        check_sub(0,P256-1'b1,P256,1);
        check_sub(N256-1'b1,0,N256,N256-1'b1);
        check_mul(0,P256-1'b1,P256,0);
        check_mul(1,1,P256,1);
        check_mul(P256-1'b1,P256-1'b1,P256,1);
        check_mul(P256-1'b1,P256-2,P256,2);
        check_mul(N256-1'b1,N256-1'b1,N256,1);
        check_mul(0,N256-1'b1,N256,0);
        check_inv(2,P256,INV2P);
        check_inv(2,N256,INV2N);
        check_inv_zero_error(P256);
        rand_seed = 32'hC0DECAFE;
        for (j=0; j<8; j=j+1) begin
            rand_seed = rand_seed * 32'd1664525 + 32'd1013904223;
            rand_a = rand_seed % 32'd65521;
            rand_seed = rand_seed * 32'd1664525 + 32'd1013904223;
            rand_b = rand_seed % 32'd65521;
            check_add(rand_a,rand_b,65521,(rand_a+rand_b)%65521);
            check_sub(rand_a,rand_b,65521,(rand_a>=rand_b) ? (rand_a-rand_b) : (65521-(rand_b-rand_a)));
            random_product = {32'd0,rand_a} * {32'd0,rand_b};
            check_mul(rand_a,rand_b,65521,random_product%65521);
        end
        $display("PASS: modular add/sub/mul/inv boundaries for P-256 p and n");
        $finish;
    end
endmodule
`default_nettype wire
