module BCDto7seg ( //common-anode共陽 driven for 0
    input A,B,C,D, //A MSB
    output reg [7:0] out //a,b,c,d,e,f,g,dp
);
always@(A or B or C or D) begin
    case ({A,B,C,D})
        4'b0000: out = 8'b00000011;
        4'b0001: out = 8'b10011111;
        4'b0010: out = 8'b00100101;
        4'b0011: out = 8'b00001101;
        4'b0100: out = 8'b10011001;
        4'b0101: out = 8'b01001001;
        4'b0110: out = 8'b01000001;
        4'b0111: out = 8'b00011111;
        4'b1000: out = 8'b00000001;
        4'b1001: out = 8'b00001001;
        default: out = 8'b11111111;
    endcase
end
endmodule