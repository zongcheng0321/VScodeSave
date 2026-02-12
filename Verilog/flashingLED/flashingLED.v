// 閃爍LED 
module flashingLED (
    input clk, rst_n, btn_key0_in, btn_key1_in,
    output [3:0] LED 
);

    reg [4:0] speed_sel;
    reg btn_key0_lastclk, btn_key1_lastclk;
    wire btn_key0_out, btn_key1_out, btn_key0_posedge, btn_key1_posedge;
    wire [29:0] divider_out;
    // key0 debounce
    debounce_counter key0 (
        .clk(clk), .rst_n(rst_n), .btn_in(btn_key0_in), 
        .btn_out(btn_key0_out)
    );
    // key1 debounce
    debounce_counter key1 (
        .clk(clk), .rst_n(rst_n), .btn_in(btn_key1_in), 
        .btn_out(btn_key1_out)
    );
    
    // divider divider_out[23] -> 2.94Hz/ 0.34s
    // 最高 21.47483648s
    binary_counter #(.WIDTH(29)) divider (
        .clk(clk), .rst_n(rst_n), .count(divider_out)
    );
    
    // edgeTrigger detected
    // 偵測上一個 clk 的訊號跟現在的 clk 訊號， 0 -> 1 時為 1，其餘為 0
    // 要先生出紀錄上一個 clk 的訊號電路，再由真值表實現功能
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_key0_lastclk <= 0;
            btn_key1_lastclk <= 0;
        end else begin
            btn_key0_lastclk <= btn_key0_out;
            btn_key1_lastclk <= btn_key1_out;
        end
    end
    assign btn_key0_posedge = btn_key0_lastclk & (~btn_key0_out);
    assign btn_key1_posedge = btn_key1_lastclk & (~btn_key1_out);

    // flashingLED
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            speed_sel <= 5'd23;   
        else begin
            if (btn_key0_posedge && speed_sel >= 1)
                speed_sel <= speed_sel - 1;  // 快
            else if (btn_key1_posedge && speed_sel <=29)
                speed_sel <= speed_sel + 1;  // 慢
            else 
                speed_sel <= speed_sel;
        end
    end

    assign LED = {4{divider_out[speed_sel]}};
endmodule