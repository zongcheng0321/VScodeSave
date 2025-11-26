module ex1 (
    input clk,rst,
    input [7:0] in,
    output reg [3:0] q,
    output reg [7:0] R1,
    output reg [7:0] R2,
    output reg [7:0] out
);
always @(posedge clk) begin
    if(rst == 1)
        q <= 4'd8;
    else if(rst == 0)
    begin
        if(q <= 4'd7)
            q <= q + 1;
        else 
            q <= 0;
    end
end

always @(posedge clk) begin
    if(q == 4'd0 || q == 4'd1 || q == 4'd2 || q == 4'd5 || q == 4'd6) 
    begin
        out <= R2;
        R2 <= R1;
        R1 <= in;
    end
    else if (q == 4'd3)
    begin
        
        R2 <= R1;
        R1 <= R2;
        out <= in;
    end
    else if (q == 4'd4 || q == 4'd7 || q == 4'd8)
    begin
        out <= R1;
        R1 <= R2;
        R2 <= R1;
        R1 <= in;
    end
end 
endmodule