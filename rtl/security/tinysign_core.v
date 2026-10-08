`timescale 1ns/1ps
`default_nettype none
module tinysign_core #(
    parameter integer OP_SLOT_CYCLES=14000
) (
    input wire clk,input wire rst_n,
    input wire bus_write,input wire [7:0] bus_address,input wire [31:0] bus_write_data,input wire [3:0] bus_byte_enable,
    output reg [31:0] bus_read_data,output wire busy
);
    localparam [7:0] A_CMD=8'h00,A_STATUS=8'h04,A_ERROR=8'h08,
        A_KEY_BASE=8'h10,A_DIGEST_BASE=8'h30,A_PUB_X=8'h50,A_PUB_Y=8'h70,
        A_SIG_R=8'h90,A_SIG_S=8'hB0;
    localparam [31:0] CMD_NOP=0,CMD_PROVISION=1,CMD_LOCK=2,CMD_GET_PUB=3,
        CMD_SIGN=4,CMD_ZEROIZE=5,CMD_CLEAR_STATUS=6;
    localparam [2:0] ST_IDLE=0,ST_PROVISION_WAIT=1,ST_LOCK_WAIT=2,ST_SIGN_WAIT=3,ST_ZEROIZE_WAIT=4;
    reg [2:0] state;
    reg [255:0] digest_reg,sig_r_reg,sig_s_reg;
    reg done_latch,error_latch,zeroized,sign_valid;
    reg [7:0] error_code;
    reg key_word_write,provision_start,lock_start,key_zeroize,sign_start;
    reg [2:0] key_word_index;
    reg [31:0] key_word_data;
    wire [255:0] signing_key,public_x,public_y,signer_r,signer_s;
    wire key_valid,key_locked,key_busy,key_done,key_error,sign_busy,sign_done,sign_error;
    assign busy=(state!=ST_IDLE);

    // The command FSM is the owner register. Ownership cannot change until
    // completion; ZEROIZE aborts both controllers and all shared engines.
    wire provision_owner=(state==ST_PROVISION_WAIT);
    wire sign_owner=(state==ST_SIGN_WAIT);
    wire engine_rst_n=rst_n&&!key_zeroize;
    wire [255:0] km_scalar,sg_scalar,km_inv_a,sg_inv_a,km_inv_mod,sg_inv_mod;
    wire [255:0] km_mul_a,km_mul_b,km_mul_mod,sg_mul_a,sg_mul_b,sg_mul_mod;
    wire km_scalar_start,sg_scalar_start,km_inv_start,sg_inv_start,km_mul_start,sg_mul_start;
    wire [255:0] engine_px,engine_py,engine_pz,engine_inv_result,engine_mul_result;
    wire engine_scalar_done,engine_scalar_error,engine_inv_done,engine_inv_error,engine_mul_done,engine_mul_error;
    localparam [255:0] GX=256'h6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    localparam [255:0] GY=256'h4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;

    scalar_mult #(.OP_SLOT_CYCLES(OP_SLOT_CYCLES)) u_shared_scalar(
        .clk(clk),.rst_n(engine_rst_n),
        .start((provision_owner&&km_scalar_start)||(sign_owner&&sg_scalar_start)),
        .scalar(provision_owner?km_scalar:sg_scalar),.x_in(GX),.y_in(GY),.z_in(256'd1),
        .x_out(engine_px),.y_out(engine_py),.z_out(engine_pz),.busy(),
        .done(engine_scalar_done),.error(engine_scalar_error));
    mod_inv u_shared_inverse(
        .clk(clk),.rst_n(engine_rst_n),
        .start((provision_owner&&km_inv_start)||(sign_owner&&sg_inv_start)),
        .a(provision_owner?km_inv_a:sg_inv_a),.modulus(provision_owner?km_inv_mod:sg_inv_mod),
        .result(engine_inv_result),.busy(),.done(engine_inv_done),.error(engine_inv_error));
    mod_mul u_shared_multiply(
        .clk(clk),.rst_n(engine_rst_n),
        .start((provision_owner&&km_mul_start)||(sign_owner&&sg_mul_start)),
        .a(provision_owner?km_mul_a:sg_mul_a),.b(provision_owner?km_mul_b:sg_mul_b),
        .modulus(provision_owner?km_mul_mod:sg_mul_mod),
        .result(engine_mul_result),.busy(),.done(engine_mul_done),.error(engine_mul_error));

    key_manager #(.OP_SLOT_CYCLES(OP_SLOT_CYCLES),.SHARED_ENGINES(1)) u_key_manager(
        .clk(clk),.rst_n(rst_n),.zeroize(key_zeroize),.key_word_write(key_word_write),.key_word_index(key_word_index),.key_word_data(key_word_data),
        .provision_start(provision_start),.lock_start(lock_start),.signing_key(signing_key),.public_x(public_x),.public_y(public_y),
        .key_valid(key_valid),.key_locked(key_locked),.busy(key_busy),.done(key_done),.error(key_error),
        .engine_scalar_start(km_scalar_start),.engine_scalar(km_scalar),
        .engine_px(engine_px),.engine_py(engine_py),.engine_pz(engine_pz),
        .engine_scalar_done(provision_owner&&engine_scalar_done),.engine_scalar_error(provision_owner&&engine_scalar_error),
        .engine_inv_start(km_inv_start),.engine_inv_a(km_inv_a),.engine_inv_modulus(km_inv_mod),
        .engine_inv_result(engine_inv_result),.engine_inv_done(provision_owner&&engine_inv_done),.engine_inv_error(provision_owner&&engine_inv_error),
        .engine_mul_start(km_mul_start),.engine_mul_a(km_mul_a),.engine_mul_b(km_mul_b),.engine_mul_modulus(km_mul_mod),
        .engine_mul_result(engine_mul_result),.engine_mul_done(provision_owner&&engine_mul_done),.engine_mul_error(provision_owner&&engine_mul_error));
    ecdsa_signer #(.OP_SLOT_CYCLES(OP_SLOT_CYCLES),.SHARED_ENGINES(1)) u_signer(
        .clk(clk),.rst_n(rst_n),.clear(key_zeroize),.start(sign_start),.private_key(signing_key),.digest(digest_reg),.r(signer_r),.s(signer_s),
        .busy(sign_busy),.done(sign_done),.error(sign_error),
        .engine_scalar_start(sg_scalar_start),.engine_scalar(sg_scalar),
        .engine_px(engine_px),.engine_py(engine_py),.engine_pz(engine_pz),
        .engine_scalar_done(sign_owner&&engine_scalar_done),.engine_scalar_error(sign_owner&&engine_scalar_error),
        .engine_inv_start(sg_inv_start),.engine_inv_a(sg_inv_a),.engine_inv_modulus(sg_inv_mod),
        .engine_inv_result(engine_inv_result),.engine_inv_done(sign_owner&&engine_inv_done),.engine_inv_error(sign_owner&&engine_inv_error),
        .engine_mul_start(sg_mul_start),.engine_mul_a(sg_mul_a),.engine_mul_b(sg_mul_b),.engine_mul_modulus(sg_mul_mod),
        .engine_mul_result(engine_mul_result),.engine_mul_done(sign_owner&&engine_mul_done),.engine_mul_error(sign_owner&&engine_mul_error));

    function automatic [31:0] word_at(input [255:0] value,input [2:0] index);
        word_at=value[255-index*32 -:32];
    endfunction
    always @* begin
        bus_read_data=0;
        case(bus_address)
            A_STATUS: bus_read_data={24'b0,zeroized,sign_valid,key_locked,key_valid,error_latch,done_latch,busy,!busy};
            A_ERROR: bus_read_data={24'b0,error_code};
            default: begin
                if(bus_address>=A_PUB_X&&bus_address<A_PUB_X+8'h20&&bus_address[1:0]==0)
                    bus_read_data=word_at(public_x,(bus_address-A_PUB_X)>>2);
                else if(bus_address>=A_PUB_Y&&bus_address<A_PUB_Y+8'h20&&bus_address[1:0]==0)
                    bus_read_data=word_at(public_y,(bus_address-A_PUB_Y)>>2);
                else if(bus_address>=A_SIG_R&&bus_address<A_SIG_R+8'h20&&bus_address[1:0]==0)
                    bus_read_data=word_at(sig_r_reg,(bus_address-A_SIG_R)>>2);
                else if(bus_address>=A_SIG_S&&bus_address<A_SIG_S+8'h20&&bus_address[1:0]==0)
                    bus_read_data=word_at(sig_s_reg,(bus_address-A_SIG_S)>>2);
            end
        endcase
    end

    task set_error(input [7:0] code);
        begin error_latch<=1;done_latch<=0;error_code<=code;end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=ST_IDLE;digest_reg<=0;sig_r_reg<=0;sig_s_reg<=0;
            done_latch<=0;error_latch<=0;zeroized<=0;sign_valid<=0;error_code<=0;
            key_word_write<=0;provision_start<=0;lock_start<=0;key_zeroize<=0;sign_start<=0;key_word_index<=0;key_word_data<=0;
        end else begin
            key_word_write<=0;provision_start<=0;lock_start<=0;key_zeroize<=0;sign_start<=0;
            if(state==ST_PROVISION_WAIT) begin
                if(key_error) begin set_error(8'h02);state<=ST_IDLE;end
                else if(key_done) begin done_latch<=1;error_latch<=0;error_code<=0;state<=ST_IDLE;end
            end else if(state==ST_LOCK_WAIT) begin
                if(key_error) begin set_error(8'h02);state<=ST_IDLE;end
                else if(key_done) begin done_latch<=1;error_latch<=0;error_code<=0;state<=ST_IDLE;end
            end else if(state==ST_SIGN_WAIT) begin
                if(sign_error) begin set_error(8'h02);state<=ST_IDLE;end
                else if(sign_done) begin sig_r_reg<=signer_r;sig_s_reg<=signer_s;sign_valid<=1;done_latch<=1;error_latch<=0;error_code<=0;state<=ST_IDLE;end
            end else if(state==ST_ZEROIZE_WAIT) begin
                if(key_done) begin done_latch<=1;state<=ST_IDLE;end
            end
            if(bus_write) begin
                if(state!=ST_IDLE&&!(bus_address==A_CMD&&bus_write_data==CMD_ZEROIZE)) set_error(8'h03);
                else if(bus_byte_enable!=4'hF) set_error(8'h04);
                else if(bus_address==A_CMD) begin
                    if(bus_write_data!=CMD_NOP&&bus_write_data!=CMD_CLEAR_STATUS) zeroized<=0;
                    case(bus_write_data)
                        CMD_NOP: begin end
                        CMD_PROVISION: begin done_latch<=0;error_latch<=0;error_code<=0;provision_start<=1;state<=ST_PROVISION_WAIT;end
                        CMD_LOCK: begin done_latch<=0;error_latch<=0;error_code<=0;lock_start<=1;state<=ST_LOCK_WAIT;end
                        CMD_GET_PUB: begin
                            if(key_valid) begin done_latch<=1;error_latch<=0;error_code<=0;end
                            else set_error(8'h01);
                        end
                        CMD_SIGN: begin
                            if(key_valid&&key_locked) begin done_latch<=0;error_latch<=0;error_code<=0;sign_start<=1;state<=ST_SIGN_WAIT;end
                            else set_error(8'h01);
                        end
                        CMD_ZEROIZE: begin
                            key_zeroize<=1;digest_reg<=0;sig_r_reg<=0;sig_s_reg<=0;sign_valid<=0;done_latch<=0;error_latch<=0;error_code<=0;zeroized<=1;state<=ST_ZEROIZE_WAIT;
                        end
                        CMD_CLEAR_STATUS: begin done_latch<=0;error_latch<=0;error_code<=0;sign_valid<=0;zeroized<=0;end
                        default: set_error(8'h01);
                    endcase
                end else if(bus_address>=A_KEY_BASE&&bus_address<A_KEY_BASE+8'h20&&bus_address[1:0]==0) begin
                    if(key_locked||key_valid) set_error(8'h01);
                    else begin
                        key_word_write<=1;key_word_index<=(bus_address-A_KEY_BASE)>>2;key_word_data<=bus_write_data;
                        done_latch<=0;error_latch<=0;error_code<=0;zeroized<=0;
                    end
                end else if(bus_address>=A_DIGEST_BASE&&bus_address<A_DIGEST_BASE+8'h20&&bus_address[1:0]==0) begin
                    digest_reg[255-((bus_address-A_DIGEST_BASE)>>2)*32 -:32]<=bus_write_data;
                    done_latch<=0;error_latch<=0;error_code<=0;zeroized<=0;
                end else set_error(8'h04);
            end
        end
    end
endmodule
`default_nettype wire
