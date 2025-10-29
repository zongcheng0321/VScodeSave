module add3 (
    output [3:0] s,
    input [3:0] a
);
assign s[0] = (a[3] & ~a[0]) | (~a[3] & ~a[2] & a[0]) | (a[2] & a[1] & ~a[0]);
assign s[1] = (a[1] & a[0] ) | (~a[2] & a[1]) | (a[3] & ~a[0]);
assign s[2] = (a[2] & ~a[1] & ~a[0]) | (a[3] & a[0]);
assign s[3] = (a[3]) | (a[2] & a[0]) | (a[2] & a[1]);

endmodule

module Converter_8bit (
    output [9:0] P,
    input [7:0] B//binary
);
wire [3:0] s1, s2, s3, s4, s6, s7;
add3 C1(.s(s1), .a({1'b0, B[7], B[6], B[5]}));
add3 C2(.s(s2), .a({s1[2], s1[1], s1[0], B[4]}));
add3 C3(.s(s3), .a({s2[2], s2[1], s2[0], B[3]}));
add3 C4(.s(s4), .a({s3[2], s3[1], s3[0], B[2]}));
add3 C5(.s(P[4:1]), .a({s4[2], s4[1], s4[0], B[1]}));
add3 C6(.s(s6), .a({1'b0, s1[3], s2[3], s3[3]}));
assign P[9] = s6[3];
add3 C7(.s(P[8:5]), .a({s6[2], s6[1], s6[0], s4[3]}));
assign P[0] = B[0];
endmodule