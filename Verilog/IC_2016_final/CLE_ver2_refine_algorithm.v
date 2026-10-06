// 此題實作了 posedge clk 跟 negedge clk 平行使用的電路(為了符合記憶體延遲以及處理 hold time violation 之問題)
// parallel two-pass CCL algorithm 有可能是這題的解答演算法，之後可以研究看看
// 經詢問過 AI 我的演算法確實有問題，當碰到 U 型連通體，右上角那格無法被改變到，但題目也只給 3 個 pattern 應該沒有隱藏的
//         x=2       x=3       x=4
// y=2   [ 02 ]    [ 00 ]    [ 03 ]  <-- 殘留 03！
// y=3   [ 02 ]    [ 00 ]    [ 02 ]  
// y=4   [ 02 ]    [ 02 ]    [ 02 ]  

//===================================
// 此版本 ver2 改了演算法，改成當碰到兩種不同編號在九宮格內，必須合併當前九宮格編號並統一，改成較小的，利用 change_flag
// 當整張圖掃完後，如果 change_flag == 1，座標重設回 (1,1) 再掃一次，直到整張掃完都沒有任何像素被修改，才判定 finish = 1。
// 未來改進方向: 
// 1. 研究 parallel two-pass CCL algorithm
// 2. 改成 一旦碰到兩種不同編號在九宮格內，原本九宮格掃描是左上到右下，改成右下到左上 -> 意即倒回去做
// 3. Two-Pass Raster-Scan CCL（Rosenfeld 算法變形），值得研究來利用達成此電路(在 2017 ICC DT 似乎有實作!!)
// 4. area 可以多一點，但 time 要盡量少(成平方比關係) 

// ** 關於第二點：單純「切換方向」無法保證完全收斂（遇到更複雜的形狀仍會死鎖或無限震盪）。
// ** 硬體 FSM 與位址控制會變得極度複雜（來回震盪時的邊界與死循環問題）。
// ** 但「正向掃一次、反向掃一次（Forward-Backward Two-Pass）」是圖像處理經典算法，只要固定方向執行，就是非常棒且可行的做法！
/*建議總結
    不要做「動態切換方向」，硬體很難處理 Ping-Pong 抖動和狀態記錄。
    如果想實作「倒回去做」，請做結構化的「反向掃描 Pass」：整張圖從 (30,30) 倒序迴圈跑到 (1,1)，這樣一來無論是 U 型、倒 U 型、S 型，標籤都能完全擴散傳遞。*/
//====================================
// 記憶體操作及使用要參照 pdf 文件(hold time violation careful)
// 找連在一起的相同物件，由於我修過資料結構，我的第一個想法是用 DFS or BFS
// DFS、BFS 評估：這樣還要實作記憶體 stack 或 queue，能不能把輸出的 SRAM 拿來當成可以存東西的(不多做一個記憶體耗面積)? -> 問 AI 
// DFS、BFS 有點麻煩

// 要一邊輸入資料做 還是 全部資料存起來再做?
// 全部資料存起來多花 32 * 32 -> 1024 bits
// 因為判斷需要判斷九宮格，但輸入資料是一次輸入橫排 8 bits 直到輸入到共 32 bits (橫排結束)後，換行繼續輸入
// 判斷九宮格如果要一直去操作輸入資料的話，我認為判斷的電路會比較麻煩，所以我打算多花 1024 bits 把題目圖片輸入進來後，再去做判斷
// 一次輸入 8 bits，所以一列只花 4 clk，4 * 32 = 128 clk

// 新想法：把輸入來的資料存進 SRAM，全部存完後把九宮格資料拿出來判斷，然後再放回去
// 消耗 clk 數為 input 4*32 + output 1024 + 一個 pixel 要花 9 clk 判斷 * 從 SRAM 把資料要出來 = 128 + 1024 + (3 * 31 + 9 * 32)*9 = 29691 clk
// 一邊做一邊要資料，雖然判斷跟多工器比較複雜，但消耗 clk 數為 input 4*32 + output and calculate 1024 * 9 = 9344 clk
// 差了三倍的時間，多出來的暫存器數量忽略不計，我決定先以一邊輸入一邊做運算來做。
// ** 此想法發現到不能偵測物件是否有被編號過，所以此想法捨棄

// 改成了先把 ROM 輸入至 SRAM，再掃描 SRAM，當掃描到物件(編號 >= 1)，生成九宮格做判斷，再把九宮格填回 SRAM
// 原方法使用 3* 32bits * 8 bits = 768 bits 的暫存器(不含九宮格的暫存器存資料)
// 改成了只用九宮格暫存器存資料 9 * 8 bits = 72 bits
// ** 此想法不能解決「U 型」「雙重 U 型」或「S 型」連通體

`timescale 1ns/10ps
//`include ""
module CLE ( clk, reset, rom_q, rom_a, sram_q, sram_a, sram_d, sram_wen, finish);
input         clk;
input         reset; // 高位準非同步
input  [7:0]  rom_q; // ***該筆資料的MSB為【X軸座標00、Y軸座標00】， LSB為【X軸座標00、Y軸座標07】
output reg [6:0]  rom_a;
input  [7:0]  sram_q;
output reg [9:0]  sram_a;
output reg [7:0]  sram_d;
output reg    sram_wen; // 當該訊號為 Low，表示 CLE 要對 SRAM 作寫入，反之，當該訊號為 High，表示 CLE 要對 SRAM 作讀取。該訊號直接與 SRAM 的控制訊號腳位 WEN 相連。
output reg    finish;

//FSM
reg [3:0] state;
localparam INPUT_ROM = 4'd0,
           STORE_SRAM = 4'd1,
           FIND_OBJECT = 4'd2,
           CALC = 4'd3,
           INPUT_3x3_GRID = 4'd4,
           OUTPUT_3x3_GRID = 4'd5,
           READ_SRAM = 4'd6,
           UPDATE_X_Y = 4'd7;
//----------------------------------------
// address
// 我的 x, y 跟題目方向相反
reg [4:0] output_x, y; // 32*32
reg [1:0] input_x;     // 4 *32

wire [6:0] input_addr;
wire [9:0] output_addr;
assign input_addr = {y, input_x};
assign output_addr = {y, output_x};
//----------------------------------------
// 九宮格
reg [3:0] cnt; 
// [0 3 6]   0:(x-1, y-1)   3:(x, y-1)   6:(x+1, y-1)
// [1 4 7]   1:(x-1, y)     4:(x, y)     7:(x+1, y)
// [2 5 8]   2:(x-1, y+1)   5:(x, y+1)   8:(x+1, y+1)
reg [7:0] pixel [8:0]; // 9個 pixel, 8 bits

// 共用位址
wire [4:0] x_plus_1, x_minus_1, y_plus_1, y_minus_1;
assign x_plus_1 = output_x + 1'd1;
assign x_minus_1 = output_x - 1'd1;
assign y_plus_1 = y + 1'd1;
assign y_minus_1 = y - 1'd1;
//----------------------------------------
// 編號電路
// 判斷此 pixel[i] 是沒編號的物件? 還是編號過的物件? 還是不是物件?
wire is_object_has_num, is_object_no_num;
wire is_object;
assign is_object = is_object_has_num || is_object_no_num;
assign is_object_has_num = (sram_q > 8'd1);
assign is_object_no_num = (sram_q == 8'd1);

// 在 FIND_OBJECT、INPUT_3x3_GRID 找有被編號過的最大值、最小值，並且把最大值、最小值存下來
// 如果沒有任何一個 pixel 有標籤(num_max == 0 || num_min == 8'hff)，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 next_num
// 如果最大最小不相等，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 num_min
// 如果最大最小相等，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 num_max or num_min
reg [7:0] num_min, num_max;
reg [7:0] next_num; // 8’h01 ~ 8’hFB ，我的設計為 未編號過的物件為 h01，所以有編號過的都是從 h02 開始

// 紀錄九個 pixel 哪個是物件 0~8 分別對應 pixel 0~8
reg [8:0] is_object_pixel;

reg is_grid_change_pixel; // 如果在 32*32 圖中發生 num_min != num_max，代表有物件相連，但前面的 pixel 沒有統一數字，所以必須整張圖重新掃描
wire max_se_sram_q, min_ge_sram_q;
assign max_se_sram_q = num_max <= sram_q;
assign min_ge_sram_q = num_min >= sram_q;
//----------------------------------------
// 正緣觸發 clk
always @(posedge clk or posedge reset) begin
    if (reset) begin
        // reset singal
        state <= INPUT_ROM;
        input_x <= 0; output_x <= 0; y <= 0; // 一開始先把 ROM 輸入至 SRAM
        cnt <= 0;
        next_num <= 8'd2;
        num_max <= 0; num_min <= 8'hff; // max 設最小，min 設最大
        is_object_pixel <= 0;
        is_grid_change_pixel <= 0;
        // module
        finish <= 0;
    end else begin
        case (state)
            INPUT_ROM: begin // 此 clk 的負緣輸入 input_addr，所以下個 正緣 clk 可以直接取到在此 負緣 clk 給的位置
                // 在此位置輸入 (0,0) -> 輸出 X軸=00, Y軸=00 ~ 07 的 pixel，下個 clk 可取值
                state <= STORE_SRAM; // 下個 state 準備寫入 SRAM
            end

            STORE_SRAM: begin
                // 接收到 (0,0) 的 8 個 pixel 資料，填入 SRAM (一開始已經指定 output_addr 為 (0,0)，所以可以直接填入)
                // sram_wen 預設為 0 -> DATA IN
                // 在當前 posedge clk 把 addr 準備好，在 negedge clk 把 data 及 addr 輸入至 SRAM or ROM，下一個正緣 SRAM 跟 ROM 都能收到穩定的資料
                // 就不會 Hold Time violation
                cnt <= cnt + 1'd1;
                output_x <= output_x + 1'd1;
                if (cnt == 4'd7) begin
                    // 因為 ROM 是接收到位置，下一個 clk 才會輸出 data，在第 8 個 clk 他收到了位置
                    // 此時他的輸出還在前一個，第 9 個 clk 他就會輸出 input_x + 1'd1 的值了
                    input_x <= input_x + 1'd1; 
                    cnt <= 0;
                    if (input_x == 2'd3) begin // 下一排，從 (0,1) 開始
                        y <= y + 1'd1;
                        if (y == 5'd31) begin
                            state <= READ_SRAM;
                            // 把等等要掃描 SRAM 的 x y 重製成 (1,1) 開始
                            output_x <= 1'd1;
                            y <= 1'd1;        
                        end
                    end
                end
            end

            READ_SRAM: begin // 此 clk 負緣給出 READ 模式及 READ_addr，所以下一個正緣(FIND_OBJECT)就可以讀到資料了
                // negedge clk 給出 pixel [4] 的位置
                state <= FIND_OBJECT;
            end

            // 從 (1,1) 掃到 (30,30)，找出物件(>= 1)，此外現在已經是 read 模式(在負緣 clk 改變的)
            FIND_OBJECT: begin // negedge clk 給出 pixel [0] 的位置
                if (is_object) begin 
                    // 找到物件，先存入中心點資料，且 state 跳轉到 INPUT_3x3_GRID
                    pixel[4] <= sram_q; // 中心點 (x, y)
                    is_object_pixel[4] <= 1'd1;
                    if (is_object_has_num) begin // 如果物件有被編號過 (pixel > 1)
                        // 在 FIND_OBJECT、INPUT_3x3_GRID 找有被編號過的最大值、最小值，並且把最大值、最小值存下來
                        // 如果沒有任何一個 pixel 有標籤(num_max == 0 || num_min == 8'hff)，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 next_num
                        // 如果最大最小不相等，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 num_min
                        // 如果最大最小相等，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 num_max or num_min
                        if (max_se_sram_q) begin
                            num_max <= sram_q; 
                        end
                        if (min_ge_sram_q) begin
                            num_min <= sram_q; 
                        end
                    end
                    state <= INPUT_3x3_GRID; // 跳轉到輸入九宮格狀態

                end else begin
                    // 若當前中心點不是物件，移動至下一個座標
                    state <= UPDATE_X_Y;
                end
            end

            // 更新座標
            UPDATE_X_Y: begin
                output_x <= output_x + 1'd1;
                if (output_x == 5'd30) begin
                    output_x <= 5'd1;
                    y <= y + 1'd1;
                    if (y == 5'd30) begin // 掃描完 (1,1) ~ (30,30) 結束
                        if (is_grid_change_pixel) begin // 如果出現相連物件編號錯誤，那就整張圖重跑，直到沒有編號錯誤為止
                            state <= READ_SRAM;
                            is_grid_change_pixel <= 0;
                            // 把等等要掃描 SRAM 的 x y 重製成 (1,1) 開始
                            output_x <= 1'd1;
                            y <= 1'd1;
                        end else begin
                            finish <= 1'd1; 
                        end
                    end
                end
                state <= READ_SRAM;
            end

            // 專門抓取九宮格周圍 8 個 pixel 的狀態
            INPUT_3x3_GRID: begin
                cnt <= cnt + 1'd1;
                // 負緣位址會提前給出，正緣依序把 SRAM 資料抓入九宮格 pixel 陣列
                case (cnt)
                    0: begin
                        pixel[0] <= sram_q; // 左上 (x-1, y-1)
                        if (is_object) is_object_pixel[0] <= 1'd1;
                        if (is_object_has_num) begin // 如果物件有被編號過 (pixel > 1)
                            // 在 FIND_OBJECT、INPUT_3x3_GRID 找有被編號過的最大值、最小值，並且把最大值、最小值存下來
                            // 如果沒有任何一個 pixel 有標籤(num_max == 0 || num_min == 8'hff)，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 next_num
                            // 如果最大最小不相等，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 num_min
                            // 如果最大最小相等，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 num_max or num_min
                            if (max_se_sram_q) begin
                                num_max <= sram_q; 
                            end
                            if (min_ge_sram_q) begin
                                num_min <= sram_q; 
                            end
                        end
                    end
                    1: begin
                        pixel[1] <= sram_q; // 左中 (x-1, y)
                        if (is_object) is_object_pixel[1] <= 1'd1;
                        if (is_object_has_num) begin // 如果物件有被編號過 (pixel > 1)
                            if (max_se_sram_q) begin
                                num_max <= sram_q; 
                            end
                            if (min_ge_sram_q) begin
                                num_min <= sram_q; 
                            end
                        end
                    end
                    2: begin
                        pixel[2] <= sram_q; // 左下 (x-1, y+1)
                        if (is_object) is_object_pixel[2] <= 1'd1;
                        if (is_object_has_num) begin // 如果物件有被編號過 (pixel > 1)
                            if (max_se_sram_q) begin
                                num_max <= sram_q; 
                            end
                            if (min_ge_sram_q) begin
                                num_min <= sram_q; 
                            end
                        end
                    end
                    3: begin
                        pixel[3] <= sram_q; // 中上 (x, y-1)
                        if (is_object) is_object_pixel[3] <= 1'd1;
                        if (is_object_has_num) begin // 如果物件有被編號過 (pixel > 1)
                            if (max_se_sram_q) begin
                                num_max <= sram_q; 
                            end
                            if (min_ge_sram_q) begin
                                num_min <= sram_q; 
                            end
                        end
                    end
                    4: begin
                        pixel[5] <= sram_q; // 中下 (x, y+1)
                        if (is_object) is_object_pixel[5] <= 1'd1;
                        if (is_object_has_num) begin // 如果物件有被編號過 (pixel > 1)
                            if (max_se_sram_q) begin
                                num_max <= sram_q; 
                            end
                            if (min_ge_sram_q) begin
                                num_min <= sram_q; 
                            end
                        end
                    end
                    5: begin
                        pixel[6] <= sram_q; // 右上 (x+1, y-1)
                        if (is_object) is_object_pixel[6] <= 1'd1;
                        if (is_object_has_num) begin // 如果物件有被編號過 (pixel > 1)
                            if (max_se_sram_q) begin
                                num_max <= sram_q; 
                            end
                            if (min_ge_sram_q) begin
                                num_min <= sram_q; 
                            end
                        end
                    end
                    6: begin
                        pixel[7] <= sram_q; // 右中 (x+1, y)
                        if (is_object) is_object_pixel[7] <= 1'd1;
                        if (is_object_has_num) begin // 如果物件有被編號過 (pixel > 1)
                            if (max_se_sram_q) begin
                                num_max <= sram_q; 
                            end
                            if (min_ge_sram_q) begin
                                num_min <= sram_q; 
                            end
                        end
                    end
                    7: begin
                        pixel[8] <= sram_q;// 右下 (x+1, y+1)
                        if (is_object) is_object_pixel[8] <= 1'd1;
                        if (is_object_has_num) begin // 如果物件有被編號過 (pixel > 1)
                            if (max_se_sram_q) begin
                                num_max <= sram_q; 
                            end
                            if (min_ge_sram_q) begin
                                num_min <= sram_q; 
                            end
                        end
                        cnt <= 0; // reset
                        state <= CALC;
                    end
                    default: ;
                endcase
            end

            CALC: begin
                // 如果沒有任何一個 pixel 有標籤(num_max == 0 || num_min == 8'hff)，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 next_num
                // 如果最大最小不相等，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 num_min
                // 如果最大最小相等，就把 (pixel[i] >= 1) 的所有 pixel 全部改為 num_max or num_min
                if (num_min == 8'hff) begin 
                    // 九宮格內都是沒有編號過的物件，給新編號
                    pixel[0] <= (is_object_pixel[0]) ? next_num : 0;
                    pixel[1] <= (is_object_pixel[1]) ? next_num : 0;
                    pixel[2] <= (is_object_pixel[2]) ? next_num : 0;
                    pixel[3] <= (is_object_pixel[3]) ? next_num : 0;
                    pixel[4] <= (is_object_pixel[4]) ? next_num : 0;
                    pixel[5] <= (is_object_pixel[5]) ? next_num : 0;
                    pixel[6] <= (is_object_pixel[6]) ? next_num : 0;
                    pixel[7] <= (is_object_pixel[7]) ? next_num : 0;
                    pixel[8] <= (is_object_pixel[8]) ? next_num : 0;
                    next_num <= next_num + 1'd1;
                end else if (num_min != num_max) begin
                    // 九宮格有物件編號不一樣
                    is_grid_change_pixel <= 1'd1;
                    pixel[0] <= (is_object_pixel[0]) ? num_min : 0;
                    pixel[1] <= (is_object_pixel[1]) ? num_min : 0;
                    pixel[2] <= (is_object_pixel[2]) ? num_min : 0;
                    pixel[3] <= (is_object_pixel[3]) ? num_min : 0;
                    pixel[4] <= (is_object_pixel[4]) ? num_min : 0;
                    pixel[5] <= (is_object_pixel[5]) ? num_min : 0;
                    pixel[6] <= (is_object_pixel[6]) ? num_min : 0;
                    pixel[7] <= (is_object_pixel[7]) ? num_min : 0;
                    pixel[8] <= (is_object_pixel[8]) ? num_min : 0;
                end else begin
                    // 九宮格編號沒有衝突
                    pixel[0] <= (is_object_pixel[0]) ? num_min : 0;
                    pixel[1] <= (is_object_pixel[1]) ? num_min : 0;
                    pixel[2] <= (is_object_pixel[2]) ? num_min : 0;
                    pixel[3] <= (is_object_pixel[3]) ? num_min : 0;
                    pixel[4] <= (is_object_pixel[4]) ? num_min : 0;
                    pixel[5] <= (is_object_pixel[5]) ? num_min : 0;
                    pixel[6] <= (is_object_pixel[6]) ? num_min : 0;
                    pixel[7] <= (is_object_pixel[7]) ? num_min : 0;
                    pixel[8] <= (is_object_pixel[8]) ? num_min : 0;
                end

                num_max <= 0; num_min <= 8'hff; // max 設最小，min 設最大
                is_object_pixel <= 0;
                state <= OUTPUT_3x3_GRID;
            end

            OUTPUT_3x3_GRID: begin
                cnt <= cnt + 1'd1;
                // 當 cnt == 8時，表示最後一個點 pixel[8] 在下一個正緣(UPDATE_X_Y) 寫入
                if (cnt == 4'd8) begin
                    cnt <= 0;
                    state <= UPDATE_X_Y;
                end
            end

            default: ;
        endcase
    end
end

//----------------------------------------
// 負緣觸發 clk
// 輸出到 SRAM/ROM 的訊號改為負緣觸發送出，這樣在正緣觸發時就能取到穩定的資料，就不會 hold time violation
always @(negedge clk or posedge reset) begin
    if (reset) begin
        rom_a <= 0;
        sram_a <= 0;
        sram_d <= 0;
        sram_wen <= 1'd1; // 初始為 READ 防止資料被寫入 X
    end else begin
        case (state)
            INPUT_ROM: begin
                rom_a <= input_addr; // 一開始先給 (0,0)
            end

            // 在當前 posedge clk 把 addr 準備好，在 negedge clk 把 data 及 addr 輸入至 SRAM or ROM，下一個正緣 SRAM 跟 ROM 都能收到穩定的資料
            STORE_SRAM: begin
                sram_a <= output_addr;
                sram_d <= {7'b0, rom_q[3'd7 - cnt]}; // ***該筆資料的MSB為【X軸座標00、Y軸座標00】， LSB為【X軸座標00、Y軸座標07】-> 第一次搞反了害我 DEBUG 那麼久
                sram_wen <= 0; // 寫入模式

                // 提早一個 cycle 將下一個位置送給 ROM
                // 在 cnt == 7 的正緣 下一個正緣 clk -> input_addr + 1
                // 但在 cnt == 7 的負緣它提前給 rom_a 下一個位置，所以下一個正緣 cnt == 0 它收到了位置資料，延遲了一點點時間給出，並在下一個負緣(cnt == 0)把資料寫入 SRAM
                if (cnt == 4'd7) begin 
                    rom_a <= input_addr + 1'd1; 
                end
            end

            READ_SRAM: begin
                sram_wen <= 1'd1; // 讀取模式
                sram_a <= output_addr; // 此為 pixel[4] 中心點的位置
            end

            FIND_OBJECT: begin
                sram_wen <= 1'd1; // 讀取模式
                if (is_object) begin
                    // 當在正緣偵測到物件，負緣送出九宮格第 0 個點 (x-1, y-1) 的位址 for 下一個 posedge clk
                    sram_a <= {y_minus_1, x_minus_1}; // 要 pixel[0]
                end else begin
                    // 當前不是物件，位址跟著 output_addr 更新以讀取下個像素，以判斷中心點是否為物件
                    sram_a <= output_addr;
                end
            end

            // 從 OUTPUT_3x3_GRID 出來時，必須在負緣把 sram_wen 切回讀取模式，並把新座標給 sram_a
            UPDATE_X_Y: begin
                sram_wen <= 1'b1; // 切回讀取模式
                sram_a <= output_addr; // 提前送出更新後的位址
            end

            INPUT_3x3_GRID: begin
                sram_wen <= 1'd1; // 讀取模式
                // 在負緣送出下一個正緣要讀的 SRAM addr
                case (cnt)
                    0: sram_a <= {y,         x_minus_1}; // 要 pixel[1] -> (x-1, y)
                    1: sram_a <= {y_plus_1,  x_minus_1}; // 要 pixel[2] -> (x-1, y+1)
                    2: sram_a <= {y_minus_1, output_x }; // 要 pixel[3] -> (x, y-1)
                    3: sram_a <= {y_plus_1,  output_x }; // 要 pixel[5] -> (x, y+1)
                    4: sram_a <= {y_minus_1, x_plus_1 }; // 要 pixel[6] -> (x+1, y-1)
                    5: sram_a <= {y,         x_plus_1 }; // 要 pixel[7] -> (x+1, y)
                    6: sram_a <= {y_plus_1,  x_plus_1 }; // 要 pixel[8] -> (x+1, y+1)
                    default: sram_a <= output_addr;
                endcase
            end

            OUTPUT_3x3_GRID: begin
                // 在負緣送出九宮格對應的位址與資料
                sram_wen <= 0; // 寫入模式
                case (cnt)
                    0: begin
                        sram_a <= {y_minus_1, x_minus_1}; // pixel[0] -> 左上 (x-1, y-1)
                        sram_d <= pixel[0];
                    end
                    1: begin
                        sram_a <= {y, x_minus_1};         // pixel[1] -> 左中 (x-1, y)
                        sram_d <= pixel[1];
                    end
                    2: begin
                        sram_a <= {y_plus_1, x_minus_1};  // pixel[2] -> 左下 (x-1, y+1)
                        sram_d <= pixel[2];
                    end
                    3: begin
                        sram_a <= {y_minus_1, output_x};  // pixel[3] -> 中上 (x, y-1)
                        sram_d <= pixel[3];
                    end
                    4: begin
                        sram_a <= {y, output_x};          // pixel[4] -> 中心 (x, y)
                        sram_d <= pixel[4];
                    end
                    5: begin
                        sram_a <= {y_plus_1, output_x};   // pixel[5] -> 中下 (x, y+1)
                        sram_d <= pixel[5];
                    end
                    6: begin
                        sram_a <= {y_minus_1, x_plus_1};  // pixel[6] -> 右上 (x+1, y-1)
                        sram_d <= pixel[6];
                    end
                    7: begin
                        sram_a <= {y, x_plus_1};          // pixel[7] -> 右中 (x+1, y)
                        sram_d <= pixel[7];
                    end
                    8: begin
                        sram_a <= {y_plus_1, x_plus_1};   // pixel[8] -> 右下 (x+1, y+1)
                        sram_d <= pixel[8];
                    end
                    default: begin
                        sram_a <= output_addr;
                        sram_d <= 0;
                    end
                endcase
            end

            default: ; 
        endcase
    end
end

endmodule
