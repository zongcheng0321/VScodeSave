/*
本題test pattern 前三點不會共線，必定會成為一三角形。 
本題test pattern 形成的凸多邊形，最多不會超過12邊。 
本題test pattern 每點產生的拋棄點，最多不會超過6個。 
*/

// 題目提示把點帶入直線方程式，但直線方程式要用到斜率 -> 點斜式 y - y0 = m (x = x0)
// 有斜率的話 -> m = dy/dx = tan -> 需要用到除法器 -> 需要小數點精度及負數 -> bits 數龐大面積很大
// 判斷點是否在直線兩側 -> 既然我們都要用外積去排序每個點了，這樣子如果兩點直線代表平行，外積平行 = 0，判斷點在同側或兩測也只要看是否在直線上兩點的左邊或右邊
// 也就是說外積兩點同時判斷是否在向量的左邊或右邊，(把 A 當作直線向量：外積為正 -> 逆時鐘 B 在 A 的左邊，為負 -> 順時鐘 B 在 A 的右邊)
// 共線無法用外積去解決
// 直線方程式並不能判斷點是否在某點的左邊或右邊或順時鐘或逆時鐘，所以直線方程式完全用不到


// 此版本 compile ultra P2未通過卡在 P2 的第 5 個點，需要連續拋棄 (308, 326) 與 (354, 298) 兩點。
// compile -map_effort high -area_effort high timing - 0.92

module CONVEX(
input CLK,
input RST, // 高位準非同步
input [4:0] PT_XY, // 新點之輸入埠 分4個cycle輸入新點的X及Y座標
output reg READ_PT, // CONVEX要求輸入新點 
output reg [9:0] DROP_X, // 拋棄點的X座標
output reg [9:0] DROP_Y, // 拋棄點的Y座標
output reg DROP_V); // 有效拋棄點。當 DROP_V 為 High，表示目前輸出的DROP_X及DROP_Y為有效的輸出。 

//FSM
reg [3:0] state;
localparam INPUT = 4'd0,
           DROP = 4'd1,
           DROP1 = 4'd2,
           DROP2 = 4'd3,
           DROP3 = 4'd4,
           DROP4 = 4'd5,
           DROP_UPDATE = 4'd6,
           SORT = 4'd7,
           SAME_LINE = 4'd8,
           SAME_LINE1 = 4'd9,
           SAME_LINE2 = 4'd10,
           LOW_DROP_V = 4'd11;

//----------------------------------------
// 每組測試pattern 有50輸入點
reg [9:0] new_x, new_y; // 0~1023
reg [3:0] cnt; // give 4 bits, 在所有圍成多邊形的點中，當前點是哪一點
reg [1:0] first_3p; // 現在輸入是否為 前三個點
reg [9:0] point_sorted_x [11:0]; // 排序過的點暫存器，有 12 個點
reg [9:0] point_sorted_y [11:0];
reg [3:0] point_cnt; // 現在有多少個點(有把 new 點算入)

wire [3:0] point_num_minus_1; // 不包含新點的所有點的數量 -1 的值
assign point_num_minus_1 = point_cnt - 2'd2;

wire [3:0] NEXT_POINT_POSITION, PREV_POINT_POSITION;
assign NEXT_POINT_POSITION = (cnt >= point_num_minus_1)? 4'd0 : cnt + 4'd1;
assign PREV_POINT_POSITION = (cnt == 0)? point_num_minus_1 /* point_cnt 有把 new 點加入計算並且位置還要再 -1 */ : cnt - 4'd1;

// 外積以及兩點距離
reg signed [10:0] mul1, mul2, mul3, mul4;
wire signed [20:0] mul_out1, mul_out2;
reg [9:0] ax2, bx2, ay2, by2; // 後點
reg [9:0] ox, oy;// 前點 (當原點)
wire signed [10:0] Ax, Bx, Ay, By; // vector
wire signed [21:0] cross_output;
reg [20:0] distance_temp1; // 需兩距離比較
wire [20:0] distance_temp;
assign distance_temp = mul_out1[19:0] + mul_out2[19:0];
assign Ax = $signed({1'd0, ax2}) - $signed({1'd0, ox}); // 向量後減前
assign Ay = $signed({1'd0, ay2}) - $signed({1'd0, oy});
assign Bx = $signed({1'd0, bx2}) - $signed({1'd0, ox});
assign By = $signed({1'd0, by2}) - $signed({1'd0, oy});

wire cmp_distance_greater, cmp_distance_equal, cmp_distance_smaller; // 共用比較器 -> 比較器面積大
assign cmp_distance_greater = distance_temp1 > distance_temp;
assign cmp_distance_equal = distance_temp1 == distance_temp;
assign cmp_distance_smaller = distance_temp1 < distance_temp;

// 0 -> 1 dis
wire signed [10:0] nextP_minus_currP_x; 
wire signed [10:0] nextP_minus_currP_y;
assign nextP_minus_currP_x = $signed({1'd0, point_sorted_x[NEXT_POINT_POSITION]}) - $signed({1'd0, point_sorted_x[cnt]});
assign nextP_minus_currP_y = $signed({1'd0, point_sorted_y[NEXT_POINT_POSITION]}) - $signed({1'd0, point_sorted_y[cnt]});
// 0 -> new dis
wire signed [10:0] new_minus_currP_x;
wire signed [10:0] new_minus_currP_y;
assign new_minus_currP_x = $signed({1'd0, new_x}) - $signed({1'd0, point_sorted_x[cnt]});
assign new_minus_currP_y = $signed({1'd0, new_y}) - $signed({1'd0, point_sorted_y[cnt]});
// 1 -> new dis
wire signed [10:0] new_minus_nextP_x;
wire signed [10:0] new_minus_nextP_y;
assign new_minus_nextP_x = $signed({1'd0, new_x}) - $signed({1'd0, point_sorted_x[NEXT_POINT_POSITION]});
assign new_minus_nextP_y = $signed({1'd0, new_y}) - $signed({1'd0, point_sorted_y[NEXT_POINT_POSITION]});

always @(*) begin
    case (state)
        SAME_LINE: begin // 產出 0 -> 1 distance (0 是當前點，1 是下一點)
            // x^2
            mul1 = nextP_minus_currP_x;
            mul2 = nextP_minus_currP_x;
            // y^2
            mul3 = nextP_minus_currP_y;
            mul4 = nextP_minus_currP_y;
        end
        SAME_LINE1: begin // 產出 0 -> new distance (0 是當前點，new 是新點)
            // x^2
            mul1 = new_minus_currP_x;
            mul2 = new_minus_currP_x;
            // y^2
            mul3 = new_minus_currP_y;
            mul4 = new_minus_currP_y;
        end
        SAME_LINE2: begin // 產出 1 -> new distance
            // x^2
            mul1 = new_minus_nextP_x;
            mul2 = new_minus_nextP_x;
            // y^2
            mul3 = new_minus_nextP_y;
            mul4 = new_minus_nextP_y;
        end
        default: begin
            mul1 = Ax;
            mul2 = By;
            mul3 = Bx;
            mul4 = Ay;
        end
    endcase
end

assign mul_out1 = mul1 * mul2;
assign mul_out2 = mul3 * mul4;
// Ax * By - Bx * Ay
assign cross_output = mul_out1 - mul_out2; // A x B -> 外積為負 B 在 A 右邊(順時針)，我們要排順時針


// 排序
reg first_3p_sort; // 前三點是否開始排序的旗標;
reg [3:0] resort_cnt;

reg [3:0] insert_new_point_position; // 紀錄新點插入位置 -> 第二個切點的前一個位置
reg tangent_point_equal_first_point; // 協助判斷新點插入位置，如果第一個點是切點，最後一個點為切點 -> 新點插入位置為最後
                                     // 如果倒數前一個點為第一個切點，且最後一個點為第二個切點 -> 新點插入位置為最後面的前一個位置
//reg tangent_point_equal_second_point;
reg is_write_insert_new_point_position; // 是否寫入過新點的座標要插在哪 -> 如果寫入過之後就不要再去更新

// DROP
reg [1:0] tangent_point_cnt; // 切點計數器

wire newpoint_overlap; // 新點與舊點是否重疊旗標
// 為什麼要判斷當前點或是下一點是否與新點重疊，是因為在做當前點與下一點的向量時，怕變成是被判斷為共線情形導致結果錯誤且進入共線 state 多浪費cycle
assign newpoint_overlap = (point_sorted_x[cnt] == new_x && point_sorted_y[cnt] == new_y) || 
                          (point_sorted_x[NEXT_POINT_POSITION] == new_x && point_sorted_y[NEXT_POINT_POSITION] == new_y);



reg CW_OR_CCW_adjacent; // 順時針或逆時針紀錄 (此為鄰點結果)
wire CW_OR_CCW_newpoint; // 順時針或逆時針紀錄 (此為新點結果)
reg is_same_side_1; // 需要紀錄 Ax 為 鄰點_NEXT 的向量做的結果 跟 Ax 為 鄰點_PREV 的向量做的結果 -> 用以判斷切點
wire is_same_side; // 兩點是否為同邊或不同邊 -> 1 為同邊 0 為不同邊
wire is_tangent_point; // 是否為切點
wire is_concave_point; // 是否為內凹點
//wire is_nothing_point; // 不是切點也不是內凹點 -> 去往下個點判斷
assign CW_OR_CCW_newpoint = cross_output[21];
assign is_same_side = !(CW_OR_CCW_adjacent ^ CW_OR_CCW_newpoint);
// 切點判斷方式為: 總共以兩個向量當基準去判斷，其中一個向量要讓新點和另一鄰點同邊，另一個向量要讓新點和另一鄰點不同邊 -> 這樣就為切點
assign is_tangent_point = is_same_side_1 ^ is_same_side;
// 內凹點為不管是以哪向量為基準新點與鄰點分隔兩側
assign is_concave_point = !is_same_side_1 & !is_same_side;
// 不管是以哪向量為基準都讓新點與鄰點同側
//assign is_nothing_point = is_same_side_1 & is_same_side;

reg have_tangentORconcave_point; // 在此新點加入時的所有點是否有被判別過切點或內凹點，如果已經做到最後一個點都沒有的話代表該新點在多邊形內
reg DROP_point_yield; // DROP 點是否產出
reg DROP_last_point; // 使否拋棄的是最後一個點

reg is_same_line; // 是否共線
reg is_output_next_point; // 是否輸出下一點
reg p_01_smaller_p_0new; // 當前點到下一點的距離是否小於當前點到新點的旗標
reg p_01_greater_p_0new; // 當前點到下一點的距離是否大於當前點到新點的旗標



always @(posedge CLK or posedge RST) begin
    if (RST) begin
        READ_PT <= 1'd1;
        DROP_V <= 0;

        first_3p <= 0;
        cnt <= 0;
        point_cnt <= 0;
        tangent_point_cnt <= 0;
        have_tangentORconcave_point <= 0;
        is_write_insert_new_point_position <= 0;
        DROP_point_yield <= 0;
        resort_cnt <= 0;
        is_output_next_point <= 0;
        is_same_line <= 0;
        state <= INPUT;
    end else begin
        case (state)
            INPUT: begin
                DROP_V <= 0;
                DROP_last_point <= 0;
                cnt <= cnt + 1'd1;
                if (first_3p_sort) begin
                    first_3p_sort <= 0;
                    point_sorted_x[0] <= ox;
                    point_sorted_y[0] <= oy;
                    if (cross_output[21] == 1'd1) begin
                        point_sorted_x[1] <= ax2;
                        point_sorted_y[1] <= ay2;
                        point_sorted_x[2] <= bx2;
                        point_sorted_y[2] <= by2;
                    end else begin
                        point_sorted_x[1] <= bx2;
                        point_sorted_y[1] <= by2;
                        point_sorted_x[2] <= ax2;
                        point_sorted_y[2] <= ay2;
                    end
                end

                case (cnt)
                    //0: READ_PT <= 1'd1; /* 等待資料送進來 在此時 HOST 收到 READ_PT 指令，下個 CLK 會送資料進來*/
                    1: begin
                        new_x[9:5] <= PT_XY;
                        READ_PT <= 1'd0;
                    end
                    2: new_x[4:0] <= PT_XY;
                    3: new_y[9:5] <= PT_XY;
                    4: begin
                        new_y[4:0] <= PT_XY;
                        cnt <= 0;
                        point_cnt <= point_cnt + 1'd1;


                        // 改成輸入前三點後排序在 INPUT 先做完
                        // state 控制
                        // 要完前三點後先去排序這三個點，之後 first_3p + 1 就會跑正常流程
                        if (first_3p == 2'd3) begin // 正常流程，同時 first_3p 維持 3
                            state <= DROP; //temp
                        end else begin
                            READ_PT <= 1'd1;
                        end

                        if (first_3p != 2'd3) begin
                            first_3p <= first_3p + 1'd1;
                        end

                        case (first_3p)
                            0: begin
                                ox <= new_x;
                                oy[9:5] <= new_y[9:5];
                                oy[4:0] <= PT_XY;
                            end 
                            1: begin
                                ax2 <= new_x;
                                ay2[9:5] <= new_y[9:5];
                                ay2[4:0] <= PT_XY;
                            end
                            2: begin
                                bx2 <= new_x;
                                by2[9:5] <= new_y[9:5];
                                by2[4:0] <= PT_XY;
                                first_3p_sort <= 1'd1;
                            end
                            default:;
                        endcase
                    end
                    default: ;
                endcase
            end

            DROP: begin 
                resort_cnt <= cnt;

                // 以 鄰點_NEXT 當基準 -> Ax 為 鄰點_NEXT 的向量
                // 先產生下一個點(鄰點_NEXT)的向量與前一個點(鄰點_PREV)的向量去做外積，下一個 clk 才能判斷外積結果
                ox <= point_sorted_x[cnt];
                oy <= point_sorted_y[cnt];
                ax2 <= point_sorted_x[NEXT_POINT_POSITION];
                ay2 <= point_sorted_y[NEXT_POINT_POSITION];
                bx2 <= point_sorted_x[PREV_POINT_POSITION]; // 如果現在是在判斷第一個點的話 -> 此點為最後一個點；如果不是那就是前一個點
                by2 <= point_sorted_y[PREV_POINT_POSITION];
                
                state <= DROP1;
                if (newpoint_overlap) begin // 新點拋棄直接去要新的點
                    point_cnt <= point_cnt -1'd1; // 點的總數減一
                    DROP_X <= new_x;
                    DROP_Y <= new_y;
                    DROP_V <= 1'd1;
                    READ_PT <= 1'd1;
                    cnt <= 0;
                    state <= INPUT;
                end
            end

            DROP1: begin
                CW_OR_CCW_adjacent <= cross_output[21];
                // 以 鄰點_NEXT 當基準 -> Ax 為 鄰點_NEXT 的向量
                // 再產生下一個點(鄰點_NEXT)的向量與新點的向量去做外積，下一個 clk 才能判斷外積結果
                bx2 <= new_x;
                by2 <= new_y;
                state <= DROP2;
            end

            DROP2: begin
                // 此時 CW_OR_CCW_newpoint = cross_output[21] 所以可以得出 is_same_side 值
                is_same_side_1 <= is_same_side;
                // 以 鄰點_PREV 當基準 -> Ax 為 鄰點_PREV 的向量
                // 先產生前一個點(鄰點_PREV)的向量與後一個點(鄰點_NEXT)的向量去做外積，下一個 clk 才能判斷外積結果
                ax2 <= point_sorted_x[PREV_POINT_POSITION]; // 如果現在是在判斷第一個點的話 -> 此點為最後一個點；如果不是那就是前一個點
                ay2 <= point_sorted_y[PREV_POINT_POSITION];
                bx2 <= point_sorted_x[NEXT_POINT_POSITION]; 
                by2 <= point_sorted_y[NEXT_POINT_POSITION];
                state <= DROP3;

                if (cross_output == 0) begin // 共線只會被 Ax 和 新點 做外積時發現
                    is_same_line <= 1'd1;
                    state <= SAME_LINE;
                end else begin
                    is_same_line <= 0;
                end
            end

            DROP3: begin
                CW_OR_CCW_adjacent <= cross_output[21];
                // 以 鄰點_PREV 當基準 -> Ax 為 鄰點_PREV 的向量
                // 再產生前一個點(鄰點_PREV)的向量與新點的向量去做外積，下一個 clk 才能判斷外積結果
                bx2 <= new_x;
                by2 <= new_y;
                state <= DROP4;
            end 

            DROP4: begin 
                if (is_tangent_point) begin
                    tangent_point_cnt <= tangent_point_cnt + 1'd1;
                    have_tangentORconcave_point <= 1'd1;
                    state <= DROP_UPDATE;
                end 

                if (is_concave_point || is_same_line) begin
                    if (is_concave_point) begin
                        have_tangentORconcave_point <= 1'd1;
                    end 
                    
                    resort_cnt <= resort_cnt + 1'd1;
                    point_sorted_x[resort_cnt] <= point_sorted_x[resort_cnt + 1'd1]; // 把下一個點的位置往前移一格
                    point_sorted_y[resort_cnt] <= point_sorted_y[resort_cnt + 1'd1];
                    if (!DROP_point_yield) begin // 因為後續會一直去變更 point_sorted，我們必須一開始先在 point_sorted 抓拋棄點，才不會去抓到被變更後的值
                        DROP_X <= point_sorted_x[cnt];
                        DROP_Y <= point_sorted_y[cnt];
                        DROP_point_yield <= 1'd1;
                    end
                    // 當最後一個點位置要移動到前一個點的位置時候跳轉狀態 或 如果現在是最後一個點，就直接跳轉狀態
                    if ((cnt == point_num_minus_1) || (resort_cnt == point_num_minus_1 -1'd1)) begin 
                        point_cnt <= point_cnt -1'd1; // 點的總數減一
                        //cnt <= (is_output_next_point)? PREV_POINT_POSITION : // 如果是共線跑到下一個點，又是 cnt = 0 的點，那就是要回去最後一個點
                        //       (cnt == 0)? 4'd0 : PREV_POINT_POSITION;       // 但如果不是共線，又是 cnt = 0 的點，那不能去最後一個點 -> 因為做外積順序會亂掉
                        cnt <= PREV_POINT_POSITION;
                        DROP_point_yield <= 0; // 重製旗標
                        DROP_V <= 1'd1; // 輸出 DROP
                        state <= LOW_DROP_V; // 去把 DROP_V 拉低後回來做下一個點
                        if (cnt == point_num_minus_1 /*&& !is_same_line*/) begin
                            DROP_last_point <= 1'd1;
                        end else begin
                            DROP_last_point <= 0;
                        end

                        // 在模擬上看最後一個值會變成 x 這樣比較好 debug -> 合成時需要刪除嗎?????????????????????????????
                        point_sorted_x[point_num_minus_1] <= 'bx;
                        point_sorted_y[point_num_minus_1] <= 'bx;
                    end
                end else begin
                    state <= DROP_UPDATE;
                end

                
            end

            DROP_UPDATE : begin
                //cnt <= cnt + 1'd1;
                cnt <= NEXT_POINT_POSITION;
                state <= DROP;
                // --- 新點的插入位置紀錄---
                if (tangent_point_cnt == 2'd1) begin
                    if (cnt == 0) begin
                        tangent_point_equal_first_point <= 1'd1;
                    end
                    // 紀錄第二個切點位置，新點加入的話就要插在這個切點的前面，且判斷是否有得出過 insert_new_point_position，防止重複變更
                end else if (tangent_point_cnt == 2'd2 && !is_write_insert_new_point_position) begin 
                    is_write_insert_new_point_position <= 1'd1;
                    insert_new_point_position <= cnt;
                    if ((cnt == point_num_minus_1 && cnt == 4'd1) || (cnt == point_num_minus_1 && tangent_point_equal_first_point)) begin
                        insert_new_point_position <= cnt + 4'd1;
                    end
                end

                // 已經得出過 insert_new_point_position，但最後一個點被拋棄了
                if ((is_write_insert_new_point_position && cnt == point_num_minus_1 && DROP_last_point)) begin 
                    // 新點要插在最後
                    insert_new_point_position <= cnt + 4'd1;
                end
                
                if (cnt == point_num_minus_1 && is_same_line && tangent_point_cnt == 2'd1) begin
                    // 新點要插在最後
                    insert_new_point_position <= cnt + 4'd1;
                end
                // ---------------------------
                
                if (cnt == point_num_minus_1) begin // point_cnt 為目前點的數量(包含新點)，假如為 4，cnt 要把 2 的點做完後於 2 跳轉狀態
                /*
                    cnt <= 0;
                    tangent_point_cnt <= 0;
                    tangent_point_equal_first_point <= 0;
                    have_tangentORconcave_point <= 0;
                    is_write_insert_new_point_position <= 0;*/
                    if (have_tangentORconcave_point) begin
                        //if (tangent_point_cnt == 2'd2) begin // 有兩個切點表示新點要加入此多邊形
                            // 累積了兩個切點就把新點加入 -> state 去 SORT 排序新點位置
                            state <= SORT;
                        //end else begin // 有內凹點的情況又沒有切點
                            // 沒有這種情況
                        //end
                    end else begin // 在多邊形內
                        // 新點拋棄直接去要新的點
                        point_cnt <= point_cnt -1'd1; // 點的總數減一
                        DROP_X <= new_x;
                        DROP_Y <= new_y;
                        DROP_V <= 1'd1;
                        READ_PT <= 1'd1;
                        cnt <= 0;
                        state <= INPUT;
                    end
                end
            end

            SORT: begin
                // 重製訊號
                cnt <= 0;
                tangent_point_cnt <= 0;
                tangent_point_equal_first_point <= 0;
                have_tangentORconcave_point <= 0;
                is_write_insert_new_point_position <= 0;

                // 點的總數已經更新
                // 新點插入的位置為 insert_new_point_position，原本的位置的點都要往後移一個位置
                state <= INPUT;
                READ_PT <= 1'd1;
                case (insert_new_point_position) // insert_new_point_position 一定為 1 ~ 12
                    1: begin
                        point_sorted_x[1] <= new_x;
                        point_sorted_y[1] <= new_y;
                        point_sorted_x[2] <= point_sorted_x[1];
                        point_sorted_y[2] <= point_sorted_y[1];
                        point_sorted_x[3] <= point_sorted_x[2];
                        point_sorted_y[3] <= point_sorted_y[2];
                        point_sorted_x[4] <= point_sorted_x[3];
                        point_sorted_y[4] <= point_sorted_y[3];
                        point_sorted_x[5] <= point_sorted_x[4];
                        point_sorted_y[5] <= point_sorted_y[4];
                        point_sorted_x[6] <= point_sorted_x[5];
                        point_sorted_y[6] <= point_sorted_y[5];
                        point_sorted_x[7] <= point_sorted_x[6];
                        point_sorted_y[7] <= point_sorted_y[6];
                        point_sorted_x[8] <= point_sorted_x[7];
                        point_sorted_y[8] <= point_sorted_y[7];
                        point_sorted_x[9] <= point_sorted_x[8];
                        point_sorted_y[9] <= point_sorted_y[8];
                        point_sorted_x[10] <= point_sorted_x[9];
                        point_sorted_y[10] <= point_sorted_y[9];
                        point_sorted_x[11] <= point_sorted_x[10];
                        point_sorted_y[11] <= point_sorted_y[10];
                    end
                    2: begin
                        point_sorted_x[2] <= new_x;
                        point_sorted_y[2] <= new_y;
                        point_sorted_x[3] <= point_sorted_x[2];
                        point_sorted_y[3] <= point_sorted_y[2];
                        point_sorted_x[4] <= point_sorted_x[3];
                        point_sorted_y[4] <= point_sorted_y[3];
                        point_sorted_x[5] <= point_sorted_x[4];
                        point_sorted_y[5] <= point_sorted_y[4];
                        point_sorted_x[6] <= point_sorted_x[5];
                        point_sorted_y[6] <= point_sorted_y[5];
                        point_sorted_x[7] <= point_sorted_x[6];
                        point_sorted_y[7] <= point_sorted_y[6];
                        point_sorted_x[8] <= point_sorted_x[7];
                        point_sorted_y[8] <= point_sorted_y[7];
                        point_sorted_x[9] <= point_sorted_x[8];
                        point_sorted_y[9] <= point_sorted_y[8];
                        point_sorted_x[10] <= point_sorted_x[9];
                        point_sorted_y[10] <= point_sorted_y[9];
                        point_sorted_x[11] <= point_sorted_x[10];
                        point_sorted_y[11] <= point_sorted_y[10];
                    end
                    3: begin
                        point_sorted_x[3] <= new_x;
                        point_sorted_y[3] <= new_y;
                        point_sorted_x[4] <= point_sorted_x[3];
                        point_sorted_y[4] <= point_sorted_y[3];
                        point_sorted_x[5] <= point_sorted_x[4];
                        point_sorted_y[5] <= point_sorted_y[4];
                        point_sorted_x[6] <= point_sorted_x[5];
                        point_sorted_y[6] <= point_sorted_y[5];
                        point_sorted_x[7] <= point_sorted_x[6];
                        point_sorted_y[7] <= point_sorted_y[6];
                        point_sorted_x[8] <= point_sorted_x[7];
                        point_sorted_y[8] <= point_sorted_y[7];
                        point_sorted_x[9] <= point_sorted_x[8];
                        point_sorted_y[9] <= point_sorted_y[8];
                        point_sorted_x[10] <= point_sorted_x[9];
                        point_sorted_y[10] <= point_sorted_y[9];
                        point_sorted_x[11] <= point_sorted_x[10];
                        point_sorted_y[11] <= point_sorted_y[10];
                    end
                    4: begin
                        point_sorted_x[4] <= new_x;
                        point_sorted_y[4] <= new_y;
                        point_sorted_x[5] <= point_sorted_x[4];
                        point_sorted_y[5] <= point_sorted_y[4];
                        point_sorted_x[6] <= point_sorted_x[5];
                        point_sorted_y[6] <= point_sorted_y[5];
                        point_sorted_x[7] <= point_sorted_x[6];
                        point_sorted_y[7] <= point_sorted_y[6];
                        point_sorted_x[8] <= point_sorted_x[7];
                        point_sorted_y[8] <= point_sorted_y[7];
                        point_sorted_x[9] <= point_sorted_x[8];
                        point_sorted_y[9] <= point_sorted_y[8];
                        point_sorted_x[10] <= point_sorted_x[9];
                        point_sorted_y[10] <= point_sorted_y[9];
                        point_sorted_x[11] <= point_sorted_x[10];
                        point_sorted_y[11] <= point_sorted_y[10];
                    end
                    5: begin
                        point_sorted_x[5] <= new_x;
                        point_sorted_y[5] <= new_y;
                        point_sorted_x[6] <= point_sorted_x[5];
                        point_sorted_y[6] <= point_sorted_y[5];
                        point_sorted_x[7] <= point_sorted_x[6];
                        point_sorted_y[7] <= point_sorted_y[6];
                        point_sorted_x[8] <= point_sorted_x[7];
                        point_sorted_y[8] <= point_sorted_y[7];
                        point_sorted_x[9] <= point_sorted_x[8];
                        point_sorted_y[9] <= point_sorted_y[8];
                        point_sorted_x[10] <= point_sorted_x[9];
                        point_sorted_y[10] <= point_sorted_y[9];
                        point_sorted_x[11] <= point_sorted_x[10];
                        point_sorted_y[11] <= point_sorted_y[10];
                    end
                    6: begin
                        point_sorted_x[6] <= new_x;
                        point_sorted_y[6] <= new_y;
                        point_sorted_x[7] <= point_sorted_x[6];
                        point_sorted_y[7] <= point_sorted_y[6];
                        point_sorted_x[8] <= point_sorted_x[7];
                        point_sorted_y[8] <= point_sorted_y[7];
                        point_sorted_x[9] <= point_sorted_x[8];
                        point_sorted_y[9] <= point_sorted_y[8];
                        point_sorted_x[10] <= point_sorted_x[9];
                        point_sorted_y[10] <= point_sorted_y[9];
                        point_sorted_x[11] <= point_sorted_x[10];
                        point_sorted_y[11] <= point_sorted_y[10];
                    end
                    7: begin
                        point_sorted_x[7] <= new_x;
                        point_sorted_y[7] <= new_y;
                        point_sorted_x[8] <= point_sorted_x[7];
                        point_sorted_y[8] <= point_sorted_y[7];
                        point_sorted_x[9] <= point_sorted_x[8];
                        point_sorted_y[9] <= point_sorted_y[8];
                        point_sorted_x[10] <= point_sorted_x[9];
                        point_sorted_y[10] <= point_sorted_y[9];
                        point_sorted_x[11] <= point_sorted_x[10];
                        point_sorted_y[11] <= point_sorted_y[10];
                    end
                    8: begin
                        point_sorted_x[8] <= new_x;
                        point_sorted_y[8] <= new_y;
                        point_sorted_x[9] <= point_sorted_x[8];
                        point_sorted_y[9] <= point_sorted_y[8];
                        point_sorted_x[10] <= point_sorted_x[9];
                        point_sorted_y[10] <= point_sorted_y[9];
                        point_sorted_x[11] <= point_sorted_x[10];
                        point_sorted_y[11] <= point_sorted_y[10];
                    end
                    9: begin
                        point_sorted_x[9] <= new_x;
                        point_sorted_y[9] <= new_y;
                        point_sorted_x[10] <= point_sorted_x[9];
                        point_sorted_y[10] <= point_sorted_y[9];
                        point_sorted_x[11] <= point_sorted_x[10];
                        point_sorted_y[11] <= point_sorted_y[10];
                    end
                    10: begin
                        point_sorted_x[10] <= new_x;
                        point_sorted_y[10] <= new_y;
                        point_sorted_x[11] <= point_sorted_x[10];
                        point_sorted_y[11] <= point_sorted_y[10];
                    end
                    11: begin
                        point_sorted_x[11] <= new_x;
                        point_sorted_y[11] <= new_y;
                    end
                    default: ;
                endcase
            end

            SAME_LINE: begin // 組合邏輯會產出 0 -> 1 distance (0 是當前點，1 是下一點)
                distance_temp1 <= distance_temp; // distance_temp1 為 當前點與下一點的距離 (0 -> 1)
                state <= SAME_LINE1;
            end

            SAME_LINE1: begin // 組合邏輯會產出 0 -> new distance (0 是當前點，new 是新點)
                // 假如 0->1距離 > 0->new距離 : 下一個比較要去比 0->1距離 是否大於或小於 1->new距離
                if (cmp_distance_greater) begin
                    // distance_temp1 = 0 -> 1 目前還是為當前點的距離(在 SAME_LINE 產出的) 
                    p_01_greater_p_0new <= 1'd1;
                    state <= SAME_LINE2; 

                // 假如 0->1距離 < 0->new距離 : 下一個比較要去比 0->new距離 是否大於或小於 1->new距離
                end else if (cmp_distance_smaller) begin
                    distance_temp1 <= distance_temp; // distance_temp1 改變為 當前點與新點的距離 (0 -> new)
                    p_01_smaller_p_0new <= 1'd1;
                    state <= SAME_LINE2; 

                // 假如 0->1距離/2 = 0->new距離 : 輸出新點
                end else if ((distance_temp1 >> 1) == distance_temp) begin
                    point_cnt <= point_cnt -1'd1; // 點的總數減一
                    DROP_X <= new_x;
                    DROP_Y <= new_y;
                    DROP_V <= 1'd1;
                    READ_PT <= 1'd1;
                    cnt <= 0;
                    state <= INPUT;

                // 假如 0->1距離*2 = 0->new距離 : 輸出下一點
                end else if ((distance_temp1 << 1) == distance_temp) begin
                    is_output_next_point <= 1'd1;
                    resort_cnt <= NEXT_POINT_POSITION;
                    cnt <= NEXT_POINT_POSITION; // 點換成下一個點，之後要記得減回來做
                    state <= DROP4;
                end

                // 假如 0->1距離 = 0->new距離 : 拋棄當前點
                if (cmp_distance_equal) begin
                    state <= DROP4; // 拋棄當前點
                end
                
            end

            SAME_LINE2: begin // 組合邏輯會產出 1 -> new distance 
                p_01_greater_p_0new <= 0;
                p_01_smaller_p_0new <= 0;
                if (p_01_greater_p_0new) begin 
                    if (cmp_distance_greater) begin // distance_temp1 > distance_temp ( 0->1 > 1->new )
                        // 輸出新點
                        point_cnt <= point_cnt -1'd1; // 點的總數減一
                        DROP_X <= new_x;
                        DROP_Y <= new_y;
                        DROP_V <= 1'd1;
                        READ_PT <= 1'd1;
                        cnt <= 0;
                        state <= INPUT;
                    end else begin
                        // 輸出當前點
                        state <= DROP4;
                    end
                end
                if (p_01_smaller_p_0new) begin
                    if (cmp_distance_greater) begin // distance_temp1 > distance_temp ( 0->new > 1->new )
                        // 輸出下一點
                        is_output_next_point <= 1'd1;
                        resort_cnt <= NEXT_POINT_POSITION;
                        cnt <= NEXT_POINT_POSITION; // 點換成下一個點，之後要記得減回來做
                        state <= DROP4;
                    end else begin
                        // 輸出當前點
                        state <= DROP4;
                    end
                end
            end

            LOW_DROP_V: begin
                DROP_V <= 0;
                if (is_output_next_point) begin // 拋棄下一點後就還要退回去上一個點重做一遍
                    is_output_next_point <= 0;
                    // 剛剛 DROP4 有把 cnt 減一了，所以 is_output_next_point 時把下一個點刪了之後 DROP4 後退回去了前一個點重做
                    state <= DROP;
                end else begin // 正常狀況:刪除點後就會去 DROP_UPDATE 更新成繼續做下一個點
                    state <= DROP_UPDATE;
                end
                
                if (point_cnt == 4'd3) begin // 當拋棄完之後點的總數只剩 3 代表這個新點一定要加入並且不會有任何拋棄點了，因為一定要成為一個三角形
                    insert_new_point_position <= 4'd2;
                    state <= SORT;
                end
            end

            default: ;
        endcase
    end
end

endmodule

