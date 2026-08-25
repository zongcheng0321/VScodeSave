#RTL simulation, pattern1
xrun tb.sv CONVEX.v +define+P1  +access+r -clean -createdebugdb -input xrun.tcl 

#Gate-Level simuation
#xrun tb.sv CONVEX_syn.v +define+SDF  +access+r  -clean -createdebugdb -input xrun.tcl  -v /cad/CBDK/CBDK_IC_Contest_v2.5/Verilog/tsmc13_neg.v -maxdelays
