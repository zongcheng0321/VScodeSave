module JAM (
input CLK,
input RST,
output reg [2:0] W,
output reg [2:0] J,
input [6:0] Cost,
output reg [3:0] MatchCount,
output reg [9:0] MinCost,
output reg Valid );

// 字典排序法?
// 想法:先做某工作的
// **一個人只能做一個工作，所以必須全部排出來之後...平板
// 但最後有太多可能性的疊加，所以回歸字典排序法
//reg [15:0] arrangeStore [2:0][2:0];// 全排序總共有8! = 40320 所以要宣告 2^16 個空間
/////////////////////////// reg [7:0][2:0] array [40319:0]; // 搞懂怎麼宣告了，宣告一個最多可以儲存40320個陣列[40319:0]，每個陣列長度8[7:0]，陣列元素數值最大為7[2:0]


// 做一個 FSM，在一邊排列時，每排完一個陣列就計算 MinCost，且紀錄陣列排序方式及每個排列方式的 Mincost。
// 做完全部40320陣列後，再做一次找 MatchCount，但不排列，把剛剛紀錄的陣列排列方式跟 Mincost比對(只比對Mincost)，做完後把 Valid 拉高結束。
//reg [15:0] arrangementCount; //計數排了多少陣列，理論上必須要排 twice 40320個陣列，才會把 Valid 拉高

//always @(*) 組合邏輯中，意味著你要求硬體在「同一個瞬間」把 W 腳位變成 0, 1, 2...7，並期望 Cost 接腳瞬間給出 8 個對應的回傳值。這在真實世界是做不到的！
//解法： 讀取 Cost 必須透過 Clock 驅動，利用計數器（Counter）在 8 個 Clock 週期內，一次送出一組 W 和 J，並把收到的 Cost 慢慢累加。
//2. 組合邏輯中的自我累加 (k++, tempMinCost += Cost)
//在 always @(*) 這種組合邏輯區塊內，寫出 k++ (等同於 k = k + 1) 或是 j-- 會產生組合邏輯迴路 (Combinational Loop)。因為沒有 Clock 控制，訊號會在閘道器之間無限狂奔，導致模擬器當機。

reg [2:0] array [7:0]; 
reg MatchCountFlag; // 做完第一次之後，第二次要開始計算 MatchCount，所以把此旗標拉高表示要開始計算了。
//原本打算只做一次全排列就把值存起來，不過做到後面發現這樣用太多記憶體，所以改成做兩次全排列，第一次找 MinCost，第二次再找 MatchCost
//reg [7:0][2:0] array [40319:0]; //宣告一個最多可以儲存40320個陣列[40319:0]，每個陣列長度8[7:0]，陣列元素數值最大為7[2:0]

reg [2:0] j = 3'd7; // array [j]
//reg [2:0] j = 7, k =7;// array [j][k]
reg [2:0] ChangingPoint; // 替換點
reg k = 1'd1; // 利用 [ChangingPoint + k] 尋找比替換點大的數
reg [2:0] minNumPosition; // 比替換點大的最小數的位置
reg [2:0] temp; // 做交換時暫存值
reg [9:0] tempMinCost; // 暫存 MinCost 值以用於比較
integer i;

// 全排序 FSM
reg [2:0] state,next_state;
parameter S0 = 3'd0,
          S1 = 3'd1, 
          S2 = 3'd2,
          S3 = 3'd3;



// 控制 FSM 執行
always @(posedge CLK or negedge RST) begin
    if(!RST) begin
        state <= S0;
    end else 
        state <= next_state;
end

// 狀態該做的事
always @(*) begin
    case (state)
        // 判斷右邊是否大於左邊並產生替換點
        S0: begin
            // initialize variable that will be used later
            j = 3'd7;
            k = 1'd1;
            temp = 3'd0;
            // 計算最小值
            for (i = 0; i<8; i++) begin
                // 提取 Cost
                W = i;
                J = array[i];
                tempMinCost += Cost;
            end
            // MinCost default is 1023
            if (tempMinCost <= MinCost) begin
                MinCost = tempMinCost;
                // 這是第二輪要開始計算 MatchCount
                if (MatchCountFlag) begin
                    MatchCount++;
                end else begin
                    MatchCount = MatchCount;
                end
            end else begin
                MinCost = MinCost;
            end

            // e.g. array[7] > array[6] 右邊大於左邊
            if (j > 0) begin // 中止條件 if j <= 0 -> j - 1 = -1 -> WRONG
                if (array[j] > array[j - 1]) begin
                ChangingPoint = j - 1; //當右邊比較大時，將左邊設為替換點
                minNumPosition = j + 1; // 預設值為 ChangingPoint 的右邊第一個
                next_state = S1; 
                // 如果右邊不大於左邊，找下一個
                end else begin
                j--;
                next_state = S0;
                end
            end else begin
                // 當已經把所有排列完成，右邊沒有任何數小於左邊
                if (MatchCountFlag) begin // 已結束第二輪，計算完 MatchCount，拉高 Vaild 結束模擬
                    Valid = 1'd1;
                end else begin // 第一輪結束 -> initialize array and repeat FSM.
                    MatchCountFlag = 1'd1;
                    for (i = 0; i < 8; i++) begin // array = [0,1,2,3,4,5,6,7]
                        array[i] <= i;
                    end
                    next_state = S0;
                end
            end
        end

        // 在替換點右邊的的數字中，找到比替換數大的最小數字，將之和替換數交換
        S1: begin
            if ((ChangingPoint + k) < 8) begin // 中止條件 當已經跑完整個陣列在 else 那邊做替換點與 minNumPosition 交換
                if (array[ChangingPoint] < array[ChangingPoint + k] ) begin // 找到比替換數大的數字
                    if (array[minNumPosition] >= array[ChangingPoint + k] ) begin // 在這之中找最小值
                        minNumPosition = ChangingPoint + k;
                        k++;
                        next_state = S1;
                    end else begin
                        k++;
                        next_state = S1;
                    end
                end
            end else begin
                // 替換點值與 minNumPosition 值交換
                temp = array[ChangingPoint];
                array[ChangingPoint] = array[minNumPosition];
                array[minNumPosition] = temp;

                next_state = S2;
            end
        end
        // 把替換點後的數字前後順序翻轉過來，即可得下一字典序列。
        S2:begin
            // 翻轉一維陣列，ChangingPoint + 1 為替換點後的數字的第一個
            // 8 - i 定義為需要翻轉之陣列的 Size
            for (i = ChangingPoint + 1; i < (8 - i + 1)/2; i++) begin
                temp = array[i];
                array[i] = array[8 - i]; // 1、7 or 2、6 or 3、5 exchange
                array[8 - i] = temp;
            end
            next_state = S0;
        end
        S3:;
        default: ; 
    endcase
end

always @(posedge CLK or negedge RST) begin
    if (!RST) begin
        // initialize variable
        MatchCount <= 0;
        MinCost <= 10'd1023;
        Valid <= 0;
        //arrangementCount <= 0;
        tempMinCost <= 0;
        MatchCountFlag <= 0;
        for (i = 0; i < 8; i++) begin // array at the beginning is [0,1,2,3,4,5,6,7]
            array[i] <= i;
        end
    end else begin

    end
end

endmodule