// counter (default 4 bits)

module binary_counter #(
    parameter WIDTH = 4
) (
    input clk, rst_n,
    output reg [WIDTH-1:0] count
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 0;
        else begin
            count <= count + 1;
        end
    end
endmodule