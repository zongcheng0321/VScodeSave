module full_sub_tb; 
reg x,y,z;
wire d,b;
fullsub f(.d(d), .b(b), .x(x), .y(y), .z(z));
initial 
begin
    x=0;y=0;z=0;
    #10;
    x=0;y=0;z=1;
    #10;
    x=0;y=1;z=0;
    #10;
    x=0;y=1;z=1;
    #10;
    x=1;y=0;z=0;
    #10;
    x=1;y=0;z=1;
    #10;
    x=1;y=1;z=0;
    #10;
    x=1;y=1;z=1;
    #10;
end
initial begin
    $dumpfile("wave.vcd"); //  iverilog -o wave full_sub_dataflow.v tb_dataflow.v
    $dumpvars(0, full_sub_tb); // vvp wave
end
endmodule