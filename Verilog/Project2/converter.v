module converter(
   input [11:0] in, // input 12bit -> max value = 4095
   output reg [15:0] bcd // result from 4095 -> need 4 digits -> 16bits bcd
   );

wire [14:0] bin = {2'b0,in}; // add leading zeros to the first 2 digits

always @(bin) begin
    bcd=0;		 	
    for (integer i=0;i<14;i=i+1) begin					//Iterate once for each bit in input number
        if (bcd[3:0] >= 5) bcd[3:0] = bcd[3:0] + 3;		//If any BCD digit is >= 5, add three
        if (bcd[7:4] >= 5) bcd[7:4] = bcd[7:4] + 3;
        if (bcd[11:8] >= 5) bcd[11:8] = bcd[11:8] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        bcd = {bcd[14:0],bin[13-i]};				//Shift one bit, and shift in proper bit from input 
    end
end
endmodule