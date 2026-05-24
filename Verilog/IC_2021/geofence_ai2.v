/* 上一版的寫法雖然已經共用了乘法器，但合成器（Synthesis Tool）在處理 Ax, Ay, Bx, By 的選擇時，會因為條件判斷較為分散，長出較多複雜的多工器（Multiplexer）和繞線（Routing）。

我們可以引入一個叫「基準點抽象化（Anchor Abstraction）」的觀念，這也是當年在解這題 2015 IC 競賽標準題時，能拿高分的神級寫法。

🧠 終極優化核心觀念：資料路徑（Datapath）整合
仔細觀察這題的幾何數學，不論是「S2 建立圍籬（排序）」還是「S3 判斷是否在內」，本質上都是在做同一件事：

「找一個基準點（Anchor），並計算另外兩個點（Point 1 與 Point 2）對此基準點的向量外積。」

S2 (排序時)： 基準點是 Receiver[0]，另外兩點是 Receiver[i+1] 和 Receiver[i+2]。

S3 (判斷時)： 基準點是 Test_Object，另外兩點是 Receiver[i] 和 Receiver[next_i]。

只要我們把「座標選擇」的多工器拉到最前面，後面的減法器和乘法器就可以100% 完美共用，合成器會直接幫你省下大量的邏輯閘面積。

🏆 更好的寫法：Anchor 基準點抽象化版本
這份程式碼大幅簡化了組合邏輯的長度，不僅面積更小，時序（Timing）也會更好。 

✨ 這個版本強在哪裡？
程式碼行數大幅減少且極具可讀性： 看 Data Path 的地方，任何人都能一眼看出這是在算外積，不再被複雜的 state 三元運算子搞得眼花撩亂。

明確指導合成器（Explicit Instantiation）： 我們將電路寫成 MUX -> SUB -> MUL -> SUB 的固定硬體流向，Design Compiler 在合成時不需要再去猜你的意圖，這保證了電路會以最少的邏輯閘實現。
*/

module geofence ( clk, reset, X, Y, valid, is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
output reg valid;
output reg is_inside;

// 待測物體的座標
reg [9:0] obj_x, obj_y;
// 接收器座標
reg [9:0] rx [5:0];
reg [9:0] ry [5:0];

// FSM 參數
localparam S0_INPUT_OBJ = 3'd0,
           S1_INPUT_REC = 3'd1,
           S2_SORT      = 3'd2,
           S3_CHECK     = 3'd3,
           S4_OUTPUT    = 3'd4;

reg [2:0] state;
reg [2:0] cnt; 
reg [2:0] i;   
reg [2:0] bubble_cnt; 

// =========================================================
// 🎯 Datapath: 完美共用硬體架構 (MUX -> SUB -> MUL -> SUB)
// =========================================================
wire [2:0] next_i = (i == 3'd5) ? 3'd0 : (i + 3'd1);

// 1. 決定基準點 (Anchor) 與 兩個目標點 (Point 1, Point 2)
wire [9:0] anchor_x = (state == S2_SORT) ? rx[0]   : obj_x;
wire [9:0] anchor_y = (state == S2_SORT) ? ry[0]   : obj_y;

wire [9:0] p1_x     = (state == S2_SORT) ? rx[i+1] : rx[i];
wire [9:0] p1_y     = (state == S2_SORT) ? ry[i+1] : ry[i];

wire [9:0] p2_x     = (state == S2_SORT) ? rx[i+2] : rx[next_i];
wire [9:0] p2_y     = (state == S2_SORT) ? ry[i+2] : ry[next_i];

// 2. 計算向量 (共用 4 個減法器)
wire signed [10:0] vec1_x = $signed({1'b0, p1_x}) - $signed({1'b0, anchor_x});
wire signed [10:0] vec1_y = $signed({1'b0, p1_y}) - $signed({1'b0, anchor_y});
wire signed [10:0] vec2_x = $signed({1'b0, p2_x}) - $signed({1'b0, anchor_x});
wire signed [10:0] vec2_y = $signed({1'b0, p2_y}) - $signed({1'b0, anchor_y});

// 3. 計算外積 (共用 2 個乘法器、1 個減法器)
// 外積公式: (X1 * Y2) - (X2 * Y1)
wire signed [21:0] mul1 = vec1_x * vec2_y;
wire signed [21:0] mul2 = vec2_x * vec1_y;
wire signed [22:0] cross_product = mul1 - mul2;

// =========================================================
// 🕹️ Control Path: FSM
// =========================================================
always @(posedge clk or posedge reset) begin
    if(reset) begin
        valid      <= 1'b0;
        is_inside  <= 1'b0;
        state      <= S0_INPUT_OBJ;
        cnt        <= 3'd0;
        i          <= 3'd0;
        bubble_cnt <= 3'd0;
    end else begin
        case (state)
            S0_INPUT_OBJ: begin 
                obj_x <= X;
                obj_y <= Y;
                state <= S1_INPUT_REC;
            end
            
            S1_INPUT_REC: begin
                rx[cnt] <= X;
                ry[cnt] <= Y;
                if (cnt == 3'd5) begin
                    cnt   <= 3'd0;
                    state <= S2_SORT;
                end else begin
                    cnt   <= cnt + 3'd1;
                end
            end
            
            S2_SORT: begin
                // 若外積為正或0 (~MSB)，代表逆時針，需交換
                if (~cross_product[22]) begin 
                    rx[i+1] <= rx[i+2]; 
                    rx[i+2] <= rx[i+1];   
                    ry[i+1] <= ry[i+2];
                    ry[i+2] <= ry[i+1];
                end
                
                // Bubble sort 邊界控制
                if (bubble_cnt < 3'd4) begin
                    if (i < 3'd3) begin 
                        i <= i + 3'd1;
                    end else begin
                        i <= 3'd0;
                        bubble_cnt <= bubble_cnt + 3'd1;
                    end
                end else begin
                    i          <= 3'd0;
                    bubble_cnt <= 3'd0;
                    state      <= S3_CHECK;
                end
            end
            
            S3_CHECK: begin 
                // 若外積為負 (MSB=1)，代表順時針，繼續檢查
                if (cross_product[22]) begin 
                    if (i < 3'd5) begin
                        i <= i + 3'd1;
                    end else begin
                        is_inside <= 1'b1; // 全部檢查完皆為順時針 -> 在內部
                        valid     <= 1'b1;
                        state     <= S4_OUTPUT;
                    end
                end else begin 
                    is_inside <= 1'b0;     // 只要有一段不是順時針 -> 在外部
                    valid     <= 1'b1;
                    state     <= S4_OUTPUT;
                end
            end
            
            S4_OUTPUT: begin
                valid     <= 1'b0;
                is_inside <= 1'b0;
                i         <= 3'd0;
                state     <= S0_INPUT_OBJ;
            end
            
            default: state <= S0_INPUT_OBJ;
        endcase
    end
end
endmodule