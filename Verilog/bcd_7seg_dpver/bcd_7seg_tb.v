module bcd_7seg_tb;

reg A,B,C,D;
wire a,b,c,d,e,f,g,dp;

//BCD1 BCD( .A(A), .B(B), .C(C), .D(D), .a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g), .dp(dp));//gate level
BCD2 BCD( .A(A), .B(B), .C(C), .D(D), .a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g), .dp(dp)); //dataflow
initial 
begin
 A = 0; B = 0; C = 0; D = 0;
 #10;
 A = 0; B = 0; C = 0; D = 1;
 #10;
 A = 0; B = 0; C = 1; D = 0;
 #10;
 A = 0; B = 0; C = 1; D = 1;
 #10;
 A = 0; B = 1; C = 0; D = 0;
 #10;
 A = 0; B = 1; C = 0; D = 1;
 #10;
 A = 0; B = 1; C = 1; D = 0;
 #10;
 A = 0; B = 1; C = 1; D = 1;
 #10;
 A = 1; B = 0; C = 0; D = 0;
 #10;
 A = 1; B = 0; C = 0; D = 1;
 #10;
end

initial begin
    $dumpfile("wave.vcd"); //iverilog -o wave BCDto7seg_gatelevel.v bcd_7seg_tb.v //iverilog -o wave BCDto7seg_dataflow.v bcd_7seg_tb.v
    $dumpvars(0, bcd_7seg_tb); //vvp wave
end
endmodule