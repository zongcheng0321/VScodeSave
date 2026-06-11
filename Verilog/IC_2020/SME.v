module SME(clk,reset,chardata,isstring,ispattern,valid,match,match_index);
input clk; // posedge
input reset; // active high asynchronous
input [7:0] chardata;
input isstring;
input ispattern;
output match;
output [4:0] match_index; // 當string 和 pattern 比對成功，輸出pattern 在string 中第一個比對成功的位置。
output valid;
reg match;
reg [4:0] match_index;
reg valid;

//-----------------------------------------
reg [2:0] state;
localparam  INPUT = 3'd0,
            CMP_WORD = 3'd2,
            CMP = 3'd3,
            OUTPUT = 3'd5;
//-----------------------------------------
reg [4:0] cnt; // 計數器 for all purpose 0 ~ 31
reg [2:0] cnt_pattern; // 計數器 for pattern 0 ~ 7
reg [7:0] string [31:0]; // 8bits 0 ~ 31
reg [7:0] pattern [7:0];// 8bits 0 ~ 7
reg [4:0] length_st; // string length (ex. 字串長度 32 的話這裡會是 31)
reg [2:0] length_pa; // pattern length
reg same; // flag for match_index 判斷 是否曾經有 string == pattern 過
//-----------------------------------------
// 判斷特殊字符或原 pattern 值
// 5E  ^ , 24 $, 2E .
wire [7:0] pattern_value;
assign pattern_value = (pattern[cnt_pattern] == 8'h2E)? string[cnt] : pattern[cnt_pattern];

wire first_word_condition; // 判斷上一個字元是否是空格或 string 第一個位置不是空格 -> 滿足條件 (協助判斷 ^ 的第一個開頭)
assign first_word_condition = (string[cnt - 32'd1] == 8'h20)? 1'd1: 
                             (cnt == 0)? 
                             ((string[0] != 8'h20)? 1'd1: 1'd0)
                             : 1'd0; 

wire last_word_condition; // string 當前為空格 or pattern 索引為最後一個 -> 最後一個他一定是某個 word 的最後一個字元 (協助判斷 $ 條件)
assign last_word_condition = (string[cnt] == 8'h20)? 1'd1: 
                             (cnt == length_st)? 1'd1: 1'd0;

wire checkWord_5E;
wire checkWord_24;
assign checkWord_5E = (pattern[0] == 8'h5E)? 1'd1: 1'd0; // 只要 pattern 有出現 ^ 就為 1
assign checkWord_24 = (pattern_value == 8'h24)? 1'd1: 1'd0; // 當 pattern_value 出現 $ 才為 1
//-----------------------------------------

always @(posedge clk or posedge reset) begin
    if (reset) begin
        match <= 0;
        match_index <= 0;
        valid <= 0;

        state <= INPUT;
        //string <= 0;
        //pattern <=0;
        length_pa <= 0;
        length_st <= 0;
        cnt <= 0; // 記得重製 cnt
        cnt_pattern <= 0;
        same <= 0;
    end else begin
        case (state)
            INPUT: begin
                // 重製 for 下一個 pattern 判斷
                match <= 0;
                match_index <= 0;
                valid <= 0;

                if (isstring) begin
                    string[cnt] <= chardata;
                    cnt <= cnt + 1'd1;
                    length_st <= cnt;
                end else if (ispattern) begin
                    pattern[cnt_pattern] <= chardata;
                    cnt_pattern <= cnt_pattern + 1'd1;
                    length_pa <= cnt_pattern;
                end else begin
                    cnt <= 0;

                    if (checkWord_5E) begin // 重製 pattern 索引，這邊判斷是否為特殊字元來決定重製位置
                            cnt_pattern <= 1'd1; // 從 pattern[1] 開始，因為 pattern [0] 為 ^
                        end else begin
                            cnt_pattern <= 0;
                    end

                    same <= 0;
                    state <= CMP;
                end
            end 

            CMP: begin
                if (cnt <= length_st) begin // 如果字串計數器(索引)小於字串長度時就去比對
                    if (string[cnt] == pattern_value) begin // 比對成功(含比對任意單一字元 '.')
                        if (!same) begin // 第一次比對到時 same = 0，match_index 輸出 Pattern 在 String 中 match 的第一個位置
                                         // 有多種  match 可能，取 match_index 最小的結果
                            match_index <= cnt;
                            same <= 1'd1;// 判斷已經有一樣過了，要確保 match_index 不會再被改變了
                        end

                        if (cnt_pattern == length_pa) begin // 當 pattern 索引等於總長度時，表示 match
                            match <= 1'd1; 
                            state <= OUTPUT;
                        end else begin // 沒有到 pattern 的最後一個時

                            if (checkWord_5E) begin // 有特殊字元 ^ 的情況
                                if (cnt_pattern == 1'd1) begin // 現在要判斷 pattern 所指定的開頭字元是否等於 string 中 word 的開頭字元
                                    if (first_word_condition) begin // 是 word 開頭 -> 兩邊同時前進
                                        cnt <= cnt + 1'd1;
                                        cnt_pattern <= cnt_pattern + 1'd1;
                                    end else begin                 // 不是 word 開頭
                                        cnt <= cnt + 1'd1;
                                        same <= 0;
                                    end
                                end else begin          // 當現在不是要判斷 pattern 的開頭字元，而是已經滿足 pattern 的開頭字元並前進到 pattern 下個位置的時候
                                    cnt <= cnt + 1'd1;  // 因為還是相等，代表又可以前進
                                    cnt_pattern <= cnt_pattern + 1'd1;
                                end
                            end else begin // 沒有特殊字元 ^ 的情況
                                cnt <= cnt + 1'd1;
                                cnt_pattern <= cnt_pattern + 1'd1;
                            end
                            
                            if (cnt == length_st) begin // 當已經判斷到 string 的最後一個卻沒有到 pattern 的最後一個時
                                if (pattern[cnt_pattern + 1'd1] ==  8'h24) begin // 當 pattern 下一個為 $ 達成條件 -> match
                                    if (same) begin // 當最後一個為 $ 時，他是否有連續判斷紀錄，如果有 ^ 且有連續判斷紀錄 (same = 1) 代表他已經符合過是 word 開頭的定義
                                                    // 如果沒有 ^，當判斷到 string 最後一個時他也已經是 word 的最後面了，不管 same = 1 or same != 1 他都會是符合 word 結尾的定義
                                        match <= 1'd1;
                                        state <= OUTPUT;
                                    end else begin
                                        // same == 0 代表這是 pattern 的第一個實質字元 (單字元 pattern 狀況)
                                        if (checkWord_5E && first_word_condition) begin // 當它不符合連續判斷紀錄且開頭有 ^ 代表說他是 ^x$ ，只要判斷他是否符合 first_word_condition 定義
                                            match <= 1'd1;
                                            state <= OUTPUT;
                                        end else if (!checkWord_5E) begin // 是 x$ (沒有 ^)，只要在字串尾巴符合就算過
                                            match <= 1'd1;                // 不管 same = 1 or same != 1 他都會是符合 word 結尾的定義
                                            state <= OUTPUT;
                                        end else begin // 是 ^x$ 但不符合開頭條件 (例如前面沒有空格)
                                            match <= 0;
                                            state <= OUTPUT;
                                        end
                                    end
                                end else begin
                                    match <= 0;
                                    state <= OUTPUT;
                                end
                            end
                        end
                    end else begin // 當比對不成功兩種情況 1. same = 0 -> 前字串字元不符合 pattern 字元 2. same = 1 -> 前字串字元符合 pattern 字元
                        if (same) begin // 第二種狀況下，因為 cnt_pattern 跳到下一個了，所以要重新重第一個索引比較，且也要復原 cnt 的值，讓 cnt 原值 + 1
                            same <= 0;
                            cnt <= match_index + 1'd1;

                            if (checkWord_24 && last_word_condition) begin // 因為前字串字元符合 pattern 字元但現在是 $ 符號，所以要判斷 $ 的條件
                                    match <= 1'd1;
                                    state <= OUTPUT;
                            end

                        end else begin // 第一種情況下，cnt_pattern 沒動，讓 cnt (字串索引) + 1，判斷下一個字元
                            cnt <= cnt + 1'd1;
                        end

                        if (checkWord_5E) begin // 不管哪種情況下都要重製 pattern 索引，這邊判斷是否為特殊字元來決定重製位置
                                cnt_pattern <= 1'd1; // 從 pattern[1] 開始，因為 pattern [0] 為 ^
                            end else begin
                                cnt_pattern <= 0;
                        end

                        if (cnt == length_st) begin // 當已經判斷到 string 的最後一個卻沒有到 pattern 的最後一個時
                            match <= 0;
                            state <= OUTPUT;
                        end
                    end
                end else begin // 當字串計數器(索引)超出陣列長度還沒比對到，代表 unmatch
                    if (cnt_pattern == length_pa) begin 
                        match <= 1'd1;
                    end else begin
                        match <= 0;
                    end
                    state <= OUTPUT;
                end
            end

            OUTPUT: begin
                valid <= 1'd1;
                cnt <= 0;
                cnt_pattern <= 0;
                same <= 0;
                state <= INPUT;
            end
            default:;
        endcase
    end
end
endmodule
