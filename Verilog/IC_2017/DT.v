// 限定本題目標為一張二值化圖像，其大小固定為128x128 pixels，若像素值為1表示為物件，
// 若像素值為0表示為背景，本題測試樣本給定物件區域不會延伸到二值化圖像最外圍一圈的像素。

module DT(
	input 			clk, 
	input			reset, // 低位準”非”同步(active low asynchronous)之系統重置信號。 
	output	reg		done ,
	output	reg		sti_rd ,
	// sti_ROM記憶體大小為16bits資料寬度及1024個位址。每個位址的16bits資料寬度剛好可存放16個pixels的二值圖像資料
	// 代表輸入資料
	output	reg 	[9:0]	sti_addr ,
	input		[15:0]	sti_di, 
	output	reg		res_wr ,
	output	reg		res_rd ,
	output	reg	[13:0]	res_addr , // 二值化圖像大小固定為128x128 pixels，每個pixel為1 bit資料，因此Host端的二值化圖像共有16384個pixel
	output	reg 	[7:0]	res_do, // res_RAM記憶體寫入資料匯流排。
	input		[7:0]	res_di // res_RAM記憶體讀取資料匯流排。
	);

//-------------------------------
//FSM
localparam INPUT_stiROM = 3'd0,
		   INPUT_resRAM = 3'd1, //     forward pass : 依 cnt 填入 P1 to P4，當 old_Pxy = 0 時，去填 P1 ~ P4，old_Pxy != 0 時，只填 P3 且其他 P 移動位置
		   UPDATE_STI_INDEX = 3'd2, // forward pass : 填入 Pxy 且更新 STI_INDEX 及 sti_rom_addr

		   ENTER_PXY_BACKWARD = 3'd3,
		   OUTPUT = 3'd7;
reg [2:0] state;
//-------------------------------
// forward and backward pass Pxy, Pw, Pnw, Pn, Pne, Pe, Pse, Ps, Psw
reg is_forwardPass; // 預設為 1
// P1 為 Pnw or Pse、 P2 為 Pn or Ps、 P3 為 Pne or Psw、 P4 為 Pe or Pw
reg [7:0] Pxy, old_Pxy; // Pxy 為輸入值, old_Pxy 為上次做的 Pxy
reg [7:0] P1, P2, P3, P4;
wire [7:0] P; // P 為輸出值

reg [2:0] cnt; // P1 ~ P4 共需 4 次 clk，但 P_addr 進去下一個 clk 才能抓值，所以我需要 5 clk，其中第一個 clk(cnt == 0) 等待 1 clk

// comparison
wire [7:0] is_smaller_P1, is_smaller_P3, P_min;
assign is_smaller_P1 = (P1 < P2)? P1: P2;
assign is_smaller_P3 = (P3 < P4)? P3: P4;
assign P_min = (is_smaller_P1 < is_smaller_P3)? is_smaller_P1: is_smaller_P3;

// OUTPUT
wire [7:0] P_forward, P_backward;
assign P_forward = P_min + 1'd1;
assign P_backward = (Pxy < P_forward)? Pxy: P_forward;

// Pxy 等於 0 代表不用去要資料，去 OUTPUT 更新 x, y 後直接回到 UPDATE_STI_INDEX 去更新新的 sti_index、Pxy
assign P = (Pxy == 0)? 1'd0: (is_forwardPass)? P_forward: P_backward; 

//-------------------------------
// input
reg is_first_data;
reg [3:0] sti_index; // 0 ~ 15, forward 時要從 15 ~ 0, backward 要從 0 ~ 15, 由於 x,y = (1,1) 所以要從 14 or 1 開始
reg [9:0] sti_ROM_addr; // 每做 16 個就 + 1 -> 當 sti_index = 15 時
reg [6:0] x, y; // 0 ~ 127

wire [6:0] truth_x, truth_y; // 因為我們的 x y 都是從 (1,1) ~ (126,126)，但 backward pass 要從 (126,126) ~ (1,1)，所以要用 127 去減(最後一個點為 127,127)
assign truth_x = (is_forwardPass)? x: 7'd127 - x;
assign truth_y = (is_forwardPass)? y: 7'd127 - y;

// 去 RAM 的位置要
wire [13:0] P_addr; // P1_addr, P2_addr, P3_addr, P4_addr;
wire [6:0] P_x_wire, P_y_wire; // 0 ~ 127

// 用多工器選擇偏移量
reg [6:0] offset_x;
reg [6:0] offset_y;

// cnt 等於 0 時就開始給 addr
always @(*) begin
    case (cnt)
		// Pnw: [x-1, y-1], Pse: [x+1, y+1] | Pw:  [x-1, y], Pe: [x+1, y]
        0, 3: begin
			if (is_forwardPass)
				offset_x = -7'd1; // x-1
			else
				offset_x =  7'd1; // x+1
		end
		// Pne: [x+1, y-1], Pse: [x-1, y+1]
        2: begin 
			if (is_forwardPass)
				offset_x =  7'd1; // x+1
			else
				offset_x = -7'd1; // x-1
			
		end
		// Pn:  [x, y-1], Ps: [x, y+1]
        default: offset_x =  7'd0; // x (cnt=1 或 default), forward 跟 backward 一樣
    endcase
end

always @(*) begin
    case (cnt)
		// Pnw: [x-1, y-1], Pse: [x+1, y+1] | Pn:  [x, y-1], Ps: [x, y+1] | Pne: [x+1, y-1], Pse: [x-1, y+1]
        0, 1, 2: begin
			if (is_forwardPass)
				offset_y = -7'd1; // y-1
			else
				offset_y =  7'd1; // y+1
		end 
		// Pw:  [x-1, y], Pe: [x+1, y]
        default: offset_y =  7'd0; // y (cnt=3 或 default), forward 跟 backward 一樣
    endcase
end

assign P_x_wire = truth_x + offset_x;
assign P_y_wire = truth_y + offset_y;

// x, y 從 1 開始所以不會減成負數
// assign P_addr = {7'd0, P_y_wire} + {7'd0, P_x_wire}; // 可以直接拼接，就不用加法器了
assign P_addr = {P_y_wire, P_x_wire};

// forward pass
// P1 : Pnw = (x-1) + [(y-1) << 7]
// P2 : Pn = x + [(y-1) << 7]
// P3 : Pne = (x+1) + [(y-1) << 7]
// P4 : Pw = (x-1) + [y << 7]

// backward pass
// P1 : Pse = (x+1) + [(y+1) << 7]
// P2 : Ps = x + [(y+1) << 7]
// P3 : Pse = (x-1) + [(y+1) << 7]
// P4 : Pe = (x+1) + [y << 7]

// old_Pxy == 0 時
// [1  2   3]	 [2          old_3    new_3]
// [4  Pxy  ] -> [old_Pxy    Pxy           ]
// [        ]    [                         ]
//-------------------------------
always @(posedge clk or negedge reset) begin
	if (!reset) begin
		done <= 0;
		sti_rd <= 0;
		sti_addr <= 0;
		res_wr <= 0;
		res_rd <= 0;
		res_addr <= 0;
		res_do <= 0;
		state <= INPUT_stiROM;
		// 重製訊號
		is_first_data <= 1'd1;
		is_forwardPass <= 1'd1; // 預設為 forward pass
		Pxy <= 0; old_Pxy <= 0; // 舊值會在 OUTPUT 產出
		P1 <= 0;
		P2 <= 0;
		P3 <= 0;
		P4 <= 0;
		sti_ROM_addr <= 4'd8; // 預設從第二排開始
		sti_index <= 4'd14;   // forward pass 預設要從第 14 個位置(最左邊 MSB 的右邊一格 開始填入 Pxy)
		x <= 1'd1; y <= 1'd1; // 預設從 (1,1) 開始
		cnt <= 0;
	end else begin
		case (state)
			INPUT_stiROM: begin
				res_wr <= 0;
				sti_rd <= 1'd1;
				sti_addr <= sti_ROM_addr; // 負緣才有 sti_di，所以下個正緣可輸出
				if (is_first_data) begin
					state <= UPDATE_STI_INDEX; // 第一筆資料還沒要的時候下一個狀態會去 UPDATE_STI_INDEX 更新 Pxy
					is_first_data <= 0;
				end else begin // 當 sti_index == 15 時跳轉到這裡要一筆新資料
					state <= INPUT_resRAM; // sti_index 現在為 0，且在 UPDATE_STI_INDEX 狀態已經更新 Pxy = sti_di[15]，已經產出 Pxy 就去要其他 P 值
				end
			end 

			// forward pass : 填入 Pxy 且更新 STI_INDEX 及 sti_rom_addr
			UPDATE_STI_INDEX: begin 
				res_wr <= 0;
				Pxy <= {7'd0, sti_di[sti_index]};
				sti_index <= sti_index - 1'd1; // 此變數 0 ~ 15，當到達 15 時 + 1 會重製為 0
											   // 此變數 15 ~ 0，當到達 0 時 - 1 會重製為 15
				//if (sti_index == 4'd15) begin  // 到達 15 時，代表我要去 sti_rom 要新的 16 bits 資料了(backward)
				if (sti_index == 0) begin // 到達 0 時，代表我要去 sti_rom 要新的 16 bits 資料了(forward pass)
					sti_ROM_addr <= sti_ROM_addr + 1'd1;
					state <= INPUT_stiROM;
				end else begin
					state <= INPUT_resRAM;
				end

			end

			// forward pass : 依 cnt 填入 P1 to P4，當 old_Pxy = 0 時，去填 P1 ~ P4，old_Pxy != 0 時，只填 P3 且其他 P 移動位置
			INPUT_resRAM: begin
				if (is_forwardPass && Pxy == 0) begin // 一定要加上 is_forwardPass && 不然在 backward pass 這邊的 Pxy 還沒進來
					state <= OUTPUT; // Pxy 等於 0 代表不用去要資料，去 OUTPUT 更新 x, y 後直接回到 UPDATE_STI_INDEX 去更新新的 sti_index、Pxy
				end else begin
					res_rd <= 1'd1;
					res_addr <= P_addr;
					cnt <= cnt + 1'd1;
					if (old_Pxy == 0) begin // 當 old_Pxy 為 0 時要去要 P1 ~ P4
						case (cnt) // 當 cnt == 0 就等待 1 clk 先填入第一個 addr，當不為 0 時就抓資料(forward)
 							0: begin
								if (!is_forwardPass) begin
												     // 當 backward 時，我們需要偷一個 clk 來讓 Pxy 輸入
									Pxy <= res_di;	 // 當 forward 時 就等待 1 clk
									if (res_di == 0)     // 因為這邊 res_di 才是正確的 Pxy，我們一樣要像 forward pass 一樣有提早結束不需要資料的功能
										state <= OUTPUT;
								end
							end
							1: P1 <= res_di;
							2: P2 <= res_di;
							3: P3 <= res_di;
							4: begin
								P4 <= res_di;
								res_rd <= 0;
								state <= OUTPUT;
							end
							default:;
						endcase
					end else begin // P3 為 cnt = 3 時填入
						if (cnt == 3'd2) begin // 當 cnt == 2 就等待 1 clk 先填入第一個 addr，當不為 0 時就抓資料 (forward)
							if (!is_forwardPass) begin
												 // 當 backward 時，我們需要偷一個 clk 來讓 Pxy 輸入
								Pxy <= res_di;	 // 當 forward 時 就等待 1 clk
								if (res_di == 0)     // 因為這邊 res_di 才是正確的 Pxy，我們一樣要像 forward pass 一樣有提早結束不需要資料的功能
									state <= OUTPUT;
							end
						end else begin // 當 cnt = 3，此時 P3 res_di 才正確
							res_rd <= 0;
							// 只填 P3 且其他 P 移動位置
							P1 <= P2;
							P2 <= P3;
							P3 <= res_di;
							P4 <= old_Pxy; // 舊值會在 OUTPUT 產出
							state <= OUTPUT;
						end
					end
				end
			end

			// 更新 x,y 且輸出資料到 RAM
			OUTPUT: begin
				// 輸出資料
				res_do <= P;
				old_Pxy <= P;
				res_wr <= 1'd1;
				res_rd <= 0;
				res_addr <= {truth_y, truth_x}; // 會根據現在是 forward 還是 backward 選擇輸出位置

				if (P == 0) begin // cnt 重製條件: 當之前的 Pxy 等於 0 時，cnt 一開始就要是 0，反之則是 2，當 old_Pxy 不是 0 時才可以只要一個資料
					cnt <= 0;
				end else begin
					cnt <= 3'd2;
				end
				if (x == 7'd126 && y == 7'd126) begin
					if (is_forwardPass) begin
						is_forwardPass <= 0;
						Pxy <= 0; old_Pxy <= 0;
						P1 <= 0;
						P2 <= 0;
						P3 <= 0;
						P4 <= 0;
						x <= 1'd1; y <= 1'd1; // 預設從 (1,1) 開始
						cnt <= 0;
						state <= ENTER_PXY_BACKWARD;
					end else begin
						done <= 1'd1;
					end
				end else begin
					x <= x + 1'd1;
					if (is_forwardPass) begin
						state <= UPDATE_STI_INDEX;
					end else begin
						state <= ENTER_PXY_BACKWARD;
					end

					if (x == 7'd126) begin // 換行
						y <= y + 1'd1;
						x <= 1'd1; // x 重製為 1

						sti_index <= 4'd14;   // forward pass 預設要從第 14 個位置(最左邊 MSB 的右邊一格 開始填入 Pxy)

						// x 為 126 時強制更新換成下一排 sti_rom 的位置
						sti_ROM_addr <= sti_ROM_addr + 1'd1;
						is_first_data <= 1'd1;
						// 換行的話一定要執行要 4 筆資料，同時把 old_Pxy reset
						cnt <= 0;
						old_Pxy <= 0;

						if (is_forwardPass) begin
							state <= INPUT_stiROM;
						end else begin
							state <= ENTER_PXY_BACKWARD;
						end
					end
				end
			end

			// backward pass : 填入 Pxy
			ENTER_PXY_BACKWARD: begin
				res_wr <= 0;
				res_rd <= 1'd1;
				res_addr <= {truth_y, truth_x}; // 會根據現在是 forward 還是 backward 選擇輸入位置，此時 x,y 已經在OUTPUT更新成新值了
				// 但 Pxy 需要一個 clk 才能抓到正確的 res_di
				state <= INPUT_resRAM;
			end
			default: ;
		endcase
	end
end

endmodule
