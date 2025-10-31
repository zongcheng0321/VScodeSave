module fullsub (
 input x,y,z,
 output d,b
);
assign d=((~x & ~y & z)|(~x & y & ~z)|(x & ~y & ~z)|(x & y & z));
assign b=((~x & y)|(~x & z)|(y & z));
endmodule