`timescale 1ns/10ps
`define CYCLE      10.0  
//`define SDFFILE    "./reg_min_syn.sdf"
`define MAX_CYCLE  100

module testfixture;

//`ifdef SDF
//    initial $sdf_annotate(`SDFFILE, u_LASER);
//`endif

//initial begin
//    $fsdbDumpfile("reg_min.fsdb");
//    $fsdbDumpvars();
//    $fsdbDumpMDA;
//end

//initial begin
//    $dumpvars();
//    $dumpfile("reg_min.vcd");
//end

parameter PAT_NUM = 10; // 單組測資長度

//--------------------------------
reg        clk;
reg        rst;
reg  [3:0] num_in;
wire [3:0] num_out;

reg_min u_reg_min (
    .clk     (clk),
    .rst     (rst),
    .num_in  (num_in),
    .num_out (num_out)
);
//--------------------------------
// Clock
always begin #(`CYCLE/2) clk = ~clk; end

// 輸入 pattern 及預期值
reg [3:0] pat_in  [0:PAT_NUM-1];
reg [3:0] pat_out [0:PAT_NUM-1];

// 新增變數 j 用於控制送測資的組數迴圈
integer i, j, err_cnt, out_cnt;
integer cycle_cnt; // 計數現在是第幾個 cycle


//--------------------------------
initial begin
    // 初始化
    clk       = 0;
    rst       = 1;
    num_in    = 0;
    err_cnt   = 0;
    out_cnt   = 0;

    // 載入測資
    pat_in[0]=0; pat_in[1]=1; pat_in[2]=2; pat_in[3]=3; pat_in[4]=4;
    pat_in[5]=5; pat_in[6]=6; pat_in[7]=7; pat_in[8]=8; pat_in[9]=9;

    pat_out[0]=0; pat_out[1]=9; pat_out[2]=6; pat_out[3]=2; pat_out[4]=3;
    pat_out[5]=7; pat_out[6]=1; pat_out[7]=4; pat_out[8]=5; pat_out[9]=8;

    // 系統重置
    #(`CYCLE * 2);
    @(negedge clk) rst = 0; 

    // 一旦 rst 結束，連續送出三組測資
    for (j = 0; j < 3; j = j + 1) begin
        for (i = 0; i < PAT_NUM; i = i + 1) begin
            @(posedge clk); // 正緣送出
            num_in <= pat_in[i]; 
        end
    end
    
    @(posedge clk);
    num_in <= 0; // 測資給完後歸零

    // 額外等待一段時間，讓剩餘兩組的波形能夠完整輸出
    #(`CYCLE * 20); 
    $finish; // 統一在這裡結束模擬
end

//--------------------------------
// 計算執行週期
always @(posedge clk) begin
    if (rst) 
        cycle_cnt <= -1; // 改成 -1，讓 rst 放開後的第一拍剛好是 -1 + 1 = 0
    else begin
        cycle_cnt <= cycle_cnt + 1;
        if (cycle_cnt > `MAX_CYCLE) begin
            $display("****************");
            $display("**  Timeout   **");
            $display("**            **");
            $display("****************");
            //$fclose(fd);
            $finish;
        end
    end
end
//--------------------------------
// verification
always @(negedge clk) begin 
    // 當 cycle_cnt 在 8~17 時取樣輸出 (僅針對第一組進行比對驗證)
    if (!rst && (cycle_cnt >= 8 && cycle_cnt <= 17)) begin
        if (num_out !== pat_out[out_cnt]) begin
            $display("ERROR at cycle %2d: Expected = %d, Got = %d", cycle_cnt, pat_out[out_cnt], num_out);
            err_cnt = err_cnt + 1;
        end else begin
            $display("PASS  at cycle %2d: Output = %d", cycle_cnt, num_out);
        end
        
        out_cnt = out_cnt + 1;

        // 結算第一組的結果
        if (out_cnt == PAT_NUM) begin
            $display("\n========================================");
            if (err_cnt == 0) begin
                $display("       FIRST SET SIMULATION PASSED!     ");
            end else begin
                $display("       FIRST SET SIMULATION FAILED!     ");
                $display("          Total Errors: %d", err_cnt);
            end
            $display("========================================\n");
        end
    end
end

endmodule
