module BCD2 ( 
    input A,B,C,D, //A MSB
    output a,b,c,d,e,f,g,dp
);

//共陽

assign dp = 1'b1;
assign a = ~((~A | B | ~C | ~D ) & (~A | ~B | C | ~D) & (A | ~B | C | D) & (A | B | C | ~D));
assign b = ~((~A | ~C | ~D) & (~A | ~B | D) & (~B | ~C | D)&(A | ~B | C | ~D));
assign c = ~((~A | ~B | ~C ) & (~A | ~B | D)&( A | B | ~C | D));
assign d = ~(( ~ B | ~C | ~D ) &(~A |  B | ~C | D ) &(A | ~B | C | D ) &(A | B | C | ~D ));
assign e = ~(( A | ~D ) &(A | ~B | C ) &( B | C | ~D ));
assign f = ~((A | ~C | ~D ) &(A | B | ~C ) &(A | B | ~D ) &(~A | ~B | C | ~D ));
assign g = ~((A | B | C) &(~A | ~B | C | D ) &(A | ~B | ~C | ~D ));

// 共陰
/*
assign dp = 1'b0;
assign a = (~A | B | ~C | ~D ) & (~A | ~B | C | ~D) & (A | ~B | C | D) & (A | B | C | ~D);
assign b = (~A | ~C | ~D) & (~A | ~B | D) & (~B | ~C | D)&(A | ~B | C | ~D);
assign c = (~A | ~B | ~C ) & (~A | ~B | D)&( A | B | ~C | D);
assign d = ( ~ B | ~C | ~D ) &(~A |  B | ~C | D ) &(A | ~B | C | D ) &(A | B | C | ~D ) ;
assign e = ( A | ~D ) &(A | ~B | C ) &( B | C | ~D ) ;
assign f = (A | ~C | ~D ) &(A | B | ~C ) &(A | B | ~D ) &(~A | ~B | C | ~D ) ;
assign g = (A | B | C) &(~A | ~B | C | D ) &(A | ~B | ~C | ~D ) ;
*/
endmodule