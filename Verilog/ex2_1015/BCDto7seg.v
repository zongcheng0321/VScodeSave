module BCDto7seg (
    input A,B,C,D, //A MSB
    output a,b,c,d,e,f,g
);
assign a = (B & ~C & ~D) | (~A & ~B & ~C & D);
assign b = (B & ~C & D) | (B & C & ~D);
assign c = ~B & C & ~D;
assign d = (B & ~C & ~D) | (B & C & D) | (~A & ~B & ~C & D);
assign e = D | (B & ~C);
assign f = (C & D) | (~B & C) | (~A & ~B & D);
assign g = (~A & ~B & ~C) | (B & C & D);

endmodule