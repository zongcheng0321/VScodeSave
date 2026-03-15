module JAM (
input CLK,
input RST,
output reg [2:0] W,
output reg [2:0] J,
input [6:0] Cost,
output reg [3:0] MatchCount,
output reg [9:0] MinCost,
output reg Valid );

//always @(*) 組合邏輯中，意味著你要求硬體在「同一個瞬間」把 W 腳位變成 0, 1, 2...7，並期望 Cost 接腳瞬間給出 8 個對應的回傳值。這在真實世界是做不到的！
//解法： 讀取 Cost 必須透過 Clock 驅動，利用計數器（Counter）在 8 個 Clock 週期內，一次送出一組 W 和 J，並把收到的 Cost 慢慢累加。
//2. 組合邏輯中的自我累加 (k++, tempMinCost += Cost)
//在 always @(*) 這種組合邏輯區塊內，寫出 k++ (等同於 k = k + 1) 或是 j-- 會產生組合邏輯迴路 (Combinational Loop)。因為沒有 Clock 控制，訊號會在閘道器之間無限狂奔，導致模擬器當機。

// 等等再改做兩次可能會大於 600000 cycles，我把它改成一次試試看。
// 把所有 for 跟 ++ --電路寫到序向邏輯
//------------------------------------------------------------------------------------------------------
// feature: 優先權編碼器 (Priority Encoder) 來處理S2，使用1clk完成比較。
// 在軟體裡，我們習慣用 for 迴圈從右邊慢慢往左邊找（$O(n)$ 的時間）。但在硬體裡，我們擁有「平行處理」的超能力。
// 我們不需要慢慢找，我們可以同時擺上 7 個比較器 (Comparator)，讓它們在同一個瞬間告訴我們結果。
//------------------------------------------------------------------------------------------------------
//********模擬失敗，clk超大，無限迴圈，問題在S2、3、4

reg [2:0] array [7:0]; 

reg [2:0] j = 3'd7; // array [j]
//reg [2:0] j = 7, k =7;// array [j][k]
reg [2:0] ChangingPoint; // 替換點
reg k = 1'd1; // 利用 [ChangingPoint + k] 尋找比替換點大的數
reg [2:0] minNumPosition; // 比替換點大的最小數的位置
//reg [2:0] temp; // 做交換時暫存值
reg [9:0] tempMinCost; // 暫存 MinCost 值以用於比較
reg [2:0] CostCount; // 計數算了多少人的 Cost
integer i;

// 全排序 FSM
reg [2:0] state;
parameter S0 = 3'd0, // initialize variable that will be used later(組合邏輯)、計算 tempMinCost
          S1 = 3'd1, // 得出 MinCost、MatchCount
          S2 = 3'd2, // 判斷右邊是否大於左邊並產生替換點、當已經把所有排列完成，右邊沒有任何數小於左邊、拉高 Vaild 結束模擬
          S3 = 3'd3, // 在替換點右邊的的數字中，找到比替換數大的最小數字，將之和替換數交換
          S4 = 3'd4; // 把替換點後的數字前後順序翻轉過來，即可得下一字典序列。

always @(*) begin
    case (state)
        // 判斷右邊是否大於左邊並產生替換點
        S0: begin
            // initialize variable that will be used later
            j = 3'd7;
            k = 1'd1;
            //temp = 3'd0;
            W = CostCount;
            J = array[CostCount];
        end

        default: begin
            W = 3'd0;
            J = 3'd0;
        end
    endcase
end

always @(posedge CLK or negedge RST) begin
    if (!RST) begin
        state <= S0;

        // initialize variable
        MatchCount <= 0;
        MinCost <= 10'd1023;
        Valid <= 0;
        tempMinCost <= 0;
        CostCount <= 0;
        for (i = 0; i < 8; i++) begin // array at the beginning is [0,1,2,3,4,5,6,7]
            array[i] <= i;
        end
    end else begin
        case (state)
            S0: begin
                // 計算最小值
                tempMinCost <= tempMinCost + Cost;
                if (CostCount == 3'd7) begin
                    state <= S1;
                    CostCount <= 0;
                end else begin
                    CostCount <= CostCount + 1;
                end
            end 
            S1: begin
                // MinCost default is 1023
                // 計算 MinCost 的同時也一併計算 MatchCount
                if (tempMinCost < MinCost) begin
                    MinCost <= tempMinCost;
                    MatchCount <= 4'd1;
                end else if (tempMinCost == MinCost) begin
                    MatchCount <= MatchCount + 1;
                end else begin
                    MinCost <= MinCost;
                    MatchCount <= MatchCount;
                end 
                tempMinCost <= 0;
                state <= S2;
            end
            S2: begin // 判斷右邊是否大於左邊並產生替換點
                // e.g. array[7] > array[6] 右邊大於左邊
                if (j > 0) begin // 中止條件 if j <= 0 -> j - 1 = -1 -> WRONG
                    if (array[j] > array[j - 1]) begin
                        ChangingPoint <= j - 1; //當右邊比較大時，將左邊設為替換點
                        minNumPosition <= j + 1; // 預設值為 ChangingPoint 的右邊第一個
                        state <= S3; 
                    // 如果右邊不大於左邊，找下一個
                    end else begin
                        j <= j - 1;
                        state <= S2;
                    end
                end else begin
                    // 當已經把所有排列完成，右邊沒有任何數小於左邊
                    // 拉高 Vaild 結束模擬
                    Valid = 1'd1;
                end
            end
            S3: begin
                if ((ChangingPoint + k) < 8) begin // 中止條件 當已經跑完整個陣列在 else 那邊做替換點與 minNumPosition 交換
                    if (array[ChangingPoint] < array[ChangingPoint + k] ) begin // 找到比替換數大的數字
                        if (array[minNumPosition] >= array[ChangingPoint + k] ) begin // 在這之中找最小值
                            minNumPosition <= ChangingPoint + k;
                            k <= k + 1;
                            state <= S3;
                        end else begin
                            k <= k + 1;
                            state <= S3;
                        end
                    end else begin
                        k <= k + 1;
                        state <= S3;
                    end
                end else begin
                    // 替換點值與 minNumPosition 值交換
                    array[ChangingPoint] <= array[minNumPosition];
                    array[minNumPosition] <= array[ChangingPoint];
                    state <= S4;
                    // setting i default
                    i <= ChangingPoint + 1;
                end
            end
            S4: begin
                // 翻轉一維陣列，ChangingPoint + 1 為替換點後的數字的第一個
                // 8 - i + 1 定義為需要翻轉之陣列的 Size
                if (i < (8 - i + 1)/2) begin
                    array[i] <= array[8 - i]; // 1、7 or 2、6 or 3、5 exchange
                    array[8 - i] <= array[i];
                    i <= i + 1;
                end else begin
                    // 排序完成，回到 S0、S1計算 MinCost、MatchCount
                    // 歸零計算成本及 CostCount
                    tempMinCost <= 0;
                    CostCount <= 0;
                    state = S0;
                end
/*
                for (i = ChangingPoint + 1; i < (8 - i + 1)/2; i++) begin
                    temp = array[i];
                    array[i] = array[8 - i]; // 1、7 or 2、6 or 3、5 exchange
                    array[8 - i] = temp;
                end
                state = S0;
                */
            end
            default: state <= state;
        endcase
    end
end

endmodule