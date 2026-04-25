module dynamic_binary_to_7seg #(
    parameter BIN_WIDTH  = 12, // 輸入的二進位位元數
    parameter NUM_DIGITS = 4   // 需要的七段顯示器數量
)(
    input  [BIN_WIDTH-1:0]        bin_in,
    output [(NUM_DIGITS*7)-1:0]   seg_out // 輸出總共 NUM_DIGITS * 7 根線
);

    // 用來連接 Bin2BCD 輸出 與 7-seg 輸入的內部線路
    wire [(NUM_DIGITS*4)-1:0] internal_bcd;

    // 1. 實例化你寫好的 Bin to BCD 轉換器
    parameterized_bin2bcd #(
        .BIN_WIDTH(BIN_WIDTH),
        .BCD_DIGITS(NUM_DIGITS)
    ) my_bin2bcd (
        .in(bin_in),
        .bcd(internal_bcd)
    );

    // 2. 動態生成 (Generate) 七段顯示器解碼器
    genvar i; // 宣告 generate 專用的變數
    generate
        // 根據需要的數字數量，自動複製出好幾個 bcd_to_seg7 模組
        for (i = 0; i < NUM_DIGITS; i = i + 1) begin : gen_7seg
            bcd_to_seg7 seg_inst (
                // 將 internal_bcd 切片，4 bits 送給一個解碼器
                .bcd( internal_bcd[i*4 +: 4] ),
                
                // 將解碼後的 7 bits 結果接回對應的輸出位置
                .seg( seg_out[i*7 +: 7] )
            );
        end
    endgenerate

endmodule