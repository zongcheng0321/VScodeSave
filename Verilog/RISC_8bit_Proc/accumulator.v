//暫存器 (Register)，用來暫存運算的結果。
module accumulator ( //todo
    input aclk,
    input rst,
    input ldac, // load accumulator 類似 enable
    input [7:0] alu_out,
    output reg [7:0] acc_out
);
//aclk 由 decoder 發出的訊號，類似 enable
always @(posedge aclk or negedge rst) begin 
    if (!rst)
        acc_out <= 8'b0;
    else if (ldac)
        acc_out <= alu_out;
end

endmodule