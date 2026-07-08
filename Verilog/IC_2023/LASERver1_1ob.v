// ver1. 找出最少須迭代幾次才能得出最佳解，使用最少面積最多cycle的方式，測出來最少面積為25000，最大cycle為73000多。

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
//reg [5:0] i, j;

//--------------------------------------------------------------
// 圓內判斷
// 圓半徑固定為4，距離剛好等於4視為在圓內。若兩個圓同時覆蓋同一目標物，僅計算一個物件。

wire signed [4:0] cir_minus_x; // 兩點相減多 1 bit 符號位元 -> -15 ~ + 15
wire signed [4:0] cir_minus_y;
wire [3:0] cir_x, cir_y;
assign cir_x = mov_cir_x;
assign cir_y = mov_cir_y;

assign cir_minus_x = $signed({1'b0, cir_x}) - $signed({1'b0, ob_x[cnt]});
assign cir_minus_y = $signed({1'b0, cir_y}) - $signed({1'b0, ob_y[cnt]});

wire [3:0] abs_cir_minus_x, abs_cir_minus_y;
assign abs_cir_minus_x = (cir_minus_x[4] == 1'd1)? (~cir_minus_x[3:0] + 1'd1) : cir_minus_x[3:0];
assign abs_cir_minus_y = (cir_minus_y[4] == 1'd1)? (~cir_minus_y[3:0] + 1'd1) : cir_minus_y[3:0];

// 計算距離以及判斷是否在圓心內
// 會有根號及平方
// 不用去做根號及平方，列出 x2 - x1 及 y2 - y1 的可能性去做
reg cir_cover; // 每一個 cnt 變動時產生一次(組合邏輯產出) / 當前標的物是否有覆蓋

// 循序邏輯變動
// 使用當前的總 cover 位置及另一個圓的最佳覆蓋位置去做 OR 才可以得出 "若兩個圓同時覆蓋同一目標物，僅計算一個物件。"
reg [39:0] current_every_cover ; // 當前
reg [39:0] best_every_cover_C1 ; // best
reg [39:0] best_every_cover_C2 ; // best

wire COVER_OR_C1, COVER_OR_C2;
assign COVER_OR_C1 = cir_cover || best_every_cover_C2[cnt];
assign COVER_OR_C2 = cir_cover || best_every_cover_C1[cnt];
// 總覆蓋量 
reg [5:0] total_cover; 
reg [5:0] total_cover_current; // 把重複選取的點合併成一點後累加起來

// 利用原本圓心的最佳位置，如果圓心不在變動，那代表結果收斂
reg [3:0] best_C1X, best_C1Y, best_C2X, best_C2Y;

always @(*) begin
    case (abs_cir_minus_x) // 使用絕對值就不用進行有號數比較，不過要比較有號數的話量兩邊都是要有號數
        0: cir_cover = (abs_cir_minus_y <= 5'd4);
        1, 2: cir_cover = (abs_cir_minus_y <= 5'd3);
        3: cir_cover = (abs_cir_minus_y <= 5'd2);
        4: cir_cover = (abs_cir_minus_y == 0);
        default: begin
            cir_cover = 0;
        end
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
        //i <= 0;
        //j <= 0;
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
            
            // scan 256 個位置找到最大覆蓋量
            SET_C2_UPDATE_C1: begin
                if (cnt == 6'd40) begin // 已經花了 40 個 cycle 判斷標的物完，去下一個座標
                    cnt <= 0;
                    total_cover_current <= 0;
                    
                    if (mov_cir_x == 4'd15 && mov_cir_y == 4'd15) begin // scan finished
                        mov_cir_x <= 0;
                        mov_cir_y <= 0;
                        total_cover <= 0;
                        best_C1X <= C1X;
                        best_C1Y <= C1Y;

                        if (best_C1X == C1X && best_C1Y == C1Y) begin
                            state <= OUTPUT;
                        end else begin
                            state <= SET_C1_UPDATE_C2;
                        end

                    end else begin
                        if (total_cover_current >= total_cover) begin// 每個座標的總 cover 如果大於等於之前的總 cover，更新總 cover 且紀錄中心點
                            total_cover <= total_cover_current;
                            best_every_cover_C1 <= current_every_cover;
                            C1X <= mov_cir_x;
                            C1Y <= mov_cir_y;
                        end
                        
                        if (mov_cir_x == 4'd15) begin
                            mov_cir_x <= 0;
                            mov_cir_y <= mov_cir_y + 1'd1;
                        end else begin
                            mov_cir_x <= mov_cir_x + 1'd1;
                        end
                    end
                end else begin
                    current_every_cover[cnt] <= cir_cover;
                    total_cover_current <= total_cover_current + {5'd0, COVER_OR_C1};
                    cnt <= cnt + 1'd1;
                end
            end

            SET_C1_UPDATE_C2: begin
                if (cnt == 6'd40) begin // 已經花了 40 個 cycle 判斷標的物完，去下一個座標
                    cnt <= 0;
                    total_cover_current <= 0;
                    
                    if (mov_cir_x == 4'd15 && mov_cir_y == 4'd15) begin // scan finished
                        mov_cir_x <= 0;
                        mov_cir_y <= 0;
                        total_cover <= 0;
                        best_C2X <= C2X;
                        best_C2Y <= C2Y;

                        if (best_C2X == C2X && best_C2Y == C2Y) begin
                            state <= OUTPUT;
                        end else begin
                            state <= SET_C2_UPDATE_C1;
                        end
                    end else begin
                        if (total_cover_current >= total_cover) begin // 每個座標的總 cover 如果大於等於之前的總 cover，更新總 cover 且紀錄中心點
                            total_cover <= total_cover_current;
                            best_every_cover_C2 <= current_every_cover;
                            C2X <= mov_cir_x;
                            C2Y <= mov_cir_y;
                        end
                        
                        if (mov_cir_x == 4'd15) begin 
                            mov_cir_x <= 0;
                            mov_cir_y <= mov_cir_y + 1'd1;
                        end else begin
                            mov_cir_x <= mov_cir_x + 1'd1;
                        end
                    end
                end else begin
                    current_every_cover[cnt] <= cir_cover;
                    total_cover_current <= total_cover_current + {5'd0, COVER_OR_C2};
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
                    //i <= 0;
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
