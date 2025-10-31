module func(
 input w,x,y,z,
 output f
);
wire wn,xn,yn,zn,a,b,c;
not w0(wn,w);
not x0(xn,x);
not y0(yn,y);
not z0(zn,z);
and a0(a,wn,yn,zn);
and b0(b,x,z);
and c0(c,w,xn,yn);
or d0(f,a,b,c);
endmodule