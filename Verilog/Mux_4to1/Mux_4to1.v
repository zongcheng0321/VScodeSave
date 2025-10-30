module Mux_4to1(F,s3,s2,s1,s0,A,B); 
output  F;
input A,B; // AB為選擇線(A -> MSB)
input s3,s2,s1,s0; // s3~s0為輸入 
wire an,bn,anbn,anB,Abn,AB;
not a1(an,A);
not b1(bn,B);
and and0(anbn,an,bn,s0);
and and1(anB,an,B,s1);
and and2(Abn,A,bn,s2);
and and3(AB,A,B,s3);
or or4(F,anbn,anB,Abn,AB);
endmodule