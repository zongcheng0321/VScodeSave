module project1_tb;

reg [3:0] s3,s2,s1,s0;
reg clk, clrn;
wire a,b,c,d,e,f,g, A1,A2,A3,A4;
project1 p(s3,s2,s1,s0, clk, clrn, a,b,c,d,e,f,g, A1,A2,A3,A4);

initial begin 
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    clrn = 0;
    #10 clrn = 1;
    s3 = 4'b0000;
    s2 = 4'b0001;
    s1 = 4'b0010;
    s0 = 4'b0011;
    #50
    s3 = 4'b1001;
    s2 = 4'b1000;
    s1 = 4'b0111;
    s0 = 4'b0110;

    #100 $finish;
end

initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave project1.v project1_tb.v
    $dumpvars(0, project1_tb); // vvp wave
end
endmodule