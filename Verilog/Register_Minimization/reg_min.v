// Input: 0,1,2,3,4,5,6,7,8,9, (0,1,2, 3, 4, 5, 6, ... )
// Based on your mobile number, please show the architecture.
// Example: Mobile: 0 9 1 8 3 5 5 9 0 9
// Output: 0,9,1,8,3,5,2,4,6,7,  (0,9, 1, 8, 3, 5, 2, 4, 6, 7) ...
//                               (digit number is repeat -> remove)
//                               (does not appear -> put the last )

// =================================================================
// output: 0 9 6 2 3 7 1 4 5 8
// 同步 rst

`timescale 1ns/10ps
module reg_min (
    // 0~9
    input            clk, rst, // posedge clk, sync rst(high active)
    input      [3:0] num_in,   // tb 調整成正緣給資料，這樣可以不需要多 1 clk 存資料
    output reg [3:0] num_out
);

// reg [3:0] in; // 由於 num_in 的資料不穩定，如果正緣給資料，那就不需要先存到 reg，但如果負緣給就需要存到 reg 之後才做功能
reg [3:0] R1, R2, R3, R4, R5, R6, R7, R8; // 根據 table 最多需 8 個 reg
reg [4:0] cnt; // 0 ~ 17 -> 共 18 個 clk
//----------------------------------
// Control R1~ R8
always @(posedge clk) begin // sync rst
    if (rst) begin
        // datapath no reset
    end else begin
        case (cnt) // 使用 case 降低 critical path
            0, 10: begin
                R1 <= num_in;
                R2 <= R1;
                R3 <= R2;
                R4 <= R3;
                R5 <= R5;
                R6 <= R6;
                R7 <= R8;
                R8 <= R7;
            end 
            1, 11: begin
                R1 <= num_in;
                R2 <= R1;
                R3 <= R2;
                R4 <= R3;
                R5 <= R4;
                R6 <= R5;
                R7 <= R6;
                R8 <= R8;
            end
            2, 12: begin
                R1 <= num_in;
                R2 <= R1;
                R3 <= R2;
                R4 <= R3;
                R5 <= R4;
                R6 <= R5;
                R7 <= R8;
                R8 <= R7;
            end
            3, 13: begin
                R1 <= num_in;
                R2 <= R1;
                R3 <= R2;
                R4 <= R3;
                R5 <= R4;
                R6 <= R6;
                R7 <= R8;
                R8 <= R7;
            end
            4, 5, 6, 7, 8, 14, 15, 16, 17: begin
                R1 <= num_in;
                R2 <= R1;
                R3 <= R2;
                R4 <= R3;
                R5 <= R4;
                R6 <= R5;
                R7 <= R6;
                R8 <= R7;
            end
            9: begin
                R8 <= R7;
                R7 <= R8;
                R6 <= R5;
                R5 <= R6;
                R4 <= R3;
                R3 <= R4;
                R2 <= R2;
                R1 <= R1;
            end
            default: ;
        endcase
    end
end

// cnt -> rst 結束後從 0 開始計數，不會變成 1 開始，所以一開始要讓他先為 -1，這樣才能符合 cycle = 0 時 num_in = 0 ...
always @(posedge clk) begin // sync rst
    if (rst) begin // high active rst
        cnt <= -5'sd1;
    end else begin
        if (cnt == 5'd17) begin
            cnt <= 5'd8; // 第二輪之後要一直保持輸出序列
        end else begin
            cnt <= cnt + 5'd1;
        end
    end
end

// output combinational
always @(*) begin
    num_out = 0;
    case (cnt)
        8, 14, 15, 16, 17: begin
            num_out = R8;
        end
        9: begin
            num_out = num_in;
        end
        10: begin
            num_out = R4;
        end
        11: begin
            num_out = R7;
        end
        12: begin
            num_out = R6;
        end
        13: begin
            num_out = R5;
        end
        default: num_out = 0;
    endcase
end

endmodule
