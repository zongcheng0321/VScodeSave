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
               INPUT_DATA        = 4'd1, 
               OUTPUT_LAYER0     = 4'd2,
               CHOOSE_LAYER1     = 4'd3,
               INPUT_DATA_LAYER1 = 4'd4, 
               OUTPUT_LAYER1     = 4'd5;

    reg [3:0] state_main;

// ---Layer0、1 要使用的變數---
    reg [5:0] col;
    reg [5:0] row;
    reg [3:0] pixel_cnt; 
    
    reg signed [19:0] max_val; 

// ---CHANGE_PIXEL、INPUT_DATA---
    wire [1:0] pixel_index_row; 
    wire [1:0] pixel_index_col; 
    wire [11:0] input_index; 

// ---Layer0 輸出變數---
    wire [19:0] Layer0_out; 
    reg signed [43:0] Convolutional_out; 
    
    // 【關鍵修改】用來阻斷 SRAM 延遲的輸入端暫存器
    reg signed [19:0] mul_in1_reg; 
    reg signed [19:0] mul_in2_reg;
    
//---------------------------------------------------------------
// 將 pixel_cnt 對應回 2D 座標
    wire [1:0] l0_row = (pixel_cnt < 3) ? 2'd0 : (pixel_cnt < 6) ? 2'd1 : 2'd2;
    wire [1:0] l0_col = (pixel_cnt == 0 || pixel_cnt == 3 || pixel_cnt == 6) ? 2'd0 :
                        (pixel_cnt == 1 || pixel_cnt == 4 || pixel_cnt == 7) ? 2'd1 : 2'd2;
    
    wire [1:0] l1_row = (pixel_cnt == 2 || pixel_cnt == 3) ? 2'd1 : 2'd0;
    wire [1:0] l1_col = (pixel_cnt == 1 || pixel_cnt == 3) ? 2'd1 : 2'd0;

    assign pixel_index_row = (state_main == INPUT_DATA_LAYER1) ? l1_row : l0_row;
    assign pixel_index_col = (state_main == INPUT_DATA_LAYER1) ? l1_col : l0_col;

//---------------------------------------------------------------
// Deal with layer0 zero_padding 
    wire boundaryT = (row == 0);
    wire boundaryB = (row == 6'd63);
    wire boundaryL = (col == 0);
    wire boundaryR = (col == 6'd63);
    
    wire need_zeroPadding; 
    assign need_zeroPadding = (boundaryT && pixel_index_row == 0) || 
                              (boundaryB && pixel_index_row == 2'd2) || 
                              (boundaryL && pixel_index_col == 0) || 
                              (boundaryR && pixel_index_col == 2'd2);

//---------------------------------------------------------------
// 處理 iaddr 
    wire [5:0] target_row = (state_main == INPUT_DATA_LAYER1) ? (pixel_index_row + row) : (pixel_index_row + row - 6'd1);
    wire [5:0] target_col = (state_main == INPUT_DATA_LAYER1) ? (pixel_index_col + col) : (pixel_index_col + col - 6'd1);
    assign input_index = (target_row << 6) + target_col;

//---------------------------------------------------------------
// ReLU & GET_WIDTH 
    wire signed [43:0] relu_result = (Convolutional_out[43] == 1'b1) ? 44'd0 : Convolutional_out;
    assign Layer0_out = relu_result[35:16] + relu_result[15];

//---------------------------------------------------------------
// kernel 宣告
    wire signed [19:0] kernel0 [0:8]; 
    assign kernel0[0] = 20'h0A89E; assign kernel0[1] = 20'h092D5; assign kernel0[2] = 20'h06D43;
    assign kernel0[3] = 20'h01004; assign kernel0[4] = 20'hF8F71; assign kernel0[5] = 20'hF6E54;
    assign kernel0[6] = 20'hFA6D7; assign kernel0[7] = 20'hFC834; assign kernel0[8] = 20'hFAC19;

    reg need_zeroPadding_d1;
    reg [3:0] pixel_cnt_d1; 

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
            mul_in1_reg <= 0;
            mul_in2_reg <= 0;
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
                        Convolutional_out <= {8'd0, 20'h01310, 16'd0}; 
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

                    // 2. 緩衝資料 (第 T+1 週期)
                    if (pixel_cnt > 0 && pixel_cnt <= 9) begin
                        mul_in1_reg <= need_zeroPadding_d1 ? 20'd0 : idata;
                        mul_in2_reg <= kernel0[pixel_cnt_d1];
                    end

                    // 3. MAC 乘加運算 (第 T+2 週期)
                    if (pixel_cnt > 1 && pixel_cnt <= 10) begin
                        Convolutional_out <= Convolutional_out + (mul_in1_reg * mul_in2_reg);
                    end

                    // 4. 控制 FSM 推進 
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

                    if (pixel_cnt < 4) begin
                        caddr_rd <= input_index; 
                        pixel_cnt <= pixel_cnt + 4'd1;
                    end

                    if (pixel_cnt > 0 && pixel_cnt <= 4) begin
                        if (pixel_cnt == 1) 
                            max_val <= cdata_rd; 
                        else if (cdata_rd > max_val) 
                            max_val <= cdata_rd; 
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
                            state_main <= LAYER0_READY; 
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