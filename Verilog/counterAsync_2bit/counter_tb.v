module counterAsync_2bit_tb;
    wire Q1,Q0;
    reg clk,clrn;
    counterAsync_2bit counter(.Q1(Q1), .Q0(Q0) , .clk(clk) , .clrn(clrn));
    initial begin
        clk  = 0;
        clrn = 0;   // 一開始清除
        #2 clrn = 1; // 2ns後釋放清除
        #100 $finish;
    end
    always #5 clk = ~clk; 
    initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, counterAsync_2bit_tb);
    end
endmodule