// 計數器法： 它是用 50MHz 的 System Clock 去數。誤差只有 1 個 Clock Cycle (20ns)。
// 延遲時間：20.00000ms ~ 20.00002ms (極度精確)。
// 移位暫存器法： 誤差取決於 Sampling Tick。
// 延遲時間：15ms ~ 20ms (誤差大)。

module debounce_counter (
    input wire clk,       // 50MHz System Clock
    input wire rst_n,     // Active Low Reset
    input wire btn_in,    // Noisy Button Input
    output reg btn_out    // Debounced Output
);

    // 1. 參數定義
    // 20ms at 50MHz = 1,000,000 cycles
    parameter DEBOUNCE_TIME = 1_000_000 - 1;
    
    reg [19:0] cnt; //count
    reg [1:0] btn_sync;   // 用於同步化的暫存器

    // 2. 輸入訊號同步化 (2-stage Synchronizer)
    // 這是 FPGA 設計的黃金準則，防止亞穩態
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync <= 2'b00;
        end else begin
            btn_sync <= {btn_sync[0], btn_in};
        end
    end

    // wire btn_stable = btn_sync[1]; // 取同步後的訊號

    // 3. 計數器與狀態更新邏輯
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
                // 如果輸入訊號跳回原值（代表剛剛是雜訊），計數器馬上清零
                cnt <= 0;
            end
        end
    end

endmodule