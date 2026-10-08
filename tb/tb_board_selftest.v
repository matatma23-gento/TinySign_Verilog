`timescale 1ns/1ps
`default_nettype none
module tb_board_selftest;
    reg clk=0;
    always #10 clk=~clk; // Match the DE10-Nano's 50 MHz clock stimulus.
    reg rst_n=0;
    wire finished,passed,core_busy;
    wire [7:0] failure_code,step;
    wire [31:0] provision_cycles,sign_cycles;
    integer cycles,fd;
    reg [4095:0] trace_path;
    reg [9:0] previous;
    wire [9:0] snapshot={dut.bus_write,core_busy,dut.u_core.key_valid,
        dut.u_core.key_locked,dut.u_core.sign_valid,dut.u_core.zeroized,
        finished,passed,(dut.u_core.signing_key!=0),
        (dut.u_core.u_signer.d_reg!=0 || dut.u_core.u_signer.k_reg!=0)};
    tinysign_board_selftest dut(.clk(clk),.rst_n(rst_n),.finished(finished),
        .passed(passed),.failure_code(failure_code),.provision_cycles(provision_cycles),
        .sign_cycles(sign_cycles),.core_busy(core_busy),.step(step));
    initial begin
        fd=0;
        if($value$plusargs("trace=%s",trace_path)) begin
            fd=$fopen(trace_path,"w");
            if(fd==0) begin $display("FAIL: cannot open trace file"); $stop; end
            $fwrite(fd,"cycle,write,busy,key_valid,key_locked,sign_valid,zeroized,finished,passed,key_nonzero,signer_secret_nonzero,step\n");
        end
        #23; rst_n=1; previous=10'hxxx;
        cycles=0;
        while(!finished && cycles<16000000) begin
            @(negedge clk); cycles=cycles+1;
            if(fd!=0 && snapshot!==previous) begin
                $fwrite(fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",cycles,
                    snapshot[9],snapshot[8],snapshot[7],snapshot[6],snapshot[5],
                    snapshot[4],snapshot[3],snapshot[2],snapshot[1],snapshot[0],step);
                previous=snapshot;
            end
        end
        if(fd!=0) $fclose(fd);
        if(!finished || !passed || failure_code!=0 || provision_cycles==0 || sign_cycles==0) begin
            $display("FAIL: board selftest step=%0d failure=%h",step,failure_code); $stop;
        end
        if(dut.u_core.signing_key!==0 || dut.u_core.u_signer.d_reg!==0 || dut.u_core.u_signer.k_reg!==0) begin
            $display("FAIL: secret registers remain after zeroize"); $stop;
        end
        $display("METRIC,simulation,provision,%0d",provision_cycles);
        $display("METRIC,simulation,sign,%0d",sign_cycles);
        $display("PASS: synthesizable board selftest, public key/signature/lock/readback/in-flight zeroize");
        $finish;
    end
endmodule
`default_nettype wire
