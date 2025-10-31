module tb;
reg x,y,w,z;
wire f;
circuit modulee(.f(f), .x(x), .y(y), .w(w), .z(z));
initial begin
  x=0;y=0;w=0;z=0;
  #10;
  x=0;y=0;w=0;z=1;
  #10;
  x=0;y=0;w=1;z=0;
  #10;
  x=0;y=0;w=1;z=1;
  #10;
  x=0;y=1;w=0;z=0;
  #10;
  x=0;y=1;w=0;z=1;
  #10;
  x=0;y=1;w=1;z=0;
  #10;
  x=0;y=1;w=1;z=1;
  #10;
  x=1;y=0;w=0;z=0;
  #10;
  x=1;y=0;w=0;z=1;
  #10;
  x=1;y=0;w=1;z=0;
  #10;
  x=1;y=0;w=1;z=1;
  #10;
  x=1;y=1;w=0;z=0;
  #10;
  x=1;y=1;w=0;z=1;
  #10;
  x=1;y=1;w=1;z=0;
  #10;
  x=1;y=1;w=1;z=1;
  #10;
end
initial begin
    $dumpfile("wave.vcd");//  iverilog -o circuit.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule