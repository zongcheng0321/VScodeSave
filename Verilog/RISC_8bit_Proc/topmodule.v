module topmodule(clk, rst, ewr, ead, edat, zr);
input  clk;         
input  rst;         
input  ewr;         // 外部寫入致能 (燒錄程式用)
input  [4:0] ead;   // 外部地址 (燒錄程式用)
input  [7:0] edat;  // 外部資料 (燒錄程式用)
output zr;          // Zero Flag (除錯用，拉出來看燈有沒有亮)

// clkgen Output
wire clk1, clk2, fch; 

// 控制訊號 (來自 Decoder Output)
wire ldac, ldir, mrd, mwr, ldpc, pclk, aclk;

// 資料匯流排
wire [7:0] alu_out, acc_out;
wire [7:0] mdat;    // 雙向資料線
wire [2:0] opcd;    // OpCode

// 地址匯流排
wire [4:0] adir;     // 來自 IR 的地址
wire [4:0] adpc;     // 來自 PC 的地址
wire [4:0] addr_out; // MUX 選完後送給 Memory 的地址

// 只有在寫入記憶體 (mwr = 1) 時，CPU 才會把 ACC 的值給匯流排
assign mdat = (mwr) ? acc_out : 8'bz;

// clkgen
clkgen u_clkgen (
    .clk(clk),     // 外部輸入
    .rst(rst), 
    .clk1(clk1),   // 產生的主時脈 (給 CPU 用) 但其實 clk 就等於 clk1
    .clk2(clk2), 
    .fch(fch)
);

// pc
pc u_pc (
    .pclk(pclk),   // Decoder 產生的 pclk
    .rst(rst), 
    .ldpc(ldpc),   // JMP 載入訊號
    .adir(adir),   // JMP 目標地址 (來自 IR)
    .adpc(adpc)     // 輸出：目前的 PC 值
);

// ir
ir u_ir (
    .clk(clk1),    // 使用主時脈
    .rst(rst), 
    .ldir(ldir), 
    .mdat(mdat),   // 讀取記憶體指令
    .opcd(opcd),   // 輸出：OpCode 給 Decoder
    .adir(adir)    // 輸出：地址給 PC 和 MUX
);

// mux
// 決定記憶體地址是來自 PC (Fetch) 還是 IR (Execute)
mux2_1 u_mux (
    .adir(adir),      // IR 地址
    .adpc(adpc),      // PC 地址
    .fch(fch),     // fch=1 選 PC, fch=0 選 IR
    .addr_out(addr_out)   // 輸出給 Memory
);

// memory
memory u_memory (
    .clk(clk1),    // 寫入需同步
    .rst(rst), 
    .mrd(mrd), 
    .mwr(mwr), 
    .ewr(ewr),     // 外部寫入開關
    .mad(addr_out),// CPU 地址 (來自 MUX)
    .ead(ead),     // 外部地址
    .edat(edat),   // 外部資料
    .mdat(mdat)    // 雙向資料匯流排
);

// ALU
alu u_alu (
    .mdat(mdat),      // 運算元 1
    .acc_out(acc_out),// 運算元 2
    .opcd(opcd), 
    .alu_out(alu_out),// 結果輸出
    .zr(zr)           // Zero Flag
);

// accumulator
accumulator u_acc (
    .aclk(aclk),      // 使用 Decoder 的 aclk (000 -> 100 正緣觸發)
    .rst(rst), 
    .ldac(ldac), 
    .alu_out(alu_out), 
    .acc_out(acc_out)
);

// decoder
decoder u_decoder (
    .clk1(clk1), 
    .clk2(clk2), 
    .fch(fch), 
    .rst(rst),
    .opcd(opcd), 
    .zr(zr),          // 接收 ALU 的 Zero Flag (給 SKZ 用)
    .ldir(ldir), 
    .ldac(ldac), 
    .mrd(mrd), 
    .mwr(mwr), 
    .ldpc(ldpc), 
    .pclk(pclk), 
    .aclk(aclk)       // 產生 aclk 給 ACC
);
endmodule