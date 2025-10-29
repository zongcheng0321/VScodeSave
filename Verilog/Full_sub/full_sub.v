module full_sub (d,bo,a,b,bi);
    output d,bo;
    input a,b,bi;
    wire an,x1,anb,x1n,bix1n;
    not not1(an,a);
    xor xor1(x1,a,b);
    and and1(anb,b,an);
    xor xor2(d,x1,bi);
    not not2(x1n,x1);
    and and2(bix1n,bi,x1n);
    or or1(bo,anb,bix1n);
endmodule

module full_sub_4bit (d,bo,a,b,bi);
    output [3:0]d;
    output bo;
    input [3:0] a,b;
    input bi;
    wire b1,b2,b3;

    full_sub s0( d[0],b1,a[0],b[0],bi);
    full_sub s1( d[1],b2,a[1],b[1],b1);
    full_sub s2( d[2],b3,a[2],b[2],b2);
    full_sub s3( d[3],bo,a[3],b[3],b3);
endmodule
