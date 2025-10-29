module encoder_8to3 (
    input [7:0] I,
    output [2:0] y
);
assign y[2] = | I[7:4];
assign y[1] = I[7] | I[6] | I[3] | I[2];
assign y[0] = I[7] | I[5] | I[3] | I[1];

endmodule