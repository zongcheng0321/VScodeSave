module JAM (
input CLK,
input RST,
output reg [2:0] W,
output reg [2:0] J,
input [6:0] Cost,
output reg [3:0] MatchCount,
output reg [9:0] MinCost,
output reg Valid );


// 等等再改做兩次可能會大於 600000 cycles，我把它改成一次試試看。
// 把所有 for 跟 ++ --電路寫到序向邏輯
//------------------------------------------------------------------------------------------------------
// feature: 優先權編碼器 (Priority Encoder) 來處理S2，使用1clk完成比較。
// 在軟體裡，我們習慣用 for 迴圈從右邊慢慢往左邊找（$O(n)$ 的時間）。但在硬體裡，我們擁有「平行處理」的超能力。
// 我們不需要慢慢找，我們可以同時擺上 7 個比較器 (Comparator)，讓它們在同一個瞬間告訴我們結果。
//------------------------------------------------------------------------------------------------------
// 要把S2、3、4改成不要用迴圈的方式
reg [2:0] array [7:0]; 

reg [2:0] ChangingPoint; // 替換點
reg k = 1'd1; // 利用 [ChangingPoint + k] 尋找比替換點大的數
reg [2:0] minNumPosition; // 比替換點大的最小數的位置
reg [9:0] tempMinCost; // 暫存 MinCost 值以用於比較
reg [2:0] CostCount; // 計數算了多少人的 Cost
integer i;
// S2 之中的比較
// 判斷右邊是否大於左邊並產生替換點
wire S2_cmp0 = (array[6] < array[7]);
wire S2_cmp1 = (array[5] < array[6]);
wire S2_cmp2 = (array[4] < array[5]);
wire S2_cmp3 = (array[3] < array[4]);
wire S2_cmp4 = (array[2] < array[3]);
wire S2_cmp5 = (array[1] < array[2]);
wire S2_cmp6 = (array[0] < array[1]);
// S3 之中的比較
// 比較誰比 array[ChangingPoint] 大，那就將會是比替換值大的最小值
wire S3_cmp0 = (array[7] > array[ChangingPoint]);
wire S3_cmp1 = (array[6] > array[ChangingPoint]);
wire S3_cmp2 = (array[5] > array[ChangingPoint]);
wire S3_cmp3 = (array[4] > array[ChangingPoint]);
wire S3_cmp4 = (array[3] > array[ChangingPoint]);
wire S3_cmp5 = (array[2] > array[ChangingPoint]);
wire S3_cmp6 = (array[1] > array[ChangingPoint]);




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
            W = CostCount;
            J = array[CostCount];
        end

        default: begin
            W = 3'd0;
            J = 3'd0;
        end
    endcase
end

always @(posedge CLK or posedge RST) begin
    if (RST) begin
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
                if (S2_cmp0) begin
                    ChangingPoint <= 3'd6;
                    state <= S3;
                end else if (S2_cmp1) begin
                    ChangingPoint <= 3'd5;
                    state <= S3;
                end else if (S2_cmp2) begin
                    ChangingPoint <= 3'd4;
                    state <= S3;
                end else if (S2_cmp3) begin
                    ChangingPoint <= 3'd3;
                    state <= S3;
                end else if (S2_cmp4) begin
                    ChangingPoint <= 3'd2;
                    state <= S3;
                end else if (S2_cmp5) begin
                    ChangingPoint <= 3'd1;
                    state <= S3;
                end else if (S2_cmp6) begin
                    ChangingPoint <= 3'd0;
                    state <= S3;
                end else begin
                    // 當已經把所有排列完成，右邊沒有任何數小於左邊
                    // 拉高 Vaild 結束模擬
                    Valid <= 1'd1;
                end
            end
            S3: begin
                // 在替換點右邊的的數字中，找到比替換數大的最小數字，將之和替換數交換
                // 經過 S2 發現因為一直比較右邊是否大於左邊，所以 ChangingPoint 右邊的陣列一定是由大到小排列的。
                // 比較 從 array [7] -> [1] 如果是大於 array[ChangingPoint]，由此可知他一定是 minNumPosition
                // 因為從大到小陣列的左邊去掃到右邊，第一個掃到的一定是比 array[ChangingPoint] 大，但又是在比他大的數之中的最小值。
                // 同時做替換點值與 minNumPosition 值交換
                if (S3_cmp0) begin
                    minNumPosition <= 3'd7;
                    array[7] <= array[ChangingPoint];
                    array[ChangingPoint] <= array[7];
                end else if (S3_cmp1) begin
                    minNumPosition <= 3'd6;
                    array[6] <= array[ChangingPoint];
                    array[ChangingPoint] <= array[6];
                end else if (S3_cmp2) begin
                    minNumPosition <= 3'd5;
                    array[5] <= array[ChangingPoint];
                    array[ChangingPoint] <= array[5];
                end else if (S3_cmp3) begin
                    minNumPosition <= 3'd4;
                    array[4] <= array[ChangingPoint];
                    array[ChangingPoint] <= array[4];
                end else if (S3_cmp4) begin
                    minNumPosition <= 3'd3;
                    array[3] <= array[ChangingPoint];
                    array[ChangingPoint] <= array[3];
                end else if (S3_cmp5) begin
                    minNumPosition <= 3'd2;
                    array[2] <= array[ChangingPoint];
                    array[ChangingPoint] <= array[2];
                end else if (S3_cmp6) begin
                    minNumPosition <= 3'd1;
                    array[1] <= array[ChangingPoint];
                    array[ChangingPoint] <= array[1];
                end else begin
                    minNumPosition <= minNumPosition;
                end
                state <= S4;
            end
            S4: begin
                // 翻轉一維陣列，根據 ChangingPoint 來去看說要做哪裡個翻轉
                case (ChangingPoint)
                    3'd0: begin // 當為 0 時，翻轉 7、1 6、2 5、3
                        array[1] <= array[7]; array[7] <= array[1];
                        array[2] <= array[6]; array[6] <= array[2];
                        array[3] <= array[5]; array[5] <= array[3];
                    end
                    3'd1: begin // 當為 0 時，翻轉 7、2 3、6 4、5
                        array[2] <= array[7]; array[7] <= array[2];
                        array[3] <= array[6]; array[6] <= array[3];
                        array[4] <= array[5]; array[5] <= array[4];
                    end
                    3'd2: begin
                        array[3] <= array[7]; array[7] <= array[3];
                        array[4] <= array[6]; array[6] <= array[4];
                    end
                    3'd3: begin
                        array[4] <= array[7]; array[7] <= array[4];
                        array[5] <= array[6]; array[6] <= array[5];
                    end
                    3'd4: begin
                        array[5] <= array[7]; array[7] <= array[5];
                    end
                    3'd5: begin
                        array[6] <= array[7]; array[7] <= array[6];
                    end
                    // ChangingPoint 是 6 的話，右邊只有一個元素，不需要翻轉
                    default: ;
                endcase

                    // 排序完成，回到 S0、S1計算 MinCost、MatchCount
                    // 歸零計算成本及 CostCount
                    tempMinCost <= 0;
                    CostCount <= 0;
                    state <= S0;
            end
            default: state <= state;
        endcase
    end
end

endmodule