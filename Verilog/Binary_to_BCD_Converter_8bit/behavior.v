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