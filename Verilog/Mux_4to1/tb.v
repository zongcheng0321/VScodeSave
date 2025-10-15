    module Mux_4to1_tb;
    wire F;
    reg A,B,s3,s2,s1,s0;
    Mux_4to1 mux(.F(F),.A(A),.B(B),.s3(s3),.s2(s2),.s1(s1),.s0(s0));
    initial begin
        A = 0; B = 0; s3 = 0; s2 = 0; s1 = 0; s0 =0;
        #5;
        A = 0; B = 0; s3 = 0; s2 = 0; s1 = 0; s0 =1;
        #5;
        A = 0; B = 1; s3 = 0; s2 = 0; s1 = 0; s0 =0;
        #5;
        A = 0; B = 1; s3 = 0; s2 = 0; s1 = 1; s0 =0;
        #5;
        A = 1; B = 0; s3 = 0; s2 = 0; s1 = 0; s0 =0;
        #5;
        A = 1; B = 0; s3 = 0; s2 = 1; s1 = 0; s0 =0;
        #5;
        A = 1; B = 1; s3 = 0; s2 = 0; s1 = 0; s0 =0;
        #5;
        A = 1; B = 1; s3 = 1; s2 = 0; s1 = 0; s0 =0;
        #5;
        $finish;
        
    end
    initial begin
        $dumpfile("wave.vcd"); //  iverilog -o wave Mux_4to1.v tb.v
        $dumpvars(0, Mux_4to1_tb); // vvp wave
    end
    endmodule