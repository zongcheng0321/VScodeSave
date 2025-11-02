module tb;
wire [9:0] P;
reg [7:0] B;//binary

Converter_8bit con(.P(P), .B(B));
initial begin
    B = 8'h9A;
    repeat(12) begin
        #10 B = B +1;
    end
    $finish;
end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave gatelevel.v tb.v
    $dumpvars(0, tb); // vvp wave
end

endmodule