// 從 Memory 抓取的指令儲存到 IR (Instruction Register)
// 從 Memory 接收 8-bit 的指令資料拆成兩部分： Opcode & Address
// Opcode 決定要做什麼； Address 決定操作對象是誰
module ir (clk, rst, ldir, mdat, adir, opcd);

input	clk, ldir, rst; // load Instruction Register 類似 enable
input	[7:0] mdat; // memory data
output	reg[4:0] adir; // 5-bit 的 Address from Instruction Register
output	reg[2:0] opcd; // 3-bit opcode

always@(posedge clk or negedge rst) begin
	if(!rst) begin
		opcd <= 0;
		adir <= 0;
	end else 
		if (ldir == 1) begin // MSB [位址][OPCODE] LSB
			adir <= mdat [7:3]; 
			opcd <= mdat [2:0];
		end
end

endmodule