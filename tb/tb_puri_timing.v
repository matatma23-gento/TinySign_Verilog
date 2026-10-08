`timescale 1ns/1ps
`default_nettype none
module tb_puri_timing;
    reg clk=0;always #20 clk=~clk;
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

    // Event-driven control trace at 25 MHz; delta-cycle rows share a timestamp.
    // Clock and secret operands are omitted; the renderer reconstructs the known clock stimulus.
    integer trace_fd,trace_cycle=0;
    reg [4095:0] trace_path;
    wire [0:0] trace_rst_n = rst_n;
    wire [0:0] trace_bus_write = bus_write;
    wire [2:0] trace_cmd = bus_address==0 ? bus_write_data[2:0] : 3'd0;
    wire [2:0] trace_core_state = dut.state;
    wire [0:0] trace_core_busy = busy;
    wire [0:0] trace_done_latch = dut.done_latch;
    wire [0:0] trace_error_latch = dut.error_latch;
    wire [0:0] trace_key_valid = dut.key_valid;
    wire [0:0] trace_key_locked = dut.key_locked;
    wire [0:0] trace_sign_valid = dut.sign_valid;
    wire [0:0] trace_provision_owner = dut.provision_owner;
    wire [0:0] trace_sign_owner = dut.sign_owner;
    wire [0:0] trace_provision_start = dut.provision_start;
    wire [0:0] trace_sign_start = dut.sign_start;
    wire [0:0] trace_zeroize = dut.key_zeroize;
    wire [2:0] trace_key_state = dut.u_key_manager.state;
    wire [4:0] trace_sign_state = dut.u_signer.state;
    wire [0:0] trace_nonce_busy = dut.u_signer.nonce_busy;
    wire [0:0] trace_nonce_done = dut.u_signer.nonce_done;
    wire [0:0] trace_scalar_start = (dut.provision_owner&&dut.km_scalar_start)||(dut.sign_owner&&dut.sg_scalar_start);
    wire [0:0] trace_scalar_busy = dut.u_shared_scalar.busy;
    wire [0:0] trace_scalar_done = dut.engine_scalar_done;
    wire [0:0] trace_inv_start = (dut.provision_owner&&dut.km_inv_start)||(dut.sign_owner&&dut.sg_inv_start);
    wire [0:0] trace_inv_busy = dut.u_shared_inverse.busy;
    wire [0:0] trace_inv_done = dut.engine_inv_done;
    wire [0:0] trace_mul_start = (dut.provision_owner&&dut.km_mul_start)||(dut.sign_owner&&dut.sg_mul_start);
    wire [0:0] trace_mul_busy = dut.u_shared_multiply.busy;
    wire [0:0] trace_mul_done = dut.engine_mul_done;
    wire [0:0] trace_sign_done = dut.sign_done;
    wire [0:0] trace_add_busy = dut.u_signer.add_busy;
    wire [39:0] trace_vector={trace_rst_n,trace_bus_write,trace_cmd,trace_core_state,trace_core_busy,trace_done_latch,trace_error_latch,trace_key_valid,trace_key_locked,trace_sign_valid,trace_provision_owner,trace_sign_owner,trace_provision_start,trace_sign_start,trace_zeroize,trace_key_state,trace_sign_state,trace_nonce_busy,trace_nonce_done,trace_scalar_start,trace_scalar_busy,trace_scalar_done,trace_inv_start,trace_inv_busy,trace_inv_done,trace_mul_start,trace_mul_busy,trace_mul_done,trace_sign_done,trace_add_busy};
    reg [39:0] trace_previous;
    initial begin
        if(!$value$plusargs("trace=%s",trace_path))trace_path="reports/puri_sign/timing/control_events.csv";
        trace_fd=$fopen(trace_path,"w");
        if(!trace_fd)begin $display("FAIL: cannot open control trace");$stop;end
        $fdisplay(trace_fd,"cycle,time_ns,rst_n,bus_write,cmd,core_state,core_busy,done_latch,error_latch,key_valid,key_locked,sign_valid,provision_owner,sign_owner,provision_start,sign_start,zeroize,key_state,sign_state,nonce_busy,nonce_done,scalar_start,scalar_busy,scalar_done,inv_start,inv_busy,inv_done,mul_start,mul_busy,mul_done,sign_done,add_busy");
    end
    always @(trace_vector) begin
        trace_cycle=($time+20)/40;
        if(trace_fd!=0)begin
            $fdisplay(trace_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",trace_cycle,$time,trace_rst_n,trace_bus_write,trace_cmd,trace_core_state,trace_core_busy,trace_done_latch,trace_error_latch,trace_key_valid,trace_key_locked,trace_sign_valid,trace_provision_owner,trace_sign_owner,trace_provision_start,trace_sign_start,trace_zeroize,trace_key_state,trace_sign_state,trace_nonce_busy,trace_nonce_done,trace_scalar_start,trace_scalar_busy,trace_scalar_done,trace_inv_start,trace_inv_busy,trace_inv_done,trace_mul_start,trace_mul_busy,trace_mul_done,trace_sign_done,trace_add_busy);
            trace_previous=trace_vector;
        end
    end
    initial begin
        #80;rst_n=1;
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
        write_reg(8'h00,4);cycles=0;
        while(!dut.u_shared_scalar.busy&&cycles<10000)begin @(negedge clk);cycles=cycles+1;end
        if(!dut.u_shared_scalar.busy)begin $display("FAIL: scalar not active before abort");$stop;end
        repeat(6)@(negedge clk);write_reg(8'h00,5);wait_idle(10);bus_address=8'h04;#1;
        if(bus_read_data[4]||bus_read_data[5]||bus_read_data[6]||!bus_read_data[7])begin $display("FAIL: zeroize status incorrect"); $stop; end
        bus_address=8'h90;#1;if(bus_read_data!==0)begin $display("FAIL: signature was not cleared by zeroize"); $stop; end
        bus_address=8'h10;#1;if(bus_read_data!==0)begin $display("FAIL: private key readback after zeroize was nonzero"); $stop; end
        if(dut.u_signer.d_reg!==0||dut.u_signer.k_reg!==0||dut.u_signer.u_nonce.d_reg!==0||dut.u_signer.u_nonce.k_reg!==0)
            begin $display("FAIL: zeroize did not clear signer and RFC6979 key state"); $stop; end
        if(dut.u_signer.u_nonce.v_reg!=={32{8'h01}}||dut.u_signer.u_nonce.state!==0)
            begin $display("FAIL: zeroize did not reset RFC6979 state"); $stop; end
        if(dut.u_shared_scalar.busy||dut.u_shared_scalar.scalar_reg!==0||dut.u_shared_inverse.busy||dut.u_shared_multiply.busy)
            begin $display("FAIL: shared engine state not reset");$stop;end
        repeat(6)@(negedge clk);
        $display("PASS: zeroize interrupts active shared scalar and clears state");
        $fclose(trace_fd);$finish;
    end
endmodule
`default_nettype wire
