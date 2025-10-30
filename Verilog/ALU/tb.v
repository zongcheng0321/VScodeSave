module tb;
wire [5:0] out;
reg [2:0] select;
reg [3:0] a, b, c;
F_8_ALU alu (.out(out), .a(a), .b(b), .c(c), .select(select));
initial begin
    a = 13; b =12; c =14; select = 7;
    for(integer i = 0;i <8;i = i + 1)
    begin
        select = select +1;
        #10;
    end
    $finish;
end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave ALU.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule