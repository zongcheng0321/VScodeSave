module converter_tb;
reg [11:0] in;
wire [15:0] bcd;
converter c(.in(in), .bcd(bcd));
initial begin
    in = 12'd0;
    repeat(4094) begin
        #10 in = in +1;
    end
    $finish;
end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave converter.v converter_tb.v
    $dumpvars(0, converter_tb); // vvp wave
end
endmodule