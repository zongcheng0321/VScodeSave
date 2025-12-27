//原本 CPU  要用單一時脈 (CLK) 配合 FSM 來切換狀態，不過這邊把 CLK 除頻變成了三個 (CLK1、CLK2、FCH) ，就會變成很像用狀態機 000, 001,...來切換狀態
//CLK1 = CLK, CLK2 = CLK/2, FCH = CLK/4 = CLK1/2 
//SEQ = 000 -> 100 -> [011 -> 111 -> 001 -> 101](提取週期) -> [010 -> 110 -> 000 -> 100](執行週期) -> [011...](提取週期)
//我不知道為什麼要使用兩個rst(rstreq, rst)?可能是要解決亞穩態，但原程式無法解決這個問題，所以我把所有 rstreq 都改成 rst
module clkgen (clk, rst, clk1, clk2, fch);//把 rstreq 刪了，只用 rst

input	clk, rst;
output	clk1, clk2, fch;
reg		clk2, fch; // 把 CLK 變成 CLK1、CLK2、FCH

assign	clk1 = clk; //就只是把 clk 改個名叫 clk1

always@(negedge clk or negedge rst) begin //revised
	if(!rst) begin
		clk2 <= 0; 
	end 
	else begin
		clk2 <= ~clk2;
	end
end

always@(posedge clk2 or negedge rst) begin //這邊 clk2 修改成正緣觸發
	if(!rst)
		fch <= 0; 
	else begin
		fch <= ~fch;
	end	
end

endmodule 