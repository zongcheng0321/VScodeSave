module alu (mdat, acc_out, opcd, alu_out, zr);

input	[7:0] mdat, acc_out; // memory data
input	[2:0] opcd; // 3-bit opcd 共八個指令
output	[7:0] alu_out;
output	zr; // zero flag

reg		[7:0]a;

always@(*) begin //更改為組合邏輯(blocking)
	case (opcd)
		3'b000 : a = acc_out;
		3'b001 : a = acc_out;
		3'b010 : a = (mdat + acc_out);
		3'b011 : a = (mdat & acc_out);
		3'b100 : a = (mdat ^ acc_out);
		3'b101 : a = mdat;
		3'b110 : a = acc_out;
		3'b111 : a = acc_out;
		default : a = 0;
	endcase
end

assign	alu_out = a;
assign	zr = &(~a); // revised

endmodule