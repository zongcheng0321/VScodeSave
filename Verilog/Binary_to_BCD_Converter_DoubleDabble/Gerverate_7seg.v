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
// 上面沒有很清楚，以下才是真正的步驟
//------------------------------OR-----------------------------
module bcd_to_7seg (
    input  wire [3:0] bcd_in,  // 4-bit 輸入 (0~9)
    output reg  [6:0] seg_out  // 7-bit 輸出 {a,b,c,d,e,f,g}
);

    always @(*) begin
        case (bcd_in)
            // 共陰極設定：1 為亮，0 為暗
            // 對應順序: {a, b, c, d, e, f, g}
            4'd0: seg_out = 7'b1111110; 
            4'd1: seg_out = 7'b0110000; 
            4'd2: seg_out = 7'b1101101; 
            4'd3: seg_out = 7'b1111001; 
            4'd4: seg_out = 7'b0110011; 
            4'd5: seg_out = 7'b1011011; 
            4'd6: seg_out = 7'b1011111; 
            4'd7: seg_out = 7'b1110000; 
            4'd8: seg_out = 7'b1111111; 
            4'd9: seg_out = 7'b1111011; 
            default: seg_out = 7'b0000000; // 預設全暗或顯示錯誤符號
        endcase
    end

endmodule
module multi_7seg_decoder #(
    parameter DIGITS = 4  // 定義有幾個七段顯示器（可由外部動態修改參數）
)(
    input  wire [(DIGITS*4)-1:0] bcd_bus, // 所有的 BCD 輸入打包 (例如 4 個就是 16 bits)
    output wire [(DIGITS*7)-1:0] seg_bus  // 所有的 7-seg 輸出打包 (例如 4 個就是 28 bits)
);

    // 宣告 genvar 用於 generate 迴圈
    genvar i;

    generate
        for (i = 0; i < DIGITS; i = i + 1) begin : gen_decoders
            // 動態實例化基礎解碼器
            bcd_to_7seg decoder_inst (
                // 每次取出 4 bits 作為輸入 (使用 +: 語法進行固定寬度擷取)
                .bcd_in (bcd_bus[i*4 +: 4]), 
                
                // 每次輸出 7 bits
                .seg_out(seg_bus[i*7 +: 7])  
            );
        end
    endgenerate

endmodule
/*程式重點
genvar i;：這是 generate 區塊專用的變數宣告方式，只能在合成（Synthesis）時期用來展開硬體結構，
不會變成真實的暫存器。
begin : gen_decoders：在 generate 的 for 迴圈中，必須為 begin 區塊命名（這裡命名為 gen_decoders）。
這能讓編譯器在展開時為每個實例產生獨特的層次名稱（例如 gen_decoders[0].decoder_inst）。
[i*4 +: 4]：這是 Verilog-2001 引入的「Indexed part-select」語法。
它的意思是「從索引值 i*4 開始，往上抓取 4 個位元」。這在處理平坦化的一維陣列（Flattened Array）時非常方便。
*/