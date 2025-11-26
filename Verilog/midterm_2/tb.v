module tb;
wire f;
reg w,x,y,z;
circuit c(f,w,x,y,z);
initial begin
    w = 0;x = 0;y = 0;z = 0;
    for(integer i = 0; i<16; i++)
    begin
        #10;
        {w,x,y,z} ++;
    end
    $finish;
end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave behavior.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule