module tb;
reg [7:0] I;
wire [2:0] y;
encoder_8to3 enc(.y(y), .I(I));
initial begin
    I = 8'B00000001;
    #10;
    I = 8'B00000010;
    #10;
    I = 8'B00000100;
    #10;
    I = 8'B00001000;
    #10;
    I = 8'B00010000;
    #10;
    I = 8'B00100000;
    #10;
    I = 8'B01000000;
    #10;
    I = 8'B10000000;
    #10;$finish;
end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave encoder_8to3.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule