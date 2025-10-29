module tb;
reg A,B,C,D; //A MSB
wire [7:0] out;;
BCDto7seg BCD(.A(A), .B(B), .C(C), .D(D), .out(out));
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
    $dumpfile("wave.vcd"); //  iverilog -o wave BCDto7seg.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule