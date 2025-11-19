module tb;
reg x, clk, clr;
wire z;
FSM f(x,clk,clr,z);
initial begin
    clr = 1; clk = 0;
    #10 clr = 0 ;x = 0;
    #10 x = 0;
    #10 x = 1;
    #10 x = 1;
    #10 x = 0;
    #10 x = 0;
    #10 x = 1;
    #10 x = 1;
    #10 x = 0;
    #10 x = 1;
    #10 x = 1;
    #10 x = 0;
    #10 x = 0;
    #10 x = 1;
    #10 x = 1;
    #10 x = 0;
    #10;
    $finish;
end
always #5 clk = ~clk;

initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave FSM.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule