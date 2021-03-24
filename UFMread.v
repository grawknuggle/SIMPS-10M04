module UFMread (
	input clk,
	input readdatavalid,
	input [3:0] controlstate,
	input [31:0] readdata,
	output reg ufmread,
	output reg [15:0] read_addr,
	output reg [9:0] psRef,
	output reg [23:0] sgRefFreq,
	output reg [11:0] sgDP0,
	output reg [11:0] sgDP1,
	output reg [11:0] sgDP2,
	output reg [11:0] sgDP3,
	output reg [11:0] sgDP4,
	output reg [11:0] sgDP5,
	output reg [11:0] sgDP6,
	output reg [11:0] sgDP7,
	output reg relay1,
	output reg relay2,
	input waitrequest,
	output reg [3:0] counter

);

reg reset;
reg [3:0] readstate;

always @ (posedge clk) begin
	reset <= 1'b0;
	case (controlstate)
		4'h0 : begin //reset
			readstate <= 4'h0;
			ufmread <= 1'b0;
			reset <= 1'b1;
		end
		4'h4 : begin
			reset <= 1'b0;
			case (readstate)
				4'h0 : begin
					ufmread <= 1'b1; //begin burst read - reads 6 sequential memory addresses in a row starting with 16'h00, somehow works. don't change.
					read_addr <= 16'h00;
					readstate <= 4'h1;
				end
				4'h1 : begin 
					ufmread <= waitrequest; //bring read low when waitrequest low
					readstate <= 4'h1;
				end
			endcase
		end
	endcase
end

always @(posedge clk or posedge reset) begin //fsm to save read data to appropriate registers
	if (reset)
		counter <= 4'h0;
	else if (readdatavalid && controlstate == 4'h4)
		case (counter)
			4'h0 : begin
				relay1 <= readdata[10];
				relay2 <= readdata[11];
				psRef <= readdata[9:0];
				counter <= 4'h1;
			end
			4'h1 : begin
				sgRefFreq <= readdata[23:0];
				counter <= 4'h2;
			end
			4'h2 : begin
				sgDP0 <= readdata[11:0];
				sgDP1 <= readdata[23:12];
				counter <= 4'h3;
			end
			4'h3 : begin
				sgDP2 <= readdata[11:0];
				sgDP3 <= readdata[23:12];
				counter <= 4'h4;
			end
			4'h4 : begin
				sgDP4 <= readdata[11:0];
				sgDP5 <= readdata[23:12];
				counter <= 4'h5;
			end
			4'h5 : begin
				sgDP6 <= readdata[11:0];
				sgDP7 <= readdata[23:12];
				counter <= 4'h6;
			end
			4'h6 : counter <= 4'h6;
		endcase
	
end

endmodule