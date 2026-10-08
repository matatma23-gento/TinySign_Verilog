`timescale 1ns/1ps
`default_nettype none
module sha256_compress (
    input wire clk, input wire rst_n, input wire start,
    input wire [511:0] block,
    input wire [255:0] hash_in,
    output reg [255:0] hash_out,
    output reg busy, output reg done
);
    localparam ST_IDLE=1'b0, ST_ROUND=1'b1;
    reg state;
    reg [5:0] round_count;
    reg [31:0] w [0:63];
    reg [31:0] h0,h1,h2,h3,h4,h5,h6,h7;
    reg [31:0] a,b,c,d,e,f,g,h;
    reg [31:0] w_value;
    integer i;

    function automatic [31:0] ror(input [31:0] x,input integer n);
        ror=(x>>n)|(x<<(32-n));
    endfunction
    function automatic [31:0] sigma0(input [31:0] x);
        sigma0=ror(x,2)^ror(x,13)^ror(x,22);
    endfunction
    function automatic [31:0] sigma1(input [31:0] x);
        sigma1=ror(x,6)^ror(x,11)^ror(x,25);
    endfunction
    function automatic [31:0] gamma0(input [31:0] x);
        gamma0=ror(x,7)^ror(x,18)^(x>>3);
    endfunction
    function automatic [31:0] gamma1(input [31:0] x);
        gamma1=ror(x,17)^ror(x,19)^(x>>10);
    endfunction
    function automatic [31:0] round_k(input [5:0] idx);
        begin
            case(idx)
                0:round_k=32'h428a2f98; 1:round_k=32'h71374491; 2:round_k=32'hb5c0fbcf; 3:round_k=32'he9b5dba5;
                4:round_k=32'h3956c25b; 5:round_k=32'h59f111f1; 6:round_k=32'h923f82a4; 7:round_k=32'hab1c5ed5;
                8:round_k=32'hd807aa98; 9:round_k=32'h12835b01; 10:round_k=32'h243185be; 11:round_k=32'h550c7dc3;
                12:round_k=32'h72be5d74; 13:round_k=32'h80deb1fe; 14:round_k=32'h9bdc06a7; 15:round_k=32'hc19bf174;
                16:round_k=32'he49b69c1; 17:round_k=32'hefbe4786; 18:round_k=32'h0fc19dc6; 19:round_k=32'h240ca1cc;
                20:round_k=32'h2de92c6f; 21:round_k=32'h4a7484aa; 22:round_k=32'h5cb0a9dc; 23:round_k=32'h76f988da;
                24:round_k=32'h983e5152; 25:round_k=32'ha831c66d; 26:round_k=32'hb00327c8; 27:round_k=32'hbf597fc7;
                28:round_k=32'hc6e00bf3; 29:round_k=32'hd5a79147; 30:round_k=32'h06ca6351; 31:round_k=32'h14292967;
                32:round_k=32'h27b70a85; 33:round_k=32'h2e1b2138; 34:round_k=32'h4d2c6dfc; 35:round_k=32'h53380d13;
                36:round_k=32'h650a7354; 37:round_k=32'h766a0abb; 38:round_k=32'h81c2c92e; 39:round_k=32'h92722c85;
                40:round_k=32'ha2bfe8a1; 41:round_k=32'ha81a664b; 42:round_k=32'hc24b8b70; 43:round_k=32'hc76c51a3;
                44:round_k=32'hd192e819; 45:round_k=32'hd6990624; 46:round_k=32'hf40e3585; 47:round_k=32'h106aa070;
                48:round_k=32'h19a4c116; 49:round_k=32'h1e376c08; 50:round_k=32'h2748774c; 51:round_k=32'h34b0bcb5;
                52:round_k=32'h391c0cb3; 53:round_k=32'h4ed8aa4a; 54:round_k=32'h5b9cca4f; 55:round_k=32'h682e6ff3;
                56:round_k=32'h748f82ee; 57:round_k=32'h78a5636f; 58:round_k=32'h84c87814; 59:round_k=32'h8cc70208;
                60:round_k=32'h90befffa; 61:round_k=32'ha4506ceb; 62:round_k=32'hbef9a3f7; 63:round_k=32'hc67178f2;
                default:round_k=0;
            endcase
        end
    endfunction

    always @* begin
        if (round_count < 16) w_value=w[round_count];
        else w_value=gamma1(w[round_count-2])+w[round_count-7]+gamma0(w[round_count-15])+w[round_count-16];
    end
    wire [31:0] ch=(e&f)^((~e)&g);
    wire [31:0] maj=(a&b)^(a&c)^(b&c);
    wire [31:0] t1=h+sigma1(e)+ch+round_k(round_count)+w_value;
    wire [31:0] t2=sigma0(a)+maj;
    wire [31:0] an=t1+t2, bn=a, cn=b, dn=c, en=d+t1, fn=e, gn=f, hn=g;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=ST_IDLE; round_count<=0; busy<=0; done<=0; hash_out<=0;
            h0<=0;h1<=0;h2<=0;h3<=0;h4<=0;h5<=0;h6<=0;h7<=0;
            a<=0;b<=0;c<=0;d<=0;e<=0;f<=0;g<=0;h<=0;
            for(i=0;i<64;i=i+1) w[i]<=0;
        end else begin
            done<=0;
            case(state)
                ST_IDLE: if(start) begin
                    h0<=hash_in[255:224]; h1<=hash_in[223:192]; h2<=hash_in[191:160]; h3<=hash_in[159:128];
                    h4<=hash_in[127:96]; h5<=hash_in[95:64]; h6<=hash_in[63:32]; h7<=hash_in[31:0];
                    a<=hash_in[255:224]; b<=hash_in[223:192]; c<=hash_in[191:160]; d<=hash_in[159:128];
                    e<=hash_in[127:96]; f<=hash_in[95:64]; g<=hash_in[63:32]; h<=hash_in[31:0];
                    for(i=0;i<16;i=i+1) w[i]<=block[511-i*32 -:32];
                    round_count<=0; busy<=1; state<=ST_ROUND;
                end
                ST_ROUND: begin
                    if(round_count>=16) w[round_count]<=w_value;
                    a<=an;b<=bn;c<=cn;d<=dn;e<=en;f<=fn;g<=gn;h<=hn;
                    if(round_count==63) begin
                        hash_out<={h0+an,h1+bn,h2+cn,h3+dn,h4+en,h5+fn,h6+gn,h7+hn};
                        busy<=0;done<=1;state<=ST_IDLE;
                    end else round_count<=round_count+1'b1;
                end
                default: begin state<=ST_IDLE;busy<=0;end
            endcase
        end
    end
endmodule
`default_nettype wire
