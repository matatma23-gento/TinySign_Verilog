`timescale 1ns/1ps
`default_nettype none
module tb_tinysign_core;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,bus_write=0;
    reg [7:0] bus_address=0;
    reg [31:0] bus_write_data=0;
    reg [3:0] bus_byte_enable=4'hF;
    wire [31:0] bus_read_data;
    wire busy;
    integer i,cycles;
    localparam [255:0] EXPECTED_R=256'h0466341174D59E93EB984C2A7C923A80AB99A9E91555BC73EBD8073D4C722121;
    localparam [255:0] EXPECTED_S=256'h998F2B7BB63082E976215E6AE46344D66D2D4EDEA67D65D91595F21311DF5030;
    tinysign_core dut(.clk(clk),.rst_n(rst_n),.bus_write(bus_write),.bus_address(bus_address),.bus_write_data(bus_write_data),.bus_byte_enable(bus_byte_enable),.bus_read_data(bus_read_data),.busy(busy));
    task write_reg(input [7:0] addr,input [31:0] value);
        begin @(negedge clk);bus_address=addr;bus_write_data=value;bus_write=1;@(negedge clk);bus_write=0;end
    endtask
    function automatic [31:0] signature_word(input [255:0] value,input integer index);
        signature_word=value[255-index*32 -:32];
    endfunction
    task wait_idle(input integer limit);
        begin cycles=0;while(busy&&cycles<limit) begin @(negedge clk);cycles=cycles+1;end
            if(busy)begin $display("FAIL: core command timed out"); $stop; end
        end
    endtask
    initial begin
        #20;rst_n=1;
        // Load digest SHA-256("sample") and a private key of one.
        write_reg(8'h30,32'hAF2BDBE1);write_reg(8'h34,32'hAA9B6EC1);write_reg(8'h38,32'hE2ADE1D6);write_reg(8'h3C,32'h94F41FC7);
        write_reg(8'h40,32'h1A831D02);write_reg(8'h44,32'h68E98915);write_reg(8'h48,32'h62113D8A);write_reg(8'h4C,32'h62ADD1BF);
        for(i=0;i<8;i=i+1) write_reg(8'h10+i*4,(i==7)?1:0);
        bus_address=8'h10;#1;if(bus_read_data!==0)begin $display("FAIL: private-key staging readback was not zero"); $stop; end
        write_reg(8'h00,1);wait_idle(8000000);#1;
        bus_address=8'h10;#1;if(bus_read_data!==0)begin $display("FAIL: provisioned key was readable"); $stop; end
        bus_address=8'h04;#1;if(!bus_read_data[4])begin $display("FAIL: key_valid not set after provisioning"); $stop; end
        write_reg(8'h00,2);wait_idle(10);bus_address=8'h04;#1;
        if(!bus_read_data[5])begin $display("FAIL: key lock status was not set"); $stop; end
        write_reg(8'h00,4);wait_idle(8000000);bus_address=8'h04;#1;
        if(!bus_read_data[6])begin $display("FAIL: signature-valid status missing"); $stop; end
        for(i=0;i<8;i=i+1) begin
            bus_address=8'h90+i*4;#1;if(bus_read_data!==signature_word(EXPECTED_R,i))begin $display("FAIL: SIG_R[%0d] mismatch",i); $stop; end
            bus_address=8'hB0+i*4;#1;if(bus_read_data!==signature_word(EXPECTED_S,i))begin $display("FAIL: SIG_S[%0d] mismatch",i); $stop; end
        end
        $display("PASS: register-controlled provisioning, lock, and ECDSA signature readback");
        write_reg(8'h00,4);repeat(5)@(negedge clk);write_reg(8'h00,5);wait_idle(10);bus_address=8'h04;#1;
        if(bus_read_data[4]||bus_read_data[5]||bus_read_data[6]||!bus_read_data[7])begin $display("FAIL: zeroize status incorrect"); $stop; end
        bus_address=8'h90;#1;if(bus_read_data!==0)begin $display("FAIL: signature was not cleared by zeroize"); $stop; end
        bus_address=8'h10;#1;if(bus_read_data!==0)begin $display("FAIL: private key readback after zeroize was nonzero"); $stop; end
        if(dut.u_signer.d_reg!==0||dut.u_signer.k_reg!==0||dut.u_signer.u_nonce.d_reg!==0||dut.u_signer.u_nonce.k_reg!==0)
            begin $display("FAIL: zeroize did not clear signer and RFC6979 key state"); $stop; end
        if(dut.u_signer.u_nonce.v_reg!=={32{8'h01}}||dut.u_signer.u_nonce.state!==0)
            begin $display("FAIL: zeroize did not reset RFC6979 state"); $stop; end
        $display("PASS: zeroize interrupts signing and clears register-visible and internal signer state");$finish;
    end
endmodule
`default_nettype wire
