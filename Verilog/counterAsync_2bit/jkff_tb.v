module jkff_tb;
    wire q ,qbar;
    reg j,k,clk,clrn;
     jkff jk(.q(q), .qbar(qbar), .j(j), .k(k), .clk(clk), .clrn(clrn));
    initial begin
        clk  = 0;
        j    = 0;
        k    = 0;
        clrn = 0;   
        #20 clrn = 1; 

        #10 j = 1; k = 0;  
        #40 j = 0; k = 1;
        #40 j = 1; k = 1;
        #100 $finish;
    end
    always #5 clk = ~clk; 
    initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, jkff_tb);
    end
endmodule