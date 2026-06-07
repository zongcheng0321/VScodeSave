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
localparam  INPUT_STRING = 3'd0,
            INPUT_PATTERN = 3'd1,
            SPLIT_WORD = 3'd2,
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
assign pattern_value = (pattern[cnt_pattern] == 8'h2E)? string[cnt] : pattern_value[cnt_pattern];
//-----------------------------------------

always @(posedge clk or posedge reset) begin
    if (reset) begin
        match <= 0;
        match_index <= 0;
        valid <= 0;

        state <= INPUT_STRING;
        //string <= 0;
        //pattern <=0;
        length_pa <= 0;
        length_st <= 0;
        cnt <= 0; // 記得重製 cnt
        same <= 0;
    end else begin
        case (state)
            INPUT_STRING: begin
                // 重製 for 下一個 pattern 判斷
                match <= 0;
                match_index <= 0;
                valid <= 0;

                if (isstring) begin
                    string[cnt] <= chardata;
                end else begin
                    cnt <= 0;
                    length_st <= cnt;
                    state <= INPUT_PATTERN;
                end
                cnt <= cnt + 1'd1;
            end 

            INPUT_PATTERN: begin
                if (ispattern) begin
                    pattern[cnt] <= chardata;
                end else begin
                    cnt <= 0;
                    same <= 0;
                    length_pa <= cnt;
                    state <= CMP;
                end
                cnt <= cnt + 1'd1;
            end 
            
            //SPLIT_WORD: begin
                
            //    cnt <= cnt + 1'd1;
            //end

            CMP: begin
                if (cnt <= length_st) begin // 如果字串計數器(索引)小於字串長度時就去比對
                    if (string[cnt] == pattern_value) begin // 比對成功(含特殊字元)
                        if (!same) begin // 第一次比對到時 same = 0，match_index 輸出 Pattern 在 String 中 match 的第一個位置
                                         // 有多種  match 可能，取 match_index 最小的結果
                            match_index <= cnt;
                            same <= 1'd1;// 判斷已經有一樣過了，要確保 match_index 不會再被改變了
                        end

                        if (cnt_pattern == length_pa) begin // 當 pattern 索引等於總長度時，表示 match
                            match <= 1'd1; 
                            state <= OUTPUT;
                        end else begin
                            cnt <= cnt + 1'd1;
                            cnt_pattern <= cnt_pattern + 1'd1;
                        end
                    end else begin // 當比對不成功兩種情況 1. 前字串字元不符合 pattern 字元 2. 前字串字元符合 pattern 字元
                        if (same) begin // 第二種狀況下，因為 cnt_pattern 跳到下一個了，所以要重新重第一個索引比較
                            same <= 0;
                            cnt_pattern <= 0;
                        end else begin // 第一種情況下，cnt_pattern 沒動，讓 cnt (字串索引) + 1，判斷下一個字元
                            cnt <= cnt + 1'd1;
                            cnt_pattern <= 0;
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
                state <= INPUT_STRING;
            end
            default:;
        endcase
    end
end
endmodule
