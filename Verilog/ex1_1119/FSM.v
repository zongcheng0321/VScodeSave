module FSM (
    input x, clk, clr,
    output reg z
);
parameter S0 = 3'd0,
          S1 = 3'd1,
          S2 = 3'd2,
          S3 = 3'd3;
reg [2:0] state, next_state;
always @(posedge clk) begin
    if(clr) 
        state <= S0;
    else 
        state <= next_state;
end

always @(state or x) begin
    case (state)
        S0: if(x) begin
                next_state = S0;
                z = 'd0;
            end
            else 
                next_state = S1;
                z = 'd0;
        S1:
        default: 
    endcase
end

always @(state) begin
    case (state)
        S0:  
        default: 
    endcase
end
endmodule