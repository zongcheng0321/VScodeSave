// ver1
// 關於排序：實作 quick/heap sort -> AI 說 verilog 不能做，需要用到 stack
// Bitonic、Odd-Even Merge、Odd-Even Transposition、Shift Register Insertion、Radix Sort -> 硬體使用的排序演算法
// 這題主要在考如何排序的方法

// 做完 SORT1 去跑合成(compile 面積effort map effort) timing +0.94 area 11618
// 後面發現如果使用奇偶排序，先排完顏色再排強度，排強度因為顏色有三種，而每個顏色最多32張圖，還必須根據多少個同個顏色的圖去啟用多少個比較器長出 3*32 個多工器
// 這樣想想面積都覺得大，所以我可能要先放棄想法: "先排顏色後，後對三塊未知長度的子陣列分別排強度"
// 1. 奇偶排序還有另一個做法就是先排所有強度，後排顏色(試試看)
// 2. 改為 bubble_sort(顏色先排)
// 3. AI 提供另外兩種我沒想到的比較好的解法(甚至不用排顏色) 詳情見*** 「AI提供的想法.md」***
//------------------------------------------
// 原本程式為先排顏色後排序 -> 捨棄
//------------------------------------------
`timescale 1ns/10ps
module ISE( clk, reset, image_in_index, pixel_in, busy, out_valid, color_index, image_out_index);
input              clk;   // 本系統為同步於時脈正緣之同步設計。 (註: Host 端採clk ”正”緣時送資料。) 
input              reset; // 高位準”非”同步(active high asynchronous)之系統重置信號。 
input   [4:0]      image_in_index;
input   [23:0]     pixel_in;
output reg         busy; // ISE 忙碌之控制訊號。當為High時，表示系統正處於忙碌階段，告知Host端，暫時停止pixel_in資料的輸入；反之，當為Low時，表示告知Host端可繼續由pixel_in 輸入資料。
output reg         out_valid;
output reg [1:0]   color_index;
output reg [4:0]   image_out_index; // ISE 影像所屬index值之輸出匯流排。當影像色彩分類與排序完成後，可透過此匯流排將各影像所屬之index值依序輸出。

parameter FRAC_BIT = 10;
//integer i;

// FSM
reg [3:0] state;
localparam DECIDE_PIXEL_COLOR = 4'd0, // 判斷單一 Pixel 是否為 R or G or B
           IMAGE_CLASS = 4'd1,
           AVG_INTENSITY = 4'd2,
           SORT1 = 4'd3,              // 先排顏色
           SORT2_RED = 4'd4,          // 再排強度
           SORT2_GREEN = 4'd5,
           SORT2_BLUE = 4'd6;
//------------------------------------------
// current image_in_index
// 不用計數 pixel 的方式去判斷是因為要多宣告 14 bits 的計數器，那不如我多花一個 clk 的時間去判斷當前圖的 image_in_index，只花 1 reg 跟 1 clk
// 發現到最後一張圖無法用 curr_image != image_in_index 去判斷是否最後一個 pixel 了，因為最後一個 pixel 輸入完後會變成高阻抗無法比對
// 所以還是必須用計數器計數 16384 個 pixel
reg [4:0] curr_image; // 用以判斷當切換到下一張圖時，busy 要拉高暫停電路
reg [13:0] pixel_cnt;

// 該影像被歸類為某色 pixel 的強度加總 -> 當成除法器分子
reg [21:0] R_intensity_sum, G_intensity_sum, B_intensity_sum;

// 把每張圖每個 pixel 的 color 存起來，用來判斷 1. 此圖是什麼類別(color_index) 2. 且當成除法器的被除數
reg [13:0] pixel_color_R_total, pixel_color_G_total, pixel_color_B_total;
reg [1:0] color_index_store [31:0];             // 最終結果是排序過後的
reg [FRAC_BIT + 8 - 1 : 0] Avg_intensity [31:0];// 最終結果是排序過後的(由小到大 = 由暗到亮)；FRAC_BIT + 8 為小數點 + 整數的 bits
reg [4:0] image_num [31:0];                     // 裡面放得是排序過的 image number

wire cmp_pixel_color_R_ge_G, cmp_pixel_color_R_ge_B, cmp_pixel_color_G_ge_B; // ge = greater than or equal
assign cmp_pixel_color_R_ge_G = pixel_in[23:16] >= pixel_in[15:8]; // R >= G
assign cmp_pixel_color_R_ge_B = pixel_in[23:16] >= pixel_in[7:0];  // R >= B
assign cmp_pixel_color_G_ge_B = pixel_in[15:8] >= pixel_in[7:0];   // G >= B

// 得出該 image 的類別
wire cmp_class_R_g_G, cmp_class_G_g_B, cmp_class_R_g_B;
assign cmp_class_R_g_G = pixel_color_R_total > pixel_color_G_total;
assign cmp_class_G_g_B = pixel_color_G_total > pixel_color_B_total;
assign cmp_class_R_g_B = pixel_color_R_total > pixel_color_B_total;
//------------------------------------------
// 排序顏色時，原本想要一個 clk 就排完，但我想出的方法是使用兩個指標指向 G 或 B 要新增進去陣列的位置，搭配移位
// 但後續考慮移位時，發現不能去判斷 G、B 位置來選擇哪裡要移位，最差情況是全部移位，但每個位置全部都要判斷，加上每個位置的移位硬體，這樣面積會太大
// 必須一個一個 clk 慢慢排，這樣面積小，cycle 多花 32 or 64 而已，比較好
// 排序強度時，原本想要一個 clk 就排完，但想到說強度的 bits 可能會達到 FRAC_BIT + 8 bits 的大小，如果小數點很大，比較器就很大，而且 32 個位置要一次比較
// 比較器會花很多，大 bits 又很多比較器會很消耗面積，所以考慮一個一個 clk 慢慢排，減少比較器數量

// 如果使用奇偶排序法，最多會耗 N 也就是 32 clk -> 320 ns，時間多沒多少，但會花 32 個比較器
// 如果使用氣泡排序之類的，最多會耗 N^2 也就是 1,024 clk -> 10240 ns，時間多一萬，面積只花一個比較器
// 兩者時間差了 
// 16384(每個 pixel)*32 + 64(得出每張圖的類別跟算出平均強度) + 64(排序顏色最多花) 同乘 10 + 10240 = 5,254,400
// 16384(每個 pixel)*32 + 64(得出每張圖的類別跟算出平均強度) + 64(排序顏色最多花) 同乘 10 + 320 = 5,244,480
// 所以氣泡排序時間只差奇偶排序 1.00189 倍 -> 假設我要用奇偶排序法: 那麼面積就不能多出 1.00189 倍 -> 32 個比較器面積不能多出一倍
// 我思考了一下還是決定先試奇偶排序

// SORT1
// 先排顏色，總共做 32 + 32 clk
// reg [4:0] G_pointer, B_pointer; // 指向 G 或 B 要新增進去陣列的位置
reg [4:0] pointer; // 預設先指向最後
reg [4:0] cnt;
reg is_sort_green; // 現在是排序藍色當中嗎? 0 為 排序藍色 1 為 排序綠色
reg has_color_red, has_color_green, has_color_blue;

// SORT2 奇偶排序
// 比偶數 (0>1, 2>3, 4>5,...)

// 比奇數 (1>2, 3>4, 5>6,...)
//------------------------------------------
// 除法器及乘法器
reg [22 + FRAC_BIT-1: 0] div_a; // 該影像被歸類為某色的某色 pixel 總強度
reg [13:0] div_b; // 總共多少某色的 pixel

/*
parameter tc_mode = 0;
parameter rem_mode = 1; // corresponds to "%" in Verilog

// 除法器分子1. 為 qx * SW-1 = 1830 -> 11 bits
//          2. x_q10 = (rx << 10)/(TW-1) -> 根據分子一定小於分母，TW-1 最大值為 60，所以 rx = 59，這樣為 6 bits + 10 bits = 16 bits
// 所以被除數要設為 16 bits
localparam a_width = 16;
localparam b_width = 6;  // 分母最大值為 60 (TW-1 or TH-1)
reg [a_width -1 : 0] a;
reg [b_width -1 : 0] b;
reg [a_width -1 : 0] quotient; // 不知道可不可以自訂這裡的寬度
reg [b_width -1 : 0] remainder;
wire divide_by_0;

// Please add +incdir+$SYNOPSYS/dw/sim_ver+ to your verilog simulator
// command line (for simulation).
// instance of DW_div

DW_div #(.a_width(a_width), 
        .b_width(b_width), 
        .tc_mode(tc_mode), 
        .rem_mode(rem_mode)) 
        DW_div1 (
        .a(a), 
        .b(b), 
        .quotient(quotient), 
        .remainder(remainder), 
        .divide_by_0(divide_by_0));

 */

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= DECIDE_PIXEL_COLOR;
        busy <= 0;
        out_valid <= 0;
        color_index <= 0;
        image_out_index <= 0;

        // reset
        pixel_color_R_total <= 0;
        pixel_color_G_total <= 0;
        pixel_color_B_total <= 0;
        R_intensity_sum <= 0;
        G_intensity_sum <= 0;
        B_intensity_sum <= 0;
        curr_image <= 0;
        pointer <= 5'd31; // 預設指向最後
        is_sort_green <= 0;
        cnt <= 0;
        pixel_cnt <= 0;
        has_color_red <= 0; has_color_green <= 0; has_color_blue <= 0;
        //div_a <= 0;
        //div_b <= 0;
        //x <= 0;
        //y <= 0;
    end else begin
        case (state)
            // 判斷單一 Pixel 是否為 R or G or B
            // 此時 busy 為 low 會一直送 pixel 進來
            // 同時加總 R、G、B 的強度
            DECIDE_PIXEL_COLOR: begin
                // 判斷單一 Pixel 是否為 R or G or B
                if (cmp_pixel_color_R_ge_G && cmp_pixel_color_R_ge_B) begin // R >= G && R >= B -> RED
                    pixel_color_R_total <= pixel_color_R_total + 1'd1;
                    // 加總各顏色的強度，用來當成除法器分子來算出平均訊號強度
                    R_intensity_sum <= R_intensity_sum + {14'd0, pixel_in[23:16]};
                end
                if (cmp_pixel_color_G_ge_B && !cmp_pixel_color_R_ge_G) begin // G >= B && G > R -> GREEN
                    pixel_color_G_total <= pixel_color_G_total + 1'd1;
                    // 加總各顏色的強度，用來當成除法器分子來算出平均訊號強度
                    G_intensity_sum <= G_intensity_sum + {14'd0, pixel_in[15:8]};
                end
                if (!cmp_pixel_color_R_ge_B && !cmp_pixel_color_G_ge_B) begin // B > R && B > G -> BLUE
                    pixel_color_B_total <= pixel_color_B_total + 1'd1;
                    // 加總各顏色的強度，用來當成除法器分子來算出平均訊號強度
                    B_intensity_sum <= B_intensity_sum + {14'd0, pixel_in[7:0]};
                end

                if (pixel_cnt == 14'd16383) begin
                    pixel_cnt <= 0;
                    busy <= 1'd1; // pixel 跑完 16394 個了，先暫停電路，算出影像的平均訊號強度
                    state <= IMAGE_CLASS; // 當換下一張圖時，狀態轉移
                end else begin
                    pixel_cnt <= pixel_cnt + 1'd1;
                end
            end

            // 得出該圖類別及輸入除法器的被除數以及除數，並且重製 image_num
            IMAGE_CLASS: begin
                case ({cmp_class_R_g_G, cmp_class_G_g_B, cmp_class_R_g_B}) // 找最大 -> 得出該圖類別
                    0, 1, 4: begin // 藍色最大
                        color_index_store[curr_image] <= 2'b10;
                        div_a <= B_intensity_sum << FRAC_BIT;
                        div_b <= pixel_color_B_total;
                        has_color_blue <= 1'd1;
                        // 順便排序，如果 critical path 太長就拆開成下個 state -> 不要這麼做，因為其餘判斷無法判斷說到底要哪個開始索引開始移位，如果要判斷這樣太消耗面積了
                        // 改成消耗 clk 去排序
                    end
                    2, 3: begin // 綠色最大
                        color_index_store[curr_image] <= 2'b01;
                        div_a <= G_intensity_sum << FRAC_BIT;
                        div_b <= pixel_color_G_total;
                        has_color_green <= 1'd1;
                    end
                    5, 6, 7: begin // 紅色最大
                        color_index_store[curr_image] <= 2'b00;
                        div_a <= R_intensity_sum << FRAC_BIT;
                        div_b <= pixel_color_R_total;
                        has_color_red <= 1'd1;
                        /* color_index_store[0] <= 2'b00;
                        G_pointer <= G_pointer + 1'd1;
                        B_pointer <= B_pointer + 1'd1;
                        for (i = 32; i > 0; i = i - 1) begin
                            color_index_store[i] <= color_index_store[i-1];
                        end */
                    end
                    default: ;
                endcase

                image_num[curr_image] <= curr_image; // 重製 image_num
                state <= AVG_INTENSITY;
            end

            AVG_INTENSITY: begin
                Avg_intensity[curr_image] <= div_a / div_b; // 應該會 timing violation
                busy <= 0; // 結束暫停
                curr_image <= curr_image + 1'd1;
                if (curr_image == 5'd31) begin 
                    state <= SORT1;
                end else begin
                    R_intensity_sum <= 0;
                    G_intensity_sum <= 0;
                    B_intensity_sum <= 0;
                    pixel_color_R_total <= 0;
                    pixel_color_G_total <= 0;
                    pixel_color_B_total <= 0;
                    state <= DECIDE_PIXEL_COLOR;
                end
            end

            // 先排顏色
            // 顏色可能會從缺
            SORT1: begin
                cnt <= cnt + 1'd1;
                // 狀態轉移條件
                if (cnt == pointer) begin // 當 cnt 跟 pointer 重疊
                    cnt <= 0;
                    //pointer <= 5'd31;
                    is_sort_green <= 1'd1;
                    if (is_sort_green == 1'd1) begin
                        state <= SORT2_RED;
                        pointer <= 5'd31;
                    end
                end

                if (!is_sort_green) begin // 排序藍色
                    if (color_index_store[cnt] == 2'b10) begin // 當前位置是藍色類別
                        color_index_store[cnt] <= color_index_store[pointer];
                        color_index_store[pointer] <= color_index_store[cnt];
                        Avg_intensity[cnt] <= Avg_intensity[pointer];
                        Avg_intensity[pointer] <= Avg_intensity[cnt];
                        image_num[cnt] <= image_num[pointer];
                        image_num[pointer] <= image_num[cnt];
                        pointer <= pointer - 1'd1;
                    end
                end else begin // 排序綠色
                    if (color_index_store[cnt] == 2'b01) begin // 當前位置是綠色類別
                        color_index_store[cnt] <= color_index_store[pointer];
                        color_index_store[pointer] <= color_index_store[cnt];
                        Avg_intensity[cnt] <= Avg_intensity[pointer];
                        Avg_intensity[pointer] <= Avg_intensity[cnt];
                        image_num[cnt] <= image_num[pointer];
                        image_num[pointer] <= image_num[cnt];
                        pointer <= pointer - 1'd1;
                    end
                end // 掃完最多 32 + 32 clk 就排序完成了
            end

            // 再排強度
            SORT2_RED: begin // 同一組 32 個比較器要判斷 3 次 for 3 color
                             // 顏色可能從缺，所以先判斷是否有這個顏色在電路中
                cnt <= cnt + 1'd1;
                if (has_color_red) begin
                    if (cnt == 5'd31) begin
                        cnt <= 0;
                        state <= SORT2_GREEN;
                    end else begin
                        
                    end
                end else begin
                    cnt <= 0;
                    state <= SORT2_GREEN;
                end
            end
            
            SORT2_GREEN: begin // 同一組 32 個比較器要判斷 3 次 for 3 color
            // 顏色可能從缺，所以先判斷是否有這個顏色在電路中


                

            end

            SORT2_BLUE: begin // 同一組 32 個比較器要判斷 3 次 for 3 color
            // 顏色可能從缺，所以先判斷是否有這個顏色在電路中
                /*                  if (!out_valid)
                                out_valid <= 1'd1;
                else 
                out_valid <= 0;
                color_index <= 0;
                image_out_index <= 0;  */
            end

            default: ;
        endcase
    end
end



endmodule
