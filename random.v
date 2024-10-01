// Random module //
module random (input CLOCK_50, input [3:0] seed, output [3:0] store4Out, output [1:0] out);
	wire [7:0] store8Out;
	wire [1:0] store2Out1, store2Out2;
	
	// square number
	ALU A1 (seed, 0, 3'b010, store8Out);
	
	// divide by 100
	ALU A2 (store8Out[3:0], 100, 3'b011, store2Out1);
	
	// modulus 100
	ALU A3 (store8Out[7:4], 100, 3'b100, store2Out2);
	
	assign store4Out = store2Out1 + (store2Out2 * 100);
	
	assign out = store4Out[1:0];
	
endmodule
