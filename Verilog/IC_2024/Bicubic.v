// 本Bicubic 電路設計的目的是對從原始圖像指定區域(左上角(H0,V0)，大小SW x SH)，放大成TW x TH大小圖像。
// 需考慮記憶體延遲(在文件中可以看)

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

// 這個 ROM 會在 CEN 為 L 時抓 address，之後負緣送出資料，在下個正緣即可抓到正確的 Q 值
wire [13:0] ROM_addr; // 0~16383
wire ROM_en;
wire [7:0] ROM_data_out; // 0 ~ 255
// when CEN  H -> DATA OUT = ROM Data, L -> DATA OUT = Last Data
// Addresses (A[0] = LSB) ,Data Outputs (Q[0] = LSB), Chip Enable(CEN)
ImgROM u_ImgROM (.Q(ROM_data_out), .CLK(CLK), .CEN(ROM_en), .A(ROM_addr)); // 16384 * 8 (A:[13:0] 14bits, Q:[7:0] 8bits)

// SRAM 在資料不管是輸入還是輸出，都在 CLK 負緣之前穩定 , CEN chip enable , WEN write enable
// CEN 為 H 不管 WEN 時輸出 Last Data, CEN 為 L 且 WEN 為 L 輸入 DATA, CEN 為 L 且 WEN 為 H 輸出 DATA 
wire [13:0] RAM_addr; // 0~16383
wire RAM_en, RAM_wr;
wire [7:0] RAM_data_in, RAM_data_out; // 0 ~ 255
// Data Inputs (D[0] = LSB), Data Outputs (Q[0] = LSB)
ResultSRAM u_ResultSRAM (.Q(RAM_data_out), .CLK(CLK), .CEN(RAM_en), .WEN(RAM_wr), .A(RAM_addr), .D(RAM_data_in)); // 16384 * 8 (A:[13:0] 14bits, Q:[7:0] 8bits)

// FSM
reg [2:0] state;
localparam INPUT = 3'd0,
           



           OUTPUT = 3'd7;


//------------------------------------------
reg [6:0] x, y; // 0 ~ 127 

// 壓縮
// 這邊要得出 P(x or y) 裡面的 x or y 的值
// 先用計數器把



//------------------------------------------
// 做 cubic interpolation (三次內插)AasjidjaisdjasidjaidjAj 重寫

// 需要 a、b、c、d, P(-1)、P(0)、P(1)、P(2), 找 P(0) ~ P(1) 的中間的某點 P( x or y )
// a = (1/2)(P(2) - P(-1)) + (3/2)(P(0) - P(-1)) -> 1 個乘法器 2 個減法器 1 個加法器
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


always @(posedge CLK or posedge RST) begin
    if(RST) begin
        state <= INPUT;
        DONE <= 0;
    end else begin
        case (state)
            INPUT: begin
                state <= OUTPUT;
                DONE <= 0;
            end 

            OUTPUT: begin
                DONE <= 1'd1;
                state <= INPUT;
            end
            default: ;
        endcase
    end
end

//------------------------------------------

always @(posedge CLK or posedge RST) begin
    if(RST) begin
        state <= INPUT;
        DONE <= 0;
    end else begin
        case (state)
            INPUT: begin
                state <= OUTPUT;
                DONE <= 0;
            end 

            OUTPUT: begin
                DONE <= 1'd1;
                state <= INPUT;
            end
            default: ;
        endcase
    end
end







endmodule


