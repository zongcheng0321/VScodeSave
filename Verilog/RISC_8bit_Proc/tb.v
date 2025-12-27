`timescale 1ns/1ns

module tb;

    reg clk, rst, ewr;
    reg [4:0] ead;
    reg [7:0] edat;
    wire zr;

    topmodule u_cpu (.clk(clk), .rst(rst), .ewr(ewr), .ead(ead), .edat(edat), .zr(zr));

    // 產生時脈 T = 20ns
    always #10 clk = ~clk;

    initial begin
        // 初始化
        clk = 0; rst = 0; ewr = 0; ead = 0; edat = 0;
/*
        // --- 顯示監控 ---
        $display("------------------------------------------------------------------");
        $display("Time\t PC\t Op\t Instr\t ACC\t ZR\t JMP\t Bus");
        $display("------------------------------------------------------------------");
        // 為了方便閱讀，我這裡做了一個簡單的 OpCode 文字轉換
        $monitor("%d\t %d\t %b\t %s\t %h\t %b\t %s\t %h", 
                 $time, u_cpu.adpc, u_cpu.opcd, 
                 (u_cpu.opcd==3'b101)?"LDA":
                 (u_cpu.opcd==3'b010)?"ADD":
                 (u_cpu.opcd==3'b011)?"AND":
                 (u_cpu.opcd==3'b100)?"XOR":
                 (u_cpu.opcd==3'b110)?"STO":
                 (u_cpu.opcd==3'b111)?"JMP":
                 (u_cpu.opcd==3'b001)?"SKZ":"HLT",
                 u_cpu.acc_out, zr, 
                 (u_cpu.ldpc)?"YES":"   ", u_cpu.mdat);
*/
        #10;
        // 燒入開始
        // 燒入到的記憶體位址 : 要做的事(Addr + Op)
        // 00: LDA 20 -> 10100(20) + 101(LDA) = A5
        ewr=1; ead=5'd00; edat=8'hA5; #20;
        
        // 01: XOR 20 -> 10100(20) + 100(XOR) = A4
        ewr=1; ead=5'd01; edat=8'hA4; #20;
        
        // 02: SKZ    -> 00000(0)  + 001(SKZ) = 01
        ewr=1; ead=5'd02; edat=8'h01; #20;
        
        // 03: JMP 00 -> 00000(0)  + 111(JMP) = 07 (陷阱)
        ewr=1; ead=5'd03; edat=8'h07; #20;
        
        // 04: ADD 21 -> 10101(21) + 010(ADD) = AA
        ewr=1; ead=5'd04; edat=8'hAA; #20;
        
        // 05: AND 22 -> 10110(22) + 011(AND) = B3
        ewr=1; ead=5'd05; edat=8'hB3; #20;
        
        // 06: JMP 08 -> 01000(8)  + 111(JMP) = 47
        ewr=1; ead=5'd06; edat=8'h47; #20;
        
        // 07: STO 31 -> 11111(31) + 110(STO) = FE (陷阱)
        ewr=1; ead=5'd07; edat=8'hFE; #20;
        
        // 08: STO 30 -> 11110(30) + 110(STO) = F6 (成功)
        ewr=1; ead=5'd08; edat=8'hF6; #20;
        
        // 09: HLT    -> 00
        ewr=1; ead=5'd09; edat=8'h00; #20;

        // 存放資料(數值)
        // 20: 0x0F
        ewr=1; ead=5'd20; edat=8'h0F; #20;
        // 21: 0x55
        ewr=1; ead=5'd21; edat=8'h55; #20;
        // 22: 0x05
        ewr=1; ead=5'd22; edat=8'h05; #20;

        ewr = 0; // 燒錄結束

        // 啟動 CPU 
        #50;
        //$display(">>> CPU RESET RELEASED <<<");
        rst = 1;
        // 給 2500ns 執行
        #2500; 
/*
        // --- Step 4: 自動驗收結果 ---
        $display("------------------------------------------------------------------");
        $display(">>> TEST REPORT <<<");
        
        // 檢查位址 30 的值 (預期是 05)
        if (u_cpu.u_memory.memr[30] === 8'h05) 
            $display("✅ FINAL RESULT: SUCCESS! (Addr 30 = 05)");
        else 
            $display("❌ FINAL RESULT: FAIL! (Addr 30 = %h, Expected 05)", u_cpu.u_memory.memr[30]);

        // 檢查是否誤觸陷阱 (位址 31 應該要是 0 或初始值，不能被寫入)
        // 假設 RAM 初始全 0
        if (u_cpu.u_memory.memr[31] !== 8'h00) 
            $display("❌ WARNING: Trap executed! (Addr 31 was written)");
        else
            $display("✅ FLOW CONTROL: Trap avoided correctly.");
*/
        $stop;
    end
endmodule