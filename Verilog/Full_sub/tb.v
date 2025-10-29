module full_sub_1bit_tb;
wire d,bo;
reg a,b,bi;
full_sub f( .a(a), .b(b), .bi(bi), .d(d), .bo(bo));
initial 
begin
	a = 0; b = 0; bi = 0;
	#10;
    a = 0; b = 0; bi = 1;
	#10;
    a = 0; b = 1; bi = 0;
	#10;
    a = 0; b = 1; bi = 1;
	#10;
    a = 1; b = 0; bi = 0;
	#10;
    a = 1; b = 0; bi = 1;
	#10;
    a = 1; b = 1; bi = 0;
	#10;
    a = 1; b = 1; bi = 1;
	#10;

end
endmodule