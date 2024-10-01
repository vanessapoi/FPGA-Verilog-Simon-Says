// Main module //

module main(input CLOCK_50, AUD_ADCDAT, input [3:0] KEY, SW, inout PS2_CLK, PS2_DAT, AUD_BCLK, AUD_ADCLRCK, AUD_DACLRCK, FPGA_I2C_SDAT,
				output [7:0] LEDR, output [6:0] HEX0, HEX2, HEX3, output AUD_XCK, AUD_DACDAT, FPGA_I2C_SCLK);


//----------------------------------------------------------- Variable Declarations -----------------------------------------------------------//
	
	// key variables //
	wire reset = ~KEY[0]; //CHANGE TO ~KEY[0] FOR BOARD TESTING// 
	wire ready = ~KEY[3]; //CHANGE TO ~KEY[3] FOR BOARD TESTING// 
	
	
	// switch variables //
	// wire [3:0] playerMove = SW[3:0];
	reg [1:0] tempMoveStore;
	reg [1:0] moveStore;
					
	
	// keyboard variables //
	wire [7:0] ps2_key_data;
	wire ps2_key_pressed;
	reg [7:0] last_data_received;
	reg keyReset;
	
	
	// LED variables //
	reg [7:0] ledrWire;
	assign LEDR[7:0] = ledrWire[7:0];
	
	
	// timer variables //
	localparam timerInitValue = 100000000;
	reg [28:0] timer;
	reg timerReset, timerEnable, timerResetQuick; // reset timer, set timer to 1 sec, set timer to 2 clock cycles
	
	
	// move counter variables //
	reg [5:0] moveCounter;// counts number of moves played by user in current round
	reg moveCounterReset, moveCounterEnable;
	reg [5:0] numMoves; // how many moves are currently in sequence - can go up to 63
	reg [5:0] moveCounterStore;
	
	
	// score variables //
	reg [5:0] score;
	reg [5:0] highScore;
	reg [7:0] highScoreName;
	
	
	// sequence variables //
	reg [1:0] sequence [0:62];
	reg sequenceReset, sequenceEnable;
	reg [1:0] randomNum, expectedMove;
	reg randomReset, randomEnable;
	// reg [3:0] seed = 4'b0001;
	
	
	// FSM variables //
	localparam welcome = 4'b0000, randomize = 4'b0001, printListenInstructions = 4'b0010, playSequence = 4'b0011, pause = 4'b0100, 
				  printPlayerInstructions = 4'b0101, playerInHigh = 4'b0110, playerInLow = 4'b0111, checkIn = 4'b1000, wonRound = 4'b1001,
				  scoreCalc = 4'b1010, lost = 4'b1011, inputUsername = 4'b1100, leaderboardUpdate = 4'b1101, leaderboardPrint = 4'b1110;
	reg [3:0] currentState, nextState;
	
	
	// test variables //
	reg [3:0] outNum;
	integer i;
	
	
	// audio variables //
	reg audio_in_available;
	reg [31:0] left_channel_audio_in;
	reg [31:0] right_channel_audio_in;
	reg read_audio_in;

	reg audio_out_allowed;
	reg [31:0] left_channel_audio_out;
	reg [31:0] right_channel_audio_out;
	reg write_audio_out;
	reg [7:0] data_received;

	reg [18:0] delay_cnt;
	reg [18:0] delay;

	reg snd;

	reg [22:0] beatCount;
	reg [9:0] address; 
	
	reg [2:0] audio_select;
	
	reg [17:0] win_audio_data [0:869];
	reg [17:0] SW0_audio_data [0:869];
	reg [17:0] SW1_audio_data [0:869];
	reg [17:0] SW2_audio_data [0:869];
	reg [17:0] SW3_audio_data [0:869];
	reg [17:0] lose_audio_data [0:869];
	



	
//------------------------------------------------------------------ Controls -----------------------------------------------------------------//

	// control state registers
	always @(posedge CLOCK_50) begin
		if(reset) begin
			currentState <= welcome;
		end
		
		else begin
			currentState <= nextState;
		end
	end
	
	
	// control timer
	always @(posedge CLOCK_50) begin
		if (timerReset) begin
			timer <= timerInitValue;
		end
		
		else if (timerResetQuick) begin
			timer <= 2;
		end
		
		else if (timerEnable) begin 
			timer <= timer - 1; // change to timer to 100000000 when modelsimming, 1 when testing on board
		end
	end
	
	
	// control moveCounter
	always @(posedge CLOCK_50) begin
		if (moveCounterReset) begin
			moveCounter <= 0;
		end
		
		else if (moveCounterEnable) begin
			moveCounter <= moveCounter + 1;
		end
	end
	
	
	// random number generator
	always @(posedge CLOCK_50) begin
		if (randomReset) begin
			randomNum <= 0;
		end
		
		else if (randomEnable) begin
			randomNum <= 1; //$urandom_range(4);
		end
	end
	
	
	// random seed generator
	//always @(posedge CLOCK_50) begin
	//	if (randomReset) begin
	//		seed <= 0;
	//	end
	//	
	//	else if (randomEnable) begin
	//		if (seed <= 8'b1110) begin
	//			seed <= seed + 1;
	//		end
	//		if (seed > 8'b1110) begin
	//			seed <= seed - 8'b1110;
	//		end
	//	end
	//end
	
	
	// control sequence
	always @(posedge CLOCK_50) begin
		if (sequenceReset) begin
			for (i = 0; i <= 62; i = i + 1) begin
				sequence[i] <= 0;
			end 
		end
		
		if (sequenceEnable && (currentState == randomize)) begin
			sequence[numMoves - 1] <= randomNum;
		end
	end
	
	
	// control keyboard data
	always @(posedge CLOCK_50) begin
		if (keyReset) begin
			last_data_received <= 8'h00;
		end
		else if (ps2_key_pressed == 1) begin
			last_data_received <= ps2_key_data;
		end
	end
	
	
	// control audio
	always @(posedge CLOCK_50) begin
		if(delay_cnt == delay) begin
			delay_cnt <= 0;
			snd <= !snd;
		end else delay_cnt <= delay_cnt + 1;
	end
	
	initial begin
		$readmemb("win.mif", win_audio_data);
		$readmemb("SW0.mif", SW0_audio_data);
		$readmemb("SW1.mif", SW1_audio_data);
		$readmemb("SW2.mif", SW2_audio_data);
		$readmemb("SW3.mif", SW3_audio_data);
		$readmemb("lose.mif", lose_audio_data);
	end

	always @(posedge CLOCK_50) begin
		if(beatCount == 23'b10011000100101101000000)begin // length of mif fail
			beatCount <= 23'b0;
			if(address < 10'd999)
				address <= address + 1;
			else begin
				address <= 0;
				beatCount <= 0;
			end
		end
		else 
			beatCount <= beatCount + 1;
	end
	
	wire [31:0] sound = snd ? 32'd100000000 : -32'd100000000;

	read_audio_in = audio_in_available & audio_out_allowed;
	left_channel_audio_out = left_channel_audio_in+sound;
	right_channel_audio_out = left_channel_audio_in+sound;
	write_audio_out = audio_in_available & audio_out_allowed;
	
	always @(posedge CLOCK_50) begin
		if (audio_out_allowed) begin
			// welcome and win sound
			if (audio_select == 0) begin
				left_channel_audio_out <= win_audio_data[address];
				right_channel_audio_out <= win_audio_data[address];
			end
			// SW[0]
			if (audio_select == 1) begin
				left_channel_audio_out <= SW0_audio_data[address];
				right_channel_audio_out <= SW0_audio_data[address];
			end
			// SW[1]
			if (audio_select == 2) begin
				left_channel_audio_out <= SW1_audio_data[address];
				right_channel_audio_out <= SW1_audio_data[address];
			end
			// SW[2]
			if (audio_select == 3) begin
				left_channel_audio_out <= SW2_audio_data[address];
				right_channel_audio_out <= SW2_audio_data[address];
			end
			// SW[3]
			if (audio_select == 4) begin
				left_channel_audio_out <= SW3_audio_data[address];
				right_channel_audio_out <= SW3_audio_data[address];
			end
			// lose sound
			if (audio_select == 5) begin
				left_channel_audio_out <= lose_audio_data[address];
				right_channel_audio_out <= lose_audio_data[address];
			end
		end
	end

					  
//----------------------------------------------------------- Module Instantiations -----------------------------------------------------------//

	hexdecoder H1(.c(outNum), .display(HEX0));
	
	PS2_Controller PS2 (
		// Inputs
		.CLOCK_50				(CLOCK_50),
		.reset				(~KEY[0]),

		// Bidirectionals
		.PS2_CLK			(PS2_CLK),
		.PS2_DAT			(PS2_DAT),

		// Outputs
		.received_data		(ps2_key_data),
		.received_data_en	(ps2_key_pressed)
	);
	
	Hexadecimal_To_Seven_Segment Segment2 (
		// Inputs
		.hex_number			(last_data_received[3:0]),

		// Bidirectional

		// Outputs
		.seven_seg_display	(HEX2)
	);

	Hexadecimal_To_Seven_Segment Segment3 (
		// Inputs
		.hex_number			(last_data_received[7:4]),

		// Bidirectional

		// Outputs
		.seven_seg_display	(HEX3)
	);
	
	sound r1(.address(addressMario), .clock(CLOCK_50), .q(delay));
	
	Audio_Controller Audio_Controller (
		// Inputs
		.CLOCK_50						(CLOCK_50),
		.reset						(reset),

		.clear_audio_in_memory		(),
		.read_audio_in				(read_audio_in),
		
		.clear_audio_out_memory		(reset),
		.left_channel_audio_out		(left_channel_audio_out),
		.right_channel_audio_out	(right_channel_audio_out),
		.write_audio_out			(write_audio_out),

		.AUD_ADCDAT					(AUD_ADCDAT),

		// Bidirectionals
		.AUD_BCLK					(AUD_BCLK),
		.AUD_ADCLRCK				(AUD_ADCLRCK),
		.AUD_DACLRCK				(AUD_DACLRCK),

		// Outputs
		.audio_in_available			(audio_in_available),
		.left_channel_audio_in		(left_channel_audio_in),
		.right_channel_audio_in		(right_channel_audio_in),

		.audio_out_allowed			(audio_out_allowed),

		.AUD_XCK					(AUD_XCK),
		.AUD_DACDAT					(AUD_DACDAT)

	);
	
	//random R1 (CLOCK_50, seed, seed, randomNum);



					  
//-------------------------------------------------------------------- FSM --------------------------------------------------------------------//

	always @(*) begin
		// init variables
		nextState = currentState;	
		tempMoveStore = 0;
		timerReset = 0;
		timerEnable = 0;
		timerResetQuick = 0;
		moveCounterReset = 0;
		moveCounterEnable = 0;
		randomReset = 0;
		randomEnable = 0;
		sequenceReset = 0;
		sequenceEnable = 0;
		keyReset = 0;
		ledrWire = 0;
		audio_out_allowed = 0;

		
		// begin FSM logic
		case(currentState)
			
			// welcome state: greets player with message, moves to next state when ready key pressed
			welcome: begin
				/*VGA outputs welcome message*/
				
				audio_out_allowed = 1;
				
				outNum = 4'b0001;
				randomEnable = 1;
								
				// reset timer, moveCounter, numMoves, score
				if (ready) begin
					timerReset = 1;
					moveCounterReset = 1;
					sequenceReset = 1;
					keyReset = 1;
					numMoves = 1;
					score = 0;
					nextState = randomize;
				end
			end
			
			
			// randomize state: randomizes number + appends to existing sequence, pauses 1 second before moving onto next state
			randomize: begin
				/*randomize number from 0-3, append to end of existing sequence*/
				outNum = 4'b0010;
								
				randomEnable = 1;
				sequenceEnable = 1;
				
				if (~ready) begin
					nextState = printListenInstructions;
				end
			end
			
			
			// printListenInstructions state: prints listening instructions to user for 1 sec, then resets timer and moves to next state
			printListenInstructions: begin
				/*VGA outputs listening instructions for 1 sec*/
				outNum = 4'b0011;
								
				timerEnable = 1;
				
				if (timer == 0) begin
					timerReset = 1;
					nextState = playSequence;
				end
			end
			
			
			// playSequence state: computer plays sequence, moves to next state
			playSequence: begin
				/*Speaker outputs sequence tones*/
				
				for (i = 0; i < numMoves && i < 63; i = i + 1) begin
					ledrWire[sequence[i]] = 1;
					timerEnable = 1;
					if (timer == 0) begin
						ledrWire[sequence[i]] = 0;
						timerReset = 1;
					end
				end
				
				outNum = 4'b0100;
							
				timerEnable = 1;
								
				if (timer == 0) begin
					timerReset = 1;
					nextState = pause;
				end
			end
			
			
			// pause state: game pauses for 1 sec, moves to next state
			pause: begin
				outNum = 4'b0101;
			
				timerEnable = 1;
				
				if (timer == 0) begin
					timerReset = 1;
					nextState = printPlayerInstructions;
				end
			end
			
			
			// printPlayerInstructions state: prints playing instructions to user for 1 sec, then resets timer and moves to next state
			printPlayerInstructions: begin
				/*VGA outputs playing instructions for 1 sec*/
				outNum = 4'b0110;
				
				timerEnable = 1;
				
				if (timer == 0) begin
					timerReset = 1;
					nextState = playerInHigh;
				end
			end
			
			
			// playerInHigh state: stores which switch was moved by player, moves to next state
			playerInHigh: begin	

				outNum = 4'b0111;
			
				if (SW[0] || SW[1] || SW[2] || SW[3]) begin
					if (SW[0]) begin
						tempMoveStore = 0;
						ledrWire[0] = 1;
					end
					else if (SW[1]) begin
						tempMoveStore = 1;
						ledrWire[1] = 1;
					end
					else if (SW[2]) begin
						tempMoveStore = 2;
						ledrWire[2] = 1;
					end
					else if (SW[3]) begin
						tempMoveStore = 3;
						ledrWire[3] = 1;
					end
					
					/*Speaker outputs player move tone*/
					
					moveStore <= tempMoveStore;
					moveCounterStore = moveCounter;
					
					timerResetQuick = 1;
					nextState = playerInLow;
				end
				
				else begin 
					nextState = playerInHigh;
				end
			end
			
			
			// playerInLow state: waits for player to bring input switch back to low, moves to next state
			playerInLow: begin	
			
				outNum = 4'b1000;
				
				if (moveStore == 0) begin
					if (moveCounter <= moveCounterStore) begin
						moveCounterEnable = 1;
					end
					ledrWire = 0;
					nextState = ~SW[0] ? checkIn : playerInLow;					
				end
				
				else if (moveStore == 1) begin
					if (moveCounter <= moveCounterStore) begin
						moveCounterEnable = 1;
					end
					ledrWire = 0;
					nextState = ~SW[1] ? checkIn : playerInLow;	
				end
				
				else if (moveStore == 2) begin
					if (moveCounter <= moveCounterStore) begin
						moveCounterEnable = 1;
					end
					ledrWire = 0;
					nextState = ~SW[2] ? checkIn : playerInLow;		
				end
				
				else if (moveStore == 3) begin
					if (moveCounter <= moveCounterStore) begin
						moveCounterEnable = 1;
					end
					ledrWire = 0;
					nextState = ~SW[3] ? checkIn : playerInLow;		
				end		
								
			end
			
			
			// checkIn state: checks the player's input against the expected input; if correct, moves to wonRound, if incorrect, moves to lost
			checkIn: begin			
			
				outNum = 4'b1001;
				
				// set expectedMove
				expectedMove <= sequence[moveCounter - 1];
			
				// check if player input matches expectedMove
				if (moveStore == expectedMove) begin
					if (moveCounter == numMoves) begin
						timerReset = 1;
						nextState = wonRound;
					end
					
					else begin
						nextState = playerInHigh;
					end
				end
				
				else begin
					timerReset = 1;
					nextState = lost;
				end
			end
			
			
			// wonRound state: player won round; play win tone, display win message on VGA, moves to scoreCalc
			wonRound: begin
				/*VGA outputs win message*/
				/*Speaker outputs win tone*/
				
				outNum = 4'b1010;
							
				timerEnable = 1;
				
				if (timer == 0) begin
					timerReset = 1;
					nextState = scoreCalc;
				end
			end
			
			
			// scoreCalc state: increments length of sequence, updates player score, moves to playerInputHigh
			scoreCalc: begin	
	
				outNum = 4'b1011;
	
				numMoves = numMoves + 1;
				score = score + 1;
				moveCounterReset = 1;
				
				nextState = randomize;
			end
			
			
			// lost state: player lost; plays lose tone, displays lose message on VGA, moves to inputUsername
			lost: begin
				/*VGA outputs lose message*/
				/*Speaker outputs lose tone*/
				
				outNum = 4'b1100;
								
				timerEnable = 1;
				
				if (timer == 0) begin
					timerReset = 1;
					nextState = inputUsername;
				end
			end
			
			
			// inputUsername state: checks highScore and takes in letter from keyboard to save, move to next state upon Enter key press
			inputUsername: begin
				/*Get username from PS2 Keyboard*/
				if (score > highScore) begin
					highScore = score;
					highScoreName = last_data_received;
				end
				
				outNum = 4'b1101;
												
				if (last_data_received == 8'b01011010) begin
					nextState = leaderboardUpdate;
				end
				else begin
					nextState = inputUsername;
				end
			end
			
			
			// leaderboardUpdate state: updates names and scores on leaderboard, moves to next state
			leaderboardUpdate: begin
				/*update leaderboard*/
				
				outNum = 4'b1110;
								
				nextState = leaderboardPrint;
			end
			
			
			// leaderboardPrint state: prints leaderboard for 3 secs, moves to welcome state
			leaderboardPrint: begin
				/*VGA outputs leaderboard*/
				
				outNum = 4'b1111;
				
				/*figure out how to make 3 secs*/
				timerEnable = 1;
				
				if (timer == 0) begin
					timerReset = 1;
					nextState = welcome;
				end
			end
				
		
		endcase
	end
			

	

endmodule
