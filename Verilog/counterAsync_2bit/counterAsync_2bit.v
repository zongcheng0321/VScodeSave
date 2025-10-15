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