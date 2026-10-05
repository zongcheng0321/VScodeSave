// 記憶體操作及使用要參照 pdf 文件
// 找連在一起的相同物件，由於我修過資料結構，我的第一個想法是用 DFS or BFS
// DFS、BFS 評估：這樣還要實作記憶體 stack 或 queue，能不能把輸出的 SRAM 拿來當成可以存東西的(不多做一個記憶體耗面積)? -> 問 AI 
// DFS、BFS 有點麻煩

// 要一邊輸入資料做 還是 全部資料存起來再做?
// 全部資料存起來多花 32 * 32 -> 1024 bits
// 因為判斷需要判斷九宮格，但輸入資料是一次輸入橫排 8 bits 直到輸入到共 32 bits (橫排結束)後，換行繼續輸入
// 判斷九宮格如果要一直去操作輸入資料的話，我認為判斷的電路會比較麻煩，所以我打算多花 1024 bits 把題目圖片輸入進來後，再去做判斷
// 一次輸入 8 bits，所以一列只花 4 clk，4 * 32 = 128 clk

// 新想法：把輸入來的資料存進 SRAM，全部存完後把九宮格資料拿出來判斷，然後再放回去
// 消耗 clk 數為 input 4*32 + output 1024 + 一個 pixel 要花 9 clk 判斷 * 從 SRAM 把資料要出來 = 128 + 1024 + (3 * 31 + 9 * 32)*9 = 29691 clk
// 一邊做一邊要資料，雖然判斷跟多工器比較複雜，但消耗 clk 數為 input 4*32 + output and calculate 1024 * 9 = 9344 clk
// 差了三倍的時間，多出來的暫存器數量忽略不計，我決定先以一邊輸入一邊做運算來做。

`timescale 1ns/10ps
//`include ""
module CLE ( clk, reset, rom_q, rom_a, sram_q, sram_a, sram_d, sram_wen, finish);
input         clk;
input         reset; // 高位準非同步
input  [7:0]  rom_q;
output reg [6:0]  rom_a;
input  [7:0]  sram_q;
output reg [9:0]  sram_a;
output reg [7:0]  sram_d;
output reg    sram_wen; // 當該訊號為 Low，表示 CLE 要對 SRAM 作寫入，反之，當該訊號為 High，表示 CLE 要對 SRAM 作讀取。該訊號直接與 SRAM 的控制訊號腳位 WEN 相連。
output reg    finish;

// ROM and SRAM
rom_128x8 u_rom ( 
   .Q(rom_q), // 看 pdf 大概負緣送出資料
   .CLK(clk),
   .CEN(0),
   .A(rom_a)
);
sram_1024x8 u_sram (
   .Q(sram_q), // 看 pdf -> 寫入或讀取都是負緣前送出資料 
   .CLK(clk),
   .CEN(0),
   .WEN(sram_wen), // L 寫入 H 讀取
   .A(sram_a),
   .D(sram_d)
);


//FSM
reg [3:0] state;
localparam INPUT_ROM_FIRST_ROW = 4'd0,
           INPUT_ROM = 4'd1,
           UPDATE_ROM_ADDR = 4'd2,
           CAUL = 4'd3,
           DROP3 = 4'd4,
           DROP4 = 4'd5,
           DROP_UPDATE = 4'd6,
           SORT = 4'd7,
           SAME_LINE = 4'd8,
           SAME_LINE1 = 4'd9,
           CALC = 4'd10,
           OUTPUT = 4'd11;
//----------------------------------------
// address
// 我的 x, y 跟題目方向相反
reg [4:0] output_x, y; // 32*32
reg [1:0] input_x;     // 4 *32
reg is_first_input;
reg [4:0] rom_x_cnt; // 最高到 30

// 讓兩個記憶體位置互相對應

//wire [6:0] input_addr;
wire [9:0] output_addr;
//assign input_addr = {y, input_x};
assign output_addr = {y, output_x};
//----------------------------------------
// 九宮格
reg accept_data; // 當此為 1 代表此 clk 準備接收資料，當為 0 代表等待給出位置
// 輸入進來的 row
reg [31:0] row_1, row_2, row_3; 
reg [1:0] choose_row_to_input; // 0: normal, 1: row_1, 2: row_2, 3: row_3
reg [3:0] cnt; 
// 0 的權重大於 1； 1 大於 2； 2 大於 3...
// [0 3 6]
// [1 4 7]
// [2 5 8]
wire [8:0] pixel; // 9個 pixel
assign pixel[0] = row_1[0 + rom_x_cnt];
assign pixel[1] = row_2[0 + rom_x_cnt];
assign pixel[2] = row_3[0 + rom_x_cnt];
assign pixel[3] = row_1[1 + rom_x_cnt];
assign pixel[4] = row_2[1 + rom_x_cnt];
assign pixel[5] = row_3[1 + rom_x_cnt];
assign pixel[6] = row_1[2 + rom_x_cnt];
assign pixel[7] = row_2[2 + rom_x_cnt];
assign pixel[8] = row_3[2 + rom_x_cnt];

always @(*) begin
    if (pixel[4] == 1'd1) begin // 中心點是 1 再去判斷
        // 從 8 的位置掃描到 0 ，如果有被編號過，那就換成那個編號，如果全部沒有被編號過，寫入編號給全部的 1
        // 我要怎麼知道有沒有被編號過??!!??!!??!!
    end
end
//----------------------------------------
// zero padding 捨棄
// 想法：處理 1. 現在做到哪(x, y)： 第 0 列 or 第 0 行 or 最後一列 or 最後一行 zero_padding
//           2. 根據 x and y ，3x3 的哪些位置要補 0? (由 cnt 決定 3*3 位置)    
// 利用多工器，判斷如果現在是上述所說的行或列，對應的 pixels 要補 0。
// 角落的四種狀態跟一般的邊界狀態
/*
wire boundaryT, boundaryB, boundaryL, boundaryR; // 上下左右邊界 Top Bottom Left Right
assign boundaryT = (x == 0)? 1'd1: 1'd0;
assign boundaryB = (x == 5'd31)? 1'd1: 1'd0;
assign boundaryL = (y == 0)? 1'd1: 1'd0;
assign boundaryR = (y == 5'd31)? 1'd1: 1'd0;
wire need_zeroPadding; // 根據想法做出需要補 0 時的狀況
// 上邊界且 pixel_index_row = 0 時
// 下邊界且 pixel_index_row = 2 時
// 左邊界且 pixel_index_col = 0 時
// 右邊界且 pixel_index_col = 2 時
// 這樣也同時滿足左右上下角
assign need_zeroPadding =   (boundaryT && (cnt == 0 || cnt == 3 || cnt == 6)) || 
                            (boundaryB && (cnt == 2 || cnt == 5 || cnt == 8)) || 
                            (boundaryL && (cnt == 0 || cnt == 1 || cnt == 2)) || 
                            (boundaryR && (cnt == 6 || cnt == 7 || cnt == 8));*/
//----------------------------------------


//----------------------------------------
always @(posedge clk or posedge reset) begin
    if (reset) begin
        // reset singal
        state <= INPUT_ROM_FIRST_ROW;
        input_x <= 0; output_x <= 0; y <= 5'd3;
        // module
        finish <= 0;
        accept_data <= 0;
        is_first_input <= 1'd1;
        cnt <= 0;
        choose_row_to_input <= 1'd1;
    end else begin
        case (state)
            INPUT_ROM: begin // 此時位置已更新好，給出要資料的位置，下一個 clk 接收資料
                cnt <= cnt + 1'd1;
                accept_data <= 1'd1;

                if (cnt == 4'd1 || cnt == 4'd3 || cnt == 4'd5 || cnt == 4'd7) begin
                    input_x <= input_x + 1'd1;
                end

                // state 改變
                if (accept_data) begin
                    accept_data <= 0;
                    case ({choose_row_to_input, cnt})
                        // 一般情況(第四排開始)
                        {2'd0, 4'd1}: begin
                            row_3[7:0] <= rom_q;
                            row_2 <= row_3;
                            row_1 <= row_2;
                        end
                        {2'd0, 4'd3}: begin
                            row_3[15:8] <= rom_q;
                        end
                        {2'd0, 4'd5}: begin
                            row_3[23:16] <= rom_q;
                        end
                        {2'd0, 4'd7}: begin
                            row_3[31:24] <= rom_q;
                            cnt <= 0;
                        end
                        // 第一排(reset 後預設 choose_row_to_input 為 1)
                        {2'd1, 4'd1}: begin
                            row_1[7:0] <= rom_q;
                        end
                        {2'd1, 4'd3}: begin
                            row_1[15:8] <= rom_q;
                        end
                        {2'd1, 4'd5}: begin
                            row_1[23:16] <= rom_q;
                        end
                        {2'd1, 4'd7}: begin
                            row_1[31:24] <= rom_q;
                            cnt <= 0;
                            choose_row_to_input <= 2'd2;
                        end
                        // 第二排(reset 後預設 choose_row_to_input 為 1)
                        {2'd2, 4'd1}: begin
                            row_2[7:0] <= rom_q;
                        end
                        {2'd3, 4'd3}: begin
                            row_2[15:8] <= rom_q;
                        end
                        {2'd2, 4'd5}: begin
                            row_2[23:16] <= rom_q;
                        end
                        {2'd2, 4'd7}: begin
                            row_2[31:24] <= rom_q;
                            cnt <= 0;
                            choose_row_to_input <= 2'd3;
                        end
                        // 第三排(reset 後預設 choose_row_to_input 為 1)
                        {2'd3, 4'd1}: begin
                            row_3[7:0] <= rom_q;
                        end
                        {2'd3, 4'd3}: begin
                            row_3[15:8] <= rom_q;
                        end
                        {2'd3, 4'd5}: begin
                            row_3[23:16] <= rom_q;
                        end
                        {2'd3, 4'd7}: begin
                            row_3[31:24] <= rom_q;
                            cnt <= 0;
                            choose_row_to_input <= 0;
                            state <= CALC;
                        end
                        
                        default: ;
                    endcase
                end
            end

            
            
            // 更新 ROM 位置，之後計算九宮格都算完後可以直接去 INPUT_ROM 要新資料
            UPDATE_ROM_ADDR: begin
                // input addr calculate
                if (x == 5'd31) begin
                    x <= 0;
                    if (next_y == 5'd31) begin //**
                        y <= 0;
                        //state <= ...;
                    end else begin
                        y <= y + 1'd1;
                    end
                end else begin
                    x <= x + 1'd1;
                end

                // state 改變
                state <= CALC;
            end

            CALC: begin
                
            end

            OUTPUT: begin
                
            end
            default: ;
        endcase
    end
end

always @(*) begin
    case (state)
        INPUT_ROM: begin
            case (choose_row_to_input)
                0: rom_a = {y, input_x};    // 從第四排開始輸入(y = 3 開始計數)
                1: rom_a = {5'd0, input_x}; // 第一排
                2: rom_a = {5'd1, input_x}; // 第二排
                3: rom_a = {5'd2, input_x}; // 第三排
                default: rom_a = {y, input_x};
            endcase
        end


        default: begin end
    endcase
end
endmodule
