// 六顆接收器
// 想法兩個FSM，同時接收並計算向量
// 另外一種想法：等資料存起來之後一併計算
// 乘法器看能不改成不使用乘法器，變成用移位的

//這寫到一半我不想寫了

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

// 向量及順時針或逆時針暫存器
reg [9:0] Ax,Bx,Ay,By;
reg clock_reg; // 儲存 A、B 向量是否是順時鐘或逆時鐘
// 向量共五個
//reg A,B,C,D,E;

// FSM 參數
reg [1:0] state_input, state_function;      // 兩個 FSM 分別同時做資料輸入及程式功能
           // FSM1
localparam DATA_INPUT_TEXTOBJECT = 2'd0, // 資料輸入(代測物)  ///////////////////////////與結果輸出 
           DATA_INPUT_RECIVER = 2'd1,    // 資料輸入(接收器)
           // FSM2
           IDLE = 2'd0,
           SETUP_FENCE_COUNT_VECTOR = 2'd1,// 建立圍籬先計算向量
           SETUP_FENCE_CROSS_PRODUCT = 2'd2, // 計算外積並排序
           ASSESS_OBJECT = 2'd3;         // 判斷待測物體是否在圍籬內 

reg [2:0] cnt_input; // 計數是否經過六個 cycle，以及 array index
reg [2:0] index; // array index
//---------------------------------------------------------------------------------------------------------
// FSM(輸入資料) 需要整個修改
always @(posedge clk or posedge reset) begin
    if(reset) begin
        valid <= 0;
        state_input <= DATA_INPUT_TEXTOBJECT;
        cnt_input <= 0;
    end else begin
        case (state_input)
            // 第一個 cycle 會輸入代測物體座標
            DATA_INPUT_TEXTOBJECT: begin 
                test_object_x <= X;
                test_object_y <= Y;
                state_input <= DATA_INPUT_RECIVER;
            end
            // 接下來6個 cycle 依續輸入 6 顆接收器座標
            DATA_INPUT_RECIVER: begin
                if (cnt_input <= 5) begin
                    reciver_x[cnt_input] <= X;
                    reciver_y[cnt_input] <= Y;
                    cnt_input <= cnt_input + 3'd1;

                    state_function <= SETUP_FENCE_COUNT_VECTOR;
                    state_input <= DATA_INPUT_RECIVER;
                end else begin
                    cnt_input <= 0;
                    //state_input <= S0_SETUP_FENCE;
                end
            end
            //S0_SETUP_FENCE : begin
                //未完成
            //end 
            default: ;
        endcase
    end
end
//---------------------------------------------------------------------------------------------------------
// FSM(實作功能) 
always @(posedge clk or posedge reset) begin
    if(reset) begin
        state_function <= IDLE;
        index <= 0;
    end else begin
        case (state_function)
            SETUP_FENCE_COUNT_VECTOR : begin 
                if (cnt_input >= 2) begin // 當 cnt_input >= 2 的時候，才有"兩個"接收器出現 -> 才可計算向量
                    Ax <= reciver_x[index];
                    Ay <= reciver_x[index];
                end else begin
                    state_function <= IDLE;
                end
            end 
            default: ;
        endcase
    end
end

endmodule

