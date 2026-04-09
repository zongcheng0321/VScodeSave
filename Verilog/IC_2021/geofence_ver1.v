// 六顆接收器
// 想法：等資料存起來之後一併計算
// 乘法器看能不改成不使用乘法器，變成用移位加法乘法器 -> （只有 1 個加法器和幾個暫存器），但計算時間會暴增 10 幾倍
// 本題目主要以面積做評分，請盡可能減少暫存器數量，以及共用運算單元，來達到最小面積的目標。
module geofence ( clk,reset,X,Y,valid,is_inside);
input clk;
input reset;
input [9:0] X; // 接收器/代測物 x 座標
input [9:0] Y; // 接收器/代測物 y 座標
output valid;
output is_inside;
reg valid;
reg is_inside;

// 待測物體的座標
reg [9:0] test_object_x, test_object_y;
// 接收器座標
reg [9:0] reciver_x [5:0];
reg [9:0] reciver_y [5:0];
// 向量變數
wire signed [10:0] vec_x [4:0]; // 如果沒有宣告成 signed 外積的時候會錯 *** 因為 -512 ~ 511 -> 不夠，所以要加 1 bit
wire signed [10:0] vec_y [4:0];
// FSM 參數
localparam S0_DATA_INPUT_TEXTOBJECT = 3'd0, // 資料輸入(代測物)
           S1_DATA_INPUT_RECIVER = 3'd1,    // 資料輸入(接收器)
           S2_SETUP_FENCE = 3'd2,           // 建立圍籬 
           S3_ASSESS_OBJECT = 3'd3,         // 判斷待測物體是否在圍籬內 S3 產生向量
           S4_ASSESS_OBJECT = 3'd4,         // S4 判斷
           S5_SET_VALID_LOW = 3'd5;
reg [2:0] state;
reg [2:0] cnt_input; // 計數是否經過六個 cycle，以及 array index
reg [2:0] i;         // integer 變數，用於 S2:判斷 bubble 是否交換； S3:計數器
reg [2:0] bubbleFinish; // 判斷 bubble 是否結束

// S3 要產生的向量
reg signed [10:0] ob_vec_x; // 從代測物指向其中一個接收器的向量 ** 要宣告成 signed
reg signed [10:0] ob_vec_y;
reg signed [10:0] rc_vec_x; // 從接收器指向下一個接收器的向量
reg signed [10:0] rc_vec_y;
//---------------------------------------------------------------------------------------------------------
// 產生 SETUP_FENCE 要判斷的向量
// 因為後面會做點跟點的交換，所以向量會發生改變，宣告成組合邏輯讓他一直改變，不需要再多寫程式在 FSM
assign vec_x[0] = reciver_x[1] - reciver_x[0]; assign vec_y[0] = reciver_y[1] - reciver_y[0];
assign vec_x[1] = reciver_x[2] - reciver_x[0]; assign vec_y[1] = reciver_y[2] - reciver_y[0];
assign vec_x[2] = reciver_x[3] - reciver_x[0]; assign vec_y[2] = reciver_y[3] - reciver_y[0];
assign vec_x[3] = reciver_x[4] - reciver_x[0]; assign vec_y[3] = reciver_y[4] - reciver_y[0];
assign vec_x[4] = reciver_x[5] - reciver_x[0]; assign vec_y[4] = reciver_y[5] - reciver_y[0];
//---------------------------------------------------------------------------------------------------------
// FSM
always @(posedge clk or posedge reset) begin
    if(reset) begin
        valid <= 0;
        state <= S0_DATA_INPUT_TEXTOBJECT;
        cnt_input <= 0;
        i <= 0;
        bubbleFinish <= 0;
    end else begin
        case (state)
            // 第一個 cycle 會輸入代測物體座標
            S0_DATA_INPUT_TEXTOBJECT: begin 
                test_object_x <= X;
                test_object_y <= Y;
                state <= S1_DATA_INPUT_RECIVER;
            end
            // 接下來6個 cycle 依續輸入 6 顆接收器座標
            S1_DATA_INPUT_RECIVER: begin
                if (cnt_input <= 5) begin
                    reciver_x[cnt_input] <= X;
                    reciver_y[cnt_input] <= Y;
                    cnt_input <= cnt_input + 3'd1;
                    state <= S1_DATA_INPUT_RECIVER;
                end else begin
                    cnt_input <= 0;
                    state <= S2_SETUP_FENCE;
                end
            end
            S2_SETUP_FENCE: begin
                // use bubble sort and exchange point.
                // A到B外積 = Ax*By – Bx*Ay，如果逆時針( >= 0 )就交換成順時針
                // i + 1 對多為 4 對應 vec[4]
                if ((vec_x[i] * vec_y[i + 1] - vec_x[i + 1] * vec_y[i]) >= 0) begin 
                    reciver_x[i + 1] <= reciver_x[i + 2]; // 3 + 1 跟 3 + 2 的位置點做互換
                    reciver_x[i + 2] <= reciver_x[i + 1];   
                    reciver_y[i + 1] <= reciver_y[i + 2];
                    reciver_y[i + 2] <= reciver_y[i + 1];
                end
                if (bubbleFinish < 4) begin
                    if (i < 3)  begin // i + 1 最多為 4、i + 2 最多為 5，此狀態共做"四次"
                        i <= i + 3'd1;
                        state <= S2_SETUP_FENCE;
                    end else begin
                        i <= 0;
                        bubbleFinish <= bubbleFinish + 3'd1;
                        state <= S2_SETUP_FENCE;
                    end
                end else begin
                    i <= 0;
                    bubbleFinish <= 0;
                    state <= S3_ASSESS_OBJECT;
                end
            end
            S3_ASSESS_OBJECT: begin
                // generate vector
                if (i < 6) begin // 最多判斷六次
                    ob_vec_x <= reciver_x[i] - test_object_x;
                    ob_vec_y <= reciver_y[i] - test_object_y;

                    if (i + 1 == 6) begin
                        rc_vec_x <= reciver_x[0] - reciver_x[5];
                        rc_vec_y <= reciver_y[0] - reciver_y[5];
                    end else begin
                        rc_vec_x <= reciver_x[i + 1] - reciver_x[i];
                        rc_vec_y <= reciver_y[i + 1] - reciver_y[i];
                    end

                    i <= i + 3'd1;
                    state <= S4_ASSESS_OBJECT;
                end else begin // 當全部判斷完畢，全部順時針 -> inside
                    is_inside <= 1;
                    valid <= 1;
                    state <= S5_SET_VALID_LOW;
                end
            end
            S4_ASSESS_OBJECT: begin // 再多做一次乘法器，等於此電路有 4 個乘法器存在 -> 面積大
                // cross product
                if ((ob_vec_x * rc_vec_y - rc_vec_x * ob_vec_y) < 0) begin // 當順時針(小於 0)->在圍籬內 
                    state <= S3_ASSESS_OBJECT;
                end else begin // 當逆時針->在圍籬外
                    is_inside <= 0;
                    valid <= 1;
                    state <= S5_SET_VALID_LOW;
                end
            end
            S5_SET_VALID_LOW: begin
                valid <= 0;
                is_inside <= 0;
                state <= S0_DATA_INPUT_TEXTOBJECT;
            end
            default: ;
        endcase
    end
end
endmodule