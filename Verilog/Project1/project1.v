module BCD(a,b,c,d,e,f,g,A,B,C,D);//A MSB
output a,b,c,d,e,f,g;
input A,B,C,D;
wire an,bn,cn,dn,bcndn,anbncnd,bcnd,bcdn,bncdn,bcd,bcn,cd,bnc,anbnd,anbncn;//11組
not n1(an,A);
not n2(bn,B);
not n3(cn,C);
not n4(dn,D);
and BCbarDbar(bcndn,B,cn,dn);
and AbarBbarCbarD(anbncnd,an,bn,cn,D);
and BCbarD(bcnd,B,cn,D);
and BCDbar(bcdn,B,C,dn);
and BbarCDbar(bncdn,bn,C,dn);
and BCD(bcd,B,C,D);
and BCbar(bcn,B,cn);
and CD(cd,C,D);
and BbarC(bnc,bn,C);
and AbarBbarD(anbnd,an,bn,D);
and AbarBbarCbar(anbncn,an,bn,cn);

or a1(a,bcndn,anbncnd);
or b1(b,bcnd,bcdn);
or c1(c,bncdn);
or d1(d,bcndn,bcd,anbncnd);
or e1(e,D,bcn);
or f1(f,cd,bnc,anbnd);
or g1(g,anbncn,bcd);
endmodule

module jkff 
(
    output q, qbar,
    input  j, k, clk ,clrn // clrn 給 0 驅動
);                         //負緣觸發

    wire cbar;    
    wire a, b;    
    wire y, ybar; 
    wire c, d;    

    not  (cbar, clk);

    nand (a, j, clk, clrn, qbar);
    nand (b, k, clk, q);

    nand (y, a, ybar);
    nand (ybar, b, y,clrn);

    nand (c, y, cbar);
    nand (d, ybar, cbar);

    nand (q, c, qbar);
    nand (qbar, d, q,clrn);
endmodule

module counterAsync_2bit (Q1,Q0,clk,clrn);//Q1 MSB
    output Q1,Q0;
    input clk,clrn;
    jkff jk1( .q(Q0), .qbar() , .j(1'd1), .k(1'd1) , .clk(clk), .clrn(clrn)); //left one
    jkff jk2( .q(Q1), .qbar() , .j(1'd1), .k(1'd1) , .clk(Q0), .clrn(clrn)); //right one
endmodule

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

module Mux_4to1( F,s3,s2,s1,s0,A,B); 

output  F;
input A,B; // AB為選擇線(A -> MSB)
input  s3,s2,s1,s0; // s3~s0為輸入 
wire an,bn,anbn,anB,Abn,AB;
not a1(an,A);
not b1(bn,B);
and and0(anbn,an,bn,s0);
and and1(anB,an,B,s1);
and and2(Abn,A,bn,s2);
and and3(AB,A,B,s3);
or or4(F,anbn,anB,Abn,AB);
endmodule

module project1 
(
    input [3:0] s3,s2,s1,s0,
    input clk, clrn,
    output a,b,c,d,e,f,g, A1,A2,A3,A4
);
wire counterQ1, counterQ0;
wire [3:0] F;
counterAsync_2bit Counter2bit(.Q1(counterQ1), .Q0(counterQ0), .clk(clk), .clrn(clrn)); // Q1 MSB //clrn driven 0
decoder_2to4 decoder(.Q3(A4), .Q2(A3), .Q1(A2), .Q0(A1), .A(counterQ1), .B(counterQ0)); //A4 is leftmost 7-seg , counterQ1 ->MSB 為選擇線
Mux_4to1  mux1 (.F(F[3]), .s3(s3[3]), .s2(s2[3]), .s1(s1[3]), .s0(s0[3]), .A(counterQ1), .B(counterQ0));
Mux_4to1  mux2 (.F(F[2]), .s3(s3[2]), .s2(s2[2]), .s1(s1[2]), .s0(s0[2]), .A(counterQ1), .B(counterQ0));
Mux_4to1  mux3 (.F(F[1]), .s3(s3[1]), .s2(s2[1]), .s1(s1[1]), .s0(s0[1]), .A(counterQ1), .B(counterQ0));
Mux_4to1  mux4 (.F(F[0]), .s3(s3[0]), .s2(s2[0]), .s1(s1[0]), .s0(s0[0]), .A(counterQ1), .B(counterQ0));
BCD bcd (.a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g), .A(F[3]), .B(F[2]), .C(F[1]), .D(F[0])); //A MSB

endmodule