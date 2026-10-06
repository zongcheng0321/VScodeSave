// 此題實作了 posedge clk 跟 negedge clk 平行使用的電路(為了符合記憶體延遲以及處理 hold time violation 之問題)
// parallel two-pass CCL algorithm 有可能是這題的解答演算法，之後可以研究看看
// 經詢問過 AI 我的演算法確實有問題，當碰到 U 型連通體，右上角那格無法被改變到，但題目也只給 3 個 pattern 應該沒有隱藏的
//         x=2       x=3       x=4
// y=2   [ 02 ]    [ 00 ]    [ 03 ]  <-- 殘留 03！
// y=3   [ 02 ]    [ 00 ]    [ 02 ]  
// y=4   [ 02 ]    [ 02 ]    [ 02 ]  
//====================================
// 記憶體操作及使用要參照 pdf 文件
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
// 原方法使用 3* 32bits * 8 bits = 7686 bits 的暫存器(不含九宮格的暫存器存資料)
// 改成了只用九宮格暫存器存資料 9 * 8 bits = 72 bits

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


// ** TB 已經把我的記憶體宣告在那邊了，我不能在這邊再宣告一次
// ROM and SRAM
// rom_128x8 u_rom ( 
//    .Q(rom_q), // 看 pdf 大概負緣送出資料
//    .CLK(~clk),//** 改成了用負緣接收位置訊號，且負緣送出訊號
//    .CEN(0),
//    .A(rom_a)
// );
// sram_1024x8 u_sram (
//    .Q(sram_q), // 看 pdf -> 寫入或讀取都是負緣前送出資料 
//    .CLK(~clk), //** 改成了用負緣接收位置訊號，且負緣送出訊號
//    .CEN(0),
//    .WEN(sram_wen), // L 寫入 H 讀取
//    .A(sram_a),
//    .D(sram_d)
// );

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
// 0 的權重大於 1； 1 大於 2； 2 大於 3...
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
wire is_object;
assign is_object = (sram_q >= 8'd1);
reg [7:0] num;
reg [7:0] next_num; // 8’h01 ~ 8’hFB ，我的設計為 未編號過的物件為 h01，所以有編號過的都是從 h02 開始
//----------------------------------------
// 判斷是否還未編號過
// 檢查 9 個 pixel 是否有任何一個已經編號過 (數值 > 8'd1)
wire [8:0] is_labeled;
assign is_labeled[0] = (pixel[0] > 8'd1);
assign is_labeled[1] = (pixel[1] > 8'd1);
assign is_labeled[2] = (pixel[2] > 8'd1);
assign is_labeled[3] = (pixel[3] > 8'd1);
assign is_labeled[4] = (pixel[4] > 8'd1);
assign is_labeled[5] = (pixel[5] > 8'd1);
assign is_labeled[6] = (pixel[6] > 8'd1);
assign is_labeled[7] = (pixel[7] > 8'd1);
assign is_labeled[8] = (pixel[8] > 8'd1);
//----------------------------------------
// 正緣觸發 clk
always @(posedge clk or posedge reset) begin
    if (reset) begin
        // reset singal
        state <= INPUT_ROM;
        input_x <= 0; output_x <= 0; y <= 0; // 一開始先把 ROM 輸入至 SRAM
        cnt <= 0;
        next_num <= 8'd2;
        // module
        finish <= 0;
        
    end else begin
        case (state)
            /*INPUT_ROM: begin // 此時位置已更新好，給出要資料的位置，下一個 clk 接收資料
                cnt <= cnt + 1'd1;
                accept_data <= 1'd1;

                if (cnt == 4'd1 || cnt == 4'd3 || cnt == 4'd5 || cnt == 4'd7) begin
                    input_x <= input_x + 1'd1;
                end

                // state 改變
                if (accept_data) begin
                    accept_data <= 0;
                    case ({choose_row_to_input, cnt})
                        // 一般情況(第四排開始)
                        {2'd0, 4'd1}: begin
                            row_3[7:0] <= rom_q;
                            row_2 <= row_3;
                            row_1 <= row_2;
                        end
                        {2'd0, 4'd3}: begin
                            row_3[15:8] <= rom_q;
                        end
                        {2'd0, 4'd5}: begin
                            row_3[23:16] <= rom_q;
                        end
                        {2'd0, 4'd7}: begin
                            row_3[31:24] <= rom_q;
                            cnt <= 0;
                        end
                        // 第一排(reset 後預設 choose_row_to_input 為 1)
                        {2'd1, 4'd1}: begin
                            row_1[7:0] <= rom_q;
                        end
                        {2'd1, 4'd3}: begin
                            row_1[15:8] <= rom_q;
                        end
                        {2'd1, 4'd5}: begin
                            row_1[23:16] <= rom_q;
                        end
                        {2'd1, 4'd7}: begin
                            row_1[31:24] <= rom_q;
                            cnt <= 0;
                            choose_row_to_input <= 2'd2;
                        end
                        // 第二排(reset 後預設 choose_row_to_input 為 1)
                        {2'd2, 4'd1}: begin
                            row_2[7:0] <= rom_q;
                        end
                        {2'd3, 4'd3}: begin
                            row_2[15:8] <= rom_q;
                        end
                        {2'd2, 4'd5}: begin
                            row_2[23:16] <= rom_q;
                        end
                        {2'd2, 4'd7}: begin
                            row_2[31:24] <= rom_q;
                            cnt <= 0;
                            choose_row_to_input <= 2'd3;
                        end
                        // 第三排(reset 後預設 choose_row_to_input 為 1)
                        {2'd3, 4'd1}: begin
                            row_3[7:0] <= rom_q;
                        end
                        {2'd3, 4'd3}: begin
                            row_3[15:8] <= rom_q;
                        end
                        {2'd3, 4'd5}: begin
                            row_3[23:16] <= rom_q;
                        end
                        {2'd3, 4'd7}: begin
                            row_3[31:24] <= rom_q;
                            cnt <= 0;
                            choose_row_to_input <= 0;
                            state <= CALC;
                        end
                        
                        default: ;
                    endcase
                end
            end*/

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
                state <= FIND_OBJECT;
            end

            // 從 (1,1) 掃到 (30,30)，找出物件(>= 1)，此外現在已經是 read 模式(在負緣 clk 改變的)
            FIND_OBJECT: begin
                if (is_object) begin // negedge clk 給出位置
                    // 找到物件，先存入中心點資料，且 state 跳轉到 INPUT_3x3_GRID
                    pixel[4] <= sram_q; // 中心點 (x, y)
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
                    if (y == 5'd30) begin
                        finish <= 1'd1; // 掃描完 (1,1) ~ (30,30) 結束
                    end
                end

                state <= READ_SRAM;
            end

            // 專門抓取九宮格周圍 8 個 pixel 的狀態
            INPUT_3x3_GRID: begin
                cnt <= cnt + 1'd1;
                // 負緣位址會提前給出，正緣依序把 SRAM 資料抓入九宮格 pixel 陣列
                case (cnt)
                    0: pixel[0] <= sram_q; // 左上 (x-1, y-1)
                    1: pixel[1] <= sram_q; // 左中 (x-1, y)
                    2: pixel[2] <= sram_q; // 左下 (x-1, y+1)
                    3: pixel[3] <= sram_q; // 中上 (x, y-1)
                    4: pixel[5] <= sram_q; // 中下 (x, y+1)
                    5: pixel[6] <= sram_q; // 右上 (x+1, y-1)
                    6: pixel[7] <= sram_q; // 右中 (x+1, y)
                    7: begin
                        pixel[8] <= sram_q;// 右下 (x+1, y+1)
                        cnt <= 0;
                        state <= CALC;     // 抓完 8 個鄰居，進入運算狀態
                    end
                    default: ;
                endcase
            end

            CALC: begin
                // 判斷 pixel 是否有被編號過，如果有被編號過(h01以外的值)，就依照權重把所有 pixel 全部改為那個 num
                // 如果沒有被編號過(h01)，就全部 pixel 全部改成 next_num

                cnt <= cnt + 1'd1;
                if (cnt <= 4'd8) begin
                    if (is_labeled[8 - cnt]) begin
                        num <= pixel[8 - cnt];
                    end
                end
                if (cnt == 4'd9) begin
                    cnt <= 0;
                    if (|is_labeled) begin // 如果其中一個為有編號過的，那就只要 pixel 不等於 0 就填為 num
                        pixel[0] <= (pixel[0] != 0) ? num : 0;
                        pixel[1] <= (pixel[1] != 0) ? num : 0;
                        pixel[2] <= (pixel[2] != 0) ? num : 0;
                        pixel[3] <= (pixel[3] != 0) ? num : 0;
                        pixel[4] <= (pixel[4] != 0) ? num : 0;
                        pixel[5] <= (pixel[5] != 0) ? num : 0;
                        pixel[6] <= (pixel[6] != 0) ? num : 0;
                        pixel[7] <= (pixel[7] != 0) ? num : 0;
                        pixel[8] <= (pixel[8] != 0) ? num : 0;
                    end else begin
                        pixel[0] <= (pixel[0] != 0) ? next_num : 0;
                        pixel[1] <= (pixel[1] != 0) ? next_num : 0;
                        pixel[2] <= (pixel[2] != 0) ? next_num : 0;
                        pixel[3] <= (pixel[3] != 0) ? next_num : 0;
                        pixel[4] <= (pixel[4] != 0) ? next_num : 0;
                        pixel[5] <= (pixel[5] != 0) ? next_num : 0;
                        pixel[6] <= (pixel[6] != 0) ? next_num : 0;
                        pixel[7] <= (pixel[7] != 0) ? next_num : 0;
                        pixel[8] <= (pixel[8] != 0) ? next_num : 0;
                        next_num <= next_num + 1'd1;
                    end
                    state <= OUTPUT_3x3_GRID;
                end
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
