module ex1_1022 (
    input w,x,y,z,
    output reg outB,
    output outG,outD
);
wire a,b,c,d;//gate level
//behavior
always @(w,x,y,z) begin
    if(((x == 1 && y == 1 ) || (z == 1 && w == 1)) && (y == 1 && w == 1))
        outB = 1;
    else 
        outB = 0;
end
//dataflow
assign outD = ((x & y) | (z & w)) & (y & w );
//gate level
and and1(a,x,y);
and and2(b,z,w);
and and3(c,y,w);
or or1(d,a,b);
and and4(outG,c,d);
endmodule