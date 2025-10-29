module F_8_ALU(out, a, b, select);
output reg [5:0] out;
input [2:0] select;
input [3:0] a, b; //改成4bit輸入
reg [5:0] compare1, compare2; //1 -> max 2 -> min
always@(select)
begin
    if(a>b) //max
        compare1 = a;
    else 
        compare1 = b;
    if(a>b) //min
        compare2 = b;
    else 
        compare2 = a;
        
    case (select)
        3'b000: out = a;
        3'b001: out = a + b;
        3'b010: out = a - b;
        3'b011: out = a + 1; // 遞增
        3'b100: out = a - 1; // 遞減
        3'b101: out = compare1;
        3'b110: out = compare2;
        3'b111: out = (a+b)/2;
        default: out = 'bx;
    endcase
end
endmodule