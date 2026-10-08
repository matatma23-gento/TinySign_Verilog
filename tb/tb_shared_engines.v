`timescale 1ns/1ps
`default_nettype none
module tb_shared_engines;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,bus_write=0;
    reg [7:0] bus_address=0;
    reg [31:0] bus_write_data=0;
    reg [3:0] bus_byte_enable=4'hF;
    wire [31:0] bus_read_data;
    wire busy;
    integer i,cycles,first_sign_cycles;
    localparam [255:0] D=256'hC9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721;
    localparam [255:0] QX=256'h60FED4BA255A9D31C961EB74C6356D68C049B8923B61FA6CE669622E60F29FB6;
    localparam [255:0] QY=256'h7903FE1008B8BC99A41AE9E95628BC64F2F1B20C2D7E9F5177A3C294D4462299;
    localparam [255:0] EXPECTED_R=256'hEFD48B2AACB6A8FD1140DD9CD45E81D69D2C877B56AAF991C34D0EA84EAF3716;
    localparam [255:0] EXPECTED_S=256'hF7CB1C942D657C41D436C7A1B6E29F65F3E900DBB9AFF4064DC4AB2F843ACDA8;
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
    task check_engine_clear;
        begin
            if(dut.u_shared_scalar.scalar_reg!==0||dut.u_shared_scalar.busy||
               dut.u_shared_inverse.base_reg!==0||dut.u_shared_inverse.accumulator_reg!==0||dut.u_shared_inverse.busy||
               dut.u_shared_multiply.busy||dut.engine_inv_result!==0||dut.engine_mul_result!==0)
                begin $display("FAIL: shared engines not cleared");$stop;end
        end
    endtask
    initial begin
        #20;rst_n=1;
        // Abort provisioning while the shared scalar engine is active, then recover.
        for(i=0;i<8;i=i+1) write_reg(8'h10+i*4,signature_word(D,i));
        write_reg(8'h00,1);repeat(20)@(negedge clk);
        if(!dut.u_shared_scalar.busy) begin $display("FAIL: scalar did not start");$stop;end
        write_reg(8'h00,5);wait_idle(10);
        check_engine_clear;
        // Load RFC 6979 key and SHA-256("sample").
        write_reg(8'h30,32'hAF2BDBE1);write_reg(8'h34,32'hAA9B6EC1);write_reg(8'h38,32'hE2ADE1D6);write_reg(8'h3C,32'h94F41FC7);
        write_reg(8'h40,32'h1A831D02);write_reg(8'h44,32'h68E98915);write_reg(8'h48,32'h62113D8A);write_reg(8'h4C,32'h62ADD1BF);
        for(i=0;i<8;i=i+1) write_reg(8'h10+i*4,signature_word(D,i));
        bus_address=8'h10;#1;if(bus_read_data!==0)begin $display("FAIL: private-key staging readback was not zero"); $stop; end
        write_reg(8'h00,1);wait_idle(8000000);#1;
        bus_address=8'h10;#1;if(bus_read_data!==0)begin $display("FAIL: provisioned key was readable"); $stop; end
        bus_address=8'h04;#1;if(!bus_read_data[4])begin $display("FAIL: key_valid not set after provisioning"); $stop; end
        for(i=0;i<8;i=i+1) begin
            bus_address=8'h50+i*4;#1;if(bus_read_data!==signature_word(QX,i))begin $display("FAIL: public X");$stop;end
            bus_address=8'h70+i*4;#1;if(bus_read_data!==signature_word(QY,i))begin $display("FAIL: public Y");$stop;end
        end
        $display("PASS: shared ECC derives RFC6979 public key after aborted provisioning");
        write_reg(8'h00,2);wait_idle(10);bus_address=8'h04;#1;
        if(!bus_read_data[5])begin $display("FAIL: key lock status was not set"); $stop; end
        write_reg(8'h00,4);wait_idle(8000000);first_sign_cycles=cycles;bus_address=8'h04;#1;
        if(!bus_read_data[6])begin $display("FAIL: signature-valid status missing"); $stop; end
        for(i=0;i<8;i=i+1) begin
            bus_address=8'h90+i*4;#1;if(bus_read_data!==signature_word(EXPECTED_R,i))begin $display("FAIL: SIG_R[%0d] mismatch",i); $stop; end
            bus_address=8'hB0+i*4;#1;if(bus_read_data!==signature_word(EXPECTED_S,i))begin $display("FAIL: SIG_S[%0d] mismatch",i); $stop; end
        end
        $display("PASS: register-controlled provisioning, lock, and ECDSA signature readback");
        // Repeated signing must reuse the shared engines without stale responses.
        write_reg(8'h00,4);wait_idle(8000000);
        if(cycles!=first_sign_cycles)begin $display("FAIL: repeat signature latency changed");$stop;end
        if(dut.sig_r_reg!==EXPECTED_R||dut.sig_s_reg!==EXPECTED_S)begin $display("FAIL: repeat signature mismatch");$stop;end
        $display("PASS: repeated shared-engine signature, fixed %0d cycle latency",cycles);
        // Abort during the second inversion (mod n), with sensitive operands live.
        write_reg(8'h00,4);cycles=0;
        while(!(dut.u_shared_inverse.busy&&dut.u_shared_inverse.modulus_reg==256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551)&&cycles<8000000)begin
            @(negedge clk);cycles=cycles+1;
        end
        if(cycles>=8000000)begin $display("FAIL: never reached nonce inversion");$stop;end
        // Reject overlapping commands without changing ownership.
        write_reg(8'h00,1);bus_address=8'h08;#1;
        if(bus_read_data!==3||!dut.sign_owner)begin $display("FAIL: busy command changed engine owner");$stop;end
        write_reg(8'h00,5);wait_idle(10);bus_address=8'h04;#1;
        if(bus_read_data[4]||bus_read_data[5]||bus_read_data[6]||!bus_read_data[7])begin $display("FAIL: zeroize status incorrect"); $stop; end
        bus_address=8'h90;#1;if(bus_read_data!==0)begin $display("FAIL: signature was not cleared by zeroize"); $stop; end
        bus_address=8'h10;#1;if(bus_read_data!==0)begin $display("FAIL: private key readback after zeroize was nonzero"); $stop; end
        if(dut.u_signer.d_reg!==0||dut.u_signer.k_reg!==0||dut.u_signer.u_nonce.d_reg!==0||dut.u_signer.u_nonce.k_reg!==0)
            begin $display("FAIL: zeroize did not clear signer and RFC6979 key state"); $stop; end
        if(dut.u_signer.u_nonce.v_reg!=={32{8'h01}}||dut.u_signer.u_nonce.state!==0)
            begin $display("FAIL: zeroize did not reset RFC6979 state"); $stop; end
        check_engine_clear;
        repeat(1000)@(negedge clk);
        if(busy||dut.sign_valid||dut.key_valid||dut.engine_inv_done||dut.engine_scalar_done||dut.engine_mul_done)
            begin $display("FAIL: stale result after zeroize");$stop;end
        // Recovery must work after aborting an operation modulo n.
        for(i=0;i<8;i=i+1) write_reg(8'h10+i*4,(i==7)?1:0);
        write_reg(8'h00,1);wait_idle(8000000);
        if(!dut.key_valid||dut.public_x!==256'h6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296)
            begin $display("FAIL: recovery after inverse abort");$stop;end
        $display("PASS: zeroize during scalar and inverse, busy rejection, no stale completion, reprovision recovery");$finish;
    end
endmodule
`default_nettype wire
