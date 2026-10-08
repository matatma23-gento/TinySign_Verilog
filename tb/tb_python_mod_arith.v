`timescale 1ns/1ps
`default_nettype none
module tb_python_mod_arith;
    localparam integer W=256;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0;
    reg add_start=0,sub_start=0,inv_start=0;
    reg [W-1:0] a=0,b=0,modulus=0;
    wire [W-1:0] add_result,sub_result,inv_result;
    wire add_busy,sub_busy,inv_busy,add_done,sub_done,inv_done,add_error,sub_error,inv_error;
    integer fd,scan_result,vector_index,operation,modulus_id,expected_error,cycles,count;
    reg [W-1:0] vector_modulus,vector_a,vector_b,expected_result,actual_result;
    reg actual_error,actual_done;
    reg [4095:0] vector_path;

    mod_add #(.WIDTH(W)) u_add(.clk(clk),.rst_n(rst_n),.start(add_start),
        .a(a),.b(b),.modulus(modulus),.result(add_result),.busy(add_busy),
        .done(add_done),.error(add_error));
    mod_sub #(.WIDTH(W)) u_sub(.clk(clk),.rst_n(rst_n),.start(sub_start),
        .a(a),.b(b),.modulus(modulus),.result(sub_result),.busy(sub_busy),
        .done(sub_done),.error(sub_error));
    mod_inv #(.WIDTH(W)) u_inv(.clk(clk),.rst_n(rst_n),.start(inv_start),
        .a(a),.modulus(modulus),.result(inv_result),.busy(inv_busy),
        .done(inv_done),.error(inv_error));

    task run_vector;
        input integer idx;
        input integer op;
        input integer mid;
        input [W-1:0] m;
        input [W-1:0] av;
        input [W-1:0] bv;
        input [W-1:0] expected;
        input integer exp_error;
        begin
            @(negedge clk);
            a=av; b=bv; modulus=m;
            add_start=(op==0); sub_start=(op==1); inv_start=(op==2);
            @(negedge clk);
            add_start=0; sub_start=0; inv_start=0; cycles=0;
            if(op==0) begin
                while(add_done!==1'b1 && add_error!==1'b1 && cycles<20) begin
                    @(negedge clk); cycles=cycles+1;
                end
                #1; actual_result=add_result; actual_error=add_error; actual_done=add_done;
            end else if(op==1) begin
                while(sub_done!==1'b1 && sub_error!==1'b1 && cycles<20) begin
                    @(negedge clk); cycles=cycles+1;
                end
                #1; actual_result=sub_result; actual_error=sub_error; actual_done=sub_done;
            end else begin
                while(inv_done!==1'b1 && inv_error!==1'b1 && cycles<140000) begin
                    @(negedge clk); cycles=cycles+1;
                end
                #1; actual_result=inv_result; actual_error=inv_error; actual_done=inv_done;
            end
            $display("RESULT|%0d|%0d|%0d|%064h|%064h|%064h|%064h|%064h|%0d|%0d|%0d|%0d",
                idx,op,mid,m,av,bv,expected,actual_result,exp_error,actual_error,actual_done,cycles);
            if(exp_error!=actual_error || (exp_error==0 &&
                (actual_done!==1'b1 || actual_result!==expected)) ||
                (exp_error!=0 && actual_done!==1'b0)) begin
                $display("FAIL|%0d",idx); $stop;
            end
        end
    endtask

    initial begin
        count=0;
        if(!$value$plusargs("vectors=%s",vector_path)) begin
            $display("FAIL: missing +vectors path"); $stop;
        end
        fd=$fopen(vector_path,"r");
        if(fd==0) begin $display("FAIL: cannot open vector file"); $stop; end
        #20; rst_n=1;
        while(!$feof(fd)) begin
            scan_result=$fscanf(fd,"%d %d %d %h %h %h %h %d\n",
                vector_index,operation,modulus_id,vector_modulus,vector_a,
                vector_b,expected_result,expected_error);
            if(scan_result==8) begin
                run_vector(vector_index,operation,modulus_id,vector_modulus,
                    vector_a,vector_b,expected_result,expected_error);
                count=count+1;
            end
        end
        $fclose(fd);
        $display("SUMMARY|%0d",count);
        $finish;
    end
endmodule
`default_nettype wire
