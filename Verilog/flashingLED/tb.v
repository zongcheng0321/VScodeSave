`timescale 1ns/10ps
module tb;
reg  clk, rst_n, btn_in; // button in
wire btn_out;       // button out

debounce_counter counter (.clk(clk), .rst_n(rst_n), .btn_in(btn_in), .btn_out(btn_out));

always #10 clk = ~clk;

initial begin
    rst_n = 0; clk = 0;btn_in = 1;
    #20 rst_n = 1;

    #21_000_000 btn_in = 0;
    #5_000_000 btn_in = 1;
    #6_000_000 btn_in = 0;
    #3_000_000 btn_in = 1;
    #3_000_000 btn_in = 0;
    //#20 btn_in = 1;
    //#10 btn_in = 0;
   // #50 btn_in = 1;
    #30_000_000;
    $finish;
end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave debounce_counter.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule