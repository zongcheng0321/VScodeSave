module tb;
reg [1:0] A,B,C,D;
reg S,E;// E = 0 驅動
wire [3:0] Y;
topmodule t(.Y(Y), .A(A), .B(B), .C(C), .D(D), .S(S), .E(E));
initial begin
    A = 2'b11; B = 2'b11; C = 2'b11; D = 2'b10; E = 1'b1; S = 1'b0;
    #10 A = 2'b00; C = 2'b00;
    #10 A = 2'b01; C = 2'b01; E = 1'b0;
    #10 A = 2'b10; C = 2'b10; 
    #10 A = 2'b11; B = 2'b10; C = 2'b11; D = 2'b11;
    #10 A = 2'b00; C = 2'b00; 
    #10 A = 2'b01; C = 2'b01;
    #10 A = 2'b10; C = 2'b10; 
    #10 A = 2'b11; B = 2'b01; C = 2'b11; D = 2'b00;
    #10 A = 2'b00; C = 2'b00;
    #10 $finish;
end
always begin
    #10 S = ~S;
end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave topmodule.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule