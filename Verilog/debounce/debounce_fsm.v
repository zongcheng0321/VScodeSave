module debounce_fsm (
    input wire clk,       // 50MHz System Clock
    input wire rst_n,     // Active Low Reset
    input wire btn_in,    // Noisy Input
    output reg btn_out    // Debounced Output
);

    // ==========================================
    // 1. 參數定義 (50MHz, 20ms)
    // ==========================================
    // 20ms / 20ns = 1,000,000 cycles
    localparam CNT_MAX = 1_000_000 - 1;

    // 狀態編碼 (State Encoding)
    localparam S_ZERO          = 2'b00; // 穩定低電位
    localparam S_CHECK_RISING  = 2'b01; // 正在確認是否變高
    localparam S_ONE           = 2'b10; // 穩定高電位
    localparam S_CHECK_FALLING = 2'b11; // 正在確認是否變低

    reg [1:0] current_state, next_state;
    reg [19:0] counter;      // 20-bit 計數器
    reg [1:0] btn_sync;      // 同步化暫存器
    wire btn_stable_in;      // 同步後的輸入訊號

    // ==========================================
    // 2. 輸入訊號同步化 (Synchronizer) - 必備！
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            btn_sync <= 2'b00;
        else 
            btn_sync <= {btn_sync[0], btn_in};
    end
    
    assign btn_stable_in = btn_sync[1];

    // ==========================================
    // 3. FSM: 狀態暫存器 (State Register)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= S_ZERO;
        else
            current_state <= next_state;
    end

    // ==========================================
    // 4. FSM: 下一個狀態邏輯 (Next State Logic)
    // ==========================================
    always @(*) begin
        // 預設保持原狀態
        next_state = current_state;

        case (current_state)
            // 狀態 0: 等待按鈕被按下
            S_ZERO: begin
                if (btn_stable_in == 1'b1)
                    next_state = S_CHECK_RISING;
            end

            // 狀態 1: 檢查上升沿是否為真 (過濾雜訊)
            S_CHECK_RISING: begin
                if (btn_stable_in == 1'b0)
                    next_state = S_ZERO;        // 發現是雜訊，退回 0
                else if (counter >= CNT_MAX)
                    next_state = S_ONE;         // 時間到，確認是有效訊號
            end

            // 狀態 2: 按鈕已穩定按下，等待放開
            S_ONE: begin
                if (btn_stable_in == 1'b0)
                    next_state = S_CHECK_FALLING;
            end

            // 狀態 3: 檢查下降沿是否為真 (過濾雜訊)
            S_CHECK_FALLING: begin
                if (btn_stable_in == 1'b1)
                    next_state = S_ONE;         // 發現是雜訊，退回 1
                else if (counter >= CNT_MAX)
                    next_state = S_ZERO;        // 時間到，確認按鈕已放開
            end
            
            default: next_state = S_ZERO;
        endcase
    end

    // ==========================================
    // 5. 資料路徑與計數器控制 (Datapath)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            btn_out <= 0;
        end else begin
            // 計數器邏輯
            if (current_state == S_CHECK_RISING || current_state == S_CHECK_FALLING) begin
                counter <= counter + 1; // 在檢查狀態時累加
            end else begin
                counter <= 0;           // 在穩定狀態時歸零
            end

            // 輸出邏輯 (Registered Output)
            // 只有進入穩定高電位狀態時，才拉高輸出
            if (current_state == S_ONE || current_state == S_CHECK_FALLING)
                btn_out <= 1'b1;
            else
                btn_out <= 1'b0;
        end
    end

endmodule