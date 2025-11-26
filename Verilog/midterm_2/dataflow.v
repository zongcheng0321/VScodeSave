module circuit (
    output f,
    input w,x,y,z
);
wire a, b, c, d, e;
assign a = ~w;
assign b = ~(x & w);
assign c = ~(a & y);
assign d = ~(b & c);
assign e = ~(w & z);
assign f = ~(d & e);
endmodule