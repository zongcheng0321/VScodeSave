module bcd_7seg_tb;

reg A,B,C,D;
wire a,b,c,d,e,f,g;

//decoder_2to4 d(Q3,Q2,Q1,Q0,A,B);
BCD BCD1( .A(A), .B(B), .C(C), .D(D), .a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g));

/*initial 
begin
 $monitor($time,"A = %b, B = %b,Q=%b%b%b%b\n",A,B,Q3,Q2,Q1,Q0);
end*/

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
    $dumpfile("wave.vcd");
    $dumpvars(0, bcd_7seg_tb);
end
endmodule