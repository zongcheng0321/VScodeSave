module circuit (
    input x,y,w,z,
    output f
);
    wire a,b,c,d,e;
    not (a,w);
    nand a1(b,x,w);
    nand b1(c,a,y);
    nand c1(d,b,c);
    nand d1(e,w,z);
    nand e1(f,d,e);
endmodule