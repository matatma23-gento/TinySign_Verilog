`timescale 1ns/1ps
`default_nettype none
// Short, readable waveform demo. The production ECC datapath remains 256 bits.
// Run: bash scripts/run_rtl_tests.sh --waves
module tb_montgomery_wave;
    reg clk=0;
    always #5 clk=~clk; // 10 ns clock period.
    reg rst_n=0, start=0;
    reg [7:0] a=0, b=0, modulus=0;
    wire [7:0] raw_result, ordinary_result;
    wire raw_busy, raw_done, raw_error;
    wire ordinary_busy, ordinary_done, ordinary_error;

    montgomery_mul #(.WIDTH(8)) raw_dut (
        .clk(clk),.rst_n(rst_n),.start(start),.a(a),.b(b),.modulus(modulus),
        .result(raw_result),.busy(raw_busy),.done(raw_done),.error(raw_error));
    mod_mul #(.WIDTH(8)) ordinary_dut (
        .clk(clk),.rst_n(rst_n),.start(start),.a(a),.b(b),.modulus(modulus),
        .result(ordinary_result),.busy(ordinary_busy),.done(ordinary_done),.error(ordinary_error));

    task multiply;
        input [7:0] av, bv, expected_raw, expected_ordinary;
        integer cycles, seen_raw, seen_ordinary;
        begin
            @(negedge clk); a=av; b=bv; modulus=251; start=1;
            @(negedge clk); start=0; seen_raw=0; seen_ordinary=0;
            for (cycles=1; cycles<=19; cycles=cycles+1) begin
                @(negedge clk);
                if (raw_error!==1'b0 || ordinary_error!==1'b0) begin
                    $display("FAIL: waveform example raised error"); $stop;
                end
                if (raw_done) begin
                    if (cycles!=9 || raw_result!==expected_raw) begin
                        $display("FAIL: raw waveform result/latency"); $stop;
                    end
                    seen_raw=1;
                end
                if (ordinary_done) begin
                    if (cycles!=19 || ordinary_result!==expected_ordinary) begin
                        $display("FAIL: ordinary waveform result/latency"); $stop;
                    end
                    seen_ordinary=1;
                end
            end
            if (!seen_raw || !seen_ordinary) begin
                $display("FAIL: waveform example timeout"); $stop;
            end
            repeat(3) @(negedge clk);
        end
    endtask

    initial begin
        #22; rst_n=1; // Release reset away from a clock edge.
        // R=256; R^-1 mod 251 = 201. Raw and ordinary results differ.
        multiply(7,9,113,63);
        multiply(250,250,201,1);
        // Even modulus: a one-clock error pulse, with no busy/done pulse.
        @(negedge clk); modulus=250; a=7; b=9; start=1;
        @(negedge clk); start=0;
        if (raw_error!==1'b1 || ordinary_error!==1'b1 ||
            raw_busy!==1'b0 || ordinary_busy!==1'b0 ||
            raw_done!==1'b0 || ordinary_done!==1'b0) begin
            $display("FAIL: waveform example accepted even modulus"); $stop;
        end
        repeat(3) @(negedge clk);
        $display("PASS: waveform demo, two products and even-modulus rejection");
        $finish;
    end
endmodule
`default_nettype wire
