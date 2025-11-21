module BCD ( //common-anode共陽 driven for 0
    input A,B,C,D, //A MSB
    output reg [7:0] out //a,b,c,d,e,f,g,dp
);
always@(A or B or C or D) begin
    case ({A,B,C,D})
        4'b0000: out = 8'b00000011;
        4'b0001: out = 8'b10011111;
        4'b0010: out = 8'b00100101;
        4'b0011: out = 8'b00001101;
        4'b0100: out = 8'b10011001;
        4'b0101: out = 8'b01001001;
        4'b0110: out = 8'b01000001;
        4'b0111: out = 8'b00011111;
        4'b1000: out = 8'b00000001;
        4'b1001: out = 8'b00001001;
        4'b1010: out = 8'b00010001;
        4'b1011: out = 8'b11000001;
        4'b1100: out = 8'b01100011;
        4'b1101: out = 8'b10000101;
        4'b1110: out = 8'b01100001;
        4'b1111: out = 8'b01110001;
        default: out = 8'b11111111;
    endcase
end
endmodule

module jkff 
(
    output q, qbar,
    input  j, k, clk ,clrn // clrn 給 0 驅動
);                         //負緣觸發

    wire cbar;    
    wire a, b;    
    wire y, ybar; 
    wire c, d;    

    not  (cbar, clk);

    nand (a, j, clk, clrn, qbar);
    nand (b, k, clk, q);

    nand (y, a, ybar);
    nand (ybar, b, y,clrn);

    nand (c, y, cbar);
    nand (d, ybar, cbar);

    nand (q, c, qbar);
    nand (qbar, d, q,clrn);
endmodule

module counterAsync_2bit (Q1,Q0,clk,clrn);//Q1 MSB
    output Q1,Q0;
    input clk,clrn;
    jkff jk1( .q(Q0), .qbar() , .j(1'd1), .k(1'd1) , .clk(clk), .clrn(clrn)); //left one
    jkff jk2( .q(Q1), .qbar() , .j(1'd1), .k(1'd1) , .clk(Q0), .clrn(clrn)); //right one
endmodule

module decoder_2to4(Q3,Q2,Q1,Q0,A,B);
output Q3,Q2,Q1,Q0;
input B,A;
wire an,bn;
not a1(an,A);
not b1(bn,B);
and and0(Q0,an,bn);
and and1(Q1,an,B);
and and2(Q2,A,bn);
and and3(Q3,A,B);
endmodule

module Mux_4to1( F,s3,s2,s1,s0,A,B); 

output  F;
input A,B; // AB為選擇線(A -> MSB)
input  s3,s2,s1,s0; // s3~s0為輸入 
wire an,bn,anbn,anB,Abn,AB;
not a1(an,A);
not b1(bn,B);
and and0(anbn,an,bn,s0);
and and1(anB,an,B,s1);
and and2(Abn,A,bn,s2);
and and3(AB,A,B,s3);
or or4(F,anbn,anB,Abn,AB);
endmodule

module project1 
(
    input [3:0] s3,s2,s1,s0,
    input clk, clrn,
    output a,b,c,d,e,f,g,dp, A1,A2,A3,A4 // add dp
);
wire counterQ1, counterQ0;
wire [3:0] F;

counterAsync_2bit Counter2bit(.Q1(counterQ1), .Q0(counterQ0), .clk(clk), .clrn(clrn)); // Q1 MSB , clrn driven 0 , jk是負緣觸發
decoder_2to4 decoder(.Q3(A4), .Q2(A3), .Q1(A2), .Q0(A1), .A(counterQ1), .B(counterQ0)); //A4 is rightmost 7-seg , counterQ1 ->MSB 為選擇線 
Mux_4to1  mux1 (.F(F[3]), .s3(s0[3]), .s2(s1[3]), .s1(s2[3]), .s0(s3[3]), .A(counterQ1), .B(counterQ0));// 當00時 A1= 1且輸出S3，原本A1為最右邊七段，
Mux_4to1  mux2 (.F(F[2]), .s3(s0[2]), .s2(s1[2]), .s1(s2[2]), .s0(s3[2]), .A(counterQ1), .B(counterQ0));// 變更為最左。 ->方便看波形
Mux_4to1  mux3 (.F(F[1]), .s3(s0[1]), .s2(s1[1]), .s1(s2[1]), .s0(s3[1]), .A(counterQ1), .B(counterQ0));
Mux_4to1  mux4 (.F(F[0]), .s3(s0[0]), .s2(s1[0]), .s1(s2[0]), .s0(s3[0]), .A(counterQ1), .B(counterQ0));
BCD bcd (.out({a,b,c,d,e,f,g,dp}), .A(F[3]), .B(F[2]), .C(F[1]), .D(F[0])); //A MSB
endmodule

module ALU_func (                    //ex2_1022
    output reg [12:0] result, 
    output reg status,
    input [12:0] x ,y,
    input [2:0] opcode,
    input aclk
);
reg [12:0] compare;
always@(negedge aclk) //改為負緣觸發 ->配合計數器的 jk
begin
    if(x >= y)
        compare = x;
    else 
        compare = y;
    case (opcode)
        3'b000: result = x;
        3'b001: result = x + y;
        3'b010: result = x - y;
        3'b011: result = x / y;
        3'b100: result = x % y;
        3'b101: result = compare; //取最大值輸出
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

module converter(
   input [11:0] in, // input 12bit -> max value = 4095
   output reg [15:0] bcd // result from 4095 -> need 4 digits -> 16bits bcd
   );

wire [13:0] bin = {2'b0,in}; // add leading zeros to the first 2 digits

always @(bin) begin
    bcd= 0;		 	
    for (integer i=0;i<14;i=i+1) begin					                //Iterate once for each bit in input number
        bcd[3:0]   = (bcd[3:0] >= 5)   ? (bcd[3:0] + 3)   : bcd[3:0];   //If any BCD digit is >= 5, add three
        bcd[7:4]   = (bcd[7:4] >= 5)   ? (bcd[7:4] + 3)   : bcd[7:4];
        bcd[11:8]  = (bcd[11:8] >= 5)  ? (bcd[11:8] + 3)  : bcd[11:8];
        bcd[15:12] = (bcd[15:12] >= 5) ? (bcd[15:12] + 3) : bcd[15:12];
        bcd = {bcd[14:0],bin[13-i]};				//Shift left one bit, and shift in proper bit from input 
    end
end
endmodule

module project2 (
    input [11:0] x, y,
    input [2:0] opcode,
    input clk, reset, // reset -> clrn, clrn driven 0
    output a,b,c,d,e,f,g,dp, A1,A2,A3,A4
);

wire [12:0] result_full, x_full, y_full;
wire [11:0] result;
wire [15:0] bcd;

assign x_full = {1'b0, x};
assign y_full = {1'b0, y};
ALU_func ALU1( .result(result_full), .status(), .x(x_full), .y(y_full), .opcode(opcode), .aclk(clk));
assign result = result_full[11:0];

converter converter1( .bcd(bcd), .in(result));

project1 proj( .s3(bcd[15:12]), .s2(bcd[11:8]), .s1(bcd[7:4]), .s0(bcd[3:0]), .clk(clk), .clrn(reset),        // A4 為最右邊的 seg -> s0 ,A1 -> s3
               .a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g), .dp(dp), .A1(A1) , .A2(A2), .A3(A3), .A4(A4));
endmodule