module multiplier2bit (
    output [3:0] out,
    input [1:0] A,B 
);
assign out[3] = (B[1] & A[1]) & ( (B[0] & A[1]) & (B[1] & A[0]) );
assign out[2] = (B[1] & A[1]) ^ ( (B[0] & A[1]) & (B[1] & A[0]) );
assign out[1] = ( (B[0] & A[1]) ^ (B[1] & A[0]) );
assign out[0] = B[0] & A[0];
endmodule

module multiplexer2to1 (
    input [3:0] AB, CD,
    input S,E, // E = 0 驅動
    output [3:0] Y
);
assign Y[0] = (AB[0] & ~S & ~E) | (CD[0] & S & ~E);
assign Y[1] = (AB[1] & ~S & ~E) | (CD[1] & S & ~E);
assign Y[2] = (AB[2] & ~S & ~E) | (CD[2] & S & ~E);
assign Y[3] = (AB[3] & ~S & ~E) | (CD[3] & S & ~E);
endmodule

module topmodule (
    input [1:0] A,B,C,D,
    input S,E, // E = 0 驅動
    output [3:0] Y
);
wire [3:0] AB,CD;
multiplier2bit m1(.out(AB), .A(A), .B(B));
multiplier2bit m2(.out(CD), .A(C), .B(D));
multiplexer2to1 mux(.Y(Y), .AB(AB), .CD(CD), .S(S), .E(E)); //E 給 0 驅動

endmodule