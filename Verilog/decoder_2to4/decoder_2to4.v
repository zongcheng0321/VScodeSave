module decoder_2to4(Q3,Q2,Q1,Q0,A,B);
output Q3,Q2,Q1,Q0;
input B,A;
wire an,bn;
not a1(an,A);
not b1(bn,B);
and and0(Q0,an,bn);
and and1(Q1,an,B);
and and2(Q2,A,bn);
and and3(Q3,A,B);
endmodule