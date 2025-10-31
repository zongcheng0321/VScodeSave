module tb;
reg x,y,w,z;
wire f;
circuit2 modulee(.f(f), .x(x), .y(y), .w(w), .z(z));
initial begin
    for(integer i=0;i<=1;i=i+1)
    begin
        for(integer j=0;j<=1;j=j+1)
        begin
            for(integer k=0;k<=1;k=k+1)
            begin
                for(integer l=0;l<=1;l=l+1)
                begin
                    x=i;
                    y=j;
                    w=k;
                    z=l;
                    #10;
                end
            end
        end
    end
    $finish;
end
initial begin
    $dumpfile("wave.vcd");//  iverilog circuit2.v tb.v
    $dumpvars(0, tb); // vvp wave
end
endmodule