`timescale 1ns/10ps
`define CYCLE      8.0  
`define SDFFILE    "./CONVEX_syn.sdf"
`define MAX_CYCLE  10000
`define USECOLOR

//`define P2

typedef struct {
    reg [9:0] X = 10'b0;
    reg [9:0] Y = 10'b0;
} PX ;
typedef struct {
    int ID = -1;
    PX  IN ;
    PX BOUND [0:11] ;
    reg [0:11] BOUNDV  = 12'b0;
    PX DROP  [0:10] ;
    reg [0:11] DROPV  = 12'b0;
} pxbound;

module testfixture();
integer fd;
string line;
integer patnum;


integer objnum;
integer obj_isin;
integer charcount;
integer pass=0;
integer fail=0;
reg CLK= 0;
reg RST =0;
reg [4:0] PT_XY;
wire READ_PT;
wire [9:0] DROP_X;
wire [9:0] DROP_Y;
wire DROP_V;

wire valid;
wire is_inside;
CONVEX u_CONVEX(.CLK(CLK),
        .RST(RST),
        .PT_XY(PT_XY),
        .READ_PT(READ_PT),
        .DROP_X(DROP_X),
        .DROP_Y(DROP_Y),
        .DROP_V(DROP_V));

`ifdef SDF
    initial $sdf_annotate(`SDFFILE, u_CONVEX);
`endif

always begin #(`CYCLE/2) CLK = ~CLK; end

//initial begin
//    $fsdbDumpfile("CONVEX.fsdb");
//    $fsdbDumpvars();
//    $fsdbDumpMDA;
//end

initial begin
    $dumpfile("CONVEX.vcd");
    $dumpvars;
end

`ifdef P2
    string PATNAME = "convex_p2.dat";
`elsif P3
    string PATNAME = "convex_p3.dat";
`else
    string PATNAME = "convex_p1.dat";
`endif

initial begin
    $timeformat(-9,2,"ns",20);
end


initial begin
    $display("----------------------");
    $display("-- Simulation Start --");
    $display("----------------------");
    RST = 1'b1; 
    #(`CYCLE*2);  
    @(posedge CLK);  #1  RST = 1'b0;
end

reg [22:0] cycle=0;
string firstword;
//reg [8:0] pointid;
reg [9:0] ix;
reg [9:0] iy;
pxbound PAT [100] ;
reg signed [7:0] PTWIDROP [100] ;
reg [7:0] PTWIDROP_idx;
int i;
int j;
reg[3:0] boundid;
reg[3:0] dropid;
int pointid = 0;
reg [9:0] total_failed_points;
int point_total=0;
initial begin
    fd = $fopen(PATNAME,"r");
    if (fd == 0) begin
        $display ("Failed read pattern: %s",PATNAME);
        $finish;
    end
    else begin
        foreach (PTWIDROP[i]) PTWIDROP[i] = -1;
        PTWIDROP_idx =1;
        while (!$feof(fd)) begin
            charcount = $fgets (line, fd);
            if (charcount == 0) continue;
            if (charcount == 1) continue;
            if (line.substr(0, 1) == "//") continue;
            if (line.substr(0, 0) == "#") continue;

            if (line.substr(0,0) == "A") begin
                if(pointid>=1) begin
                    if(|PAT[pointid].DROPV) begin
                        PTWIDROP[PTWIDROP_idx] = pointid;
                        PTWIDROP_idx = PTWIDROP_idx +1;
                    end
                end
                pointid = pointid +1;
                charcount = $sscanf(line, "A %d %d",ix,iy);
                //$display ("Get point, %d, (%4d,%4d)", pointid,ix,iy);
                PAT[pointid].IN = '{ix,iy};
                PAT[pointid].ID=pointid;
                boundid = 0;
                dropid = 0;
                point_total = point_total +1;
            end
            else if (line.substr(0,0) == "C") begin
                charcount = $sscanf(line, "C %d %d",ix,iy);
                //$display ("Get bound, (%4d,%4d)", ix,iy);
                PAT[pointid].BOUND[boundid] = '{ix,iy};
                PAT[pointid].BOUNDV[boundid] = 1'b1;
                boundid=boundid+1;
            end
            else if (line.substr(0,0) == "R") begin
                charcount = $sscanf(line, "R %d %d",ix,iy);
                //$display ("Get drop , (%4d,%4d)", ix,iy);
                PAT[pointid].DROP[dropid] = '{ix,iy};
                PAT[pointid].DROPV[dropid] = 1'b1;
                dropid=dropid+1;
            end
            else begin
                $display ("UNDEFINE KEYWORD , %s", line);
            end
        end
        $fclose(fd);
        if(|PAT[pointid].DROPV) begin
            PTWIDROP[PTWIDROP_idx] = pointid;
        end
        PTWIDROP_idx = 1;
        /* display input pattern
        foreach (PAT[i])  begin
            if (PAT[i].ID == -1 ) continue;
            $display ("point%3d, (%4d,%4d)", i, PAT[i].IN.X, PAT[i].IN.Y);
            if (|PAT[i].BOUNDV) begin
                $write ("  bound ");
                foreach (PAT[i].BOUND[j])  begin
                    if (PAT[i].BOUNDV[j] == 1) begin
                        if (j>0) $write (",");
                        $write ("(%4d,%4d)", PAT[i].BOUND[j].X, PAT[i].BOUND[j].Y);
                    end
                end
                $write ("\n");
            end
            //$display ("  boundv %b",PAT[i].BOUNDV) ;
            if (|PAT[i].DROPV)  begin
            //if (PTWIDROP[PTWIDROP_idx] == PAT[i].ID)  begin
                $write ("  drop  ");
                foreach (PAT[i].DROP[j])  begin
                    if (PAT[i].DROPV[j] == 1) begin
                        if (j>0) $write (",");
                        $write ("(%4d,%4d)", PAT[i].DROP[j].X, PAT[i].DROP[j].Y);
                    end
                end
                $write ("\n");
                //PTWIDROP_idx = PTWIDROP_idx +1;
            end
            //$display ("  dropv %b",PAT[i].DROPV) ;
        end
        */
    end
end

reg [7:0] READ_PT_num;
reg [2:0] READ_PT_count;
always @(posedge CLK) begin
    if (RST) begin
        READ_PT_count <=3'b0;
        READ_PT_num <=3'b0;
    end
    else begin
        if (READ_PT_count <= 1) begin
            if (READ_PT == 1) begin
                if (PAT[READ_PT_num+1].ID >=0) begin
                    #1
                    READ_PT_num <= PAT[READ_PT_num+1].ID;
                    READ_PT_count <= 4;
                    `ifdef USECOLOR
                        $display ("%10t , %c[0;34mAdd POINT %2d (%d,%d)%c[0m in 4 cycles",$time,27,READ_PT_num+1,PAT[READ_PT_num+1].IN.X,PAT[READ_PT_num+1].IN.Y,27);
                    `else
                        $display ("%10t , Add POINT %2d (%d,%d) in 4 cycles",$time,READ_PT_num+1,PAT[READ_PT_num+1].IN.X,PAT[READ_PT_num+1].IN.Y);
                    `endif
                    if (|PAT[READ_PT_num+1].DROPV)  begin
                        $write ("               - Expect Drop:");
                        foreach (PAT[READ_PT_num+1].DROP[j])  begin
                            if (PAT[READ_PT_num+1].DROPV[j] == 1) begin
                                if (j>0) $write (",");
                                $write ("(%4d,%4d)", PAT[READ_PT_num+1].DROP[j].X, PAT[READ_PT_num+1].DROP[j].Y);
                            end
                        end
                        $write ("\n");
                    end 
                    else begin
                        $display ("               - Expect Drop: None");
                    end
                end
            end
            else begin
                READ_PT_count <=0;
            end
        end
        else #1 READ_PT_count <= READ_PT_count - 1;
    end
end

always @(*) begin
    case (READ_PT_count)
        3'd4: PT_XY = PAT[READ_PT_num].IN.X[9:5];
        3'd3: PT_XY = PAT[READ_PT_num].IN.X[4:0];
        3'd2: PT_XY = PAT[READ_PT_num].IN.Y[9:5];
        3'd1: PT_XY = PAT[READ_PT_num].IN.Y[4:0];
        default: PT_XY = 5'b0 ;
    endcase
end

int match_drop;
always @(posedge CLK ) begin
    if (RST) PTWIDROP_idx<=8'b1;
    else begin
        total_failed_points= point_total - PTWIDROP[PTWIDROP_idx] +1;
        if (DROP_V == 1) begin
            if(PTWIDROP[PTWIDROP_idx] > READ_PT_num) begin
                `ifdef USECOLOR
                    $display ("%10t , %c[1;31mGet DROP point (%d,%d)%c[0m, Wrong, Expect:NONE",$time,27,DROP_X,DROP_Y,27);
                `else
                    $display ("%10t , Get DROP point (%d,%d), Wrong, Expect:NONE",$time,DROP_X,DROP_Y);
                `endif

                $display ("\n-------------------------------------------------");
                $display ("-- Simulation Failed");
                $display ("-- Failed at POINT %d", PTWIDROP[PTWIDROP_idx]);
                $display ("-- Total Failed points: %0d", total_failed_points);
                $display ("-------------------------------------------------");
                $finish;
            end
            else begin
                match_drop = 0;
                foreach (PAT[PTWIDROP[PTWIDROP_idx]].DROP[j])  begin
                    if ((PAT[PTWIDROP[PTWIDROP_idx]].DROPV[j]==1)&&(DROP_X == PAT[PTWIDROP[PTWIDROP_idx]].DROP[j].X) && (DROP_Y == PAT[PTWIDROP[PTWIDROP_idx]].DROP[j].Y)) begin
                        PAT[PTWIDROP[PTWIDROP_idx]].DROPV[j] = 0;
                        `ifdef USECOLOR
                        $display ("%10t , %c[0;32mGet DROP point (%d,%d)%c[0m, Correct",$time,27,DROP_X,DROP_Y,27);
                        `else
                        $display ("%10t , Get DROP point (%d,%d), Correct",$time,DROP_X,DROP_Y);
                        `endif
                        match_drop = 1;
                    end
                end
                if (match_drop == 1) begin
                    if (|PAT[PTWIDROP[PTWIDROP_idx]].DROPV==0) begin
                        PTWIDROP_idx = PTWIDROP_idx + 1;
                        if (PTWIDROP[PTWIDROP_idx] == -1 ) begin
                            $display ("\n-------------------------------------------------");
                            $display ("-- Congratulation! Simulation completed");
                            //$display ("-- Total points:%0d , failed points: %0d", point_total,total_failed_points-1);
                            $display ("-- Total points:%0d , failed points: 0", point_total);
                            $display ("-- Total Simulation CYCLE %0d",cycle);
                            $display ("-------------------------------------------------\n");
                            $finish;
                        end

                    end
                end
                else begin
                    `ifdef USECOLOR
                        $write ("%10t , %c[1;31mGet DROP point (%d,%d)%c[0m, Wrong, Expect:",$time,27,DROP_X,DROP_Y,27);
                    `else
                        $write ("%10t , Get DROP point (%d,%d), Wrong, Expect:",$time,DROP_X,DROP_Y);
                    `endif
                    foreach (PAT[PTWIDROP[PTWIDROP_idx]].DROP[j])  begin
                        if (PAT[PTWIDROP[PTWIDROP_idx]].DROPV[j] == 1) begin
                            $write (" (%4d,%4d)", PAT[PTWIDROP[PTWIDROP_idx]].DROP[j].X, PAT[PTWIDROP[PTWIDROP_idx]].DROP[j].Y);
                        end
                    end
                    $write ("\n");
                    $display ("\n-------------------------------------------------");
                    $display ("-- Simulation Failed at cycle %0d (time %0t)",cycle,$time);
                    $display ("-- Failed at POINT %0d", PTWIDROP[PTWIDROP_idx]);
                    $display ("-- Total Failed points: %0d", total_failed_points);
                    $display ("-------------------------------------------------");
                    $finish;
                end
            end
        end
    end
end

reg [7:0] ERROR_PT_ID;
always @(posedge CLK) begin
    cycle=cycle+1;
    if (cycle > `MAX_CYCLE) begin
        ERROR_PT_ID = PTWIDROP[PTWIDROP_idx];
        if (ERROR_PT_ID > READ_PT_num ) ERROR_PT_ID = READ_PT_num;
        if (ERROR_PT_ID == 0) ERROR_PT_ID =1;
        total_failed_points= point_total - ERROR_PT_ID +1;
        $display("--------------------------------------------------");
        $display("-- MAX_CYCLE %d reached, Simulation STOP ", `MAX_CYCLE);
        $display("-- You can modify MAX_CYCLE in tb.v if necessary.");
        $display("-- Failed at POINT %d",ERROR_PT_ID);
        $display("-- Total Failed points: %0d",total_failed_points);
        $display("--------------------------------------------------");
        $fclose(fd);
        $finish;
    end
end

endmodule
