/*平行處理 (Parallel Processing) = 面積換速度
假設你有 4 筆資料需要做加法。

作法：你實作了 4 個加法器 (Adder)，在同一個 Clock 週期內把 4 筆資料同時算完。

結果：速度超快（1 個 cycle 搞定），但面積變大（用了 4 個加法器的硬體資源）。這就是所謂的平行處理。

資源共享 / 串行處理 (Resource Sharing) = 速度換面積
一樣有 4 筆資料要做加法。

作法：你為了省面積，只實作了 1 個加法器，然後搭配多工器 (MUX) 和狀態機 (FSM)，分 4 個 Clock 週期把資料輪流送進去算。

結果：面積變小了（只用了 1 個加法器），但速度變慢了（需要 4 個 cycle 才算完）。
*/
module  CONV(
    input   clk,
    input   reset,
    output reg busy,
    input   ready,
    
    output reg [11:0] iaddr,
    input signed [19:0] idata,

    output reg cwr,
    output reg [11:0] caddr_wr,
    output reg signed [19:0] cdata_wr,

    output reg crd,
    output reg [11:0] caddr_rd,
    input signed [19:0] cdata_rd,

    output reg [2:0] csel
);
//---------------------------------------------------------------
// FSM parameter
    localparam 
               LAYER0_READY = 4'd9,
               SIGNAL_INPUT = 4'd0, // 將 busy 拉為 1 表示要開始做了
               ZERO_PADDING = 4'd1, // 判斷角落的四種狀態跟一般的邊界狀態決定是否要補 0
               UPDATE_PIXEL_ROW_AND_COL = 4'd2, // 更新 pixel 的 row and col 到下一個位置
               INPUT_DATA = 4'd3,   // 把輸入進來的資料分給 pixels
               CHANGE_PIXEL = 4'd4, // 一次一個 clk 把資料輸入進來，當row不等於第一列or最後一列 or 當col不等於第一行or最後一列
               WAIT_CONV = 4'd5,
               //ReRU = 4'd6,
               GET_WIDTH = 4'd6,
               OUTPUT_LAYER0 = 4'd7,
               
                
               CHOOSE_LAYER1 = 4'd8,
               LAYER1_READY = 4'd15,
               INPUT_DATA_LAYER1 = 4'd10,
               CHANGE_PIXEL_LAYER1 = 4'd11,
               UPDATE_PIXEL_ROW_AND_COL_LAYER1 = 4'd12,
               MAX_POOLING = 4'd13,
               OUTPUT_LAYER1 = 4'd14;

    reg [3:0] state_main;
    reg [3:0] state_Convolutional;
// ---ZERO_PADDING要使用的變數---
    reg [5:0] col; // 從左數到右的計數器，表示做到矩陣的哪裡，最大值 6'd63
    reg [5:0] row; // 從上數到下的計數器，表示做到矩陣的哪裡，最大值 6'd63

    // 要跟 kernel 做乘法然後做完全部相加，且在 main 中當作完一次捲積(endConvolutional = 1)，pixels 值要做更換
    reg signed [19:0] pixels [2:0][2:0]; // 此為補過 0 的 3x3 暫存器 
// ---CHANGE_PIXEL、INPUT_DATA---
    reg [1:0] pixel_index_row; // 改變 PIXEL 時要用的引索(row)
    reg [1:0] pixel_index_col; // 改變 PIXEL 時要用的引索(col)
    wire [11:0] input_index; // 紀錄現在取到多少了
// ---Layer0、1 輸出變數---
    reg [19:0] Layer0_out;

// FSM for Convolutional
    // 20bits * 20 bits = 40 bits
    // 2 個相加 = 41 bits
    // 4 個相加 = 42 bits
    // 8 個相加 = 43 bits
    // 9 個相加 = 44 bits
    reg signed [43:0] Convolutional_out; // 捲積輸出
    reg endConvolutional; // 結束捲積旗標

//---------------------------------------------------------------
// Deal with layer0 zero_padding
// 想法：處理 1. 現在做到哪(row, col)： 第 0 列 or 第 0 行 or 最後一列 or 最後一行 zero_padding
//           2. 根據 row and col ，3x3 的哪些位置要補 0? (pixel_index_col, pixel_index_row)    
// 利用多工器，判斷如果現在是上述所說的行或列，對應的 pixels 要補 0。
    // 角落的四種狀態跟一般的邊界狀態
    wire boundaryT, boundaryB, boundaryL, boundaryR; // 上下左右邊界 Top Bottom Left Right
    assign boundaryT = (row == 0)? 1'd1: 1'd0;
    assign boundaryB = (row == 6'd63)? 1'd1: 1'd0;
    assign boundaryL = (col == 0)? 1'd1: 1'd0;
    assign boundaryR = (col == 6'd63)? 1'd1: 1'd0;
    wire need_zeroPadding; // 根據想法做出需要補 0 時的狀況
    // 上邊界且 pixel_index_row = 0 時
    // 下邊界且 pixel_index_row = 2 時
    // 左邊界且 pixel_index_col = 0 時
    // 右邊界且 pixel_index_col = 2 時
    // 這樣也同時滿足左右上下角
    assign need_zeroPadding = (boundaryT && pixel_index_row == 0) || 
                              (boundaryB && pixel_index_row == 2'd2) || 
                              (boundaryL && pixel_index_col == 0) || 
                              (boundaryR && pixel_index_col == 2'd2);

//---------------------------------------------------------------
// 處理 Layer0 跟 Layer1 的要資料的位置 iaddr

    // 如果這樣寫面積會大(會產生一堆加法器):
    // 三種判別情況 1. 碰到最右邊的時候 2. 碰到最下面的時候 3. 不在最右邊跟最下面的時候
    /*
    wire MaxRight, MaxBottom, Normal;
    assign MaxRight = ((pixel_index_row + row - 6'd1) << 6) + col + pixel_index_col; // col 這邊不減 1
    assign MaxBottom = ((pixel_index_row + row) << 6) + col + pixel_index_col; // row 這邊不減 1
    assign Normal = ((pixel_index_row + row - 6'd1) << 6) + col + pixel_index_col - 6'd1; // 兩邊都要減 1
    always @(*) begin
        // 判斷 csel == 3'b001 -> L0_MEM0(Layer0), csel == 3'b011 -> L1_MEM0(Layer1)
        if (csel == 3'b001) begin
            case ({boundaryB, boundaryR})
                2'b10: input_index = MaxBottom;
                2'b01: input_index = MaxRight;
                default: input_index = Normal;
            endcase
        end else begin
            ;
        end
    end
    */

    // 縮小面積 - > 先決定出目標 row and col (用多工器) 再一次加起來
    wire [5:0] target_row;
    wire [5:0] target_col;
    assign target_row = (state_main == INPUT_DATA)? pixel_index_row + row - 6'd1: pixel_index_row + row;
    assign target_col = (state_main == INPUT_DATA)? pixel_index_col + col - 6'd1: pixel_index_col + col;

    /* 錯誤程式 -> 把row and col 最大值想成 62 的狀況。
    ////////////////////////////////////////////////////////////////////////////////////////
    // 如果碰到下面界，row 不用減 1；否則正常情況要減 1
    assign target_row = boundaryB? (pixel_index_row + row): (pixel_index_row + row - 6'd1);
    // 如果碰到右邊界，col 不用減 1；否則正常情況要減 1
    assign target_col = boundaryR? (pixel_index_col + col): (pixel_index_col + col - 6'd1);
    */
    ////////////////////////////////////////////////////////////////////////////////////////
    //簡化
    /*always @(*) begin
        // initialize 組合邏輯
        input_index = 0; 

        // 判斷 csel == 3'b001 -> L0_MEM0(Layer0), csel == 3'b011 -> L1_MEM0(Layer1)
        if (state_main == INPUT_DATA) begin
            input_index = (target_row << 6) + target_col;
        end else if (state_main == INPUT_DATA_LAYER1) begin
            input_index = (target_row << 6) + target_col;
        end
    end*/
    ////////////////////////////////////////////////////////////////////////////////////////
    assign input_index = (target_row << 6) + target_col;
//---------------------------------------------------------------
// ReLU
    wire signed [43:0] relu_result;
    // 如果 MSB [43] 是 1 (負數)，輸出 0；否則是正數，輸出原本的值
    assign relu_result = (Convolutional_out[43] == 1'b1) ? 44'd0 : Convolutional_out;
//---------------------------------------------------------------
//FSM main
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            busy <= 0;
            state_main <= LAYER0_READY;
            col <= 0;
            row <= 0;
            pixel_index_row <= 0; // 從左上角開始填入資料
            pixel_index_col <= 0; // 從左上角開始填入資料
            

            cwr <= 0; // 寫入記憶體致能
            caddr_wr <= 12'hFFF; // 預設最大值 -> + 1 變 0 開始
            cdata_wr <= 0;
            crd <= 0; // 記憶體寫入致能
            caddr_rd <= 0;
            iaddr <= 0;
            csel <= 3'b001;
        end else begin
            case (state_main) 

                // --- LAYER0 ---
                LAYER0_READY: begin // 一開始 or 換圖測試
                    col <= 0;
                    row <= 0;
                    pixel_index_row <= 0; // 從左上角開始填入資料
                    pixel_index_col <= 0; // 從左上角開始填入資料
                    cwr <= 0; // 寫入記憶體致能
                    caddr_wr <= 12'hFFF; // 預設最大值 -> + 1 變 0 開始
                    cdata_wr <= 0;
                    crd <= 0; // 記憶體寫入致能
                    caddr_rd <= 0;
                    iaddr <= 0;
                    csel <= 3'b001;
                    busy <= 0;
                    if (ready) begin
                        busy <= 1'b1;
                        state_main <= ZERO_PADDING; // 一開始因為是左上角所以要先去 ZERO_PADDING
                    end
                end

                SIGNAL_INPUT: begin
                    // 第二輪開始的初始化
                    cwr <= 0;
                    //caddr_wr <= 12'hFFF;; // 預設最大值 -> + 1 變 0 開始
                    //cdata_wr <= 0;
                    //col <= 0;
                    //row <= 0;
                    pixel_index_row <= 0; // 從左上角開始填入資料
                    pixel_index_col <= 0; // 從左上角開始填入資料
                    csel <= 3'b001; // Layer0 寫入 L0_MEM0
                    state_main <= ZERO_PADDING;
                end
                
                // 檢查補 0 還是去要資料
                ZERO_PADDING: begin
                    if (need_zeroPadding) begin // 補 0
                        pixels[pixel_index_row][pixel_index_col] <= 0;
                        state_main <= UPDATE_PIXEL_ROW_AND_COL;
                    end else begin              // 讀資料
                        state_main <= INPUT_DATA;
                    end
                end
                
                // pixel_index_col、pixel_index_row 要跳到下一個位置
                UPDATE_PIXEL_ROW_AND_COL: begin
                    if (pixel_index_row == 2'd2 && pixel_index_col == 2'd2) begin
                        // 座標歸零，準備下一次 3x3
                        pixel_index_row <= 0;
                        pixel_index_col <= 0;
                        state_main <= WAIT_CONV;// 全部做完進入捲積
                    end else begin
                        // 還沒數完，座標 + 1
                        if (pixel_index_col == 2'd2) begin
                            pixel_index_col <= 0;
                            pixel_index_row <= pixel_index_row + 2'd1;
                        end else begin
                            pixel_index_col <= pixel_index_col + 2'd1;
                        end
                        state_main <= ZERO_PADDING; // 繼續判斷下一個是否要補 0 還是要資料
                    end
                end

                WAIT_CONV: begin
                    if (endConvolutional == 1) begin
                        state_main <= GET_WIDTH; // 否則就一直等待
                    end
                end

                // 要一筆資料
                INPUT_DATA: begin // 會從第一筆資料開始要
                    iaddr <= input_index; // idata 會在負緣時進來且維持到下一個負緣
                    state_main <= CHANGE_PIXEL;
                end

                // 把要的那筆資料填入
                CHANGE_PIXEL: begin
                    pixels[pixel_index_row][pixel_index_col] <= idata;
                    state_main <= UPDATE_PIXEL_ROW_AND_COL;
                end

                // ReRU 不能這樣因為 Convolutional_out 不能在兩個 FSM 被改變，要用組合邏輯完成
                ////////////////////////////////////////////////////////////////////////////////////////
                /*
                ReRU: begin
                    if (Convolutional_out[43] == 1) begin
                        Convolutional_out <= 0;
                    end else begin
                        Convolutional_out <= Convolutional_out;
                    end
                    state_main <= GET_WIDTH;
                end*/
                ////////////////////////////////////////////////////////////////////////////////////////

                // 取 4 bits 整數 (不會有負的因為經過 ReRU 負的已經變成 0 了) + 16 bits 小數 (17 bits 以後四捨五入)
                // + 處理寫入記憶體訊號
                GET_WIDTH: begin
                    // 判斷小數 17 bits 是否為 1 -> [17 bit 為 16 bit 的一半以上] ，而四捨五入也包含五就要進位，因為 17 bits 以後的 MSB 為 1 的話
                    // 就已經等於 5 了，所以後面再有東西也會進位
                    // 只需要把小數的 MSB 加到那 20bits 上即可
                    // 原本的東西是 12 bits 整數 + 32 bits 小數 -> 36~43 8bits 整數捨去，往回數20個
                    Layer0_out <= relu_result[35:16] + relu_result[15];
                    caddr_wr <= caddr_wr + 12'd1;
                    
                    state_main <= OUTPUT_LAYER0;
                end

                OUTPUT_LAYER0: begin
                    cdata_wr <= Layer0_out;
                    cwr <= 1;
                    if (col == 6'd63) begin
                        col <= 0;
                        if (row == 6'd63) begin
                            row <= 0;
                            state_main <= CHOOSE_LAYER1;
                        end else begin
                            row <= row + 6'd1;
                            state_main <= SIGNAL_INPUT;
                        end
                    end else begin
                        col <= col + 6'd1;
                        state_main <= SIGNAL_INPUT;
                    end
                end

                // --- LAYER1 ---
                CHOOSE_LAYER1: begin // 初始化
                    // csel 不改 -> 繼續提取 L0_MEM0 的值
                    csel <= 3'b001; // 準備提取 L0_MEM0 的值
                    col <= 0;
                    row <= 0;
                    cwr <= 0;
                    crd <= 0;
                    caddr_rd <= 0;
                    caddr_wr <= 12'hFFF; // 預設最大值 -> + 1 變 0 開始
                    cdata_wr <= 0;
                    // 把 pixels[0][0] 當成 max_pooling 輸出 (Store)，pixels[0][1] 當成輸入值進行比較 (Temp)
                    pixels[0][0] <= 0; // Store
                    pixels[0][1] <= 0; // Temp
                    // 此時把 pixel_index 限制成 2x2
                    pixel_index_row <= 0; // 從左上角開始填入資料
                    pixel_index_col <= 0; // 從左上角開始填入資料
                    state_main <= INPUT_DATA_LAYER1;
                end

                LAYER1_READY: begin
                    // 第二輪開始的初始化
                    csel <= 3'b001; // 準備提取 L0_MEM0 的值
                    cwr <= 0;
                    crd <= 0;
                    pixels[0][0] <= 0; // Store
                    pixels[0][1] <= 0; // Temp
                    pixel_index_row <= 0; // 從左上角開始填入資料
                    pixel_index_col <= 0; // 從左上角開始填入資料
                    state_main <= INPUT_DATA_LAYER1;
                end

                // 要一筆資料
                INPUT_DATA_LAYER1: begin
                    crd <= 1'd1;
                    caddr_rd <= input_index; // 當時脈負緣觸發時若crd為High，則會在觸發後立刻將caddr_rd 所指示位址的資料讀取到cdata_rd 上
                    state_main <= CHANGE_PIXEL_LAYER1;
                end

                // 把要的那筆資料填入
                CHANGE_PIXEL_LAYER1: begin
                    crd <= 1'd0;
                    pixels[0][1] <= cdata_rd; // 把 pixels[0][0] 當成 max_pooling 輸出，pixels[0][1] 當成輸入值進行比較
                    state_main <= MAX_POOLING;
                end
                
                // 共用比較器
                MAX_POOLING: begin
                    crd <= 0;
                    if (pixels[0][0] < pixels[0][1]) begin // Store < Temp
                        pixels[0][0] <= pixels[0][1]; // Store = Temp
                    end else begin
                        pixels[0][0] <= pixels[0][0]; // 不變
                    end
                    state_main <= UPDATE_PIXEL_ROW_AND_COL_LAYER1;
                end 

                // pixel_index_col、pixel_index_row 要跳到下一個位置
                UPDATE_PIXEL_ROW_AND_COL_LAYER1: begin
                    if (pixel_index_row == 2'd1 && pixel_index_col == 2'd1) begin
                        // 座標歸零，準備下一次 2x2
                        pixel_index_row <= 0;
                        pixel_index_col <= 0;
                        csel <= 3'b011; // 把記憶體選成要輸出的記憶體 L1_MEM0
                        caddr_wr <= caddr_wr + 12'd1;
                        state_main <= OUTPUT_LAYER1;// 全部做完進入去輸出 pixels[0][0]
                    end else begin
                        // 還沒數完，座標 + 1
                        if (pixel_index_col == 2'd1) begin
                            pixel_index_col <= 0;
                            pixel_index_row <= pixel_index_row + 2'd1;
                        end else begin
                            pixel_index_col <= pixel_index_col + 2'd1;
                        end
                        state_main <= INPUT_DATA_LAYER1; // 繼續要資料
                    end
                end

                OUTPUT_LAYER1: begin
                    cdata_wr <= pixels[0][0];
                    cwr <= 1;
                    if (col == 6'd62) begin
                        col <= 0;
                        if (row == 6'd62) begin
                            row <= 0;
                            state_main <= LAYER0_READY;
                        end else begin
                            row <= row + 6'd2; // step = 2
                            state_main <= LAYER1_READY;
                        end
                    end else begin
                        col <= col + 6'd2;     // step = 2
                        state_main <= LAYER1_READY;
                    end
                end

                default: ;
            endcase
        end
    end

//---------------------------------------------------------------
// kernel 宣告
    wire signed [19:0] kernel0 [2:0][2:0]; // ( 4bits整數+16bits小數)
    assign kernel0 [0][0] = 20'h0A89E; // 一開始要用複製的，自己打有可能打錯...
    assign kernel0 [0][1] = 20'h092D5;
    assign kernel0 [0][2] = 20'h06D43;
    assign kernel0 [1][0] = 20'h01004;
    assign kernel0 [1][1] = 20'hF8F71;
    assign kernel0 [1][2] = 20'hF6E54;
    assign kernel0 [2][0] = 20'hFA6D7;
    assign kernel0 [2][1] = 20'hFC834;
    assign kernel0 [2][2] = 20'hFAC19;
// 共用乘法器
    reg signed [19:0] mul_in1, mul_in2;
    wire signed [39:0] mul_out; // 20 bits + 20 bits
    assign mul_out = mul_in1 * mul_in2;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mul_in1 <= 0;
            mul_in2 <= 0;
            state_Convolutional <= 0;
            Convolutional_out <= 0;
            endConvolutional <= 0;
        end else begin
            case (state_Convolutional) 
                4'd0: begin    // 狀態 0 idle
                    endConvolutional <= 0;
                    if (state_main == WAIT_CONV)
                        state_Convolutional <= 4'd1;
                end
                4'd1: begin    // 從 main 接收到訊號 (state更換) 開始捲積
                    //Convolutional_out <= 43'h01310; 錯誤，這樣會從最後面變成小數，必須指定 20 bits
                    Convolutional_out <= {8'd0, 20'h01310, 16'd0}; // 捲積輸出必須重製，這邊重製為 bias 的值 01310H，不然會用到上一個的結果
                    mul_in1 <= pixels[0][0];
                    mul_in2 <= kernel0[0][0];
                    state_Convolutional <= 4'd2;
                end
                4'd2: begin
                    Convolutional_out <= Convolutional_out + mul_out;
                    mul_in1 <= pixels[0][1];
                    mul_in2 <= kernel0[0][1];
                    state_Convolutional <= 4'd3;
                end
                4'd3: begin
                    Convolutional_out <= Convolutional_out + mul_out;
                    mul_in1 <= pixels[0][2];
                    mul_in2 <= kernel0[0][2];
                    state_Convolutional <= 4'd4;
                end
                4'd4: begin
                    Convolutional_out <= Convolutional_out + mul_out;
                    mul_in1 <= pixels[1][0];
                    mul_in2 <= kernel0[1][0];
                    state_Convolutional <= 4'd5;
                end
                4'd5: begin
                    Convolutional_out <= Convolutional_out + mul_out;
                    mul_in1 <= pixels[1][1];
                    mul_in2 <= kernel0[1][1];
                    state_Convolutional <= 4'd6;
                end
                4'd6: begin
                    Convolutional_out <= Convolutional_out + mul_out;
                    mul_in1 <= pixels[1][2];
                    mul_in2 <= kernel0[1][2];
                    state_Convolutional <= 4'd7;
                end
                4'd7: begin
                    Convolutional_out <= Convolutional_out + mul_out;
                    mul_in1 <= pixels[2][0];
                    mul_in2 <= kernel0[2][0];
                    state_Convolutional <= 4'd8;
                end
                4'd8: begin
                    Convolutional_out <= Convolutional_out + mul_out;
                    mul_in1 <= pixels[2][1];
                    mul_in2 <= kernel0[2][1];
                    state_Convolutional <= 4'd9;
                end
                4'd9: begin
                    Convolutional_out <= Convolutional_out + mul_out;
                    mul_in1 <= pixels[2][2];
                    mul_in2 <= kernel0[2][2];
                    state_Convolutional <= 4'd10;
                end
                4'd10: begin
                    Convolutional_out <= Convolutional_out + mul_out; // 在這邊已經做到捲積完 + bias 的結果
                    state_Convolutional <= 4'd11; // 等待一個 clk
                    endConvolutional <= 1'd1; // 旗標拉高讓 state_main 去 GET_WIDTH
                end
                4'd11: begin
                    // 因為如果在 4'd10 就去 0 的地方時，state_main 那邊的狀態還會繼續在 WAIT_CONV，所以要多留一個 clk 給 WAIT_CONV 改變
                    state_Convolutional <= 4'd0; // 回到 idle 狀態
                end
                default: ;
            endcase
        end
    end
//---------------------------------------------------------------
endmodule




