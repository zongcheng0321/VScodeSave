#RTL simulation, pattern1
vcs -R -sverilog tb.sv CONVEX.v +define+P1 +access+r +vcs+fsdbon +fsdb+mda +fsdbfile+CONVEX.fsdb 

#Gate-Level simuation
#vcs -R -sverilog tb.sv CONVEX_syn.v +define+SDF +access+r +vcs+fsdbon +fsdb+mda +fsdbfile+CONVEX.fsdb -v /cad/CBDK/CBDK_IC_Contest_v2.5/Verilog/tsmc13_neg.v +maxdelays +neg_tchk
