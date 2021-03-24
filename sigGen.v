module sigGen (
	input clk,
	input [3:0] controlstate,
	input [11:0] sgDP0,
	input [11:0] sgDP1,
	input [11:0] sgDP2,
	input [11:0] sgDP3,
	input [11:0] sgDP4,
	input [11:0] sgDP5,
	input [11:0] sgDP6,
	input [11:0] sgDP7,
	output reg [11:0] sgOut
);

	reg [3:0] sgState;
	reg [11:0] sgDP [7:0];

	always @(negedge clk) begin //DAC CLOCKS DATA ON POSEDGE, LOOP RUNS ON NEGEDGE TO ALLOW AMPLE TIME BEFORE DAC DOES STUFF
		case (controlstate)
			default : begin
				sgState <= 4'h0;
				sgOut[11:0] <= 12'b0;
			end
			4'h5 : begin
				sgDP [0] <= sgDP0;
				sgDP [1] <= sgDP1;
				sgDP [2] <= sgDP2;
				sgDP [3] <= sgDP3;
				sgDP [4] <= sgDP4;
				sgDP [5] <= sgDP5;
				sgDP [6] <= sgDP6;
				sgDP [7] <= sgDP7;
			end
			4'h7 : begin
				if (sgState < 4'h7) begin
					sgOut[11:0] <= sgDP[sgState][11:0]; //SINGLE STATE FSM, GENIUS.
					sgState <= sgState + 1'b1;				
				end else begin
					sgState <= 4'h0;
				end
//				case (sgState)
//					BEGIN : begin
//						SGout[11:0] <= sgDP[0][11:0];
//						sgState <= ST1;
//					end
//					ST1 : begin
//						SGout[11:0] <= sgDP[1][11:0];
//						sgState <= ST2;
//					end
//					ST2 : begin
//						SGout[11:0] <= sgDP[2][11:0];
//						sgState <= ST3;
//					end
//					ST3 : begin
//						SGout[11:0] <= sgDP[3][11:0];
//						sgState <= ST4;
//					end
//					ST4 : begin
//						SGout[11:0] <= sgDP[4][11:0];
//						sgState <= ST5;
//					end
//					ST5 : begin
//						SGout[11:0] <= sgDP[5][11:0];
//						sgState <= ST6;
//					end
//					ST6 : begin
//						SGout[11:0] <= sgDP[6][11:0];
//						sgState <= ST7;
//					end
//					ST7 : begin
//						SGout[11:0] <= sgDP[7][11:0];
//						sgState <= BEGIN;
//					end
//				endcase
			end
		endcase
	end
endmodule