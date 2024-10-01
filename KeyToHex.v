module KeyToHex (

	input [7:0] hex_input,
	output [6:0] hex_display
	);
	
	always @* begin
        case(hex_input)
				2'h0: hex_display = 7'b1111110; //  output A
            2'h1: hex_display = 7'b0110000; //  output B
            2'h2: hex_display = 7'b1101101; //  output C
            2'h3: hex_display = 7'b1111001; //  output D
            2'h4: hex_display = 7'b0110011; //  output E
            2'h5: hex_display = 7'b1011011; //  output F
				default: hex_display = 7'b0000000;
			end case
	end
endmodule 
