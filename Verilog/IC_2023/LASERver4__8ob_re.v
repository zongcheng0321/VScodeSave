// ver4_revised. 改善邏輯不使用有號數加減法及二補數
// 但發現其實只能改善成 28731，但 timing violation 沒了，因為在合成出了太多 6 bits的加法，改用先把 1 bit 的加法加起來
// 在分給 total_cover_current 做 6 bits 的加法這樣才不會 timing violation
// 所以最後只能採取平行四個標的物的方法

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

wire [3:0] cir_x, cir_y;
assign cir_x = mov_cir_x;
assign cir_y = mov_cir_y;

// 產生八個點的 Index
wire [5:0] idx0, idx1, idx2, idx3, idx4, idx5, idx6, idx7;
assign idx0 = {cnt[2:0], 3'b000}; // cnt * 8
assign idx1 = {cnt[2:0], 3'b001}; // cnt * 8 + 1
assign idx2 = {cnt[2:0], 3'b010}; // cnt * 8 + 2
assign idx3 = {cnt[2:0], 3'b011}; // cnt * 8 + 3
assign idx4 = {cnt[2:0], 3'b100}; // cnt * 8 + 4
assign idx5 = {cnt[2:0], 3'b101}; // cnt * 8 + 5
assign idx6 = {cnt[2:0], 3'b110}; // cnt * 8 + 6
assign idx7 = {cnt[2:0], 3'b111}; // cnt * 8 + 7

/* 不使用有號數減法
wire signed [4:0] cir_minus_x0, cir_minus_y0; // 兩點相減多 1 bit 符號位元 -> -15 ~ + 15
wire signed [4:0] cir_minus_x1, cir_minus_y1;
wire signed [4:0] cir_minus_x2, cir_minus_y2;
wire signed [4:0] cir_minus_x3, cir_minus_y3;
wire signed [4:0] cir_minus_x4, cir_minus_y4;
wire signed [4:0] cir_minus_x5, cir_minus_y5;
wire signed [4:0] cir_minus_x6, cir_minus_y6;
wire signed [4:0] cir_minus_x7, cir_minus_y7;

assign cir_minus_x0 = $signed({1'b0, cir_x}) - $signed({1'b0, ob_x[idx0]});
assign cir_minus_y0 = $signed({1'b0, cir_y}) - $signed({1'b0, ob_y[idx0]});
assign cir_minus_x1 = $signed({1'b0, cir_x}) - $signed({1'b0, ob_x[idx1]});
assign cir_minus_y1 = $signed({1'b0, cir_y}) - $signed({1'b0, ob_y[idx1]});
assign cir_minus_x2 = $signed({1'b0, cir_x}) - $signed({1'b0, ob_x[idx2]});
assign cir_minus_y2 = $signed({1'b0, cir_y}) - $signed({1'b0, ob_y[idx2]});
assign cir_minus_x3 = $signed({1'b0, cir_x}) - $signed({1'b0, ob_x[idx3]});
assign cir_minus_y3 = $signed({1'b0, cir_y}) - $signed({1'b0, ob_y[idx3]});
assign cir_minus_x4 = $signed({1'b0, cir_x}) - $signed({1'b0, ob_x[idx4]});
assign cir_minus_y4 = $signed({1'b0, cir_y}) - $signed({1'b0, ob_y[idx4]});
assign cir_minus_x5 = $signed({1'b0, cir_x}) - $signed({1'b0, ob_x[idx5]});
assign cir_minus_y5 = $signed({1'b0, cir_y}) - $signed({1'b0, ob_y[idx5]});
assign cir_minus_x6 = $signed({1'b0, cir_x}) - $signed({1'b0, ob_x[idx6]});
assign cir_minus_y6 = $signed({1'b0, cir_y}) - $signed({1'b0, ob_y[idx6]});
assign cir_minus_x7 = $signed({1'b0, cir_x}) - $signed({1'b0, ob_x[idx7]});
assign cir_minus_y7 = $signed({1'b0, cir_y}) - $signed({1'b0, ob_y[idx7]});
*/

wire [3:0] abs_cir_minus_x0, abs_cir_minus_y0; // 取絕對值的方式使用無號數減法及不使用二補數轉換的方式，使用變更減數以及被減數
wire [3:0] abs_cir_minus_x1, abs_cir_minus_y1; // 來達到絕對值的效果
wire [3:0] abs_cir_minus_x2, abs_cir_minus_y2; // 原本是先做有號數減法，剪完後取絕對值做了 NOT、無號數加法
wire [3:0] abs_cir_minus_x3, abs_cir_minus_y3; // 這邊改成用多工器選擇被減數及減數改善面積
wire [3:0] abs_cir_minus_x4, abs_cir_minus_y4;
wire [3:0] abs_cir_minus_x5, abs_cir_minus_y5;
wire [3:0] abs_cir_minus_x6, abs_cir_minus_y6;
wire [3:0] abs_cir_minus_x7, abs_cir_minus_y7;

assign abs_cir_minus_x0 = (cir_x >= ob_x[idx0]) ? (cir_x - ob_x[idx0]) : (ob_x[idx0] - cir_x);
assign abs_cir_minus_y0 = (cir_y >= ob_y[idx0]) ? (cir_y - ob_y[idx0]) : (ob_y[idx0] - cir_y);
assign abs_cir_minus_x1 = (cir_x >= ob_x[idx1]) ? (cir_x - ob_x[idx1]) : (ob_x[idx1] - cir_x);
assign abs_cir_minus_y1 = (cir_y >= ob_y[idx1]) ? (cir_y - ob_y[idx1]) : (ob_y[idx1] - cir_y);
assign abs_cir_minus_x2 = (cir_x >= ob_x[idx2]) ? (cir_x - ob_x[idx2]) : (ob_x[idx2] - cir_x);
assign abs_cir_minus_y2 = (cir_y >= ob_y[idx2]) ? (cir_y - ob_y[idx2]) : (ob_y[idx2] - cir_y);
assign abs_cir_minus_x3 = (cir_x >= ob_x[idx3]) ? (cir_x - ob_x[idx3]) : (ob_x[idx3] - cir_x);
assign abs_cir_minus_y3 = (cir_y >= ob_y[idx3]) ? (cir_y - ob_y[idx3]) : (ob_y[idx3] - cir_y);
assign abs_cir_minus_x4 = (cir_x >= ob_x[idx4]) ? (cir_x - ob_x[idx4]) : (ob_x[idx4] - cir_x);
assign abs_cir_minus_y4 = (cir_y >= ob_y[idx4]) ? (cir_y - ob_y[idx4]) : (ob_y[idx4] - cir_y);
assign abs_cir_minus_x5 = (cir_x >= ob_x[idx5]) ? (cir_x - ob_x[idx5]) : (ob_x[idx5] - cir_x);
assign abs_cir_minus_y5 = (cir_y >= ob_y[idx5]) ? (cir_y - ob_y[idx5]) : (ob_y[idx5] - cir_y);
assign abs_cir_minus_x6 = (cir_x >= ob_x[idx6]) ? (cir_x - ob_x[idx6]) : (ob_x[idx6] - cir_x);
assign abs_cir_minus_y6 = (cir_y >= ob_y[idx6]) ? (cir_y - ob_y[idx6]) : (ob_y[idx6] - cir_y);
assign abs_cir_minus_x7 = (cir_x >= ob_x[idx7]) ? (cir_x - ob_x[idx7]) : (ob_x[idx7] - cir_x);
assign abs_cir_minus_y7 = (cir_y >= ob_y[idx7]) ? (cir_y - ob_y[idx7]) : (ob_y[idx7] - cir_y);

// 計算距離以及判斷是否在圓心內
// 會有根號及平方
// 不用去做根號及平方，列出 x2 - x1 及 y2 - y1 的可能性去做
reg cir_cover0, cir_cover1, cir_cover2, cir_cover3;
reg cir_cover4, cir_cover5, cir_cover6, cir_cover7; // 每一個 cnt 變動時產生一次(組合邏輯產出) / 當前標的物是否有覆蓋

// 循序邏輯變動
// 使用當前的總 cover 位置及另一個圓的最佳覆蓋位置去做 OR 才可以得出 "若兩個圓同時覆蓋同一目標物，僅計算一個物件。"
reg [39:0] current_every_cover ; // 當前
reg [39:0] best_every_cover_C1 ; // best
reg [39:0] best_every_cover_C2 ; // best

wire COVER_OR_C1_0, COVER_OR_C1_1, COVER_OR_C1_2, COVER_OR_C1_3, COVER_OR_C1_4, COVER_OR_C1_5, COVER_OR_C1_6, COVER_OR_C1_7;
wire COVER_OR_C2_0, COVER_OR_C2_1, COVER_OR_C2_2, COVER_OR_C2_3, COVER_OR_C2_4, COVER_OR_C2_5, COVER_OR_C2_6, COVER_OR_C2_7;

assign COVER_OR_C1_0 = cir_cover0 || best_every_cover_C2[idx0];
assign COVER_OR_C1_1 = cir_cover1 || best_every_cover_C2[idx1];
assign COVER_OR_C1_2 = cir_cover2 || best_every_cover_C2[idx2];
assign COVER_OR_C1_3 = cir_cover3 || best_every_cover_C2[idx3];
assign COVER_OR_C1_4 = cir_cover4 || best_every_cover_C2[idx4];
assign COVER_OR_C1_5 = cir_cover5 || best_every_cover_C2[idx5];
assign COVER_OR_C1_6 = cir_cover6 || best_every_cover_C2[idx6];
assign COVER_OR_C1_7 = cir_cover7 || best_every_cover_C2[idx7];

assign COVER_OR_C2_0 = cir_cover0 || best_every_cover_C1[idx0];
assign COVER_OR_C2_1 = cir_cover1 || best_every_cover_C1[idx1];
assign COVER_OR_C2_2 = cir_cover2 || best_every_cover_C1[idx2];
assign COVER_OR_C2_3 = cir_cover3 || best_every_cover_C1[idx3];
assign COVER_OR_C2_4 = cir_cover4 || best_every_cover_C1[idx4];
assign COVER_OR_C2_5 = cir_cover5 || best_every_cover_C1[idx5];
assign COVER_OR_C2_6 = cir_cover6 || best_every_cover_C1[idx6];
assign COVER_OR_C2_7 = cir_cover7 || best_every_cover_C1[idx7];

wire [3:0] sum_cover_c1, sum_cover_c2;

assign sum_cover_c1 =
    ((COVER_OR_C1_0 + COVER_OR_C1_1) + (COVER_OR_C1_2 + COVER_OR_C1_3)) +
    ((COVER_OR_C1_4 + COVER_OR_C1_5) + (COVER_OR_C1_6 + COVER_OR_C1_7));

assign sum_cover_c2 =
    ((COVER_OR_C2_0 + COVER_OR_C2_1) + (COVER_OR_C2_2 + COVER_OR_C2_3)) +
    ((COVER_OR_C2_4 + COVER_OR_C2_5) + (COVER_OR_C2_6 + COVER_OR_C2_7));

// 總覆蓋量 
reg [5:0] total_cover; 
reg [5:0] total_cover_current; // 把重複選取的點合併成一點後累加起來

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
    case (abs_cir_minus_x4) 
        0: cir_cover4 = (abs_cir_minus_y4 <= 5'd4);
        1, 2: cir_cover4 = (abs_cir_minus_y4 <= 5'd3);
        3: cir_cover4 = (abs_cir_minus_y4 <= 5'd2);
        4: cir_cover4 = (abs_cir_minus_y4 == 0);
        default: cir_cover4 = 0;
    endcase
    case (abs_cir_minus_x5) 
        0: cir_cover5 = (abs_cir_minus_y5 <= 5'd4);
        1, 2: cir_cover5 = (abs_cir_minus_y5 <= 5'd3);
        3: cir_cover5 = (abs_cir_minus_y5 <= 5'd2);
        4: cir_cover5 = (abs_cir_minus_y5 == 0);
        default: cir_cover5 = 0;
    endcase
    case (abs_cir_minus_x6) 
        0: cir_cover6 = (abs_cir_minus_y6 <= 5'd4);
        1, 2: cir_cover6 = (abs_cir_minus_y6 <= 5'd3);
        3: cir_cover6 = (abs_cir_minus_y6 <= 5'd2);
        4: cir_cover6 = (abs_cir_minus_y6 == 0);
        default: cir_cover6 = 0;
    endcase
    case (abs_cir_minus_x7) 
        0: cir_cover7 = (abs_cir_minus_y7 <= 5'd4);
        1, 2: cir_cover7 = (abs_cir_minus_y7 <= 5'd3);
        3: cir_cover7 = (abs_cir_minus_y7 <= 5'd2);
        4: cir_cover7 = (abs_cir_minus_y7 == 0);
        default: cir_cover7 = 0;
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
                if (cnt == 6'd5) begin // 已經花了 5 個 cycle 判斷標的物完，去下一個座標
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
                    current_every_cover[idx0] <= cir_cover0;
                    current_every_cover[idx1] <= cir_cover1;
                    current_every_cover[idx2] <= cir_cover2;
                    current_every_cover[idx3] <= cir_cover3;
                    current_every_cover[idx4] <= cir_cover4;
                    current_every_cover[idx5] <= cir_cover5;
                    current_every_cover[idx6] <= cir_cover6;
                    current_every_cover[idx7] <= cir_cover7;
                    // 八個點同時判斷完，所以要一起加上去
                    total_cover_current <= total_cover_current + {2'b00, sum_cover_c1};
                    cnt <= cnt + 1'd1;
                end
            end

            SET_C1_UPDATE_C2: begin
                if (cnt == 6'd5) begin // 已經花了 5 個 cycle 判斷標的物完，去下一個座標
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
                    current_every_cover[idx0] <= cir_cover0;
                    current_every_cover[idx1] <= cir_cover1;
                    current_every_cover[idx2] <= cir_cover2;
                    current_every_cover[idx3] <= cir_cover3;
                    current_every_cover[idx4] <= cir_cover4;
                    current_every_cover[idx5] <= cir_cover5;
                    current_every_cover[idx6] <= cir_cover6;
                    current_every_cover[idx7] <= cir_cover7;
                    // 八個點同時判斷完，所以要一起加上去
                   total_cover_current <= total_cover_current + {2'b00, sum_cover_c2}; 
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
