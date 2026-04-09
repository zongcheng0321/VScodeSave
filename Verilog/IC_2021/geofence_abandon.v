// 六顆接收器
// 想法兩個FSM，同時接收並計算向量
// 另外一種想法：等資料存起來之後一併計算
// 乘法器看能不改成不使用乘法器，變成用移位的

// 寫到一半部血了

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
//reg [9:0] reciver_x, reciver_y;

// 向量及順時針或逆時針暫存器
reg [9:0] Ax, Bx, Ay, By, Cx, Cy, Dx, Dy ,Ex ,Ey; // vector
reg [19:0] cross_pordctAB, cross_pordctAC, cross_pordctAD, cross_pordctAE,
            cross_pordctBC, cross_pordctBD, cross_pordctBE, cross_pordctCD,
            cross_pordctCE,cross_pordctDE;        // 所有外積


// FSM 參數
reg [3:0] state_input, state_function;      // 兩個 FSM 分別同時做資料輸入及程式功能
           // FSM1
localparam DATA_INPUT_TEXTOBJECT = 2'd0, // 資料輸入(代測物)  ///////////////////////////與結果輸出 
           DATA_INPUT_RECIVER = 2'd1,    // 資料輸入(接收器)
           // FSM2
           IDLE = 2'd0,
           CROSS_PRODUCT = 4'd1, // 計算外積
           ARRANGEMENT = 4'd2, // 排序
           ASSESS_OBJECT = 4'd4;         // 判斷待測物體是否在圍籬內 

reg [2:0] cnt_input; // 計數是否經過六個 cycle，以及 array index
reg [2:0] index; // array index
//---------------------------------------------------------------------------------------------------------
// FSM(輸入資料) 需要整個修改
always @(posedge clk or posedge reset) begin
    if(reset) begin
        valid <= 0; // 題目規定
        state_input <= DATA_INPUT_TEXTOBJECT;
        cnt_input <= 0;
        Ax <= 0; Ay <= 0; Bx <= 0; Ay <= 0;
    end else begin
        case (state_input)
            // 第一個 cycle 會輸入代測物體座標
            DATA_INPUT_TEXTOBJECT: begin 
                test_object_x <= X;
                test_object_y <= Y;
                state_input <= DATA_INPUT_RECIVER;
            end
            // 接下來 6 個 cycle 依續輸入 6 顆接收器座標，並且將產生 5 個向量
            DATA_INPUT_RECIVER: begin
                if (cnt_input <= 5) begin
                    case (cnt_input)
                        3'd0: begin
                            Ax <= X; Bx <= X; Cx <= X; Dx <= X; Ex <= X; 
                            Ay <= Y; By <= Y; Cy <= Y; Dy <= Y; Ey <= Y; 
                        end
                        3'd1: begin
                            Ax <= X - Ax;
                            Ay <= Y - Ay;
                        end
                        3'd2: begin
                            Bx <= X - Bx;
                            By <= Y - By;
                        end
                        3'd3: begin
                            Cx <= X - Cx;
                            Cy <= Y - Cy;
                        end
                        3'd4: begin
                            Dx <= X - Dx;
                            Dy <= Y - Dy;
                        end
                        3'd5: begin
                            Ex <= X - Ex;
                            Ey <= Y - Ey;
                        end
                        default: ;
                    endcase
                    cnt_input <= cnt_input + 3'd1;

                    state_function <= CROSS_PRODUCT;
                    state_input <= DATA_INPUT_RECIVER;
                end else begin
                    cnt_input <= 0;
                    //state_input <= S0_SETUP_FENCE;
                end
            end
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
            // 計算外積
            CROSS_PRODUCT : begin 
                case (cnt_input)
                    3'd2: begin 
                        cross_pordctAB <= Ax*By - Bx*Ay; // A 到 B 外積
                    end
                    3'd3: begin
                        cross_pordctAC <= Ax*Cy - Cx*Ay; // A 到 C 外積
                        cross_pordctBC <= Bx*Cy - Cx*By; // B 到 C 外積
                    end
                    3'd4: begin
                        cross_pordctAD <= Ax*Dy - Dx*Ay; // A 到 D 外積
                        cross_pordctBD <= Bx*Dy - Dx*By; // B 到 D 外積
                        cross_pordctCD <= Cx*Dy - Dx*Cy; // C 到 D 外積
                    end
                    3'd5: begin
                        cross_pordctAE <= Ax*Ey - Ex*Ay; // A 到 E 外積
                        cross_pordctBE <= Bx*Ey - Ex*By; // B 到 E 外積
                        cross_pordctCE <= Cx*Ey - Ex*Cy; // C 到 E 外積
                        cross_pordctDE <= Dx*Ey - Ex*Dy; // D 到 E 外積
                    end
                    default: ;
                endcase
                state_function <= ARRANGEMENT; 
            end
            // 找逆時鐘，做交換
            ARRANGEMENT : begin
                if (cross_pordctAB < 0) begin // A 到 B 順時鐘
                    // 當 AB順時鐘時 判斷 C
                    if (cross_pordctAC < 0) begin // A 到 C 順時鐘
                        if (cross_pordctBC < 0) begin // B 到 C 順時鐘
                            // 當 ABC 順時鐘時判斷 D
                            if (cross_pordctAD < 0) begin // A 到 D 順時鐘
                                if (cross_pordctBD < 0) begin // B 到 D 順時鐘
                                    if (cross_pordctCD < 0) begin // C 到 D 順時鐘
                                        // 當 ABCD 順時鐘時判斷 E
                                        if (cross_pordctAE < 0) begin // A 到 E 順時鐘
                                            if (cross_pordctBE < 0) begin // B 到 E 順時鐘
                                                if (cross_pordctCE < 0) begin // C 到 E 順時鐘
                                                    if (cross_pordctDE < 0) begin // D 到 E 順時鐘
                                                        // 排序完成
                                                        state_function <= ASSESS_OBJECT;
                                                    end else begin // C 到 E 逆時鐘
                                                        
                                                    end
                                                end else begin // C 到 E 逆時鐘
                                            
                                                end
                                            end else begin // B 到 E 逆時鐘
                                            
                                            end
                                        end else begin // A 到 E 逆時鐘
                                            
                                        end
                                    end else begin // C 到 D 逆時鐘
                                        
                                    end
                                end else begin // B 到 D 逆時鐘
                                    
                                end
                            end else begin // A 到 D 逆時鐘
                                // 
                            end
                        end else begin // B 到 C 逆時鐘
                            // BC 交換
                            Bx <= Cx; By <= Cy;
                            Cx <= Bx; Cy <= By;
                        end
                    end else begin // A 到 C 逆時鐘 (因為 AB 排好，所以要全換)
                        // A 變 B、B 變 C、C 變 A
                        Ax <= Bx; Ay <= By;
                        Bx <= Cx; By <= Cy;
                        Cx <= Ax; Cy <= Ay;
                    end
                end else begin // A 到 B 逆時鐘
                    // AB 交換
                    Ax <= Bx; Ay <= By;
                    Bx <= Ax; By <= Ay;
                end
            end
            default: ;
        endcase
    end
end


endmodule