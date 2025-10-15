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