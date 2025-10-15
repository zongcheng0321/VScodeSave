module decoder_2to4_tb;

reg A,B;
wire Q3,Q2,Q1,Q0;

decoder_2to4 d( .A(A), .B(B), .Q3(Q3), .Q2(Q2), .Q1(Q1) , .Q0(Q0));

initial 
begin
 $monitor($time,"A = %b, B = %b,Q=%b%b%b%b\n",A,B,Q3,Q2,Q1,Q0);
end

initial 
begin
 A = 0; B = 0;
 #10;
 A = 0; B = 1;
 #10;
 A = 1; B = 0;
 #10;
 A = 1; B = 1;
 #10;

end
initial begin
        $dumpfile("wave.vcd"); //  iverilog -o wave decoder_2to4.v decoder_2to4_tb.v
        $dumpvars(0, decoder_2to4_tb); // vvp wave
end
endmodule