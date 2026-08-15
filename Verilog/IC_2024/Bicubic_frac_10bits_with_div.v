// 學習到小數點的乘除操作、多項式的作法、除法器DW、乘以常數可用直式乘法推倒移位被乘數、算數位移的使用(<<< >>>)
// 四捨五入 兩種做法、小數點精準度判斷、如何取得小數點(利用除法器把被除數擴大 bits 才可得出數值，把商當成小數)

// 捨棄想法: 要多做 x or y 的四捨五入，因為除法器是無條件捨去，如果要四捨五入，除了被除數多 1 bit 然後去判斷 quotient LSB 是否為 1 去做 + 1 或維持原值之外
        //   因為如果被除數 + 1 bit 除法器面積就會變大，所以我利用 [被除數 + (除數 / 2)] / 除數的方式，這樣可以不用擴大除法器也可以得到四捨五入過後的商

// 精度到底要設定多少是一個很大的問題，一開始設定 10 bits 小數點，但發現好像不夠，錯了五個 + timing violation (slack 為負)
// 一開始不能把精度寫死，使用切片方式，要使用算術位移取代寫死切片

// 合成沒過，不能在兩個always都改變 cnt , state...

// 面積大的誇張769781um time:668668ns 

`timescale 1ns/10ps
// 可改 1. pipeline 除法器解決timing violation(-slack)
//     2. 改變除法規則 9/8 直接算不用取 rx
//     3. 改變變成不用除法器??只有乘法器
//     4. 多項式原本做法為 x * x -> 2o bits 後砍 10 bits ，改變多項式作法 -> [(ax + b)x +c]x + d 保留所有bits不捨去
//     5. $2 \cdot P(x) = ((2a \cdot x + 2b)x + 2c)x + 2d$ 全部乘 2 之後答案移位就好
//     6, 可能 cycle 無法小於 30 要使用 兩個乘法器同時做?
//     7. 如果變成不用除法器，那多的乘法器可以拿來作第六點????
//     8. 小數點的精度到底要多少?
//     9. 看別人的程式面積大小 GITHUB，別人都 * / % 直接用，如果合成面積一樣那我還要那麼麻煩幹嘛??
// 本Bicubic 電路設計的目的是對從原始圖像指定區域(左上角(H0,V0)，大小SW x SH)，放大成TW x TH大小圖像。
// 需考慮記憶體延遲(在文件中可以看)***

module Bicubic (
input CLK, // 本系統為同步於時脈正緣之同步設計
input RST, // active high
input [6:0] V0, // 電路欲處理區域的左上角座標的V座標值，介於0到99。 垂直
input [6:0] H0, // 電路欲處理區域的左上角座標的H座標值，介於0到99。 水平
input [4:0] SW, // 電路欲處理區域的水平方向寛度。該值加上H0不會超出原圖範圍。 H0+SW< 99 
input [4:0] SH, // 電路欲處理區域的垂直方向高度。該值加上V0不會超出原圖範圍。 V0+SH < 99
// P 的 x 方向位置 -> H0 ~ H0 + (SW - 1) -> 共 SW 個點 
// P 的 y 方向位置 -> V0 ~ V0 + (SH - 1) -> 共 SH 個點 
input [5:0] TW, // 電路處理區域放大後的水平方向寛度，TW不會超過2倍SW大小。 SW< TW < 2*SW
input [5:0] TH, // 電路處理區域放大後的垂直方向高度，TH不會超過2倍SH大小。 SH< TH < 2*SH
// Q 的 x 方向位置 -> H0 ~ H0 + (SW - 1) -> 共 TW 個點 
// Q 的 y 方向位置 -> H0 ~ H0 + (SW - 1) -> 共 TH 個點 
output reg DONE);


// FSM
reg [2:0] state;
localparam //READ_ROM = 3'd0,
           CAL_RATE_X = 3'd1, // 計算當前 Q 點的 x
           CAL_RATE_Y = 3'd2, // 計算當前 Q 點的 y
           CHOOSE_PATH = 3'd3,// 判斷現在要去做CUBIC還是直接要資料填入RAM
           X_CUBIC = 3'd4, // 水平 cubic
           Y_CUBIC = 3'd5, // 垂直 cubic
           BICUBIC = 3'd6,
           OUTPUT = 3'd7;
           
// 這個 ROM 會在 CEN 為 L 時抓 address，之後負緣送出資料，在下個正緣即可抓到正確的 Q 值
reg [13:0] ROM_addr; // 0~16383
wire [7:0] ROM_data_out; // 0 ~ 255
wire ROM_en;
assign ROM_en = (state == OUTPUT);


// when CEN  L -> DATA OUT = ROM Data, H -> DATA OUT = Last Data
// Addresses (A[0] = LSB) ,Data Outputs (Q[0] = LSB), Chip Enable(CEN)
ImgROM u_ImgROM (.Q(ROM_data_out), .CLK(CLK), .CEN(ROM_en), .A(ROM_addr)); // 16384 * 8 (A:[13:0] 14bits, Q:[7:0] 8bits)

// SRAM 在資料不管是輸入還是輸出，都在 CLK 負緣之前穩定 , CEN chip enable , WEN write enable
// CEN 為 H 不管 WEN 時輸出 Last Data, CEN 為 L 且 WEN 為 L 輸入 DATA, CEN 為 L 且 WEN 為 H 輸出 DATA 
wire [13:0] RAM_addr; // 0~16383
wire RAM_en, RAM_wr;
assign RAM_wr = 0;
assign RAM_en = (state != OUTPUT);
reg [7:0] RAM_data_in, RAM_data_out; // 0 ~ 255
// Data Inputs (D[0] = LSB), Data Outputs (Q[0] = LSB)
ResultSRAM u_ResultSRAM (.Q(RAM_data_out), .CLK(CLK), .CEN(RAM_en), .WEN(RAM_wr), .A(RAM_addr), .D(RAM_data_in)); // 16384 * 8 (A:[13:0] 14bits, Q:[7:0] 8bits)




//------------------------------------------
// 除法器及乘法器
//parameter width = 8;
parameter tc_mode = 0;
parameter rem_mode = 1; // corresponds to "%" in Verilog
/*
With numerator (a) the same
size as the divisor (b) both
a_width and b_width parameters
for DW_div are the same
*/
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
        U1 (
        .a(a), 
        .b(b), 
        .quotient(quotient), 
        .remainder(remainder), 
        .divide_by_0(divide_by_0));

// SW 最大值為 31、TW 最大值為 61，所以最大輸出像素 61 * 61 = 3721
// qx * SW-1 最大值為 61 * 31 -1 = 1830，所以乘法器輸出需 11 bits
reg signed [22:0] mul1; // 23 bits for a_num
reg signed [10:0] mul2; // 11 bits for x_signed
wire signed [32:0] mul_out; // 33bits
assign mul_out = mul1 * mul2;

//------------------------------------------
// 首先要先得出每一Q點的比例，根據觀察：qx or qy * (SW-1 / TW -1) 可以得出某點的一個假分數的值(e.g. 3*4/9)
// 如果是 12 / 9，那除出來的商就是 P(0)，x or y 的值為餘數 rx or ry / TW-1 or TH-1

reg [5:0] Qw_cnt, Qh_cnt; // qx , qy
reg [3:0] cnt;
reg [5:0] cnt2;

// 此為小數 Q0.10, 可以表示到 0.9990234375 
reg [9:0] x [59:0];
reg [9:0] y [59:0];


// P0 的位置
reg [5:0] P0_x [59:0]; // 最多 TW -1 個
reg [5:0] P0_y [59:0]; // 最多 TH -1 個

reg [5:0] rx [59:0]; // remainder 最多 TW -1 個
reg [5:0] ry [59:0]; // remainder 最多 TH -1 個

wire direct_x, direct_y; // 用於 CHOOSE_PATH 判斷是否要去做 cubic 還是直接去 ROM 取值
assign direct_x = (rx[Qw_cnt] == 0);
assign direct_y = (ry[Qh_cnt] == 0);
//reg [2:0] next_path;

// 記憶體位置計算
wire [13:0] input_addr; // H + V * 100
reg [13:0] output_addr;
reg [6:0] V;
//assign V = V0 + {1'd0, P0_y[Qh_cnt]};
assign input_addr = H0 + {1'd0, P0_x[Qw_cnt]} + (V << 6) + (V << 5) + (V << 2); // 此為 P0 位置
assign RAM_addr = output_addr;

//------------------------------------------

// cubic interpolation (三次內插)
// 需要 a、b、c、d, P(-1)、P(0)、P(1)、P(2)
// a = (1/2)(P(2) - P(-1)) + (3/2)(P(0) - P(1)) -> 1 個乘法器 2 個減法器 1 個加法器 (常數乘法不需乘法器)
// b = P(-1) + 2*P(1) - (1/2)(5*P(0) + P(2))    -> 1 個乘法器 1 個減法器 2 個加法器 (常數乘法不需乘法器)
// c = (1/2)(P(1) - P(-1))                      ->           1 個減法器
// d = P(0)
// ** 除 2 還會有個0.5要保留
// p(x) = ax^3+bx^2+cx+d -> 3 個乘法器 + 2 個乘法器 + 1 個乘法器 + d
// 多項式的做法為 [(ax + b)x +c]x + d -> 小數點每次乘完之後捨棄第十位之後的值

// a 最大值 510 最小值 -510 所以需要 9 + 1(signed) bits
// b 最大值 765 最小值 -765 所以需要 10 + 1(signed) bits
// c 最大值 127.5 最小值 -127.5 所以需要 7 + 1 (符號) + 1(小數點第一位) bits
// 因為 a b c d 各有不同的最大及最小值 bits，我統一成 1(signed) + 10(整數) + 1(小數點第一位) 去做比較不會亂

// 因為我們運算會有 (a*x+b)*x
// a*x+b = a(10 bits(整數) + 11bits(小數) + 1(signed)) + b(10 bits(整數) + 1bits(小數點第一位) + 1(signed)) = 11 bits(整數) + 11 bits(小數) + 1(signed) = 23 bits
// 再 *x = 11 bits(整數) + 21 bits(小數) + 1(signed) = 33 bits
// 所以乘法器輸出 bit 會變成 33 bits

// 預想上花 30000 cycle 每個點花 < 30 cycle 需處理完畢 -> BICUBIC至少一定會用掉 5* 11 = 55
// 在 CHOOSE_PATH 給了 P(0) 的位置，所以轉換 state 時會延遲一點點時間給出 ROM_data **

reg [7:0] P_1, P0, P1, P2;
reg [7:0] P_1_Bicubic, P0_Bicubic, P1_Bicubic, P2_Bicubic;
// abcd 都是 1(signed) + 10(整數) + 1(小數點第一位)
// 如果這樣子去看的話，代表說其實因為 abcd_num 都包含一個小數位置，代表不移位去做運算的話，等號右邊都是已經除以 2 之後的結果
// 換句話說就是變成了 a_num = a 提出了 1/2 的結果，其他也以此類推
reg signed [11:0] a_num; 
reg signed [11:0] b_num; 
reg signed [11:0] c_num; 
reg signed [11:0] d_num; 

// a*x(10 bits(整數) + 11bits(小數) + 1(signed)) + b(10 bits(整數) + 1bits(小數點第一位) + 1(signed)) = 11 bits(整數) + 11 bits(小數) + 1(signed) = 23 bits
reg signed [22:0] P;
wire [10:0] round;
wire [7:0] cubic_ans; // 題目要求當 P < 0 -> 0, P > 255 -> 255
assign round = (P[10] == 1)? P[21:11] + 1'd1 : P[21:11];
assign cubic_ans  = (P[22] == 1)? 8'd0 : (round >= 8'd255)? 8'd255 : round[7:0];


// 無號數轉有號數 + 1 bit
wire signed [8:0] s_P_1;
wire signed [8:0] s_P0;
wire signed [8:0] s_P1;
wire signed [8:0] s_P2;
wire signed [10:0] x_signed; // signed 從 10 bits 補到 11 bits
wire signed [10:0] y_signed;
wire signed [9:0] p0_p1_minus;


assign s_P_1 = (cnt2 != 3'd4)? {1'b0, P_1} : {1'b0, P_1_Bicubic};
assign s_P0  = (cnt2 != 3'd4)? {1'b0, P0}  : {1'b0, P0_Bicubic};
assign s_P1  = (cnt2 != 3'd4)? {1'b0, P1}  : {1'b0, P1_Bicubic};
assign s_P2  = (cnt2 != 3'd4)? {1'b0, P2}  : {1'b0, P2_Bicubic};
assign p0_p1_minus = s_P0 - s_P1;
assign x_signed = {1'b0, x[Qw_cnt]};
assign y_signed = {1'b0, y[Qh_cnt]};

//------------------------------------------
// 壓縮
// x 軸 要用的 x 是一樣的/ y 軸要用的 y 是一樣的
// 所以可以先把所有 x 跟 y 算出來存起來，可以省去重複計算的 cycle
always @(posedge CLK or posedge RST) begin
    if(RST) begin
        state <= CAL_RATE_X;
        DONE <= 0;
        Qw_cnt <= 0; Qh_cnt <= 0;
        cnt <= 0;
        cnt2 <= 0;
        output_addr <= 0;
        P <= 0;
    end else begin
        case (state)
            // 由於 使用 Qw_cnt or Qh_cnt 時，input_addr 會隨之變動，導致到達 CHOOSE_PATH 時，input_addr 才正確，但因記憶體延遲
            // 在 CHOOSE_PATH 之前，正確 input_addr 就要存在，不然會導致抓到錯誤值，所以這邊使用不同計數器(cnt2 來取代)
            // 在這邊使用的乘法器把 LSB 當成整數第一位，不會跟後面的小數點乘法混淆

            CAL_RATE_X: begin 
                cnt <= cnt + 1'd1;
                case (cnt)
                    0: begin // 第一步先算出 qx * SW -1
                        mul1 <= cnt2; // qx
                        mul2 <= SW - 1'd1;
                    end
                    1: begin // 再算出 qx * SW -1 / TW -1
                        a <= mul_out;
                        b <= TW - 1'd1;
                    end
                    2: begin // 把 qx * SW -1 / TW -1 的商跟餘數存起來，並且算 x 
                        P0_x[cnt2] <= quotient[5:0];
                        rx[cnt2] <= remainder;
                        a <= {remainder, 10'd0};
                        b <= TW - 1'd1;
                    end
                    3: begin // 把 x 值存起來
                        x[cnt2] <= quotient;

                        cnt2 <= cnt2 + 1'd1; // 做完三步之後再產生下一個點的 x
                        cnt <= 0;
                        if (cnt2 == (TW - 1'd1)) begin // state 轉換條件
                            cnt2 <= 0;
                            state <= CAL_RATE_Y;
                        end
                    end
                    default: ;
                endcase
            end

            // 由於 使用 Qw_cnt or Qh_cnt 時，input_addr 會隨之變動，導致到達 CHOOSE_PATH 時，input_addr 才正確，但因記憶體延遲
            // 在 CHOOSE_PATH 之前，正確 input_addr 就要存在，不然會導致抓到錯誤值，所以這邊使用不同計數器(cnt2 來取代)
            CAL_RATE_Y: begin 
                cnt <= cnt + 1'd1;
                case (cnt)
                    0: begin // 第一步先算出 qy * SH -1
                        mul1 <= cnt2; // qy
                        mul2 <= SH - 1'd1;
                    end
                    1: begin // 再算出 qy * SH -1 / TH -1
                        a <= mul_out;
                        b <= TH - 1'd1;
                    end
                    2: begin // 把 qy * SH -1 / TH -1 的商跟餘數存起來，並且算 y 
                        P0_y[cnt2] <= quotient[5:0];
                        ry[cnt2] <= remainder;
                        a <= {remainder, 10'd0};
                        b <= TH - 1'd1;
                    end
                    3: begin // 把 y 值存起來
                        y[cnt2] <= quotient;

                        cnt2 <= cnt2 + 1'd1; // 做完三步之後再產生下一個點的 y
                        cnt <= 0;
                        if (cnt2 == (TH - 1'd1)) begin // state 轉換條件
                            cnt2 <= 0;
                            state <= CHOOSE_PATH;
                        end
                    end
                    default: ;
                endcase
            end

            CHOOSE_PATH: begin // 一定需要這個狀態，不能用組合邏輯處理，因為在 OUTPUT 那邊 state 無法跳轉到下一個 Q 點座標要做的事
                case ({direct_x, direct_y})
                    2'b00: state <= BICUBIC; // 4 次水平 cubic 後再做 1 次垂直 cubic，共讀 16 點
                    2'b01: state <= X_CUBIC; // y 為整數 -> 做水平 cubic 讀 4 點
                    2'b10: state <= Y_CUBIC; // x 為整數 -> 做垂直 cubic 讀 4 點
                    2'b11: begin // 直接讀取 1 個原圖點(P0位置)
                        // ROM_addr <= input_addr; 在這裡的話給位置的話，因記憶體延遲，下一個狀態 OUTPUT 才會收到座標位置，導致 OUTPUT 狀態時無法收到正確 ROM_data
                        // 要在組合邏輯給 input_addr
                        state <= OUTPUT; 
                    end
                    default: ;
                endcase 
            end
            
            OUTPUT: begin
                // Q 的計數器運作電路及 pattern 結束條件
                // 當 RST 結束後輸入V0、H0、SW、SH、TW、TH等資料，並持續到 DONE 訊號拉高。
                if (DONE == 0) begin
                    output_addr <= output_addr + 1'd1;
                    
                    
                    if (Qw_cnt == (TW - 1'd1) && Qh_cnt == (TH - 1'd1)) begin
                        // 這裡放重製的東西
                        DONE <= 1'd1; 
                        Qw_cnt <= 0;
                        Qh_cnt <= 0;
                        output_addr <= 0;
                    end else begin // 要去選擇路徑
                        if (Qw_cnt == (TW - 1'd1)) begin // 當垂直計數器 +1 時，重新計算 y 值跟 x 值
                            Qw_cnt <= 0;
                            Qh_cnt <= Qh_cnt + 1'd1;
                        end else begin // 當水平計數器 +1 時，垂直的 y 值已經算過，所以要去計算每一 Q 點的 x
                            Qw_cnt <= Qw_cnt + 1'd1;
                        end
                        state <= CHOOSE_PATH;
                    end
                end else begin // 第一個點不用計算 x 跟 y，直接去要值
                    DONE <= 1'd0;
                    state <= CAL_RATE_X;
                end
            end 


            X_CUBIC, Y_CUBIC, BICUBIC: begin
                cnt <= cnt + 1'd1;
                case (cnt)
                    0: begin
                        P0 <= ROM_data_out; // P(0) 穩定
                    end
                    1: begin
                        P_1 <= ROM_data_out; // P(-1) 穩定
                        P <= d_num << 10;
                    end
                    2: begin
                        P1 <= ROM_data_out; // P(1) 穩定
                    end
                    3: begin
                        P2 <= ROM_data_out; // P(2) 穩定
                    end
                    4: begin
                        // a = (1/2)(P(2) - P(-1)) + (3/2)(P(0) - P(1))
                        // P(2) - P(-1) 如果 + 到 a_num 的話，因為 a_num 最右邊的那一位元是小數點第一位，所以 P(2) - P(-1) 就已經是除以 2 之後的結果了
                        // 那如果這樣子去看的話，代表說其實因為 abcd_num 都包含一個小數位置，代表不移位去做運算的話，等號右邊都是已經除以 2 之後的結果
                        // 換句話說就是變成了 a_num = a 提出了 1/2 的結果，其他也以此類推
                        // a_num = P(2) - P(-1) + 3*(P(0) - P(1)) , 常數乘法由直式推導, 乘以 3 代表 本身移位 0 位元 + 本身移位 1 位元
                        a_num <= (s_P2 - s_P_1) + (p0_p1_minus) + ((p0_p1_minus) << 1);
                        
                        // 因為 b_num 為提出了 1/2 後的結果，可是我們的 b 為 P(-1) + 2*P(1) - (1/2)(5*P(0) + P(2))
                        // 所以 P(-1) 要乘 2，P(1) 要乘 4
                        // b_num = 2*P(-1) + 4*P(1) - 5*P(0) - P(2)
                        b_num <= (s_P_1 << 1) + (s_P1 << 2) - (s_P0 + (s_P0 << 2)) - s_P2;

                        // c = (1/2)(P(1) - P(-1))
                        // c_num = P(1) - P(-1)
                        c_num <= s_P1 - s_P_1;
                        
                        // d = P(0)
                        // d_num = 2*P(0)
                        d_num <= s_P0 << 1;
                    end

                    // P = a * x + b
                    5: begin 
                        mul1 <= $signed({a_num[11], a_num, 10'd0}); // 要把 a_num 補成 11 bits 小數，這樣相乘才為 21 bits 小數
                        mul2 <= (state == Y_CUBIC || (state == BICUBIC && cnt2 == 3'd4))? y_signed: x_signed;
                    end
                    6: begin 
                        // 如果 a_num 沒補成 11 bits 小數
                        // mul_out 為 a(10 bits(整數) + 1bits(小數) + 1(signed)) * 10 bits 小數，所以為 10 bits(整數) + 11bits(小數) + 1(signed) -> 所以不能砍
                        // 但如果補成 11 bits 小數就可以砍 10 bits
                        P <= $signed(mul_out[32:10]) + $signed({b_num[11], b_num, 10'd0}); // 砍掉後 10 bits 小數，b_num 要從 P 的小數點第一位開始加
                    end
                    // P = (a * x + b) * x + c
                    7: begin
                        mul1 <= P; 
                        mul2 <= (state == Y_CUBIC || (state == BICUBIC && cnt2 == 3'd4))? y_signed: x_signed;
                    end
                    8: begin 
                        P <= $signed(mul_out[32:10]) + $signed({c_num[11], c_num, 10'd0});
                    end
                    // P = ((a * x + b) * x + c) * x + d
                    9: begin
                        mul1 <= P; 
                        mul2 <= (state == Y_CUBIC || (state == BICUBIC && cnt2 == 3'd4))? y_signed: x_signed;
                    end
                    10: begin 
                        P <= $signed(mul_out[32:10]) + $signed({d_num[11], d_num, 10'd0});
                        if (state != BICUBIC) begin
                            state <= OUTPUT;
                            cnt <= 0;
                        end
                    end
                    11: begin // when state == BICUBIC
                        cnt <= 0;
                        cnt2 <= cnt2 + 1'd1;
                        case (cnt2)
                            0: P0_Bicubic <= cubic_ans;
                            1: P_1_Bicubic <= cubic_ans;
                            2: P1_Bicubic <= cubic_ans;
                            3: begin 
                                P2_Bicubic <= cubic_ans;
                                cnt <= 3'd4;
                            end
                            4: begin
                                cnt2 <= 0;
                                cnt <= 0;
                                state <= OUTPUT;
                            end
                            default: ;
                        endcase
                    end
                    default: ;
                endcase
            end

            default: ;
        endcase
    end
end


//------------------------------------------
// 做 cubic interpolation (三次內插)============================================================ 廢棄想法

// 需要 a、b、c、d, P(-1)、P(0)、P(1)、P(2), 找 P(0) ~ P(1) 的中間的某點 P( x or y )
// a = (1/2)(P(2) - P(-1)) + (3/2)(P(0) - P(1)) -> 1 個乘法器 2 個減法器 1 個加法器
// b = P(-1) + 2*P(1) - (1/2)(5*P(0) + P(2))     -> 1 個乘法器 1 個減法器 2 個加法器
// c = (1/2)(P(1) - P(-1))                       ->           1 個減法器
// d = P(0)

// 想法: 由於 x or y 需要除法器，除法器是必須的，我不知道除法器跟乘法器如果同時使用 critical path 會不會太長，
// 或者是 多少個乘法器及一個除法器一起使用的話 critical path 會不會太長，我先嘗試在 1 clock 裡面只使用一個乘法器，或除法器
// 但這樣要得到 P( x or y ) 的值的話，需要 :

// abcd 共花兩個 clk (due to 2 mul) , 得出 x(or y) 的值花 1 clk (1 div) , a*x^3 花 3 clk (due to 3 mul) , b*x^2 花 2 clk (2 mul) , c*x 花 1 clk (1 mul)
// 所以重新整理一下順序: 
// 先花 5 clk 輸入四筆 P 資料
// 1. 把 P(-1) 位置給 ROM，下一個 clk 資料才會進，在此 clk 同時做 x 的除法算出 x
// 2. 把 P(0) 位置給 ROM，下一個 clk 資料才會進
// 3. 把 P(1) 位置給 ROM
//---------------------------------------------
// 組合邏輯更動記憶體索取的位置
always @(*) begin
    ROM_addr = input_addr;
    V = V0 + {1'd0, P0_y[Qh_cnt]};
    case (state)
        OUTPUT: begin
            if ({direct_x, direct_y} == 2'b11) begin
                RAM_data_in = ROM_data_out;
            end else begin
                RAM_data_in = cubic_ans;
            end
        end

        X_CUBIC: begin // ROM 的資料索取
            case (cnt)
                0: begin
                    ROM_addr = input_addr - 1'd1; // P(-1)
                end 
                1: begin
                    ROM_addr = input_addr + 1'd1; // P(1)
                end
                2: begin
                    ROM_addr = input_addr + 2'd2; // P(2)
                end
                default: ROM_addr = input_addr ;
            endcase
        end

        Y_CUBIC: begin // ROM 的資料索取
            ROM_addr = input_addr;
            case (cnt)
                0: begin
                    V = V0 + {1'd0, P0_y[Qh_cnt]} - 1'd1; // P(-1)
                end 
                1: begin
                    V = V0 + {1'd0, P0_y[Qh_cnt]} + 1'd1; // P(1)
                end
                2: begin
                    V = V0 + {1'd0, P0_y[Qh_cnt]} + 2'd2; // P(2)
                end
                default: V = V0 + {1'd0, P0_y[Qh_cnt]};
            endcase
        end

        BICUBIC: begin
            case (cnt)
                0: begin
                    ROM_addr = input_addr - 1'd1; // P(-1)
                end 
                1: begin
                    ROM_addr = input_addr + 1'd1; // P(1)
                end
                2: begin
                    ROM_addr = input_addr + 2'd2; // P(2)
                end
                default: ROM_addr = input_addr ;
            endcase

            if (cnt >= 0 && cnt <= 4) begin
                case (cnt2)
                    0: begin
                        V = V0 + {1'd0, P0_y[Qh_cnt]};        // P(0) Bicubic
                    end
                    1: begin
                        V = V0 + {1'd0, P0_y[Qh_cnt]} - 1'd1; // P(-1) Bicubic
                    end 
                    2: begin
                        V = V0 + {1'd0, P0_y[Qh_cnt]} + 1'd1; // P(1) Bicubic
                    end
                    3: begin
                        V = V0 + {1'd0, P0_y[Qh_cnt]} + 2'd2; // P(2) Bicubic
                    end
                    
                    default: V = V0 + {1'd0, P0_y[Qh_cnt]}; // P(0) Bicubic
                endcase
            end else begin
                    case (cnt2)
                    0: begin
                        V = V0 + {1'd0, P0_y[Qh_cnt]} - 1'd1; // P(-1) Bicubic
                    end 
                    1: begin
                        V = V0 + {1'd0, P0_y[Qh_cnt]} + 1'd1; // P(1) Bicubic
                    end
                    2: begin
                        V = V0 + {1'd0, P0_y[Qh_cnt]} + 2'd2; // P(2) Bicubic
                    end
                    default: V = V0 + {1'd0, P0_y[Qh_cnt]}; // P(0) Bicubic
                endcase
            end
        end

        default: begin
            ROM_addr = input_addr;
            V = V0 + {1'd0, P0_y[Qh_cnt]};
        end
    endcase
end

endmodule


