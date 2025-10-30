module Mux_4to1(F,s3,s2,s1,s0,A,B); 
output F;
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

module ex9 ( //先做比較器，再用比較器判斷誰大誰小，利用四對一多工器輸出 //此程式輸出最大值
    input [3:0] a, b,
    output [3:0] out
);
wire [3:0] xi, bn, an;
wire maxA, maxB, equivalent, and1, and2, and3, and4, and5, and6, and7, and8;
generate
    for(genvar i = 0; i < 4; i = i + 1)
    begin
        xnor (xi[i], a[i], b[i]);
        not (bn[i], b[i]);
        not (an[i], a[i]);
    end
endgenerate
//and (equivalent,xi[3],xi[2],xi[1],xi[0]);
and (and1, a[3], bn[3]);
and (and2, xi[3], a[2], bn[2]);
and (and3, xi[3], xi[2], a[2], bn[1]);
and (and4, xi[3], xi[2], xi[1], a[0], bn[0]);

and (and5, an[3], b[3]);
and (and6, xi[3], an[2], b[2]);
and (and7, xi[3], xi[2], an[2], b[1]);
and (and8, xi[3], xi[2], xi[1], an[0], b[0]);

or (maxA, and1, and2, and3, and4);
or (maxB, and5, and6, and7, and8);

Mux_4to1 mux1(.F(out[3]), .s3(bx), .s2(a[3]), .s1(b[3]), .s0(a[3]), .A(maxA), .B(maxB)); //當maxA = maxB = 0時，代表 A = B 所以第29行不寫
Mux_4to1 mux2(.F(out[2]), .s3(bx), .s2(a[2]), .s1(b[2]), .s0(a[2]), .A(maxA), .B(maxB)); //如果要輸出最小值，s2 -> b 、 s1 -> a
Mux_4to1 mux3(.F(out[1]), .s3(bx), .s2(a[1]), .s1(b[1]), .s0(a[1]), .A(maxA), .B(maxB));
Mux_4to1 mux4(.F(out[0]), .s3(bx), .s2(a[0]), .s1(b[0]), .s0(a[0]), .A(maxA), .B(maxB)); 
endmodule