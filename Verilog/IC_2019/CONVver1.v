module  CONV(
    input   clk,
    input   reset,
    output reg busy,
    input   ready,
    
    output reg [11:0] iaddr,
    input signed [19:0] idata,

    output  cwr,
    output [11:0] caddr_wr,
    output signed [19:0] cdata_wr,

    output  crd,
    output [11:0] caddr_rd,
    input signed [19:0] cdata_rd,

    output [2:0] csel
);
//---------------------------------------------------------------
// input image reg
// 想法：宣告 3*3 暫存器為輸入資料



//---------------------------------------------------------------
// FSM parameter
    localparam SIGNAL_INPUT = 4'd0, // 將 busy 拉為 1 表示要開始做了
               ZERO_PADDING = 4'd1, // 判斷角落的四種狀態跟一般的邊界狀態決定是否要補 0
               HANDLING_PIXEL_ROW_AND_COL = 4'd2, // 處理 pixel 的 row and col 到下一個位置
               INPUT_DATA   = 4'd3; // 一次一個 clk 把資料輸入進來，當row不等於第一列or最後一列 or 當col不等於第一行or最後一列
               //CHANGE_PIXEL = 4'd4; // 把輸入進來的資料分給 pixels
               
    reg [3:0] state_main;
    reg [3:0] state_Convolutional;
// ---ZERO_PADDING要使用的變數---
    reg [5:0] col; // 從左數到右的計數器，表示做到矩陣的哪裡，最大值 6'd63
    reg [5:0] row; // 從上數到下的計數器，表示做到矩陣的哪裡，最大值 6'd63

    // 要跟 kernel 做乘法然後做完全部相加，且在 main 中當作完一次捲積(endConvolutional = 1)，pixels 值要做更換
    reg signed [19:0] pixels [2:0][2:0]; // 此為補過 0 的暫存器
// ---CHANGE_PIXEL、INPUT_DATA---
    reg [1:0] pixel_index_row; // 改變 PIXEL 時要用的引索(row)
    reg [1:0] pixel_index_col; // 改變 PIXEL 時要用的引索(col)
    wire [11:0] input_index; // 紀錄現在取到多少了
//---------------------------------------------------------------
// ---Convolutional共用乘法、加法器---  ********這樣不會共用乘法器，要拆成FSM
// 乘法器
/*
    function signed [39:0] mul;
        input signed [19:0] mul1 , mul2;
        begin
            mul = mul1 * mul2;
        end
    endfunction
// 捲積結果
    function signed [42:0] Convolutional; // 20bits * 20 bits = 40 bits, 9 個 40 bits 相加 -> 40 bits + 40 bits = 41 bits
                                          // 有四個 41 bits -> 41 bits + 41 bits = 42 bits, 兩個 42 bits -> 43 bits
        input signed [19:0] pixels0, pixels1, pixels2, pixels3, pixels4, pixels5, pixels6, pixels7, pixels8;
        begin
            Convolutional = mul(pixels0, $signed(20'h0A891)) + mul(pixels0, $signed(20'h0A891))...;
        end
    endfunction*/
//---------------------------------------------------------------
// Deal with layer0 zero_padding
// 想法:處理第 0 列 or 第 0 行 or 最後一列 or 最後一行 zero_padding
// 利用多工器，判斷如果現在是上述所說的行或列，對應的 pixels 要補 0。
    // 角落的四種狀態跟一般的邊界狀態
    wire boundaryT, boundaryB, boundaryL, boundaryR; // 上下左右邊界 Top Bottom Left Right
    assign boundaryT = (col == 0)? 1'd1: 1'd0;
    assign boundaryB = (col == 6'd63)? 1'd1: 1'd0;
    assign boundaryL = (row == 0)? 1'd1: 1'd0;
    assign boundaryR = (row == 6'd63)? 1'd1: 1'd0;
//---------------------------------------------------------------
// 處理 input_index 要改
// 要讓他 + pixel_index_row * 64 且 每個 clk + 1
    reg [5:0] input_index_col; // 會在 state = INPUT_DATA 時 + 1
    assign input_index = input_index_col + (pixel_index_row << 6);
//---------------------------------------------------------------


//---------------------------------------------------------------
//FSM main
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            busy <= 0;
            state_main <= SIGNAL_INPUT;
            col <= 0;
            row <= 0;
            pixel_index_row <= 0; // 從左上角開始填入資料
            pixel_index_col <= 0; // 從左上角開始填入資料
            input_index_col <= 0;
            iaddr <= 0; // 一開始就先要了第一筆資料放進 idata

            // cwr <= 0;
            // caddr_wr <= 0;
            // cdata_wr <= 0;
            // crd <= 0;
            // caddr_rd <= 0;
            // csel <= 0;
        end else begin
            case (state_main) 
                SIGNAL_INPUT: begin
                    // 第二輪開始的初始化
                    col <= 0;
                    row <= 0;
                    pixel_index_row <= 0; // 從左上角開始填入資料
                    pixel_index_col <= 0; // 從左上角開始填入資料
                    input_index_col <= 0;
                    iaddr <= 0; // 一開始就先要了第一筆資料放進 idata

                    if (ready) begin
                        busy <= 1'b1;
                        state_main <= ZERO_PADDING; // 一開始因為是左上角所以要先去 ZERO_PADDING，此時已經要了一筆資料了
                    end
                end

                ZERO_PADDING: begin
                    case ({boundaryT, boundaryB, boundaryL, boundaryR})
                        4'b0000: state_main <= INPUT_DATA; // 如果輸入的資料不在邊界上，那就正常去要輸入資料填入 pixels reg
                        4'b1010: begin // 假如在左上角時
                            //pixels[0][0] <= 0; pixels[0][1] <= 0; pixels[0][2] <= 0; pixels[1][0] <= 0; pixels[2][0] <= 0;
                            if(pixel_index_row == 0 || pixel_index_col == 0) begin
                                pixels[pixel_index_row][pixel_index_col] <= 0;
                                state_main <= HANDLING_PIXEL_ROW_AND_COL;
                            end else begin
                                pixels[pixel_index_row][pixel_index_col] <= idata;
                                state_main <= INPUT_DATA;
                            end
                        end
                        4'b1001: begin // 假如在右上角時
                            //pixels[0][0] <= 0; pixels[0][1] <= 0; pixels[0][2] <= 0; pixels[1][2] <= 0; pixels[2][2] <= 0;
                            if(pixel_index_row == 0 || pixel_index_col == 2'd2) begin
                                pixels[pixel_index_row][pixel_index_col] <= 0;
                                state_main <= HANDLING_PIXEL_ROW_AND_COL;
                            end else begin
                                pixels[pixel_index_row][pixel_index_col] <= idata;
                                state_main <= INPUT_DATA;
                            end
                        end
                        4'b0110: begin // 假如在左下角時
                            //pixels[2][0] <= 0; pixels[2][1] <= 0; pixels[2][2] <= 0; pixels[1][0] <= 0; pixels[0][0] <= 0;
                            if(pixel_index_row == 2'd2 || pixel_index_col == 0) begin
                                pixels[pixel_index_row][pixel_index_col] <= 0;
                                state_main <= HANDLING_PIXEL_ROW_AND_COL;
                            end else begin
                                pixels[pixel_index_row][pixel_index_col] <= idata;
                                state_main <= INPUT_DATA;
                            end
                        end
                        4'b0101: begin // 假如在右下角時
                            //pixels[2][0] <= 0; pixels[2][1] <= 0; pixels[2][2] <= 0; pixels[1][2] <= 0; pixels[0][2] <= 0;
                            if(pixel_index_row == 2'd2 || pixel_index_col == 2'd2) begin
                                pixels[pixel_index_row][pixel_index_col] <= 0;
                                state_main <= HANDLING_PIXEL_ROW_AND_COL;
                            end else begin
                                pixels[pixel_index_row][pixel_index_col] <= idata;
                                state_main <= INPUT_DATA;
                            end
                        end
                        4'b1000: begin // 假如在上邊界
                            //pixels[0][0] <= 0; pixels[0][1] <= 0; pixels[0][2] <= 0;
                            if(pixel_index_row == 0) begin
                                pixels[pixel_index_row][pixel_index_col] <= 0;
                                state_main <= HANDLING_PIXEL_ROW_AND_COL;
                            end else begin
                                pixels[pixel_index_row][pixel_index_col] <= idata;
                                state_main <= INPUT_DATA;
                            end
                        end
                        4'b0100: begin // 假如在下邊界
                            //pixels[2][0] <= 0; pixels[2][1] <= 0; pixels[2][2] <= 0;
                            if(pixel_index_row == 2'd2) begin
                                pixels[pixel_index_row][pixel_index_col] <= 0;
                                state_main <= HANDLING_PIXEL_ROW_AND_COL;
                            end else begin
                                pixels[pixel_index_row][pixel_index_col] <= idata;
                                state_main <= INPUT_DATA;
                            end
                        end
                        4'b0010: begin // 假如在左邊界
                            //pixels[0][0] <= 0; pixels[1][0] <= 0; pixels[2][0] <= 0;
                            if(pixel_index_col == 0) begin
                                pixels[pixel_index_row][pixel_index_col] <= 0;
                                state_main <= HANDLING_PIXEL_ROW_AND_COL;
                            end else begin
                                pixels[pixel_index_row][pixel_index_col] <= idata;
                                state_main <= INPUT_DATA;
                            end
                        end
                        4'b0001: begin // 假如在右邊界
                            //pixels[0][2] <= 0; pixels[1][2] <= 0; pixels[2][2] <= 0;
                            if(pixel_index_col == 2'd2) begin
                                pixels[pixel_index_row][pixel_index_col] <= 0;
                                state_main <= HANDLING_PIXEL_ROW_AND_COL;
                            end else begin
                                pixels[pixel_index_row][pixel_index_col] <= idata;
                                state_main <= INPUT_DATA;
                            end
                        end
                        default: state_main <= HANDLING_PIXEL_ROW_AND_COL; // 不會有此狀況
                    endcase
                    
                end
                
                // pixel_index_col、pixel_index_row 要跳到下一個位置
                HANDLING_PIXEL_ROW_AND_COL: begin
                    if (pixel_index_col == 2'd2) begin
                        pixel_index_col <= 0;
                        pixel_index_row <= pixel_index_row + 2'd1;
                        if (pixel_index_row == 2'd2) begin
                            pixel_index_row <= 0;
                        end
                    end else begin
                        pixel_index_col <= pixel_index_col + 2'd1;
                    end

                    // if ((pixel_index_row != 2'd2 ) || (pixel_index_col != 2'd2)) begin
                    //     if ((boundaryT || boundaryB) || (boundaryL || boundaryR)) begin
                    //         state_main <= ZERO_PADDING;
                    //     end else begin
                    //         state_main <= INPUT_DATA;
                    //     end
                    // end else begin
                    //     state_Convolutional <= 4'd1; // 進入捲積 FSM 開始捲積
                    // end
                end

                // 要一筆資料
                INPUT_DATA: begin // 會從第一筆資料開始要
                    iaddr <= input_index; // idata 會在負緣時進來且維持到下一個負緣
                    input_index_col <= input_index_col + 6'd1; // 加這個 1 是 pixel_index_col 的 1
                    //state_main <= CHANGE_PIXEL;
                end
                // 把要的那筆資料填入


                default: ;
            endcase
        end
    end
//---------------------------------------------------------------
// kernel 宣告
    wire signed [19:0] kernel0 [2:0][2:0]; // ( 4bits整數+16bits小數)
    assign kernel0 [0][0] = 20'h0A891;
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
// FSM for Convolutional
    // 20bits * 20 bits = 40 bits, 9 個 40 bits 相加 -> 40 bits + 40 bits = 41 bits
    // 有四個 41 bits -> 41 bits + 41 bits = 42 bits, 兩個 42 bits -> 43 bits
    reg signed [42:0] Convolutional_out; // 捲積輸出
    
    reg endConvolutional; // 結束捲積旗標
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mul_in1 <= 0;
            mul_in2 <= 0;
            state_Convolutional <= 0;
            endConvolutional <= 0;
            Convolutional_out <= 0;
        end else begin
            case (state_Convolutional) 
                4'd0: begin    // 狀態 0 idle
                    endConvolutional <= 0; // 捲積結束旗標設為 0
                end
                4'd1: begin    // 從 main 接收到訊號 (state更換) 開始捲積
                    Convolutional_out <= 43'h01310; // 捲積輸出必須重製，這邊重製為 bias 的值 01310H，不然會用到上一個的結果
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
                    state_Convolutional <= 4'd0; // 回到 idle 狀態
                    endConvolutional <= 1'b1; // 捲積結束旗標設為 1
                end
                default: ;
            endcase
        end
    end
endmodule




