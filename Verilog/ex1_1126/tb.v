module tb;
reg clk,rst;
reg [7:0] in;
wire [3:0] q;
wire [7:0] R1;
wire [7:0] R2;
wire [7:0] out;
ex1 ex(.out(out),.R1(R1),.R2(R2),.q(q),.clk(clk),.rst(rst),.in(in));
always #5 clk = ~clk;
initial begin
    clk = 1'b1; rst = 1'b1;
    #10 rst = 1'b0;//0驅動
    #10 in = 8'd11;
    #10 in = 8'd22;
    #10 in = 8'd33;
    #10 in = 8'd44;
    #10 in = 8'd55;
    #10 in = 8'd66;
    #10 in = 8'd77;
    #10 in = 8'd88;
    #10 in = 8'd99;
    #100;
    $finish;
end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave ex1.v tb.v
    $dumpvars(0, tb); // vvp wave
end

endmodule