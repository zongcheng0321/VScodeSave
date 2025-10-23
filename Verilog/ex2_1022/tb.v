module tb;
wire [12:0] result;
wire status;
reg [12:0] x ,y;
reg [2:0] opcode;
reg aclk;
ALU_func alu(.result(result), .status(status), .x(x), .y(y), .opcode(opcode), .aclk(aclk));
initial begin
    x = 4; y =2; opcode = 7; aclk = 0;
    for(integer i = 0;i <8;i = i + 1)
    begin
        opcode = opcode +1;
        #10;
    end
    $finish;
end
always #5 aclk = ~aclk;
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave ex2.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule