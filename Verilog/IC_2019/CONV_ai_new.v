// mul_in1 到 Convolutional_out critical path 太長
// 新增 mul_out_reg 來縮短 critical path
// 把 pixel 3x3 暫存器捨棄，縮短面積
// 過不了!

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
    input [19:0] cdata_rd,

    output reg [2:0] csel
);

//---------------------------------------------------------------
// FSM parameter 
    localparam LAYER0_READY      = 4'd0,
               INPUT_DATA        = 4'd1, // 管線化 Fetch + MAC
               OUTPUT_LAYER0     = 4'd2,
               CHOOSE_LAYER1     = 4'd3,
               INPUT_DATA_LAYER1 = 4'd4, // 管線化 Fetch + Max pooling
               OUTPUT_LAYER1     = 4'd5;

    reg [2:0] state_main;

// ---Layer0、1 要使用的變數---
    reg [5:0] col;
    reg [5:0] row;
    reg [3:0] pixel_cnt; // 用來推動管線的計數器
    
    // 取代原本的 pixels[0][0]，宣告專屬的暫存器做 Max Pooling 擂台
    reg signed [19:0] max_val; 

// ---CHANGE_PIXEL、INPUT_DATA---
    wire [1:0] pixel_index_row; 
    wire [1:0] pixel_index_col; 
    wire [11:0] input_index; 

// ---Layer0 輸出變數---
    wire [19:0] Layer0_out; 
    reg signed [43:0] Convolutional_out; 
    reg signed [39:0] mul_out_reg; // new to deal with critical path
    
//---------------------------------------------------------------
// 將 pixel_cnt 對應回你原本的 2D 座標 (pixel_index_row, pixel_index_col)
    // Layer 0 的 3x3 座標轉換 (用來計算邊界與記憶體位置)
    wire [1:0] l0_row = (pixel_cnt < 3) ? 2'd0 : (pixel_cnt < 6) ? 2'd1 : 2'd2;
    wire [1:0] l0_col = (pixel_cnt == 0 || pixel_cnt == 3 || pixel_cnt == 6) ? 2'd0 :
                        (pixel_cnt == 1 || pixel_cnt == 4 || pixel_cnt == 7) ? 2'd1 : 2'd2;
    // Layer 1 的 2x2 座標轉換
    wire [1:0] l1_row = (pixel_cnt == 2 || pixel_cnt == 3) ? 2'd1 : 2'd0;
    wire [1:0] l1_col = (pixel_cnt == 1 || pixel_cnt == 3) ? 2'd1 : 2'd0;

    // 依據目前狀態，將座標賦予給你原本命名的變數
    assign pixel_index_row = (state_main == INPUT_DATA_LAYER1) ? l1_row : l0_row;
    assign pixel_index_col = (state_main == INPUT_DATA_LAYER1) ? l1_col : l0_col;

//---------------------------------------------------------------
// Deal with layer0 zero_padding 
    wire boundaryT, boundaryB, boundaryL, boundaryR;
    assign boundaryT = (row == 0) ? 1'd1: 1'd0;
    assign boundaryB = (row == 6'd63)? 1'd1: 1'd0;
    assign boundaryL = (col == 0)? 1'd1: 1'd0;
    assign boundaryR = (col == 6'd63)? 1'd1: 1'd0;
    
    wire need_zeroPadding; 
    assign need_zeroPadding = (boundaryT && pixel_index_row == 0) || 
                              (boundaryB && pixel_index_row == 2'd2) || 
                              (boundaryL && pixel_index_col == 0) || 
                              (boundaryR && pixel_index_col == 2'd2);

//---------------------------------------------------------------
// 處理 Layer0 跟 Layer1 的要資料的位置 iaddr 
    wire [5:0] target_row = (state_main == INPUT_DATA_LAYER1) ? (pixel_index_row + row) : (pixel_index_row + row - 6'd1);
    wire [5:0] target_col = (state_main == INPUT_DATA_LAYER1) ? (pixel_index_col + col) : (pixel_index_col + col - 6'd1);
    assign input_index = (target_row << 6) + target_col;

//---------------------------------------------------------------
// ReLU & GET_WIDTH 
    wire signed [43:0] relu_result;
    assign relu_result = (Convolutional_out[43] == 1'b1) ? 44'd0 : Convolutional_out;
    assign Layer0_out = relu_result[35:16] + relu_result[15];

//---------------------------------------------------------------
// kernel 宣告 (改為 1D 陣列)
    wire signed [19:0] kernel0 [0:8]; 
    assign kernel0[0] = 20'h0A89E; assign kernel0[1] = 20'h092D5; assign kernel0[2] = 20'h06D43;
    assign kernel0[3] = 20'h01004; assign kernel0[4] = 20'hF8F71; assign kernel0[5] = 20'hF6E54;
    assign kernel0[6] = 20'hFA6D7; assign kernel0[7] = 20'hFC834; assign kernel0[8] = 20'hFAC19;

// 共用乘法器 (Pipeline 用)
    reg need_zeroPadding_d1;
    reg [3:0] pixel_cnt_d1; // 用來記錄前一個週期的計數，方便直接從 1D Kernel 抽值
    
    wire signed [19:0] mul_in1, mul_in2;
    wire signed [39:0] mul_out; 
    
    assign mul_in1 = need_zeroPadding_d1 ? 20'd0 : idata;
    assign mul_in2 = kernel0[pixel_cnt_d1]; // 直接用 1D index 取出對應權重
    assign mul_out = mul_in1 * mul_in2;

//---------------------------------------------------------------
// FSM main
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            col <= 0; row <= 0; pixel_cnt <= 0;
            busy <= 0; cwr <= 0; crd <= 0;
            caddr_rd <= 0; caddr_wr <= 12'hFFF; 
            iaddr <= 0; cdata_wr <= 0;
            csel <= 3'b001; 
            state_main <= LAYER0_READY;
            Convolutional_out <= {8'd0, 20'h01310, 16'd0};
            need_zeroPadding_d1 <= 0;
            pixel_cnt_d1 <= 0;
            max_val <= 0;
        end else begin
            case (state_main) 
                LAYER0_READY: begin 
                    col <= 0; row <= 0; pixel_cnt <= 0;
                    cwr <= 0; crd <= 0;
                    caddr_wr <= 12'hFFF; cdata_wr <= 0; caddr_rd <= 0; iaddr <= 0;
                    csel <= 3'b001; busy <= 0;
                    if (ready) begin
                        busy <= 1'b1;
                        state_main <= INPUT_DATA; 
                        Convolutional_out <= {8'd0, 20'h01310, 16'd0}; // Reset Bias
                    end
                end

                INPUT_DATA: begin
                    cwr <= 0; 
                    
                    // 1. Fetch 記憶體 (第 T 週期)
                    if (pixel_cnt < 9) begin
                        iaddr <= input_index;
                        need_zeroPadding_d1 <= need_zeroPadding;
                        pixel_cnt_d1 <= pixel_cnt; 
                    end

                    // 2. 乘法計算並「暫存」 (第 T+1 週期)
                    // 這裡不直接加到 Convolutional_out，而是存進 mul_out_reg，完美切斷 Critical Path！
                    if (pixel_cnt > 0 && pixel_cnt <= 9) begin
                        mul_out_reg <= mul_in1 * mul_in2;
                    end

                    // 3. 累加計算 (第 T+2 週期)
                    // 延後一個週期才做加法
                    if (pixel_cnt > 1 && pixel_cnt <= 10) begin
                        Convolutional_out <= Convolutional_out + mul_out_reg;
                    end

                    // 4. 控制 FSM 推進 (極限值從 9 改成 10)
                    if (pixel_cnt == 10) begin
                        state_main <= OUTPUT_LAYER0;
                        pixel_cnt <= 0;
                    end else begin
                        pixel_cnt <= pixel_cnt + 4'd1;
                    end
                end

                OUTPUT_LAYER0: begin
                    cdata_wr <= Layer0_out; 
                    caddr_wr <= caddr_wr + 12'd1;
                    cwr <= 1'd1;
                    
                    if (col == 6'd63) begin
                        col <= 0;
                        if (row == 6'd63) begin
                            row <= 0;
                            state_main <= CHOOSE_LAYER1;
                        end else begin
                            row <= row + 6'd1;
                            state_main <= INPUT_DATA;
                        end
                    end else begin
                        col <= col + 6'd1;
                        state_main <= INPUT_DATA;
                    end
                    Convolutional_out <= {8'd0, 20'h01310, 16'd0};
                end

                CHOOSE_LAYER1: begin 
                    csel <= 3'b001; 
                    col <= 0; row <= 0; pixel_cnt <= 0;
                    cwr <= 0; crd <= 0; caddr_rd <= 0;
                    caddr_wr <= 12'hFFF; cdata_wr <= 0;
                    max_val <= 0; 
                    state_main <= INPUT_DATA_LAYER1;
                end

                INPUT_DATA_LAYER1: begin
                    cwr <= 0;
                    crd <= 1'd1;
                    csel <= 3'b001;
                    // 1. Fetch 記憶體
                    if (pixel_cnt < 4) begin
                        caddr_rd <= input_index; 
                        pixel_cnt <= pixel_cnt + 4'd1;
                    end

                    // 2. MAX_POOLING 打擂台比較
                    if (pixel_cnt > 0 && pixel_cnt <= 4) begin
                        if (pixel_cnt == 1) 
                            max_val <= cdata_rd; // 第一筆讀進來直接當擂台主
                        else if (cdata_rd > max_val) 
                            max_val <= cdata_rd; // 後續進來的值如果比較大，就換人當
                    end

                    if (pixel_cnt == 4) begin
                        state_main <= OUTPUT_LAYER1;
                        pixel_cnt <= 0;
                        crd <= 1'd0;
                    end
                end

                OUTPUT_LAYER1: begin
                    cdata_wr <= max_val;
                    caddr_wr <= caddr_wr + 12'd1;
                    csel <= 3'b011; 
                    cwr <= 1'd1;
                    
                    if (col == 6'd62) begin
                        col <= 0;
                        if (row == 6'd62) begin
                            row <= 0;
                            state_main <= LAYER0_READY; // 結束
                        end else begin
                            row <= row + 6'd2; 
                            state_main <= INPUT_DATA_LAYER1;
                        end
                    end else begin
                        col <= col + 6'd2;     
                        state_main <= INPUT_DATA_LAYER1;
                    end
                end

                default: ;
            endcase
        end
    end
endmodule