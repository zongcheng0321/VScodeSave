module tb;
reg w,x,y,z;
wire outB;
wire outG,outD;
ex1_1022 ex(.outB(outB), .outG(outG), .outD(outD), .w(w), .x(x), .y(y), .z(z));
initial begin
    w = 0; x = 0; y = 0; z = 0;
    #10;
    w = 0; x = 1; y = 0; z = 1;
    #10;
    w = 1; x = 0; y = 1; z = 0;
    #10;
    w = 1; x = 1; y = 1; z = 1;
    #10;
    w = 1; x = 0; y = 1; z = 1;
    #10;
    w = 1; x = 1; y = 0; z = 1;
    #10;
end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave ex1.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule