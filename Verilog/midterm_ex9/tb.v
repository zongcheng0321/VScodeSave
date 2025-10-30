module tb;
reg [3:0] a, b;
wire [3:0] out;
ex9 ex(.out(out), .a(a), .b(b));
initial begin
    a = 15; b = 10;
    #10;
    a = 8; b = 8;
    #10;
    a = 0; b = 2;
    #10;
    $finish;
end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave ex9.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule