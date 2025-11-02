module add3 (
    output [3:0] s,
    input [3:0] a
);
wire a0,a1,a2,a3,b,c,d,e,f,g,h,i,j,k,l,m,n,o;

not a00(a0,a[0]);
not b00(a1,a[1]);
not c00(a2,a[2]);
not d00(a3,a[3]);

and a22(b,a[3],a0);
and b2(c,a3,a2);
and c2(d,c,a[0]);
and d2(e,a[2],a[1]);
and e2(f,e,a0);
or f2(s[0],b,d,f);

and a33(g,a[1],a[0]);
and b3(h,a2,a[1]);
and c3(i,a[3],a0);
or f3(s[1],g,h,i);

and a4(j,a[2],a1);
and b4(k,j,a0);
and c4(l,a[3],a[0]);//A3A0
or f4(s[2],k,l);

and a5(m,a[2],a[0]);
or b5(n,m,a[3]);
and c5(o,a[2],a[1]);
or f5(s[3],m,n,o);

endmodule

module Converter_8bit (
    output [9:0] P,
    input [7:0] B//binary
);
wire [3:0] s1, s2, s3, s4, s6, s7;
add3 C1(.s(s1), .a({1'b0, B[7], B[6], B[5]}));
add3 C2(.s(s2), .a({s1[2], s1[1], s1[0], B[4]}));
add3 C3(.s(s3), .a({s2[2], s2[1], s2[0], B[3]}));
add3 C4(.s(s4), .a({s3[2], s3[1], s3[0], B[2]}));
add3 C5(.s(P[4:1]), .a({s4[2], s4[1], s4[0], B[1]}));
add3 C6(.s(s6), .a({1'b0, s1[3], s2[3], s3[3]}));
or a6(P[9],s6[3],0);
add3 C7(.s(P[8:5]), .a({s6[2], s6[1], s6[0], s4[3]}));
or a7(P[0],B[0],0);
endmodule 
