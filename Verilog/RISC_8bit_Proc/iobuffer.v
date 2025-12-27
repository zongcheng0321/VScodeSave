/*module iobuffer (clk2, mrd, fch, alu_out, mdat);

input	clk2, mrd, fch;
input	[7:0] alu_out;
output	[7:0] mdat;
wire	en, en1;

assign	en = mrd || fch || clk2;
assign	en1 = ~en;
assign	mdat = (en1) ? alu_out : 'hzz;

endmodule*/
//不須用到此程式，以此(assign mdat = (mwr) ? acc_out : 8'bz;)代替