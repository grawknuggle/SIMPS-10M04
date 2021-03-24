module UFMwrite (
	input clk,
	input [3:0] controlstate,
	input dataready, //high when serial read is complete and registers are full
	input waitrequest, //high when ufm busy
	//output [3:0] writecontrol, //ufm write FSM
	output ufmwrite,
	output [1:0] writestate,
	output [15:0] write_addr,
	input [1:0] csr_status,
	output [31:0] writedata

);

reg ufmwrite_;
reg [1:0] writestate_;
reg [3:0] writecontrol_;
reg [15:0] write_addr_;
reg [31:0] writedata_;

//assign writecontrol = writecontrol_;
assign ufmwrite = ufmwrite_;
assign writestate = writestate_;
assign write_addr = write_addr_;
assign writedata = writedata_;


always @(posedge clk) begin //WRITE TO UFM
	case (controlstate)
		4'h0 : begin //reset
			ufmwrite_ <= 1'b0;
			writestate_ <= 2'b00;
			writecontrol_ <= 4'b0000;
		end
		4'h3 : begin //write data to UFM - advances through writecontrol FSM automatically, ends at state 2b11 when complete
			if (dataready) begin
				case (writestate_)
					2'b00 : begin
						ufmwrite_ <= 1'b1;
						writestate_ <= 2'b01;
					end
					2'b01 : begin
						if (waitrequest == 1'b1)//hold at current state while waitrequest is high
							writestate_ <= 2'b01;
						else begin
							ufmwrite_ <= 1'b0; //end write and advance state when waitrequest is low
							writestate_ <= 2'b10;
						end
					end
					2'b10 : begin
						if (csr_status == 2'b00) begin
							if (writecontrol_ < 4'b0101) begin
								writecontrol_ <= writecontrol_ + 1'b1; //advance to next writecontrol_ until complete
								writestate_ <= 2'b00;
							end else begin
								writestate_ <= 2'b11;
							end
						end else begin
							writestate_ <= 2'b10;
						end
					end
					2'b11 : begin
						writestate_ <= 2'b11;
					end
				endcase			
			end
		end

	endcase
	case (writecontrol_) //data addresses and values - HARD CODED FOR NOW. CHANGE AS NEEDED FOR TESTING. READ COMMENTS FIRST.
			4'b0000 : begin
				write_addr_ <= 16'h0; //psRef and relay resets
				writedata_ <= 32'h0000001e;	//test value: writedata_[10] = relay1reset, writedata_[11] = relay2reset, writedata_[9:0] = psRef
			end
			4'b0001 : begin
				write_addr_ <= 16'h1; //sgRefFreq
				writedata_ <= 32'h004c4b40;	//test value: writedata_[23:0] = sgRefFreq
			end
			4'b0010 : begin
				write_addr_ <= 16'h2; //sgDP 0-1
				writedata_ <= 32'h00100100;	//test value: writedata_[11:0] = sgDP[0], writedata_[23:12] = sgDP[1]
			end
			4'b0011 : begin
				write_addr_ <= 16'h3; //sgDP 2-3
				writedata_ <= 32'h00100100; //test value: see previous state, pattern repeats
			end
			4'b0100 : begin
				write_addr_ <= 16'h4; //sgDP 4-5
				writedata_ <= 32'h00100100; //test value: see previous state, pattern repeats
			end
			4'b0101 : begin
				write_addr_ <= 16'h5; //sgDP 6-7
				writedata_ <= 32'h00100100; //test value: see previous state, pattern repeats
			end		
	endcase
	
end
	
endmodule

