module Converter_8bit (
    output reg [9:0] P,
    input [7:0] B//binary
);
reg [3:0] s1, s2, s3, s4, s5, s6, s7;
reg [3:0] s1in, s2in, s3in, s4in, s5in, s6in, s7in;
always @(*) begin //按圖施工保證成功
    s1in = {1'b0, B[7], B[6], B[5]};
    s1 = (s1in >= 5) ? s1in + 3 : s1in; //Check if sin is >= 5
    
    s2in = {s1[2], s1[1], s1[0], B[4]};
    s2 = (s2in >= 5) ? s2in + 3 : s2in;
    
    s3in = {s2[2], s2[1], s2[0], B[3]};
    s3 = (s3in >= 5) ? s3in + 3 : s3in;

    s4in = {s3[2], s3[1], s3[0], B[2]};
    s4 = (s4in >= 5) ? s4in + 3 : s4in;

    s5in = {s4[2], s4[1], s4[0], B[1]};
    s5 = (s5in >= 5) ? s5in + 3 : s5in;

    s6in = {1'b0, s1[3], s2[3], s3[3]};
    s6 = (s6in >= 5) ? s6in + 3 : s6in;

    s7in = {s6[2], s6[1], s6[0], s4[3]};
    s7 = (s7in >= 5) ? s7in + 3 : s7in;
    
    P[0] = B[0];
    P[4:1] = s5;
    P[9] = s6[3];
    P[8:5] = s7;
end
endmodule
// 下面的版本較好!!
module converter(
    input [11:0] in,
    output reg [15:0] bcd
);

    //wire [15:0] bin = {4'b0, in}; // 前面補 4 個 0 因為只要 12 個輸入

    always @(in) begin
        bcd = 0; // 初始化
        for (integer i = 0; i < 12; i = i + 1) begin // 輸入是 12 bits，所以精準執行 12 次 (i = 0 到 11)
            // 改用三元運算子，讓 X 能夠正確擴散
            bcd[3:0]   = (bcd[3:0] >= 5)   ? (bcd[3:0] + 3)   : bcd[3:0];
            bcd[7:4]   = (bcd[7:4] >= 5)   ? (bcd[7:4] + 3)   : bcd[7:4];
            bcd[11:8]  = (bcd[11:8] >= 5)  ? (bcd[11:8] + 3)  : bcd[11:8];
            bcd[15:12] = (bcd[15:12] >= 5) ? (bcd[15:12] + 3) : bcd[15:12];
            
            // Shift
            //bcd = {bcd[14:0], bin[11-i]};
            bcd = {bcd[14:0], in[11-i]}; // 不補 0 也可以，因為 bcd 初始化為 0
        end
    end
endmodule