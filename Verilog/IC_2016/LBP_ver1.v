// 每個點花 260ns * 16384 = 4259840 -> 面積 5300 -> score = 22G 未達標
// 想法：改成一次做 3 個點 4286580/3 = 1,428,8601,428,860 * 8000(猜測值) = 11,430,880,000 < 12,000,000,000

`timescale 1ns/10ps
module LBP ( clk, reset, gray_addr, gray_req, gray_ready, gray_data, lbp_addr, lbp_valid, lbp_data, finish);
input   	clk;
input   	reset; // 高準位非同步
output reg [13:0] 	gray_addr; // 每一個週期僅能索取一個位址的資料。 題目不限制位址及資料的索取次數。 
output reg       	gray_req; // 。當為High時，表示LBP端要向Host 端索取灰階圖像資料。
input   	gray_ready; // 當為High時，表示Host端已經將灰階圖像記憶體及相關訊號準備完成了；
                        //LBP端需在偵測到此訊號為High後才可以開始對Host端進行資料索取動作。 
input   [7:0] 	gray_data;
output reg [13:0] 	lbp_addr;
output reg 	lbp_valid;
output reg [7:0] 	lbp_data;
output reg	finish;

//------------------------------------------------
// FSM
reg [2:0] state;
localparam INPUT = 3'd1,
           OUTPUT = 3'd2,
           GET_gc = 3'd3,
           UPDATE = 3'd4, // 更新座標
           SAVE_LBP = 3'd5;

reg delay1CLK;
//------------------------------------------------
reg [6:0] x, y; // gc -> 1 ~ 2^7 -1 灰階圖像中間縮一圈的範圍，gc 從中間做因為最後輸出最外圈會是 0
reg [1:0] pixel_row, pixel_col; // 九宮格的x ,y

wire [6:0] plus_x_pixel_col; // 0 ~ 127
wire [13:0] plus_y_pixel_row; // 最多為 127 * (2 ^ 7) = 16256
wire [13:0] input_addr; // (x - 1) + pixel_col + (pixel_row << 7) + [(y - 1) << 7] 
// 原本 x, y 要從 1 跑到 2^7 -1，但我這邊的 input_addr 改成 x, y 不減 1 了，所以 x, y 那邊要在減 1 一次變成 (1 - 1) ~ (2^7 -1 -1)
// so x, y 範圍變成-> 0 ~ 2^7 -2, input_addr 變成 x + pixel_col + (pixel_row << 7) + y << 7，少了兩個減法器以及後續判斷的比較器。
assign plus_x_pixel_col = x + {5'd0, pixel_col};
assign plus_y_pixel_row = ({5'd0, pixel_row} << 7) + (y << 7);
assign input_addr = {7'd0, plus_x_pixel_col} + plus_y_pixel_row; // 當現在為 gc 位置時，也同時為輸出記憶體位置

//------------------------------------------------
// 共用項
wire is_pixel_row_eq_1, is_pixel_col_eq_2;
assign is_pixel_row_eq_1 = (pixel_row == 1'd1);
assign is_pixel_col_eq_2 = (pixel_col == 2'd2);

wire x_end;
assign x_end = (x == 7'd125);
//------------------------------------------------
// Threshold值
// 一開始要去要 gc 的值，九宮格的中間是 gc 值
wire is_gc_input;
assign is_gc_input = (pixel_col == 1'd1 && is_pixel_row_eq_1);

reg [7:0] gc;

// gray_data = gp
wire s;
wire [8:0] z; // -255 ~ 255
assign z = gray_data - gc;
assign s = (z[8] == 0)? 1'd1: 0;

reg [2:0] power; // 根據 update 幾次座標來判斷現在的次方是多少 (0 ~ 7)
wire [7:0] multiplyWeight; // 最大值為 2 ^ 7 = 128 -> 8bits 才有 128
assign multiplyWeight = (s == 1'd1 && power == 0)? 1'd1 : {7'd0, s} << power;// 因為有 0 次方的計算，所以要多一個判斷
//====================================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        gray_addr <= 0;
        gray_req <= 0;
        lbp_addr <= 0;
        lbp_valid <= 0;
        lbp_data <= 0;
        finish <= 0;
        
        // 重製
        state <= INPUT;
        x <= 0;
        y <= 0;
        // 一開始要去要 gc 的值
        pixel_col <= 1'd1;
        pixel_row <= 1'd1;
        gc <= 0;
        power <= 0;
        delay1CLK <= 0;
    end else begin
        case (state)
            INPUT: begin
                lbp_valid <= 0;
                if (gray_ready) begin
                    gray_addr <= input_addr; // 當現在為 gc 位置時，也同時為輸出記憶體位置
                    gray_req <= 1'd1;
                end
                if (is_gc_input) begin
                    lbp_addr <= input_addr;
                    state <= GET_gc;
                end else begin
                    state <= SAVE_LBP;
                end
                
            end 

            GET_gc: begin
                gc <= gray_data;
                lbp_data <= 0;
                state <= UPDATE;
            end

            UPDATE: begin
                if (is_gc_input) begin
                    pixel_col <= 0;
                    pixel_row <= 0;
                    power <= 0;
                end else begin
                    power <= power + 1'd1;

                    // 更新 pixel_row and col 座標
                    if (is_pixel_row_eq_1 && (pixel_col == 0)) begin // (1,0) 時要變成 (1,2)
                        pixel_col <= pixel_col + 2'd2;
                    end else begin // normal situation
                        pixel_col <= pixel_col + 1'd1;
                        if (is_pixel_col_eq_2) begin
                            pixel_col <= 0;
                            pixel_row <= pixel_row + 1'd1;
                        end
                    end
                end
                state <= INPUT;
            end
            
            SAVE_LBP: begin
                lbp_data <= lbp_data + multiplyWeight;
                if (is_pixel_col_eq_2 && pixel_row == 2'd2) begin
                    state <= OUTPUT;
                    pixel_col <= 1'd1; // 重製為 (1,1) 對應 gc 位置
                    pixel_row <= 1'd1;
                    power <= 0;
                end else begin
                    state <= UPDATE;
                end
            end

            OUTPUT: begin
                lbp_valid <= 1'd1;
                if (x_end && y == 7'd125) begin
                    if (delay1CLK == 0) begin
                        delay1CLK <= 1'd1;
                    end else begin
                        finish <= 1'd1;
                    end
                end else begin
                    // 更新 x, y 座標
                    x <= x + 1'd1;
                    if (x_end) begin
                        y <= y + 1'd1;
                        x <= 0;
                    end
                    state <= INPUT;
                end
            end
            default: ;
        endcase
    end
end
//====================================================================
endmodule
