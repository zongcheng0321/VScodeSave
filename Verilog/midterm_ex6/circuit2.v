module circuit2(
    input x,y,w,z,
    output f
);
assign f= ~( (~( (~(x & w)) & (~(~w & y)))) & (~(w & z)));
endmodule