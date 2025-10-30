module BCD1(a,b,c,d,e,f,g,dp,A,B,C,D);//A MSB
output a,b,c,d,e,f,g,dp;
input A,B,C,D;
wire an,bn,cn,dn,bcndn,anbncnd,bcnd,bcdn,bncdn,bcd,bcn,cd,bnc,anbnd,anbncn,ao,bo,co,do,eo,fo,go;//11組
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
//共陽

or dp1(dp,1,0);
or a1(a,bcndn,anbncnd);
or b1(b,bcnd,bcdn);
or c1(c,bncdn);
or d1(d,bcndn,bcd,anbncnd);
or e1(e,D,bcn);
or f1(f,cd,bnc,anbnd);
or g1(g,anbncn,bcd);


//共陰
/*
or dp2(dp,0,0);
or a2(ao,bcndn,anbncnd);
or b2(bo,bcnd,bcdn);
or c2(co,bncdn);
or d2(do,bcndn,bcd,anbncnd);
or e2(eo,D,bcn);
or f2(fo,cd,bnc,anbnd);
or g2(go,anbncn,bcd);
not a3(a,ao);
not b3(b,bo);
not c3(c,co);
not d3(d,do);
not e3(e,eo);
not f3(f,fo);
not g3(g,go);
*/
endmodule