// 現在要執行哪一行指令
module pc (pclk, rst, adir, ldpc, adpc);

input	pclk, rst, ldpc;
input	[4:0] adir; //Address from Instruction Register
output	[4:0] adpc; //Address from Program Counter

reg		[4:0] temp1 = 0;

always@(posedge pclk or negedge rst) begin //pclk 由 decoder 發出的訊號，類似 enable
	if(!rst)
		temp1 <= 0;
	else if(ldpc == 1)
		temp1 <= adir; //載入要執行的指令位置
	else
		temp1 <= temp1 + 1; //下一行
end

assign adpc = temp1; // output Address from Program Counter

endmodule