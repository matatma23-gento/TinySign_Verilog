`timescale 1ns/1ps
`default_nettype none
module tb_key_manager;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,zeroize=0,key_word_write=0,provision_start=0,lock_start=0;
    reg [2:0] key_word_index=0;
    reg [31:0] key_word_data=0;
    wire [255:0] signing_key,public_x,public_y;
    wire key_valid,key_locked,busy,done,error;
    integer cycles,i;
    localparam [255:0] GX=256'h6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    localparam [255:0] GY=256'h4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;
    key_manager dut(.clk(clk),.rst_n(rst_n),.zeroize(zeroize),.key_word_write(key_word_write),.key_word_index(key_word_index),.key_word_data(key_word_data),
        .provision_start(provision_start),.lock_start(lock_start),.signing_key(signing_key),.public_x(public_x),.public_y(public_y),
        .key_valid(key_valid),.key_locked(key_locked),.busy(busy),.done(done),.error(error));
    task write_word(input [2:0] idx,input [31:0] value);
        begin @(negedge clk);key_word_index=idx;key_word_data=value;key_word_write=1;@(negedge clk);key_word_write=0;end
    endtask
    initial begin
        #20;rst_n=1;
        write_word(0,0);
        @(negedge clk);provision_start=1;@(negedge clk);provision_start=0;#1;
        if(!error||key_valid)begin $display("FAIL: incomplete key staging was accepted"); $stop; end
        $display("PASS: key manager rejects incomplete provisioning");
        for(i=1;i<8;i=i+1) write_word(i,(i==7)?32'h00000001:32'h00000000);
        // Replace the final word with zero to exercise private-key range validation.
        write_word(7,0);
        @(negedge clk);provision_start=1;@(negedge clk);provision_start=0;#1;
        if(!error||key_valid)begin $display("FAIL: zero private key was provisioned"); $stop; end
        $display("PASS: key manager rejects out-of-range private key");
        write_word(7,1);
        @(negedge clk);provision_start=1;@(negedge clk);provision_start=0;cycles=0;
        while(done!==1'b1&&error!==1'b1&&cycles<8000000) begin @(negedge clk);cycles=cycles+1;end
        #1;if(error||!done||!key_valid||signing_key!==256'h1||public_x!==GX||public_y!==GY)
            begin $display("FAIL: provision failed cycles=%0d valid=%b d=%h Qx=%h Qy=%h",cycles,key_valid,signing_key,public_x,public_y); $stop; end
        $display("PASS: protected key provisioning and public-key derivation (%0d cycles)",cycles);
        @(negedge clk);lock_start=1;@(negedge clk);lock_start=0;#1;
        if(error||!key_locked)begin $display("FAIL: valid key did not lock"); $stop; end
        @(negedge clk);key_word_index=7;key_word_data=32'h2;key_word_write=1;@(negedge clk);key_word_write=0;#1;
        if(!error||signing_key!==256'h1)begin $display("FAIL: locked key was changed by staging write"); $stop; end
        $display("PASS: locked key rejects overwrite");
        @(negedge clk);zeroize=1;@(negedge clk);zeroize=0;#1;
        if(key_valid||key_locked||signing_key!==0||public_x!==0||public_y!==0)begin $display("FAIL: zeroize did not clear key state"); $stop; end
        $display("PASS: key manager zeroize clears secret and public state");$finish;
    end
endmodule
`default_nettype wire
