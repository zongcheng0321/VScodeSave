/* 拔除 Comparator，改用 MSB 判斷 (面積大幅降低)
原版的 if (crosss_product >= 0) 和 < 0 會讓合成器長出 23-bit 的比較器Comparator。因為我們已經是有號數Signed正數的最高位元MSB為 0負數的 MSB 為 1。

>= 0 可直接寫成 ~cross_product[22]

< 0 可直接寫成 cross_product[22]
這個改動可以直接省下比較器的面積。

修復多餘的 Clock Cycle 浪費
在原先的 S1_DATA_INPUT_RECIVER 中，讀取最後一筆資料時會多浪費一個 cycle 才跳轉狀態。我將計數與跳轉邏輯整併，讓它一讀完第 6 顆接收器就無縫進入 S2。 */



module geofence ( clk, reset, X, Y, valid, is_inside);
input clk;
input reset;
input [9:0] X; // 接收器/待測物 x 座標
input [9:0] Y; // 接收器/待測物 y 座標
output reg valid;
output reg is_inside;

// 待測物體的座標
reg [9:0] test_object_x, test_object_y;
// 接收器座標
reg [9:0] receiver_x [5:0];
reg [9:0] receiver_y [5:0];

// FSM 參數
localparam S0_DATA_INPUT_OBJ = 3'd0, // 資料輸入(待測物)  
           S1_DATA_INPUT_REC = 3'd1, // 資料輸入(接收器)
           S2_SETUP_FENCE    = 3'd2, // 建立圍籬 (Bubble Sort)
           S3_ASSESS_OBJECT  = 3'd3, // 判斷待測物體是否在圍籬內
           S4_OUTPUT         = 3'd4; // 輸出結果並降下 valid

reg [2:0] state;
reg [2:0] cnt; 
reg [2:0] i;   
reg [2:0] bubbleFinish; 

// 宣告有號數向量變數
wire signed [10:0] Ax, Ay, Bx, By; 
wire signed [21:0] mul1, mul2;
wire signed [22:0] cross_product; 

wire [2:0] next_i;
assign next_i = (i == 3'd5) ? 3'd0 : (i + 3'd1); 

// 利用 $signed 確保無號數擴充後進行正確的有號數減法
assign Ax = (state == S2_SETUP_FENCE) ?
            $signed({1'b0, receiver_x[i + 1]}) - $signed({1'b0, receiver_x[0]}) : 
            $signed({1'b0, receiver_x[i]})     - $signed({1'b0, test_object_x});

assign Ay = (state == S2_SETUP_FENCE) ?
            $signed({1'b0, receiver_y[i + 1]}) - $signed({1'b0, receiver_y[0]}) :
            $signed({1'b0, receiver_y[i]})     - $signed({1'b0, test_object_y});

assign Bx = (state == S2_SETUP_FENCE) ?
            $signed({1'b0, receiver_x[i + 2]}) - $signed({1'b0, receiver_x[0]}) :
            $signed({1'b0, receiver_x[next_i]})- $signed({1'b0, receiver_x[i]});

assign By = (state == S2_SETUP_FENCE) ?
            $signed({1'b0, receiver_y[i + 2]}) - $signed({1'b0, receiver_y[0]}) :
            $signed({1'b0, receiver_y[next_i]})- $signed({1'b0, receiver_y[i]});

// 共用兩個乘法器與一個減法器 (大幅節省面積)
assign mul1 = Ax * By;
assign mul2 = Bx * Ay;
assign cross_product = mul1 - mul2;

// FSM
always @(posedge clk or posedge reset) begin
    if(reset) begin
        valid        <= 1'b0;
        is_inside    <= 1'b0;
        state        <= S0_DATA_INPUT_OBJ;
        cnt          <= 3'd0;
        i            <= 3'd0;
        bubbleFinish <= 3'd0;
    end else begin
        case (state)
            // 讀取待測物
            S0_DATA_INPUT_OBJ: begin 
                test_object_x <= X;
                test_object_y <= Y;
                state         <= S1_DATA_INPUT_REC;
            end
            
            // 讀取 6 顆接收器
            S1_DATA_INPUT_REC: begin
                receiver_x[cnt] <= X;
                receiver_y[cnt] <= Y;
                if (cnt == 3'd5) begin
                    cnt   <= 3'd0;
                    state <= S2_SETUP_FENCE;
                end else begin
                    cnt   <= cnt + 3'd1;
                end
            end
            
            // 建立圍籬 (Bubble Sort)
            S2_SETUP_FENCE: begin
                // 原 >= 0 邏輯，有號數正數或零的 MSB 為 0
                if (~cross_product[22]) begin 
                    receiver_x[i + 1] <= receiver_x[i + 2]; 
                    receiver_x[i + 2] <= receiver_x[i + 1];   
                    receiver_y[i + 1] <= receiver_y[i + 2];
                    receiver_y[i + 2] <= receiver_y[i + 1];
                end
                
                if (bubbleFinish < 3'd4) begin
                    if (i < 3'd3) begin 
                        i <= i + 3'd1;
                    end else begin
                        i <= 3'd0;
                        bubbleFinish <= bubbleFinish + 3'd1;
                    end
                end else begin
                    i            <= 3'd0;
                    bubbleFinish <= 3'd0;
                    state        <= S3_ASSESS_OBJECT;
                end
            end
            
            // 判斷是否在圍籬內
            S3_ASSESS_OBJECT: begin 
                // 原 < 0 邏輯，有號數負數的 MSB 為 1 (省去比較器面積)
                if (cross_product[22]) begin 
                    if (i < 3'd5) begin
                        i <= i + 3'd1;
                    end else begin
                        is_inside <= 1'b1;
                        valid     <= 1'b1;
                        state     <= S4_OUTPUT;
                    end
                end else begin // 只要有一個大於等於0 (逆時針)，就在圍籬外
                    is_inside <= 1'b0;
                    valid     <= 1'b1;
                    state     <= S4_OUTPUT;
                end
            end
            
            // 輸出完畢，歸零
            S4_OUTPUT: begin
                valid     <= 1'b0;
                is_inside <= 1'b0;
                i         <= 3'd0;
                state     <= S0_DATA_INPUT_OBJ;
            end
            
            default: state <= S0_DATA_INPUT_OBJ;
        endcase
    end
end
endmodule