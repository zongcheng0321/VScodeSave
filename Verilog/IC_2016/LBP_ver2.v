// 每個點花 260ns * 16384 = 4259840 -> 面積 5300 -> score = 22G 未達標
// 想法：改成一次做 3 個點 4286580/3 = 1,428,8601,428,860 * 8000(猜測值) = 11,430,880,000 < 12,000,000,000
// 此想法不行：有點難做要一次要玩三個點的座標且同時做運算
// 如果 10ns *3 -> 更新座標 + 要資料 + 累加 -> 八個點 -> 30 * 8 = 240 ns
// 先把九個點的資料放進來，同時八個點判斷同時加起來，然後 1 clk 輸出 -> 90ns + 10ns = 100ns 但這樣算出來的值一樣無法小於12,000,000,000

// 那當坐標前進時，是從左到右由上到下，往右移動一格代表說我只要去多要右邊那排的資料，往下移動的話就重新要9筆資料。
// 所以這樣子預估一下時間：平均除了換行(90 ns)以外都花了30 ns 要資料，然後用 1 clock 輸出
// 這樣子的話做完一行要 90ns + 40 ns * 128，總共128行，所以128 * (90ns + 40 ns * 128) = 666,880，面積預估10000 ，所以666,880 * 10000 < 12G


`timescale 1ns/10ps
module LBP ( clk, reset, gray_addr, gray_req, gray_ready, gray_data, lbp_addr, lbp_valid, lbp_data, finish);
input   	clk;
input   	reset; // 高準位非同步
output reg [13:0] 	gray_addr; // 每一個週期僅能索取一個位址的資料。 題目不限制位址及資料的索取次數。 
output reg       	gray_req; // 。當為High時，表示LBP端要向Host 端索取灰階圖像資料。
input   	gray_ready; // 當為High時，表示Host端已經將灰階圖像記憶體及相關訊號準備完成了；
                        //LBP端需在偵測到此訊號為High後才可以開始對Host端進行資料索取動作。 
input   [7:0] 	gray_data;
output reg [13:0] 	lbp_addr;
output reg 	lbp_valid;
output reg [7:0] 	lbp_data;
output reg	finish;

//------------------------------------------------
// FSM
reg state;
localparam INPUT = 3'd0, // 更新座標、要資料
           OUTPUT = 3'd1; // 輸出組合邏輯的資料
reg delay1CLK;
//------------------------------------------------
reg [6:0] x, y; // gc -> 1 ~ 2^7 -1 灰階圖像中間縮一圈的範圍，gc 從中間做因為最後輸出最外圈會是 0
reg [1:0] pixel_row, pixel_col; // 九宮格的x ,y

wire Change_row; // 換行旗標
assign Change_row = (x == 0);


wire [6:0] plus_x_pixel_col; // 0 ~ 127
wire [13:0] plus_y_pixel_row; // 最多為 127 * (2 ^ 7) = 16256
wire [13:0] input_addr; // (x - 1) + pixel_col + (pixel_row << 7) + [(y - 1) << 7] 
// 原本 x, y 要從 1 跑到 2^7 -1，但我這邊的 input_addr 改成 x, y 不減 1 了，所以 x, y 那邊要在減 1 一次變成 (1 - 1) ~ (2^7 -1 -1)
// so x, y 範圍變成-> 0 ~ 2^7 -2, input_addr 變成 x + pixel_col + (pixel_row << 7) + y << 7，少了兩個減法器以及後續判斷的比較器。

wire [1:0] pixel_col_for_input; // 新增判斷現在如果要換行，取新九宮格，如果不換行，pixel_col 就固定為 2，等於是只取用最右邊那整排的資料
assign pixel_col_for_input = (Change_row)? pixel_col : 2'd2;
assign plus_x_pixel_col = x + {5'd0, pixel_col_for_input};
assign plus_y_pixel_row = ({5'd0, pixel_row} << 7) + (y << 7);
assign input_addr = {7'd0, plus_x_pixel_col} + plus_y_pixel_row;
//------------------------------------------------
// 九宮格輸入
// p[0] p[1] p[2]
// p[3] p[4] p[5] -> p[4] 就是 gc
// p[6] p[7] p[8]
reg [7:0] P [8:0];
reg [3:0] cnt; // 計數器： P index

reg [7:0] P_temp_data [2:0];

wire stopINPUT; // 停止輸入條件 & cnt == 2 可以給交換 P 那裡做判斷
assign stopINPUT = (Change_row)? (cnt == 4'd8) : (cnt == 4'd2);

// 區塊註解為廢棄程式，理由：真正的管線化，必須是「每個 Clock 連續不斷地給 Address」。
// 只要你跳去別的狀態做 UPDATE，你的讀取動作就被打斷了，這樣 3 筆資料就不會是連續的 40ns，而是被拉長到 60ns 以上。
// 更新座標的動作必須跟發送 Address 在同一個 Clock 內完成。
/* wire [3:0] cnt_plus_1, cnt_plus_2, cnt_plus_3;
assign cnt_plus_1 = 3'd1 + cnt;
assign cnt_plus_2 = 3'd2 + cnt;
assign cnt_plus_3 = 3'd3 + cnt;

wire [7:0] P_cnt_plus_1, P_cnt_plus_2, P_cnt_plus_3;
assign P_cnt_plus_1 = P[cnt_plus_1];
assign P_cnt_plus_2 = P[cnt_plus_2];
assign P_cnt_plus_3 = P[cnt_plus_3];

wire [7:0] P_exchange0, P_exchange1, P_exchange2;
assign P_exchange0 = (stopINPUT)? P_cnt_plus_1 : gray_data;
assign P_exchange1 = (stopINPUT)? P_cnt_plus_2 : gray_data;
assign P_exchange2 = (stopINPUT)? P_cnt_plus_3 : gray_data; */
//------------------------------------------------
// 共用項
wire is_pixel_col_eq_2;
// 這裡為了共用要改成 pixel_col_for_input，這樣 cnt 加 1 pixel_row 才會 +1
assign is_pixel_col_eq_2 = (pixel_col_for_input == 2'd2); 

wire x_end;
assign x_end = (x == 7'd125);


//------------------------------------------------
// Threshold值
wire [7:0] s;
wire [8:0] z [7:0]; // -255 ~ 255
assign z[0] = P[0] - P[4];
assign z[1] = P[1] - P[4];
assign z[2] = P[2] - P[4];
assign z[3] = P[3] - P[4];
assign z[4] = P[5] - P[4];
assign z[5] = P[6] - P[4];
assign z[6] = P[7] - P[4];
assign z[7] = P[8] - P[4];

// 判斷符號位元以達成 >= 0 之效果
assign s[0] = (z[0][8] == 0)? 1'd1: 0; // 2^0
assign s[1] = (z[1][8] == 0)? 1'd1: 0; // 2^1
assign s[2] = (z[2][8] == 0)? 1'd1: 0; // 2^2
assign s[3] = (z[3][8] == 0)? 1'd1: 0; // 2^3
assign s[4] = (z[4][8] == 0)? 1'd1: 0; // 2^4
assign s[5] = (z[5][8] == 0)? 1'd1: 0; // 2^5
assign s[6] = (z[6][8] == 0)? 1'd1: 0; // 2^6
assign s[7] = (z[7][8] == 0)? 1'd1: 0; // 2^7

wire [7:0] multiplyWeight [7:0]; // 最大值為 2 ^ 7 = 128 -> 8bits 才有 128
assign multiplyWeight[0] = {7'd0, s[0]};
assign multiplyWeight[1] = s[1] << 1;
assign multiplyWeight[2] = s[2] << 2;
assign multiplyWeight[3] = s[3] << 3;
assign multiplyWeight[4] = s[4] << 4;
assign multiplyWeight[5] = s[5] << 5;
assign multiplyWeight[6] = s[6] << 6;
assign multiplyWeight[7] = s[7] << 7;

wire [1:0] sum1_0;  // 最大值 3
wire [3:0] sum1_1;  // 最大值 12
wire [5:0] sum1_2;  // 最大值 48
wire [7:0] sum1_3;  // 最大值 192

assign sum1_0 = multiplyWeight[0][1:0] + multiplyWeight[1][1:0];
assign sum1_1 = multiplyWeight[2][3:0] + multiplyWeight[3][3:0];
assign sum1_2 = multiplyWeight[4][5:0] + multiplyWeight[5][5:0];
assign sum1_3 = multiplyWeight[6][7:0] + multiplyWeight[7][7:0];

wire [3:0] sum2_0;  // 最大值 15
wire [7:0] sum2_1;  // 最大值 240

assign sum2_0 = {2'd0, sum1_0} + sum1_1;
assign sum2_1 = {2'd0, sum1_2} + sum1_3;

wire [7:0] sum;     // 最大值 255
assign sum = {4'd0, sum2_0} + sum2_1;


//====================================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        gray_addr <= 0;
        gray_req <= 0;
        lbp_addr <= 0;
        lbp_valid <= 0;
        lbp_data <= 0;
        finish <= 0;
        
        // 重製
        state <= INPUT;
        x <= 0;
        y <= 0;
        pixel_col <= 0;
        pixel_row <= 0;
        delay1CLK <= 0;
        P[0] <= 0; P[1] <= 0; P[2] <= 0;
        P[3] <= 0; P[4] <= 0; P[5] <= 0;
        P[6] <= 0; P[7] <= 0; P[8] <= 0;
        P_temp_data[0] <= 0; P_temp_data[1] <= 0; P_temp_data[2] <= 0;
        cnt <= 4'b1111; // 先設為最大值，因為要多等一個 clk
    end else begin
        case (state)

            INPUT: begin
                cnt <= cnt + 1'd1;
                lbp_valid <= 0;
                if (gray_ready) begin
                    gray_addr <= input_addr;
                    gray_req <= 1'd1;
                    // 資料會連續進來，但第一筆要多等一個 clk，把每一筆存起來，等到最後一個 clk 一次改變 P[] 的值
                    if (delay1CLK == 0) begin // 當要 delay1CLK時
                        delay1CLK <= 1'd1;
                    end else begin // 此時已經經過一個 clk, cnt 變為 0, 且資料經過一個負緣也出來了
                        if (Change_row) begin // 換行 要九筆資料花 90 ns
                            P[cnt] <= gray_data;
                        end else begin // 當 x 坐標右移一格時
                            /* P[0] <= P[1];
                            P[3] <= P[4];
                            P[6] <= P[7];

                            P[1] <= P[2];
                            P[4] <= P[5];
                            P[7] <= P[8]; */
                            P_temp_data[cnt] <= gray_data; // 用不到 P_temp_data[2] 狀態
                        end
                    end
                end

                if (stopINPUT) begin
                    state <= OUTPUT; // 輸出資料
                    cnt <= 4'b1111; // 設為最大值，因為要多等一個 clk
                    pixel_col <= 1'd0;
                    pixel_row <= 1'd0;
                    if (!Change_row) begin // 當九宮格右移時，三筆資料要在此 clk 產出正確的 P 資料
                        P[0] <= P[1];
                        P[3] <= P[4];
                        P[6] <= P[7];

                        P[1] <= P[2];
                        P[4] <= P[5];
                        P[7] <= P[8];

                        P[2] <= P_temp_data[0];
                        P[5] <= P_temp_data[1];
                        P[8] <= gray_data;
                    end
                end else begin
                    // 更新 pixel_row and col 座標
                    if (is_pixel_col_eq_2 && pixel_row == 2'd2) begin
                        pixel_col <= 1'd0;
                        pixel_row <= 1'd0;
                    end else begin
                        pixel_col <= pixel_col + 1'd1;
                        if (is_pixel_col_eq_2) begin
                            pixel_col <= 0;
                            pixel_row <= pixel_row + 1'd1;
                        end
                    end
                end
            end 

            OUTPUT: begin
                delay1CLK <= 0;
                lbp_valid <= 1'd1;
                lbp_addr <= {7'd0, (x + 7'd1)} +  (({7'd0, y} + 7'd1) << 7);
                lbp_data <= sum;
                if (x_end && y == 7'd125) begin
                    if (delay1CLK == 0) begin // 當要 delay1CLK時
                        delay1CLK <= 1'd1;
                    end else begin
                        finish <= 1'd1;
                    end
                end else begin
                    // 更新 x, y 座標
                    x <= x + 1'd1;
                    if (x_end) begin
                        y <= y + 1'd1;
                        x <= 0;
                    end
                    state <= INPUT;
                end
            end
            default: ;
        endcase
    end
end
//====================================================================
endmodule
