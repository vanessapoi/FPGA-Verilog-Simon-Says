// ALU module //
module ALU (input [7:0] operandA, input [7:0] operandB, input [3:0] select, output [7:0] out);
    
	reg [7:0] result;

	always @(*) begin
	  case(select)
			4'b0000: // Addition
				 result <= operandA + operandB; 
			4'b0001: // Subtraction
				 result <= operandA - operandB;
			4'b0010: // Square
				 result <= operandA * operandA;
			4'b0011: // Divisions
				 if (operandB != 0)
					  result <= operandA / operandB;
			4'b0100: // Modulus
				 if (operandB != 0)
					  result <= operandA % operandB;
			default: result <= operandA + operandB; 
	  endcase

	  while (result > 8'b11111111) begin
			result = result / 2'b10;
	  end
	end

	assign out = result;

endmodule
