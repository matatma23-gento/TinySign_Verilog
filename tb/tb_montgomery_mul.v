`timescale 1ns/1ps
`default_nettype none
module tb_montgomery_mul;
    parameter integer WIDTH=256;
    parameter integer VECTOR_COUNT=1;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, start=0;
    reg [WIDTH-1:0] a=0, b=0, modulus=0;
    wire [WIDTH-1:0] raw_result, ordinary_result;
    wire raw_busy, raw_done, raw_error, ordinary_busy, ordinary_done, ordinary_error;
    reg [5*WIDTH-1:0] vectors [0:VECTOR_COUNT-1];
    reg [4095:0] vector_path;
    reg [WIDTH-1:0] expected_raw, expected_ordinary;
    integer i, cycles, seen_raw, seen_ordinary;

    montgomery_mul #(.WIDTH(WIDTH)) raw_dut (
        .clk(clk),.rst_n(rst_n),.start(start),.a(a),.b(b),.modulus(modulus),
        .result(raw_result),.busy(raw_busy),.done(raw_done),.error(raw_error));
    mod_mul #(.WIDTH(WIDTH)) ordinary_dut (
        .clk(clk),.rst_n(rst_n),.start(start),.a(a),.b(b),.modulus(modulus),
        .result(ordinary_result),.busy(ordinary_busy),.done(ordinary_done),.error(ordinary_error));

    task reject_input;
        input [WIDTH-1:0] av, bv, mv;
        begin
            @(negedge clk); a=av; b=bv; modulus=mv; start=1;
            @(negedge clk); start=0;
            if (raw_error!==1'b1 || ordinary_error!==1'b1 ||
                raw_busy!==1'b0 || ordinary_busy!==1'b0 || raw_done!==1'b0 || ordinary_done!==1'b0) begin
                $display("FAIL: invalid Montgomery input accepted W=%0d a=%h b=%h m=%h",WIDTH,av,bv,mv); $stop;
            end
            @(negedge clk);
            if (raw_error!==1'b0 || ordinary_error!==1'b0) begin
                $display("FAIL: error pulse lasted more than one clock"); $stop;
            end
        end
    endtask

    task abort_operation;
        input integer age;
        begin
            @(negedge clk); a=2; b=2; modulus=3; start=1;
            @(negedge clk); start=0;
            repeat(age) @(negedge clk);
            rst_n=0;
            #1;
            if (raw_busy!==1'b0 || ordinary_busy!==1'b0 || raw_done!==1'b0 ||
                ordinary_done!==1'b0 || raw_result!==0 || ordinary_result!==0 ||
                raw_dut.accumulator!==0 || raw_dut.a_reg!==0 || raw_dut.b_reg!==0 ||
                ordinary_dut.b_mont!==0 || ordinary_dut.a_reg!==0 ||
                ordinary_dut.u_montgomery.accumulator!==0 ||
                ordinary_dut.u_montgomery.a_reg!==0 || ordinary_dut.u_montgomery.b_reg!==0) begin
                $display("FAIL: reset did not clear Montgomery operation"); $stop;
            end
            @(negedge clk); rst_n=1;
            repeat(2*WIDTH+6) begin
                @(negedge clk);
                if (raw_done!==1'b0 || ordinary_done!==1'b0 || raw_error!==1'b0 || ordinary_error!==1'b0) begin
                    $display("FAIL: stale completion after reset"); $stop;
                end
            end
        end
    endtask

    initial begin
        if (!$value$plusargs("vectors=%s",vector_path)) begin
            $display("FAIL: missing +vectors file"); $stop;
        end
        $readmemh(vector_path,vectors);
        #20; rst_n=1;
        reject_input(0,0,0);
        reject_input(0,0,1);
        reject_input(0,0,2);
        if (WIDTH>2) reject_input(1,1,4);
        reject_input(3,0,3);
        reject_input(0,3,3);
        abort_operation(1);       // Raw multiply and wrapper conversion active.
        abort_operation(WIDTH+1); // Wrapper's internal Montgomery engine active.
        for (i=0;i<VECTOR_COUNT;i=i+1) begin
            @(negedge clk);
            {a,b,modulus,expected_raw,expected_ordinary}=vectors[i];
            start=1;
            @(negedge clk); start=0; cycles=0; seen_raw=0; seen_ordinary=0;
            if (raw_busy!==1'b1 || ordinary_busy!==1'b1) begin
                $display("FAIL: valid request not accepted W=%0d vector=%0d",WIDTH,i); $stop;
            end
            // Live input changes and a second start must not disturb latched operands.
            a=0; b=0; modulus=0;
            while (cycles<2*WIDTH+3) begin
                @(negedge clk); cycles=cycles+1;
                if (cycles==1) start=1;
                if (cycles==2) start=0;
                if (raw_error!==1'b0 || ordinary_error!==1'b0) begin
                    $display("FAIL: valid transaction raised error W=%0d vector=%0d",WIDTH,i); $stop;
                end
                if (raw_done) begin
                    if (seen_raw || cycles!=WIDTH+1 || raw_busy!==1'b0 || raw_result!==expected_raw) begin
                        $display("FAIL: raw Montgomery mismatch W=%0d vector=%0d cycles=%0d expected=%h got=%h",WIDTH,i,cycles,expected_raw,raw_result); $stop;
                    end
                    seen_raw=1;
                end else if (cycles<WIDTH+1 && raw_busy!==1'b1) begin
                    $display("FAIL: raw busy dropped early"); $stop;
                end
                if (ordinary_done) begin
                    if (seen_ordinary || cycles!=2*WIDTH+3 || ordinary_busy!==1'b0 || ordinary_result!==expected_ordinary) begin
                        $display("FAIL: ordinary Montgomery mismatch W=%0d vector=%0d cycles=%0d expected=%h got=%h",WIDTH,i,cycles,expected_ordinary,ordinary_result); $stop;
                    end
                    seen_ordinary=1;
                end else if (ordinary_busy!==1'b1) begin
                    $display("FAIL: ordinary busy dropped early"); $stop;
                end
            end
            if (!seen_raw || !seen_ordinary) begin $display("FAIL: Montgomery timeout"); $stop; end
            @(negedge clk);
            if (raw_done!==1'b0 || ordinary_done!==1'b0 || raw_busy!==1'b0 || ordinary_busy!==1'b0) begin
                $display("FAIL: completion pulse or idle state incorrect"); $stop;
            end
        end
        $display("PASS: Montgomery W=%0d vectors=%0d, exact latency, invalid inputs, busy/start, reset",WIDTH,VECTOR_COUNT);
        $finish;
    end
endmodule
`default_nettype wire
