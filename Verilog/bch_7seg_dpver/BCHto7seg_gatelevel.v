module BCD1(a,b,c,d,e,f,g,dp,A,B,C,D);//A MSB
output a,b,c,d,e,f,g,dp;
input A,B,C,D;
wire an,bn,cn,dn,adn,bc,anc,bndn,anbd,anbn,acnd,ancd,ancndn,anb,cnd,bnd,bncn,abnd,abdn,ancdn,bncd
    ,bncndn,ac,ab,abn,ad,cdn,bnc,bcnd,anbdn,bdn,cndn,anbcn,abncn,ao,bo,co,do,eo,fo,go;
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
or a1(ao,adn,bc,anc,bndn,anbd,abncn);//  adn+bc+anc+bndn+anbd+abncn
or b1(bo,bndn,anbn,acnd,ancd,ancndn);//bndn+anbn+acnd+ancd+ancndn
or c1(co,abn,anb,cnd,bnd,bncn);// abn+anb+cnd+bnd+bncn
or d1(do,abnd,abdn,bcnd,ancdn,bncd,bncndn); //abnd+abdn+bcnd+ancdn+bncd+bncndn
or e1(eo,ac,ab,cdn,bndn);// ac+ab+cdn+bndn
or f1(fo,abn,ac,bdn,cndn,anbcn);//abn+ac+bdn+cndn+anbcn
or g1(go,abn,ad,cdn,bnc,bcnd,anbdn);// abn+ad+cdn+bnc+bcnd+anbdn
//共陰
/*
or a2(a,ao,0);
or b2(b,bo,0);
or c2(c,co,0);
or d2(d,d0,0);
or e2(e,e0,0);
or f2(f,f0,0);
or g2(g,go,0);
or dp1(dp,0,0);
*/
//共陽
not(a,ao);
not(b,bo);
not(c,co);
not(d,do);
not(e,eo);
not(f,fo);
not(g,go);
or dp1(dp,1,0);
endmodule 