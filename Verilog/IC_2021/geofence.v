// 六顆接收器
// 想法：等資料存起來之後一併計算
// 乘法器看能不改成不使用乘法器，變成用移位的

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
// FSM 參數
localparam S0_DATA_INPUT_TEXTOBJECT = 2'd0, // 資料輸入(代測物)  ///////////////////////////與結果輸出 
           S1_DATA_INPUT_RECIVER = 2'd1,    // 資料輸入(接收器)
           S2_SETUP_FENCE = 2'd2,           // 建立圍籬 
           S3_ASSESS_OBJECT = 2'd3;         // 判斷待測物體是否在圍籬內 
reg [1:0] state;
reg [2:0] cnt_input; // 計數是否經過六個 cycle，以及 array index
//---------------------------------------------------------------------------------------------------------
// FSM
always @(posedge clk or posedge reset) begin
    if(reset) begin
        valid <= 0;
        state <= S0_DATA_INPUT_TEXTOBJECT;
        cnt_input <= 0;
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
            default: ;
        endcase
        

        
    end
end

endmodule

