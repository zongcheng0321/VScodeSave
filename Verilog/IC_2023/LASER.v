// ver5 改為 4 個平行判斷標的物，以及縮小坐標判斷在 step2 以後變為 [2,2] -> [13,12] 掃描
// step 1 為 [0,0] -> [15,15]
// 此外共用了一些邏輯達到 27019 的面積，讓我產生了可以回到 8 個同時處理的標的物的方法(事實上還是不行28800多面積)

// 面積 16 * 16 固定有40個標的物
// 用兩發雷射，雷射形狀為半徑4的圓形，請找出這兩個圓的圓心位置，讓這兩個圓能達到最大量的標的物覆蓋
module LASER (
input CLK, // positive edge trigger
input RST, // Synchronous reset signal (active high)。由 testbench 提供，拉高 2 cycle 後恢復為 low。 
input [3:0] X, // 標的物X座標，無號二進位整數。
input [3:0] Y, // 標的物Y座標，無號二進位整數。 
output reg [3:0] C1X, // 輸出第一發電射X座標，無號二進位整數。 圓心1
output reg [3:0] C1Y, // 輸出第一發電射Y座標，無號二進位整數。
output reg [3:0] C2X, // 輸出第二發電射X座標，無號二進位整數。 圓心2
output reg [3:0] C2Y, // 輸出第二發電射Y座標，無號二進位整數。 
output reg DONE); // 完成訊號，testbench 會在收到 DONE 訊號後抓取兩發雷射的座標，並計算覆蓋的標的物數量。 

reg [3:0] mov_cir_x;
reg [3:0] mov_cir_y;

// 標的物 x, y 共四十個標的物
reg [3:0] ob_x [39:0]; //  x1
reg [3:0] ob_y [39:0]; //  y1
// FSM state
localparam INPUT = 3'd0, // 分 40 個 cycle 輸入 40 筆座標資料，LASER 電路需要將這 40 筆座標記錄以便後續運算。 
           SET_C2_UPDATE_C1 = 3'd1, // 對應 step1、step3
           SET_C1_UPDATE_C2 = 3'd2, // 對應 step2
           OUTPUT = 3'd7; 
reg [2:0] state;

// 計數器 (6 bits due to input 40 cycles)
reg [5:0] cnt;

reg first_step; // 第一步要先掃描 256 個座標，後續步驟才能改為 [2,2] -> [13,12]
wire [3:0] coor_max_x;
wire [3:0] coor_max_y;
wire [3:0] coor_min_x;
assign coor_max_x = first_step ? 4'd15 : 4'd13;
assign coor_max_y = first_step ? 4'd15 : 4'd12;
assign coor_min_x = first_step ? 4'd0  : 4'd2; // 同時也是 min y

//--------------------------------------------------------------
// 圓內判斷
// 圓半徑固定為4，距離剛好等於4視為在圓內。若兩個圓同時覆蓋同一目標物，僅計算一個物件。

wire [3:0] cir_x, cir_y;
assign cir_x = mov_cir_x;
assign cir_y = mov_cir_y;

// 產生四個點的 Index
wire [5:0] idx0;
assign idx0 = {cnt[3:0], 2'b00}; // 相當於 cnt * 4 (左移2位元)
wire [5:0] idx1;
assign idx1 = {cnt[3:0], 2'b01}; // 相當於 cnt * 4 + 1 (左移2位元 + 1)
wire [5:0] idx2;
assign idx2 = {cnt[3:0], 2'b10}; // 相當於 cnt * 4 + 2 (左移2位元 + 2)
wire [5:0] idx3;
assign idx3 = {cnt[3:0], 2'b11}; // 相當於 cnt * 4 + 3 (左移2位元 + 3)

wire [3:0] abs_cir_minus_x0, abs_cir_minus_y0; // 取絕對值的方式使用無號數減法及不使用二補數轉換的方式，使用變更減數以及被減數
wire [3:0] abs_cir_minus_x1, abs_cir_minus_y1; // 來達到絕對值的效果
wire [3:0] abs_cir_minus_x2, abs_cir_minus_y2; // 原本是先做有號數減法，剪完後取絕對值做了 NOT、無號數加法
wire [3:0] abs_cir_minus_x3, abs_cir_minus_y3; // 這邊改成用多工器選擇被減數及減數改善面積

assign abs_cir_minus_x0 = (cir_x >= ob_x[idx0]) ? (cir_x - ob_x[idx0]) : (ob_x[idx0] - cir_x);
assign abs_cir_minus_y0 = (cir_y >= ob_y[idx0]) ? (cir_y - ob_y[idx0]) : (ob_y[idx0] - cir_y);
assign abs_cir_minus_x1 = (cir_x >= ob_x[idx1]) ? (cir_x - ob_x[idx1]) : (ob_x[idx1] - cir_x);
assign abs_cir_minus_y1 = (cir_y >= ob_y[idx1]) ? (cir_y - ob_y[idx1]) : (ob_y[idx1] - cir_y);
assign abs_cir_minus_x2 = (cir_x >= ob_x[idx2]) ? (cir_x - ob_x[idx2]) : (ob_x[idx2] - cir_x);
assign abs_cir_minus_y2 = (cir_y >= ob_y[idx2]) ? (cir_y - ob_y[idx2]) : (ob_y[idx2] - cir_y);
assign abs_cir_minus_x3 = (cir_x >= ob_x[idx3]) ? (cir_x - ob_x[idx3]) : (ob_x[idx3] - cir_x);
assign abs_cir_minus_y3 = (cir_y >= ob_y[idx3]) ? (cir_y - ob_y[idx3]) : (ob_y[idx3] - cir_y);

// 計算距離以及判斷是否在圓心內
// 會有根號及平方
// 不用去做根號及平方，列出 x2 - x1 及 y2 - y1 的可能性去做
reg cir_cover0, cir_cover1, cir_cover2, cir_cover3; // 每一個 cnt 變動時產生一次(組合邏輯產出) / 當前標的物是否有覆蓋

// 循序邏輯變動
// 使用當前的總 cover 位置及另一個圓的最佳覆蓋位置去做 OR 才可以得出 "若兩個圓同時覆蓋同一目標物，僅計算一個物件。"
reg [39:0] current_every_cover ; // 當前
reg [39:0] best_every_cover_C1 ; // best
reg [39:0] best_every_cover_C2 ; // best

wire is_c1_state, best_every_cover_idx0, best_every_cover_idx1, best_every_cover_idx2, best_every_cover_idx3;
assign is_c1_state = (state == SET_C2_UPDATE_C1);
assign best_every_cover_idx0 = is_c1_state ? best_every_cover_C2[idx0] : best_every_cover_C1[idx0];
assign best_every_cover_idx1 = is_c1_state ? best_every_cover_C2[idx1] : best_every_cover_C1[idx1];
assign best_every_cover_idx2 = is_c1_state ? best_every_cover_C2[idx2] : best_every_cover_C1[idx2];
assign best_every_cover_idx3 = is_c1_state ? best_every_cover_C2[idx3] : best_every_cover_C1[idx3];

wire cover_OR0, cover_OR1, cover_OR2, cover_OR3;
assign cover_OR0 = cir_cover0 | best_every_cover_idx0;
assign cover_OR1 = cir_cover1 | best_every_cover_idx1;
assign cover_OR2 = cir_cover2 | best_every_cover_idx2;
assign cover_OR3 = cir_cover3 | best_every_cover_idx3;

wire [1:0] sum_01, sum_23; 
wire [2:0] sum_cover;
assign sum_01 = cover_OR0 + cover_OR1;
assign sum_23 = cover_OR2 + cover_OR3;
assign sum_cover = sum_01 + sum_23;

// 總覆蓋量 
reg [5:0] total_cover; 
reg [5:0] total_cover_current; // 把重複選取的點合併成一點後累加起來

// 共用一些比較器
wire is_better_or_eq; // 共用 6 bits 比較器在兩個 state 中
assign is_better_or_eq = (total_cover_current >= total_cover);
wire scan_done;
assign scan_done = (mov_cir_x == coor_max_x && mov_cir_y == coor_max_y);
wire x_end;
assign x_end = (mov_cir_x == coor_max_x);

// 利用原本圓心的最佳位置，如果圓心不在變動，那代表結果收斂
reg [3:0] best_C1X, best_C1Y, best_C2X, best_C2Y;

always @(*) begin
    case (abs_cir_minus_x0) // 使用絕對值就不用進行有號數比較，不過要比較有號數的話量兩邊都是要有號數
        0: cir_cover0 = (abs_cir_minus_y0 <= 5'd4);
        1, 2: cir_cover0 = (abs_cir_minus_y0 <= 5'd3);
        3: cir_cover0 = (abs_cir_minus_y0 <= 5'd2);
        4: cir_cover0 = (abs_cir_minus_y0 == 0);
        default: cir_cover0 = 0;
    endcase
    case (abs_cir_minus_x1) 
        0: cir_cover1 = (abs_cir_minus_y1 <= 5'd4);
        1, 2: cir_cover1 = (abs_cir_minus_y1 <= 5'd3);
        3: cir_cover1 = (abs_cir_minus_y1 <= 5'd2);
        4: cir_cover1 = (abs_cir_minus_y1 == 0);
        default: cir_cover1 = 0;
    endcase
    case (abs_cir_minus_x2) 
        0: cir_cover2 = (abs_cir_minus_y2 <= 5'd4);
        1, 2: cir_cover2 = (abs_cir_minus_y2 <= 5'd3);
        3: cir_cover2 = (abs_cir_minus_y2 <= 5'd2);
        4: cir_cover2 = (abs_cir_minus_y2 == 0);
        default: cir_cover2 = 0;
    endcase
    case (abs_cir_minus_x3) 
        0: cir_cover3 = (abs_cir_minus_y3 <= 5'd4);
        1, 2: cir_cover3 = (abs_cir_minus_y3 <= 5'd3);
        3: cir_cover3 = (abs_cir_minus_y3 <= 5'd2);
        4: cir_cover3 = (abs_cir_minus_y3 == 0);
        default: cir_cover3 = 0;
    endcase
end
//--------------------------------------------------------------

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        DONE <= 1'b0;
        C1X <= 1'b0;
        C1Y <= 1'b0;
        C2X <= 1'b0;
        C2Y <= 1'b0;
        cnt <= 0;
        first_step <= 1'b1; // 重製為 1，因為一開始要進入第一步驟
        // ob_x,y 不重製，因為新輸入的資料會覆蓋過去
        mov_cir_x <= 0;
        mov_cir_y <= 0;
        best_C1X <= 4'd0; best_C1Y <= 4'd0;
        best_C2X <= 4'd0; best_C2Y <= 4'd0;
        current_every_cover <= 0;
        best_every_cover_C1 <= 0;
        best_every_cover_C2 <= 0;
        total_cover_current <= 0;
        total_cover <= 0;

        state <= INPUT;
    end else begin
        case (state)
            INPUT: begin // 40 個 cycle 輸入 40 筆座標資料
                ob_x[cnt] <= X;
                ob_y[cnt] <= Y;
                cnt <= cnt + 1'd1;

                if (cnt == 6'd39) begin
                    cnt <= 0;
                    state <= SET_C2_UPDATE_C1;
                end
            end 
            
            // scan 位置找到最大覆蓋量
            // 為什麼需要多 1 clk 去處理，因為 total_cover_current 一定要等一個 clk 來讓最後一筆[10]的資料進去暫存器，後續判斷才會準確不會少一筆。
            SET_C2_UPDATE_C1: begin
                if (cnt == 6'd10) begin // 已經花了 10 個 cycle 判斷標的物完，去下一個座標
                    cnt <= 0;
                    total_cover_current <= 0;
                    
                    if (scan_done) begin // scan finished (第一步為 [15,15]，之後為[13,12])
                        total_cover <= 0;
                        best_C1X <= C1X;
                        best_C1Y <= C1Y;
                        first_step <= 1'b0;

                        if (best_C1X == C1X && best_C1Y == C1Y) begin
                            state <= OUTPUT;
                        end else begin
                            state <= SET_C1_UPDATE_C2;
                            mov_cir_x <= 4'd2; // 下一個狀態會從 [2,2] 開始
                            mov_cir_y <= 4'd2;
                        end

                    end else begin
                        if (is_better_or_eq) begin// 每個座標的總 cover 如果大於等於之前的總 cover，更新總 cover 且紀錄中心點
                            total_cover <= total_cover_current;
                            best_every_cover_C1 <= current_every_cover;
                            C1X <= mov_cir_x;
                            C1Y <= mov_cir_y;
                        end
                        
                        if (x_end) begin // x_end 為到達 x 的邊界時(13 or 15)
                            mov_cir_x <= coor_min_x; // 到達邊界時重製為 0 或者 2 根據是否是第一步來決定
                            mov_cir_y <= mov_cir_y + 1'd1;
                        end else begin
                            mov_cir_x <= mov_cir_x + 1'd1;
                        end
                    end
                end else begin
                    current_every_cover[idx0] <= cir_cover0;
                    current_every_cover[idx1] <= cir_cover1;
                    current_every_cover[idx2] <= cir_cover2;
                    current_every_cover[idx3] <= cir_cover3;
                    // 四個點同時判斷完，所以要一起加上去
                    total_cover_current <= total_cover_current + {3'b00, sum_cover};
                    cnt <= cnt + 1'd1;
                end
            end

            SET_C1_UPDATE_C2: begin
                if (cnt == 6'd10) begin // 已經花了 10 個 cycle 判斷標的物完，去下一個座標
                    cnt <= 0;
                    total_cover_current <= 0;
                    
                    // 進入這裡時 first_step 已經是 0，所以固定範圍是 [2,2] 到 [13,12]
                    if (scan_done) begin // scan finished
                        total_cover <= 0;
                        best_C2X <= C2X;
                        best_C2Y <= C2Y;

                        if (best_C2X == C2X && best_C2Y == C2Y) begin
                            state <= OUTPUT;
                        end else begin
                            state <= SET_C2_UPDATE_C1;
                            mov_cir_x <= 4'd2; // 下一個狀態會從 [2,2] 開始
                            mov_cir_y <= 4'd2;
                        end
                    end else begin
                        if (is_better_or_eq) begin // 每個座標的總 cover 如果大於等於之前的總 cover，更新總 cover 且紀錄中心點
                            total_cover <= total_cover_current;
                            best_every_cover_C2 <= current_every_cover;
                            C2X <= mov_cir_x;
                            C2Y <= mov_cir_y;
                        end
                        
                        if (x_end) begin // x_end 會固定為 13 在此 state 中
                            mov_cir_x <= 4'd2; // 到達邊界重製為 2，因為這裡不是第一步驟
                            mov_cir_y <= mov_cir_y + 1'd1;
                        end else begin
                            mov_cir_x <= mov_cir_x + 1'd1;
                        end
                    end
                end else begin
                    current_every_cover[idx0] <= cir_cover0;
                    current_every_cover[idx1] <= cir_cover1;
                    current_every_cover[idx2] <= cir_cover2;
                    current_every_cover[idx3] <= cir_cover3;
                    // 四個點同時判斷完，所以要一起加上去
                    total_cover_current <= total_cover_current + {3'b00, sum_cover}; 
                    cnt <= cnt + 1'd1;
                end
            end

            // LASER完成第一組pattern計算後，拉高DONE訊號表示完成。當DONE訊號再被拉回low後，便開始送出第二組pattern。
            OUTPUT: begin
                if (DONE == 1'b1) begin
                    DONE <= 1'b0;
                    C1X <= 1'b0;
                    C1Y <= 1'b0;
                    C2X <= 1'b0;
                    C2Y <= 1'b0;
                    cnt <= 0;
                    first_step <= 1'b1; // 新的 pattern 會先進入 first_step 掃描256個座標
                    // ob_x,y 不重製，因為新輸入的資料會覆蓋過去
                    mov_cir_x <= 0;
                    mov_cir_y <= 0;
                    best_C1X <= 4'd0; best_C1Y <= 4'd0;
                    best_C2X <= 4'd0; best_C2Y <= 4'd0;
                    current_every_cover <= 0;
                    best_every_cover_C1 <= 0;
                    best_every_cover_C2 <= 0;
                    total_cover_current <= 0;
                    total_cover <= 0;
                    state <= INPUT;
                end else begin
                    DONE <= 1'b1;
                end
            end

            default: ;
        endcase
    end
end
endmodule
