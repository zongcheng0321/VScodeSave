module F_8_ALU(out, a, b, c, select);
output reg [5:0] out;
input [2:0] select;
input [3:0] a, b, c; //改成4bit輸入
reg [5:0] compare1, compare2, mid; //1 -> max 2 -> min
always@(select)
begin
    /*                            
    if(a > b) //max
        compare1 = a;
    else 
        compare1 = b;         只有ab參數時取max,min
    if(a > b) //min
        compare2 = b;
    else 
        compare2 = a;
    */                            
    if(a >= b && a >= c) //a最大
    begin
        compare1 = a;
        if(b >= c)begin //c最小
            compare2 = c;
            mid = b;
        end
        else begin //b最小
            compare2 = b;
            mid = c;
        end
    end
    else if (b >= a && b >= c) //b最大
    begin
        compare1 = b;
        if(a >= c) begin //c最小
            compare2 = c;
            mid = a;
        end
        else begin//a最小
            compare2 = a;
            mid = c;
        end
    end
    else if (c >= a && c >= b) //c最大
    begin
        compare1 = c;
        if(a >= b) begin//b最小
            compare2 = b;
            mid = a;
        end
        else begin//a最小
            compare2 = a;
            mid = b;
        end
    end
    
    case (select)
        3'b000: out = a * b; 
        3'b001: out = a + b;
        3'b010: out = a - b;
        3'b011: out = a + 1; // 遞增
        3'b100: out = a - 1; // 遞減
        3'b101: out = compare1; // max
        3'b110: out = compare2; // min
        3'b111: out = mid; // 中間值
        default: out = 'bx;
    endcase
end
endmodule