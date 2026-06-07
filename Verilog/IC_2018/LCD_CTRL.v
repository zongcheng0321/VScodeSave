module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
input clk; // posedge
input reset; // active high
input [3:0] cmd; // 輸入指令訊號 當 cmd_valid "high" and busy "low" 為有效
input cmd_valid;
input [7:0] IROM_Q; // data bus
output reg IROM_rd; // 當為High時，表示 LCD_CTRL 端要向 Host 端索取資料
output reg [5:0] IROM_A; // address bus
output reg IRAM_valid;
output reg [7:0] IRAM_D; // data bus
output reg [5:0] IRAM_A; // address bus
output reg busy; // reset -> high, :當本信號為high時，表示此控制器正在執行現行指令(current)，
//           而無法接受其他新的指令輸入；當本信號為low時，系統會開始輸入指令。
output reg done;


//------------------------------------------------
reg [2:0] state; // for FSM state
localparam INPUT_CMD = 3'd0,
           INPUT_DATA = 3'd1,
           OPERATION = 3'd2,
           READY_INPUT = 3'd4,
           //UPDATE_OP_POSITION = 3'd3,
           OUTPUT = 3'd3;
//------------------------------------------------   
reg [2:0] op_x, op_y; // operation point
wire [5:0] index1; // 操作點對應的四格 pixel 的索引
wire [5:0] index2; // 操作點對應的四格 pixel 的索引
wire [5:0] index3; // 操作點對應的四格 pixel 的索引
wire [5:0] index4; // 操作點對應的四格 pixel 的索引

assign index1 = (op_x - 3'd1) + ((op_y - 3'd1 ) << 3'd3); // if (2,3) -> (1,2) = 左上角那點
assign index2 = index1 + 6'd1;
assign index3 = (op_x - 3'd1) + ((op_y        ) << 3'd3);
assign index4 = index3 + 6'd1;

reg [5:0] count; // for input and output and operation counter, 0 ~ 63
reg [7:0] image [63:0]; 
reg [3:0] cmd_input;
//assign cmd_input = (state == INPUT_CMD)? cmd: cmd_input; 會產生 latch 但我又想鎖住他的值


reg [9:0] temp; // for func. of max and min and average(多寫 2bits)
//------------------------------------------------     
// share 共用項
wire [7:0] cmpValue; // 待比較值 給 max, min 用
assign cmpValue = (count == 0)? image[index2] : 
                  (count == 1)? image[index3] : image[index4];
//------------------------------------------------   
always @(posedge clk or posedge reset) begin
    if (reset) begin
        IROM_A <= 0;
        IROM_rd <= 1'b1; // start ROM data in
        IRAM_valid <= 0;
        IRAM_A <= 0;
        IRAM_D <= 0;
        busy <= 1'b1; // reset default high
        done <= 0;

        op_x <= 3'd4;
        op_y <= 3'd4;
        temp <= 0;
        count <= 6'd0; 
        state <= READY_INPUT;

    end else begin
        case (state)
            READY_INPUT: begin
                IROM_A <= count;
                state <= INPUT_DATA;
            end
            INPUT_DATA: begin
                image[count] <= IROM_Q;
                if (count == 6'd63) begin 
                    busy <= 0; // set low to accept CMD input
                    count <= 0;
                    IROM_rd <= 0;
                    state <= INPUT_CMD;
                end else begin
                    count <= count + 6'd1;
                    state <= READY_INPUT;
                end
            end

            INPUT_CMD: begin
                // wait CMD input
                if (cmd_valid) begin
                    cmd_input <= cmd;
                    temp <= image[index1];  // max, min, average 需要用到
                    count <= 0;             // max, min, average 需要用到
                    busy <= 1'b1; // 拉高開始執行此指令
                    state <= OPERATION;
                end
            end

            OPERATION: begin
                
                case (cmd_input)
                    4'b0: begin // write
                        IRAM_A <= count;
                        IRAM_D <= image[count];
                        IRAM_valid <= 1'b1;
                        state <= OUTPUT;
                    end 

                    4'b1: begin // shift up
                        if (op_y == 3'd1) begin
                            op_y <= op_y;
                        end else begin
                            op_y <= op_y - 3'd1;
                        end
                        busy <= 0;
                        state <= INPUT_CMD;
                    end 

                    4'd2: begin // shift down
                        if (op_y == 3'd7) begin
                            op_y <= op_y;
                        end else begin
                            op_y <= op_y + 3'd1;
                        end
                        busy <= 0;
                        state <= INPUT_CMD;
                    end 

                    4'd3: begin // shift left
                        if (op_x == 3'd1) begin
                            op_x <= op_x;
                        end else begin
                            op_x <= op_x - 3'd1;
                        end
                        busy <= 0;
                        state <= INPUT_CMD;
                    end 

                    4'd4: begin // shift right
                        if (op_x == 3'd7) begin
                            op_x <= op_x;
                        end else begin
                            op_x <= op_x + 3'd1;
                        end
                        busy <= 0;
                        state <= INPUT_CMD;
                    end 

                    4'd5: begin // max
                        case (count)
                            6'd0: begin
                                if (temp <= cmpValue) begin
                                    temp[7:0] <= cmpValue;
                                end
                            end
                            6'd1: begin
                                if (temp <= cmpValue) begin
                                    temp[7:0] <= cmpValue;
                                end 
                            end
                            6'd2: begin
                                if (temp <= cmpValue) begin
                                    temp[7:0] <= cmpValue;
                                end 
                            end
                            6'd3: begin
                                image[index1] <= temp[7:0];
                                image[index2] <= temp[7:0];
                                image[index3] <= temp[7:0];
                                image[index4] <= temp[7:0];
                                count <= 0;
                                busy <= 0;
                                state <= INPUT_CMD;
                            end
                            default:;
                        endcase
                        count <= count + 6'd1;
                    end 

                    4'd6: begin // min
                        case (count)
                            6'd0: begin
                                if (temp >= cmpValue) begin
                                    temp[7:0] <= cmpValue;
                                end
                            end
                            6'd1: begin
                                if (temp >= cmpValue) begin
                                    temp[7:0] <= cmpValue;
                                end 
                            end
                            6'd2: begin
                                if (temp >= cmpValue) begin
                                    temp[7:0] <= cmpValue;
                                end 
                            end
                            6'd3: begin
                                image[index1] <= temp[7:0];
                                image[index2] <= temp[7:0];
                                image[index3] <= temp[7:0];
                                image[index4] <= temp[7:0];
                                count <= 0;
                                busy <= 0;
                                state <= INPUT_CMD;
                            end
                            default:;
                        endcase
                        count <= count + 6'd1;
                    end 

                    4'd7: begin // average
                        case (count)
                            6'd0: begin // temp 可能會溢位，所以要多 2 bits
                                temp <= ((image[index1] + image[index2]) + (image[index3] + image[index4])) >> 10'd2;
                            end
                            6'd1: begin
                                image[index1] <= temp[7:0];
                                image[index2] <= temp[7:0];
                                image[index3] <= temp[7:0];
                                image[index4] <= temp[7:0];
                                count <= 0;
                                busy <= 0;
                                state <= INPUT_CMD;
                            end
                            default:;
                        endcase
                        count <= count + 6'd1;
                    end 
                    
                    4'd8: begin // Counterclockwise Rotation
                        image[index1] <= image[index2];
                        image[index2] <= image[index4];
                        image[index3] <= image[index1];
                        image[index4] <= image[index3];
                        busy <= 0;
                        state <= INPUT_CMD;
                    end 

                    4'd9: begin // clockwise Rotation
                        image[index1] <= image[index3];
                        image[index2] <= image[index1];
                        image[index3] <= image[index4];
                        image[index4] <= image[index2];
                        busy <= 0;
                        state <= INPUT_CMD;
                    end 

                    4'd10: begin // Mirror X
                        image[index1] <= image[index3];
                        image[index2] <= image[index4];
                        image[index3] <= image[index1];
                        image[index4] <= image[index2];
                        busy <= 0;
                        state <= INPUT_CMD;
                    end 

                    4'd11: begin // Mirror Y
                        image[index1] <= image[index2];
                        image[index2] <= image[index1];
                        image[index3] <= image[index4];
                        image[index4] <= image[index3];
                        busy <= 0;
                        state <= INPUT_CMD;
                    end 


                    default: state <= OUTPUT; // for debug
                endcase
            end

            OUTPUT: begin
                //IRAM_D <= image[count];
                if (count == 6'd63) begin 
                    busy <= 0;
                    count <= 0;
                    done <= 1'd1;
                end else begin
                    count <= count + 6'd1;
                    state <= OPERATION;
                end
            end

            default: ;
        endcase
    end
end
endmodule