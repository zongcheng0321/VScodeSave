`timescale 1ns/10ps
module ISE( clk, reset, image_in_index, pixel_in, busy, out_valid, color_index, image_out_index);
input              clk;   // 本系統為同步於時脈正緣之同步設計。 (註: Host 端採clk ”正”緣時送資料。) 
input              reset; // 高位準”非”同步(active high asynchronous)之系統重置信號。 
input   [4:0]      image_in_index;
input   [23:0]     pixel_in;
output reg         busy; // ISE 忙碌之控制訊號。當為High時，表示系統正處於忙碌階段，告知Host端，暫時停止pixel_in資料的輸入；反之，當為Low時，表示告知Host端可繼續由pixel_in 輸入資料。
output reg         out_valid;
output reg [1:0]   color_index;
output reg [4:0]   image_out_index; // ISE 影像所屬index值之輸出匯流排。當影像色彩分類與排序完成後，可透過此匯流排將各影像所屬之index值依序輸出。

parameter FRAC_BIT = 10;

// FSM
reg [3:0] state;
localparam INPUT = 4'd0,
           // = 4'd0,
           OUTPUT = 4'd15;

//------------------------------------------
// 除法器及乘法器
//parameter width = 8;
parameter tc_mode = 0;
parameter rem_mode = 1; // corresponds to "%" in Verilog

// 除法器分子1. 為 qx * SW-1 = 1830 -> 11 bits
//          2. x_q10 = (rx << 10)/(TW-1) -> 根據分子一定小於分母，TW-1 最大值為 60，所以 rx = 59，這樣為 6 bits + 10 bits = 16 bits
// 所以被除數要設為 16 bits
localparam a_width = 16;
localparam b_width = 6;  // 分母最大值為 60 (TW-1 or TH-1)
reg [a_width -1 : 0] a;
reg [b_width -1 : 0] b;
reg [a_width -1 : 0] quotient; // 不知道可不可以自訂這裡的寬度
reg [b_width -1 : 0] remainder;
wire divide_by_0;

// Please add +incdir+$SYNOPSYS/dw/sim_ver+ to your verilog simulator
// command line (for simulation).
// instance of DW_div

DW_div #(.a_width(a_width), 
        .b_width(b_width), 
        .tc_mode(tc_mode), 
        .rem_mode(rem_mode)) 
        DW_div1 (
        .a(a), 
        .b(b), 
        .quotient(quotient), 
        .remainder(remainder), 
        .divide_by_0(divide_by_0));

// SW 最大值為 31、TW 最大值為 61，所以最大輸出像素 61 * 61 = 3721
// qx * SW-1 最大值為 61 * 31 -1 = 1830，所以乘法器輸出需 11 bits
reg signed [22:0] mul1; // 23 bits for a_num
reg signed [10:0] mul2; // 11 bits for x_signed
wire signed [32:0] mul_out; // 33bits
assign mul_out = mul1 * mul2;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= INPUT;
        busy <= 0;
        out_valid <= 0;
        color_index <= 0;
        image_out_index <= 0;
    end else begin
        case (state)
            INPUT: begin
                
            end
            default: ;
        endcase
    end
end

always @(*) begin
    case (state)
        INPUT: begin
            
        end
        default: begin
            
        end
    endcase
end

endmodule
