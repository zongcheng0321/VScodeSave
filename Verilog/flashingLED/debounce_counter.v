// 延遲時間：20.00000ms ~ 20.00002ms (極度精確)。
// system clk = 50Mhz
module debounce_counter (
    input  clk, rst_n, btn_in, // button in
    output reg btn_out         // button out
);
    // 50Mhz -> T = 20ns. We need 20ms to debounce. So clk needs 20ms/20ns = 1M cycle.
    parameter DEBOUNCE_TIME = 1_000_000 - 1;
    
    reg [19:0] cnt;       // count
    reg [1:0] btn_sync;   // 同步後的 button signal

    // double flop sync 
    // 防止亞穩態訊號
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync <= 2'b00;
        end else begin
            btn_sync <= {btn_sync[0], ~btn_in};
            // 讓同步後的訊號是正邏輯 (如果按鈕按下是 0 的話)
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
            btn_out <= 0;
        end else begin
            // 如果同步後的輸入訊號 != 目前輸出狀態
            if (btn_sync[1] != btn_out) begin
                // 開始計數
                if (cnt < DEBOUNCE_TIME) begin
                    cnt <= cnt + 1;
                end else begin
                    // 計數完成，確認訊號穩定，更新輸出
                    btn_out <= btn_sync[1];
                    cnt <= 0; // 計數器歸零，準備下一次變化
                end
            end else begin
                // 如果輸入訊號跳回原值（代表剛剛是雜訊），計數器清零
                cnt <= 0;
            end
        end
    end

endmodule