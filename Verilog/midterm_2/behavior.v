module circuit (
    output reg f,
    input w,x,y,z
);
reg b, c, d, e;
always @(*) begin
    b = (x == 0 || w == 0)?1:0;
    c = (w == 1 || y == 0)?1:0;
    d = (b == 0 || c == 0)?1:0;
    e = (w == 0 || z == 0)?1:0;
    f = (d == 0 || e == 0)?1:0;
end

endmodule