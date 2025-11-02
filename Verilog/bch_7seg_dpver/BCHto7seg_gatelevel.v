module BCD1(a,b,c,d,e,f,g,dp,A,B,C,D);//A MSB
output a,b,c,d,e,f,g,dp;
input A,B,C,D;
wire an,bn,cn,dn,adn,bc,anc,bndn,anbd,anbn,acnd,ancd,ancndn,anb,cnd,bnd,bncn,abnd,abdn,ancdn,bncd,bncndn,ac,ab,abn,ad,cdn,bnc,bcnd,anbdn,bdn,cndn,anbcn,abncn,ao,bo,co,do,eo,fo,go;//11組
//共陰
not n1(an,A);
not n2(bn,B);
not n3(cn,C);
not n4(dn,D);

and (adn,A,dn);//a
and (bc,B,C);
and (anc,an,C);
and (bndn,bn,dn);
and (anbd,an,B,D);
and (abncn,A,bn,cn);

and(bndn,bn,dn);//b
and(anbn,an,bn);
and(acnd,A,cn,D);
and(ancd,an,C,D);
and(ancndn,an,cn,dn);

and(abn,A,bn);//c
and(anb,an,B);
and(cnd,cn,D);
and(bnd,bn,D);
and(bncn,bn,cn);

and(abnd,A,bn,D);//d
and(abdn,A,B,dn);
and(bcnd,B,cn,D);
and(ancdn,an,C,dn);
and(bncd,bn,C,D);
and(bncndn,bn,cn,dn);

and(ac,A,C);//e
and(ab,A,B);
and(cdn,C,dn);
and(bndn,bn,dn);

and(abn,A,bn);//f
and(ac,A,C);
and(bdn,B,dn);
and(cndn,cn,dn);
and(anbcn,an,B,cn);

and(abn,A,bn);//g
and(ad,A,D);
and(cdn,C,dn);
and(bnc,bn,C);
and(bcnd,B,cn,D);
and(anbdn,an,B,dn);

or dp1(dp,1,0);
or a1(a,adn,bc,anc,bndn,anbd,abncn);//  adn+bc+anc+bndn+anbd+abncn
or b1(b,bndn,anbn,acnd,ancd,ancndn);//bndn+anbn+acnd+ancd+ancndn
or c1(c,abn,anb,cnd,bnd,bncn);// abn+anb+cnd+bnd+bncn
or d1(d,abnd,abdn,bcnd,ancdn,bncd,bncndn); //abnd+abdn+bcnd+ancdn+bncd+bncndn
or e1(e,ac,ab,cdn,bndn);// ac+ab+cdn+bndn
or f1(f,abn,ac,bdn,cndn,anbcn);//abn+ac+bdn+cndn+anbcn
or g1(g,abn,ad,cdn,bnc,bcnd,anbdn);// abn+ad+cdn+bnc+bcnd+anbdn

//共陽
not(ao,a);
not(bo,b);
not(co,c);
not(do,d);
not(eo,e);
not(fo,f);
not(go,g);
not(ho,h);

endmodule