//接收來自 MUX 的地址 (addr_out)
//接收來自 Decoder 的控制訊號 (mrd, mwr - 讀與寫)
//把資料送給 IR (抓指令時) 和 ALU (運算時) (use mdat)
//把 ACC 的資料存起來 (執行 STORE 指令時)
module memory (clk, rst, mrd, mwr, ewr, mad, ead, edat, mdat);

input	clk, rst, mrd, mwr, ewr; //Memory read, Memory write, External write
input	[4:0] mad, ead; //Memory Address (for CPU), External Address
input	[7:0] edat;     //edat: external data
inout	[7:0] mdat;	    //mdat: CPU-memory data

reg		[7:0] memr [31:0]; //32 Bytes RAM
reg		[7:0] temp;

//寫入模式
always@(posedge clk) begin 
	if (!rst) begin // 當 rst = 0 (燒入模式，CPU 不工作時) 且 ewr = 1 (外部寫入致能) ，把外部資料跟地址寫入 32 Bytes RAM
		if(ewr)
			memr [ead] <= edat;
	end 
	else begin // CPU 工作時，由記憶體讀取寫入致能驅動
		if(mwr) 
			memr [mad] <= mdat;
	end
end

//讀取模式
assign mdat = (rst && mrd) ? memr[mad] : 8'bz; //當 (CPU 在跑) 且 (mrd 為 1) 時，記憶體輸出資料
											   //其他時候 (包含寫入時)，mdat 高阻抗，允許外部/CPU 灌資料進來
endmodule