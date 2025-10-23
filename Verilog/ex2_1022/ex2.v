module ALU_func (
    output reg [12:0] result, 
    output reg status,
    input [12:0] x ,y,
    input [2:0] opcode,
    input aclk
);
reg [12:0] compare;
always@(posedge aclk)
begin
    if(x>y)
        compare = x;
    else 
        compare = y;
    case (opcode)
        3'b000: result = x;
        3'b001: result = x + y;
        3'b010: result = x - y;
        3'b011: result = x / y;
        3'b100: result = x % y;
        3'b101: result = compare;
        3'b110: result = x >> 1;
        3'b111: result = x << 1;
        default: result = 13'hx;
    endcase
    
    if(result == 0)
        status = 1;
    else 
        status = 0;
end
endmodule