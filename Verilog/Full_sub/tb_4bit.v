module full_sub_4bit_tb; 
wire [3:0]d;
wire bo;
reg [3:0] a,b;
reg bi;
full_sub_4bit f(d,bo,a,b,bi);
initial 
begin
	a = 4'd0; b = 4'd0; bi = 1'd0;
	#10;
    a = 4'd10; b = 4'd4; bi = 1'd1;
	#10;
    a = 4'd6; b = 4'd8; bi = 1'd0;
	#10;
    a = 4'd2; b = 4'd1; bi = 1'd1;
	#10;
    a = 4'd15; b = 4'd7; bi = 1'd0;
	#10;

end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave full_sub.v tb_4bit.v
    $dumpvars(0, full_sub_4bit_tb); // vvp wave
end
endmodule