// 移位暫存器採樣法 (Shift Register Sampling)
// 採樣不確定性 (Sampling Uncertainty)
// 延遲時間並不是固定的 20ms，而是在 15ms 到 20ms 之間浮動。

// 這在實務上嚴重嗎？
// 對於「除彈跳」來說，通常不嚴重。
// 機械彈跳通常在 5ms ~ 10ms 內就會結束。
// 我們的最小延遲是 15ms，這已經大於絕大多數的彈跳時間（>10ms），所以即使發生「情況 A」，電路依然能有效過濾彈跳，功能是正常的。

module debounce_shift_reg (
    input wire clk,       // 50MHz System Clock
    input wire rst_n,     // Active Low Reset
    input wire btn_in,    // Noisy Button Input
    output reg btn_out    // Debounced Output
);

    // 1. 參數定義
    // 5ms at 50MHz = 250,000 cycles (T = 20ns so 5ms = 20ns * 250000)
    parameter TICK_MAX = 250_000 - 1; 
    
    reg [17:0] tick_cnt;
    reg sample_tick;
    reg [3:0] shift_reg;

    // 2. 慢速脈衝產生器 (Tick Generator)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt <= 0;
            sample_tick <= 0;
        end else begin
            if (tick_cnt >= TICK_MAX) begin
                tick_cnt <= 0;
                sample_tick <= 1'b1; // 產生一個 Cycle 的脈衝
            end else begin
                tick_cnt <= tick_cnt + 1;
                sample_tick <= 1'b0;
            end
        end
    end

    // 3. 移位暫存器邏輯
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 4'b0000;
            btn_out <= 0;
        end else if (sample_tick) begin
            // 每次 Tick 發生時，將輸入訊號推入暫存器 (LSB in)
            shift_reg <= {shift_reg[2:0], btn_in};
            
            // 4. 判斷邏輯 (全 1 或 全 0 才改變輸出)
            if (shift_reg == 4'b1111)
                btn_out <= 1'b1;
            else if (shift_reg == 4'b0000)
                btn_out <= 1'b0;
            // 若是 0011, 1010 等中間狀態，保持 btn_out 原值不變
        end
    end

endmodule