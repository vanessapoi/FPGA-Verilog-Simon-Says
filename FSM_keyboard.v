// Main module //

module main(input CLOCK_50, input [3:0] KEY, input [3:0] SW, output [7:0] LEDR, output [6:0] HEX0 /*audio output*/ /*VGA output*/);


//----------------------------------------------------------- Variable Declarations -----------------------------------------------------------//

	// PS2 keyboard variables //\
	wire		[7:0] ps2_key_data;
	wire		ps2_key_pressed;


	
	// key variables //
	wire reset = ~KEY[0];
	wire ready = ~KEY[3];
	
	
	// switch variables //
	// wire [3:0] playerMove = SW[3:0];
	reg [1:0] playerMoveStore;
	
	
	// keyboard variables //
	/* add keyboard variables here*/
	
	
	// timer variables //
	localparam timerInitValue = 100000000;
	reg [28:0] timer;
	reg timerReset, timerEnable;
	
	
	// move counter variables //
	reg [5:0] moveCounter;// counts number of moves played by user in current round
	reg moveCounterReset, moveCounterEnable;
	reg [5:0] numMoves; // how many moves are currently in sequence - can go up to 63
	
	
	// score variables //
	reg [5:0] score;
	
	
	// sequence variables //
	reg [1:0] sequence [0:62];
	reg sequenceReset, sequenceEnable;
	reg [1:0] randomNum, expectedMove;
	reg randomReset, randomEnable;
	
	
	// FSM variables //
	localparam welcome = 4'b0000, randomize = 4'b0001, printListenInstructions = 4'b0010, playSequence = 4'b0011, pause = 4'b0100, 
				  printPlayerInstructions = 4'b0101, playerInHigh = 4'b0110, playerInLow = 4'b0111, checkIn = 4'b1000, wonRound = 4'b1001,
				  scoreCalc = 4'b1010, lost = 4'b1011, inputUsername = 4'b1100, leaderboardUpdate = 4'b1101, leaderboardPrint = 4'b1110;
	reg [3:0] currentState, nextState;
	
	
	// test variables //
	reg [3:0] outNum;
	integer i;
	



	
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
		
		else if (timerEnable) begin 
			timer <= timer - 1;
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
	
	
	// control sequence
	always @(posedge CLOCK_50) begin
		if (sequenceReset) begin
			for (i = 0; i <= 62; i = i + 1) begin
				sequence[i] <= 0;
			end 
		end
		
		if (sequenceEnable) begin
			sequence[numMoves - 1] = randomNum;
		end
	end

					  
//----------------------------------------------------------- Module Instantiations -----------------------------------------------------------//

	hexdecoder H1(.c(outNum), .display(HEX0));
	PS2_Controller PS2 (
	// Inputs
	.CLOCK_50			(CLOCK_50),
		.reset			(~KEY[1]),

	// Bidirectionals
	.PS2_CLK			(PS2_CLK),
 	.PS2_DAT			(PS2_DAT),

	// Outputs
	.received_data			(ps2_key_data),
	.received_data_en		(ps2_key_pressed)
);




					  
//-------------------------------------------------------------------- FSM --------------------------------------------------------------------//

	always @(*) begin
		// init variables
		nextState = currentState;	
		playerMoveStore = 0;
		timerReset = 0;
		timerEnable = 0;
		moveCounterReset = 0;
		moveCounterEnable = 0;
		randomReset = 0;
		randomEnable = 0;
		sequenceReset = 0;
		sequenceEnable = 0;

		
		// begin FSM logic
		case(currentState)
			
			// welcome state: greets player with message, moves to next state when ready key pressed
			welcome: begin
				/*VGA outputs welcome message*/
				/*Speaker outputs welcome tone*/
				
				outNum = 4'b0001;
								
				// reset timer, moveCounter, numMoves, score
				if (ready) begin
					timerReset = 1;
					moveCounterReset = 1;
					randomReset = 1;
					sequenceReset = 1;
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
				/*LEDRs output sequence*/
				/*Speaker outputs sequence tones*/
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
						playerMoveStore = 0;
					end
					else if (SW[1]) begin
						playerMoveStore = 1;
					end
					else if (SW[2]) begin
						playerMoveStore = 2;
					end
					else if (SW[3]) begin
						playerMoveStore = 3;
					end
					
					/*LEDR outputs player move*/
					/*Speaker outputs player move tone*/
					
					nextState = playerInLow;
				end
			end
			
			
			// playerInLow state: waits for player to bring input switch back to low, moves to next state
			playerInLow: begin	
	
				outNum = 4'b1000;
	
				if (playerMoveStore == 0) begin
					nextState = !SW[0] ? checkIn : playerInLow;
				end
				else if (playerMoveStore == 1) begin
					nextState = !SW[1] ? checkIn : playerInLow;
				end
				else if (playerMoveStore == 2) begin
					nextState = !SW[2] ? checkIn : playerInLow;
				end
				else if (playerMoveStore == 3) begin
					nextState = !SW[3] ? checkIn : playerInLow;
				end
				
			end
			
			
			// checkIn state: checks the player's input against the expected input; if correct, moves to wonRound, if incorrect, moves to lost
			checkIn: begin			
			
				outNum = 4'b1001;
				
				// set expectedMove
				expectedMove = sequence[moveCounter];
			
				// check if player input matches expectedMove
				if (playerMoveStore == expectedMove) begin
					moveCounterEnable = 1;
					if (moveCounter == numMoves) begin
						nextState = wonRound;
					end
					
					else begin
						nextState = playerInHigh;
					end
				end
				
				else begin
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
			
			
			// inputUsername state: gets 3-digit username from player via PS2 Keyboard, move to next state upon Enter key press
			inputUsername: begin
				/*Get username from PS2 Keyboard*/
				
				outNum = 4'b1101;
								
				nextState = leaderboardUpdate;
				
				//if (/*PS2 Keyboard enter key pressed*/) begin
					//nextState = leaderboardUpdate;
				//end
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
