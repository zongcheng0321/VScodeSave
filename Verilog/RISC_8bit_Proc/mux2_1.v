//連接 PC、IR 和 Memory
//當 fetch 為 1 時（代表現在要去抓指令），輸出應該選 adpc
//當 fetch 為 0 時（代表現在可能在執行 Load/Store），輸出應該選 adir
module mux2_1 (adir, adpc, fch, addr_out);

input	fch; // fetch
input	[4:0] adir, adpc; //Address from Instruction Register 
						  //Address from Program Counter
output	reg[4:0] addr_out;//修改了變數名稱 admem -> addr_out (Address output)

always@(fch or adpc or adir) begin
	case (fch)
		1'b0 : addr_out = adir;//指令暫存器的指令位址
		1'b1 : addr_out = adpc;//程式計數器的下一行地址
	endcase
end

endmodule