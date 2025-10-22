module ALU_func (
    output reg result, status,
    input [12:0] x ,y,
    input [2:0] opcode,
    input aclk
);
always@(posedge aclk)
begin
    case (opcode)
        3'b000: result = x;
        3'b001: result = x + y;
        3'b010: result = x - y;
        3'b011: result = x / y;
        3'b100: result = x % y;
        3'b101: result = (x > y);
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