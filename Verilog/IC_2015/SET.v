// 非常厲害的 只要把 INPUT 裡面判斷 en == 1 拔掉，瞬間所有timing violation 就不見了
// 記得刪除 en

// 半徑 1~15，所以無法使用查表方式，只能做出乘法器出來。
module SET ( clk , rst, en, central, radius, mode, busy, valid, candidate );
input clk, rst; // 非同步系統重置訊號。當此訊號為1時表示系統重置。 
input en; // 資料有效信號。當此訊號為1時表示輸入資料為有效。

input [23:0] central; //集合座標資料。其組成為{x1,y1,x2,y2,x3,y3}
/* 其中 
central[23:20] ：為集合A的X軸座標（x1） 
central[19:16] ：為集合A的Y軸座標（y1） 
central[15:12] ：為集合B的X軸座標（x2） 
central[11:8] ：為集合B的Y軸座標（y2） 
central[7:4] ：為集合C的X軸座標（x3） 
central[3:0] ：為集合C的Y軸座標（y3）  */

input [11:0] radius; //集合半徑資料。其組成為{r1,r2,r3}，其中 
/* radius[11:8]為集合A的半徑值r1 
radius[7:4] 為集合B的半徑值r2 
radius[3:0] 為集合C的半徑值r3  */
input [1:0] mode;
output reg busy;
output reg valid;
output reg [7:0] candidate;
//---------------------------------------------
reg [3:0] x1, y1, x2, y2, x3, y3; // 圓心
reg [3:0] r1, r2, r3; // r 最大值為 15
reg [1:0] whichMode;

// FSM
reg [1:0] state;
localparam INPUT = 2'd0,
           MODE = 2'd1,
           UPDATE = 2'd2,
           //MODE2 = 3'd3,
           //MODE3 = 3'd4,
           OUTPUT = 2'd3;

//---------------------------------------------
reg [3:0] x, y; // 移動的點
reg [1:0] isABC; /// 0: A ,1: B, 2:C ，預設為 0 ->A
wire isB, isC; // 現在要判斷哪個圓
assign isC = (isABC == 2'd2);
assign isB = (isABC == 2'd1);
//assign isA = (isABC == 2'd0);

wire [3:0] Cx, Cy; // 圓心的 x y
assign Cx = (isC)? x3 : 
            (isB)? x2 : x1;
assign Cy = (isC)? y3 : 
            (isB)? y2 : y1;

wire [3:0] r; // 根據不同 set 來指定不同的 r
assign r = (isC)? r3 : 
           (isB)? r2 : r1;

// 此寫法為 slack 跟面積會達到最佳效果的寫法
// Critical Path： 1 個減法器延遲 + MUX 延遲。（路徑最短，Slack 最好）
// 如果採二補數的話 Critical Path： 1 個減法器延遲 + MUX 延遲 + 1 個加法器延遲。（路徑較長，Slack 較差）
wire [3:0] abs_minus_x, abs_minus_y;
assign abs_minus_x = (Cx >= x)? Cx - x : x - Cx;
assign abs_minus_y = (Cy >= y)? Cy - y : y - Cy;

reg [8:0] dis_plus; // (disx)^2 + (disy)^2

reg [3:0] mul12;
wire [7:0] sq_out;
assign sq_out = mul12 * mul12;

wire cmp;
assign cmp = (dis_plus <= sq_out); // 此時這裡的 sq_out 為 r^2

reg Acover, Bcover, Ccover;

// 交集作法
// A 交集 B
wire intersection_AB, intersection_BC, intersection_AC, intersection_ABC;
assign intersection_AB = Acover & Bcover;
assign intersection_BC = Bcover & Ccover;
assign intersection_AC = Acover & Ccover;
assign intersection_ABC = Acover & Bcover & Ccover;

// 聯集作法
// A 聯集 B
wire union_AB;
assign union_AB = Acover | Bcover;

reg [5:0] total_union, total_intersection;
reg [5:0] ansMode11;

reg [5:0] cnt; // 每次計數 x, y 坐標前進

/* 上面部分共用的最佳化寫法
reg [3:0] Cx, Cy, r;
always @(*) begin
    case (isABC)
        2'd2: begin Cx = x3; Cy = y3; r = r3; end
        2'd1: begin Cx = x2; Cy = y2; r = r2; end
        default: begin Cx = x1; Cy = y1; r = r1; end
    endcase
end
 */
//---------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        busy <= 0;
        valid <= 0;
        candidate <= 0;
        state <= INPUT;
        ansMode11 <= 0;
        whichMode <= 0;
        x1 <= 0; x2 <= 0; x3 <= 0; 
        y1 <= 0; y2 <= 0; y3 <= 0; 
        r1 <= 0; r2 <= 0; r3 <= 0; 
        cnt <= 0;
        x <= 4'd1;
        y <= 4'd1;
        isABC <= 0;
        mul12 <= 0;
        dis_plus <= 0;
        Acover <= 0; Bcover <= 0; Ccover <= 0;
        total_union <= 0;
        total_intersection <= 0;
    end else begin
        case (state) 
            INPUT: begin
                if (en == 1'd1) begin
                    busy <= 1'd1;
                    // A set
                    x1 <= central[23:20];
                    y1 <= central[19:16];
                    r1 <= radius[11:8];
                    // Bset
                    x2 <= central[15:12];
                    y2 <= central[11:8];
                    r2 <= radius[7:4];
                    // Cset
                    x3 <= central[7:4];
                    y3 <= central[3:0];
                    r3 <= radius[3:0];

                    whichMode <= mode;
                    state <= MODE; // 第一個坐標[1,1]
                end
            end

            MODE: begin
                cnt <= cnt + 1'd1;
                case (whichMode)
                    0: begin
                        case (cnt)
                            0: mul12 <= abs_minus_x;
                            1, 3: dis_plus <= dis_plus + {1'd0, sq_out};
                            2: mul12 <= abs_minus_y;
                            4: mul12 <= r;
                            5: begin
                                if (cmp == 1'd1) begin
                                    candidate <= candidate + 1'd1;
                                end
                                cnt <= 0;
                                state <= UPDATE;
                            end
                            default: ;
                        endcase
                    end 

                    1: begin
                        case (cnt)
                            0: mul12 <= abs_minus_x; // 初始狀態會是預設 A set
                            1, 3: dis_plus <= dis_plus + {1'd0, sq_out};
                            2: mul12 <= abs_minus_y;
                            4: mul12 <= r;
                            5: begin
                                if (isB) begin
                                    dis_plus <= 0;
                                    Bcover <= cmp;
                                    isABC <= 0; // 指定為 A
                                end else begin
                                    dis_plus <= 0;
                                    Acover <= cmp;
                                    isABC <= 2'd1; // 指定為 B
                                    cnt <= 0;
                                end
                            end
                            6: begin
                                candidate <= candidate + {7'd0,intersection_AB};
                                state <= UPDATE;
                                cnt <= 0;
                            end
                            default: ;
                        endcase
                    end

                    2: begin
                        case (cnt)
                            0: mul12 <= abs_minus_x; // 初始狀態會是預設 A set
                            1, 3: dis_plus <= dis_plus + {1'd0, sq_out};
                            2: mul12 <= abs_minus_y;
                            4: mul12 <= r;
                            5: begin
                                if (isB) begin
                                    dis_plus <= 0;
                                    Bcover <= cmp;
                                    isABC <= 0; // 指定為 A
                                end else begin
                                    dis_plus <= 0;
                                    Acover <= cmp;
                                    isABC <= 2'd1; // 指定為 B
                                    cnt <= 0;
                                end
                            end
                            6: begin
                                total_union <= total_union + {5'd0, union_AB};
                                total_intersection <= total_intersection + {5'd0, intersection_AB};
                                state <= UPDATE;
                                cnt <= 0;
                            end
                            default: ;
                        endcase
                    end

                    3: begin
                        case (cnt)
                            0: mul12 <= abs_minus_x; // 初始狀態會是預設 A set
                            1, 3: dis_plus <= dis_plus + {1'd0, sq_out};
                            2: mul12 <= abs_minus_y;
                            4: mul12 <= r;
                            5: begin
                                if (isC) begin
                                    dis_plus <= 0;
                                    Ccover <= cmp;
                                    isABC <= 0; // 指定為 A
                                    
                                end else if (isB) begin
                                    dis_plus <= 0;
                                    Bcover <= cmp;
                                    isABC <= 2; // 指定為 C
                                    cnt <= 0;
                                end else begin
                                    dis_plus <= 0;
                                    Acover <= cmp;
                                    isABC <= 2'd1; // 指定為 B
                                    cnt <= 0;
                                end
                            end
                            6: begin
                                if (!intersection_ABC) begin
                                    ansMode11 <= ansMode11 + {5'd0, (intersection_AB | intersection_AC | intersection_BC)};
                                end
                                state <= UPDATE;
                                cnt <= 0;
                            end
                            default: ;
                        endcase
                    end
                    default: ;
                endcase
            end

            UPDATE: begin
                Acover <= 0; Bcover <= 0; Ccover <= 0;
                dis_plus <= 0;
                if (x == 4'd8 && y == 4'd8) begin
                    if (whichMode == 2'd2) begin
                        candidate <= total_union - total_intersection;
                    end else if (whichMode == 2'd3) begin
                        candidate <= {2'd0, ansMode11};
                    end
                    state <= OUTPUT;
                end else begin
                    x <= x + 1'd1;
                    if (x == 4'd8) begin
                        x <= 1'd1;
                        y <= y + 1'd1;
                    end
                    state <= MODE;
                end
            end

            OUTPUT: begin // 花 2 clk
                if (busy == 1'd1) begin
                    busy <= 0;
                    valid <= 1'd1;
                    //candidate <= ??
                end else begin
                    valid <= 0;
                    candidate <= 0;
                    state <= INPUT;
                    // 以下為重製訊號...
                    ansMode11 <= 0;
                    whichMode <= 0;
                    x1 <= 0; x2 <= 0; x3 <= 0; 
                    y1 <= 0; y2 <= 0; y3 <= 0; 
                    r1 <= 0; r2 <= 0; r3 <= 0; 
                    total_union <= 0;
                    total_intersection <= 0;
                    cnt <= 0;
                    x <= 4'd1;
                    y <= 4'd1;
                    isABC <= 0;
                    mul12 <= 0;
                    dis_plus <= 0;
                    Acover <= 0; Bcover <= 0; Ccover <= 0;
                end
            end
            default: ;
        endcase
    end
end



endmodule

// 以下是把MDOE叫AI共用的結果，省面積，但是不要用if else if ，用我原本的case寫法。
/* MODE: begin
    cnt <= cnt + 1'd1;

    // 【優化1：合併共同路徑】
    // 大家共用的步驟直接拉出來，大幅減少 MUX 判斷層級
    if (cnt == 3'd0) mul12 <= abs_minus_x;
    else if (cnt == 3'd1 || cnt == 3'd3) dis_plus <= dis_plus + {1'd0, sq_out};
    else if (cnt == 3'd2) mul12 <= abs_minus_y;
    else if (cnt == 3'd4) mul12 <= r;
    else if (cnt == 3'd5) begin
        // 只有 cnt=5 需要針對不同圓形做判斷
        case (whichMode)
            0: begin
                if (cmp == 1'd1) candidate <= candidate + 1'd1;
                cnt <= 0;
                state <= UPDATE;
            end
            1, 2: begin
                dis_plus <= 0;
                if (isABC == 2'd1) begin // 原本的 isB
                    Bcover <= cmp;
                    isABC <= 0; 
                end else begin // 原本的 isA
                    Acover <= cmp;
                    isABC <= 2'd1; 
                    cnt <= 0;
                end
            end
            3: begin
                dis_plus <= 0;
                case (isABC) // 【優化2：用 case 取代 if-else，拔掉優先權編碼器延遲】
                    2'd2: begin Ccover <= cmp; isABC <= 0; end
                    2'd1: begin Bcover <= cmp; isABC <= 2'd2; cnt <= 0; end
                    2'd0: begin Acover <= cmp; isABC <= 2'd1; cnt <= 0; end
                endcase
            end
        endcase
    end
    else if (cnt == 3'd6) begin
        state <= UPDATE;
        cnt <= 0;
        case (whichMode)
            1: candidate <= candidate + {7'd0, intersection_AB};
            2: begin
                total_union <= total_union + {6'd0, union_AB};
                total_intersection <= total_intersection + {6'd0, intersection_AB};
            end
            3: begin
                if (!intersection_ABC) 
                    ansMode11 <= ansMode11 + {6'd0, (intersection_AB | intersection_AC | intersection_BC)};
            end
        endcase
    end
end */
