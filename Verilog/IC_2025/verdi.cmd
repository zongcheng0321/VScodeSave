#RTL simulation
verdi -sverilog tb.sv CONVEX.v.v -ssf CONVEX.v.fsdb

#Gate-Level simuation
#verdi -sverilog tb.sv CONVEX.v_syn.v -v /cad/CBDK/CBDK_IC_Contest_v2.5/Verilog/tsmc13_neg.v -ssf CONVEX.v.fsdb
