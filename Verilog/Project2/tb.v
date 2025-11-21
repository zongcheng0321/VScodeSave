module tb;
reg [11:0] x, y;
reg [2:0] opcode; 
reg clk, reset;  // reset -> clrn, clrn driven 0
wire a,b,c,d,e,f,g,dp, A1,A2,A3,A4;
project2 p( x, y, opcode, clk, reset, a,b,c,d,e,f,g,dp, A1,A2,A3,A4);

initial begin 
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    reset = 0;
    #10 reset = 1;
    x = 4; y =2; opcode = 7;
    for(integer i = 0;i <8;i = i + 1)
    begin
        opcode = opcode +1;
        #40;
    end
    x = 201; y =200; opcode = 7;
    for(integer i = 0;i <8;i = i + 1)
    begin
        opcode = opcode +1;
        #40;
    end
    $finish;
end

initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave project2.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule