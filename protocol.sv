
module protocol(
		input reset, clk,
		output reg rd_en, wr_en,
		input rd_empty, wr_full,
		output reg [7:0] wr_data, 
		input [7:0] rd_data,
		input [3:0] op_mode,
		output reg ps_en, fg_en,
		output reg [11:0] ps_sp,
		output reg [1:0] range,
		output reg [7:0] program_data [0:21],
		output reg program_ready,
		input [7:0] measurement_data [0:97]
	);
	
	// Finite State Machine - States
	localparam	STATE_IDLE					= 8'd0,
					STATE_PRE_SELECT			= 8'd1,
					STATE_SELECT				= 8'd2,
					STATE_PS_ENABLE			= 8'd3,
					STATE_PS_DISABLE			= 8'd4,
					STATE_FG_ENABLE			= 8'd5,
					STATE_FG_DISABLE			= 8'd6,
					STATE_ECHO_PRE_READ		= 8'd7,
					STATE_ECHO_READ			= 8'd8,
					STATE_ECHO_WRITE			= 8'd9,
					STATE_RANGE_PRE_READ		= 8'd10,
					STATE_RANGE_READ			= 8'd11,
					STATE_RANGE_SET			= 8'd12,
					STATE_RANGE_WRITE			= 8'd13,
					STATE_OPMODE_WRITE		= 8'd14,
					STATE_PS_PRE_READ_MSB	= 8'd15,
					STATE_PS_READ_MSB			= 8'd16,
					STATE_PS_SET_MSB			= 8'd17,
					STATE_PS_PRE_READ_LSB	= 8'd18,
					STATE_PS_READ_LSB			= 8'd19,
					STATE_PS_SET_LSB			= 8'd20,
					STATE_PROG_PRE_READ		= 8'd21,
					STATE_PROG_READ			= 8'd22,
					STATE_PROG_SET				= 8'd23,
					STATE_PROG_READY			= 8'd24,
					STATE_MEAS_PRE_WRITE		= 8'd25,
					STATE_MEAS_WRITE			= 8'd26;
	
	logic [7:0] state = STATE_IDLE;
	logic [7:0] next_state;
	
	// Counter used for counting clocks in order to meet timings.
	logic [4:0] counter = 4'd0;
	
	// Prevent the FSM from getting locked into a state forever.
	logic [23:0] max_wait = 24'd2500000; // 100ms @ 25MHz
	logic [23:0] lockup_counter = 24'd0;
	
	// How much program data should we read.
	logic [7:0] programming_counter = 8'd0;
	logic [7:0] programming_length = 8'd22;
	
	// How much measurement data should we send.
	logic [7:0] measurement_counter = 8'd0;
	logic [7:0] measurement_length = 8'd98; // = length of measurement_data
	
	// FSM sequential state transition
	always_ff @ (posedge clk or posedge reset)
		if (reset) begin
			state <= STATE_IDLE;
		end
		else begin
			state <= next_state;
		end	
	
	// FSM sequential logic
	always_ff @ (posedge clk or posedge reset)
		if (reset) begin
			rd_en <= 1'b0;
			wr_en <= 1'b0;
			counter <= 4'd0;
			lockup_counter <= 24'd0;
			programming_counter <= 8'd0;
			program_ready <= 1'b0;
			
			// Might not want to do this in the final code...
			ps_en <= 1'b0;
			fg_en <= 1'b0;
			range <= 2'd0;
			ps_sp <= 12'd0;
		end
		else begin
			// Default values. Overridden by the case statement below.
			rd_en <= 1'b0;
			wr_en <= 1'b0;
			lockup_counter <= 24'd0;
			counter <= 4'd0;
			program_ready <= 1'b0;
			
			case(state)
				// 1. The idle state is waiting for a byte to be available.
				//STATE_IDLE : No need to do anything.
				
				// 2. A byte is availble. Use the read buffer enable to get the data.
				STATE_PRE_SELECT : rd_en <= 1'b1;
				
				// 3. Wait until the read buffer puts stable data onto the read bus.
				//			Then detmine the next state to go into from the read byte.
				//			Make sure we don't wait too long to go into another state.
				//			We also make sure that the programming & measurement counter are reset to zero.
				STATE_SELECT : begin
					counter <= counter + 4'd1;
					lockup_counter <= lockup_counter + 24'd1;
					programming_counter <= 8'd0;
					measurement_counter <= 8'd0;
				end
				
				// 4a. Enable the power supply.
				STATE_PS_ENABLE : ps_en <= 1'b1;
				
				//	4b. Disable the power supply.
				STATE_PS_DISABLE : ps_en <= 1'b0;
				
				//	4c. Enable the function generator.
				STATE_FG_ENABLE : fg_en <= 1'b1;
				
				//	4d. Disable the function generator.
				STATE_FG_DISABLE : fg_en <= 1'b0;
				
				// 4e. Echo: Ask for another byte. We will later write this byte back to the host.
				STATE_ECHO_PRE_READ : rd_en <= 1'b1;
				
				// 5. Echo: Wait for the read buffer to put stable data onto the read bus.
				//			Make sure we don't wait too long in this state for the write buffer.
				STATE_ECHO_READ : begin
					counter <= counter + 4'd1;
					lockup_counter <= lockup_counter + 24'd1;
				end
				
				// 6. Echo: Write the byte from the read buffer bus to the write buffer bus.
				//			Enable the write enable.
				STATE_ECHO_WRITE : begin
					wr_data <= rd_data;
					wr_en <= 1'b1;
				end
				
				// 4f. Range: Ask the read buffer for a byte of data.
				STATE_RANGE_PRE_READ : rd_en <= 1'b1;
				
				// 5. Range: Wait until the data is good.
				STATE_RANGE_READ : counter <= counter + 4'd1;
				
				// 6. Range: Set the data into the range register.
				STATE_RANGE_SET : range <= rd_data[1:0];
				
				// 4g. Mode: Send the current operation mode to the write buffer.
				STATE_OPMODE_WRITE : begin
					wr_data[3:0] <= op_mode;
					wr_data[7:4] <= 4'd0;
					wr_en <= 1'b1;
				end
				
				// 4h. PS: Ask the read buffer for a byte of data.
				STATE_PS_PRE_READ_MSB : rd_en <= 1'b1;
				
				// 5. PS:  Wait until the data is good.
				STATE_PS_READ_MSB : counter <= counter + 4'd1;
				
				// 6. PS: Set the MSBs for the power supply setpoint.
				STATE_PS_SET_MSB : begin
					ps_sp[11:8] <= rd_data[3:0];
					lockup_counter <= lockup_counter + 24'd1;
				end
				
				// 7. PS: Ask the read buffer for a byte of data.
				STATE_PS_PRE_READ_LSB : rd_en <= 1'b1;
				
				// 8. PS:  Wait until the data is good.
				STATE_PS_READ_LSB : counter <= counter + 4'd1;
				
				// 9. PS: Set the LSBs for the power supply setpoint.
				STATE_PS_SET_LSB : ps_sp[7:0] <= rd_data;
				
				// 4i. Prog:  Ask the read buffer for a byte of data.
				//			Increment the programming counter to keep track of the amount of data we are reading.
				STATE_PROG_PRE_READ : begin
					rd_en <= 1'b1;
					programming_counter <= programming_counter + 8'd1;
				end
				
				// 5. Prog: Wait until the data is good.
				STATE_PROG_READ : counter <= counter + 4'd1;
				
				// 6. Prog: Set the current progam data byte.
				//			This state also serves to make sure that there is another byte available to read
				//			before looping back to the pre read state.
				STATE_PROG_SET : begin
					program_data[programming_counter-1] <= rd_data;
					lockup_counter <= lockup_counter + 24'd1;
				end
				
				// 7. Prog: Strobe the program_ready control line high to indicate the programming data is ready.
				STATE_PROG_READY : program_ready <= 1'b1;
				
				// 4j. Measurement: Ensure that we can write data before doing so.
				//			Also, increment the measurement counter.
				STATE_MEAS_PRE_WRITE : begin
					measurement_counter <= measurement_counter + 8'd1;
					lockup_counter <= lockup_counter + 24'd1;
				end
				
				// 5. Measurement: Write the current measurement byte.
				STATE_MEAS_WRITE : begin
					wr_data <= measurement_data[measurement_counter-1];
					wr_en <= 1'b1;
				end
				
				// 4k. Range: Write the range to the write buffer.
				STATE_RANGE_WRITE : begin
					wr_data[1:0] <= range;
					wr_data[7:2] <= 4'd0;
					wr_en <= 1'b1;
				end
				
			endcase
		end
	
	// Next state combinational logic.
	always_comb begin
		case(state)
			/* 1. Wait until the read buffer has data. */
			STATE_IDLE :
				if (!rd_empty)
					next_state = STATE_PRE_SELECT;
				else
					next_state = STATE_IDLE;
			
			// 2. Pull the read enable low to read byte from the read buffer.
			//		We can safely assume that there is a byte available from the last operation.
			STATE_PRE_SELECT : 
				next_state = STATE_SELECT;
			
			// 3. Use this byte to determine which state to go into.
			STATE_SELECT :
				// Wait for the read buffer to put the data onto the read bus.
				if (counter <= 4'd1)
					next_state = STATE_SELECT;
				
				else if (lockup_counter >= max_wait)
					next_state = STATE_IDLE;
				
				else case (rd_data)
					// These states do not need to READ.
					8'h03 : next_state = STATE_PS_DISABLE;
					8'h04 : next_state = STATE_PS_ENABLE;
					8'h05 : next_state = STATE_MEAS_PRE_WRITE;
					8'h07 : next_state = STATE_FG_DISABLE;
					8'h08 : next_state = STATE_FG_ENABLE;
					
					// These state need to WRITE, so the write buffer needs to be available.
					// Going to this again over state IDLE provides for a more immedate operation + no anti-lockup issues.
					8'h09 :
						if (!wr_full)
							next_state = STATE_OPMODE_WRITE;
						else
							next_state = STATE_SELECT;
					8'h0b :
						if (!wr_full)
							next_state = STATE_RANGE_WRITE;
						else
							next_state = STATE_SELECT;
					
					// These states need to READ, so there needs to be a byte in the read buffer.
					// Going to this again over state IDLE provides for a more immedate operation + no anti-lockup issues.
					8'h01, 8'h80 :
						if (!rd_empty)
							next_state = STATE_ECHO_PRE_READ;
						else
							next_state = STATE_SELECT;
					8'h02 :
						if (!rd_empty)
							next_state = STATE_PROG_PRE_READ;
						else
							next_state = STATE_SELECT;
					8'h06 :
						if (!rd_empty)
							next_state = STATE_RANGE_PRE_READ;
						else
							next_state = STATE_SELECT;
					8'h0a :
						if (!rd_empty)
							next_state = STATE_PS_PRE_READ_MSB;
						else
							next_state = STATE_SELECT;
					
					// Otherwise go back to the IDLE state.
					default : next_state = STATE_IDLE;
				endcase
			
			// 4e. Echo: This state asks the read buffer for a byte of data.
			STATE_ECHO_PRE_READ : next_state = STATE_ECHO_READ;
			
			// 5. Echo: ...
			STATE_ECHO_READ :
				// Wait for the read buffer to put the data onto the read bus.
				if (counter <= 4'd1)
					next_state = STATE_ECHO_READ;
				
				// Ensure that we are okay to write data.
				else if (!wr_full)
					next_state = STATE_ECHO_WRITE;
				
				// Prevent a lockup condition: waiting to be able to write forever.
				else if (lockup_counter >= max_wait)
					next_state = STATE_IDLE;
				
				// Stay in this state until a previous condition is met.
				else
					next_state = STATE_ECHO_READ;
			
			// 4f. Range ...
			STATE_RANGE_PRE_READ : next_state = STATE_RANGE_READ;
			
			// 5. Range: ...
			STATE_RANGE_READ :
				// Wait until the read buffer has stable data.
				if (counter <= 4'd1)
					next_state = STATE_RANGE_READ;
				
				// Go the the next state which sets the range bits.
				else
					next_state = STATE_RANGE_SET;
			
			// 6. Range: ...
			STATE_RANGE_SET : next_state = STATE_IDLE;
			
			// 4h. PS:
			STATE_PS_PRE_READ_MSB : next_state = STATE_PS_READ_MSB;
			
			// 5. PS:
			STATE_PS_READ_MSB :
				// Wait until the read buffer has stable data.
				if (counter <= 4'd1)
					next_state = STATE_PS_READ_MSB;
				
				// Go the the next state which sets the MSBs of the power supply.
				else
					next_state = STATE_PS_SET_MSB;
			
			// 6. PS:
			STATE_PS_SET_MSB :
				// Ensure that we are okay to read data again.
				 if (!rd_empty)
					next_state = STATE_PS_PRE_READ_LSB;
				
				// Prevent a lockup condition: waiting to be able to write forever.
				else if (lockup_counter >= max_wait)
					next_state = STATE_IDLE;
				
				// Stay in this state until a previous condition is met.
				else
					next_state = STATE_PS_SET_MSB;
			
			// 7. PS:
			STATE_PS_PRE_READ_LSB : next_state = STATE_PS_READ_LSB;
			
			// 8. PS:
			STATE_PS_READ_LSB :
				// Wait until the read buffer has stable data.
				if (counter <= 4'd1)
					next_state = STATE_PS_READ_LSB;
				
				// Go the the next state which sets the LSBs of the power supply.
				else
					next_state = STATE_PS_SET_LSB;
			
			// 4i. Prog: This state drives the read buffer enable high.
			STATE_PROG_PRE_READ : next_state = STATE_PROG_READ;
			
			// 5. Prog: Wait until there is good data on the read buffers data lines.
			STATE_PROG_READ :
				// Wait until the read buffer has stable data.
				if (counter <= 4'd1)
					next_state = STATE_PROG_READ;
				
				// Go the the next state which sets a byte of programming data.
				else
					next_state = STATE_PROG_SET;
			
			// 6. Prog: Set the data on the read buffers data lines into program memory/registers.
			STATE_PROG_SET :
				// Are we done programming the program memory/registers?
				if (programming_counter >= programming_length)
					next_state = STATE_PROG_READY;
				
				// Ensure that we are okay to read data again.
				else if (!rd_empty)
					next_state = STATE_PROG_PRE_READ;
				
				// Prevent a lockup condition: waiting to be able to write forever.
				else if (lockup_counter >= max_wait)
					next_state = STATE_IDLE;
				
				// Stay in this state until a previous condition is met.
				//		Setting the same data over and over again (in the always_ff) should not hurt anything.
				else
					next_state = STATE_PROG_SET;
			
			// 4j. Measurement:
			STATE_MEAS_PRE_WRITE :
				// Ensure that we are okay to write data.
				if (!wr_full)
					next_state = STATE_MEAS_WRITE;
				
				// Prevent a lockup condition: waiting to be able to write forever.
				else if (lockup_counter >= max_wait)
					next_state = STATE_IDLE;
				
				// Stay in this state until a previous condition is met.
				else
					next_state = STATE_MEAS_PRE_WRITE;
			
			// 5. Measurement:
			STATE_MEAS_WRITE :
				// Are we done programming the program memory/registers?
				if (measurement_counter >= measurement_length)
					next_state = STATE_IDLE;
				
				// Go write some more data.
				else
					next_state = STATE_MEAS_PRE_WRITE;
			
			default : 
				next_state = STATE_IDLE;
		endcase
	end

endmodule
