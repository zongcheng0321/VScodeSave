module FSM (
    input x, clk, clr,
    output reg z
);
parameter S0 = 3'd0,
          S1 = 3'd1,
          S2 = 3'd2,
          S3 = 3'd3;
reg [2:0] state = S0, next_state = S0;
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
                z = 1'd0;
            end
            else begin
                next_state = S1;
                z = 1'd0;
            end
        S1: if(x) begin
                next_state = S2;
                z = 1'd0;
            end
            else begin
                next_state = S1;
                z = 1'd0;
            end
        S2: if(x) begin
            next_state = S3;
            z = 1'd0;
        end
        else begin
            next_state = S1;
            z = 1'd0;
        end
        S3: if(x) begin
            next_state = S0;
            z = 1'd0;
        end
        else begin
            next_state = S1;
            z = 1'd1;
        end
        default: z = 1'd0; 
    endcase
end
endmodule