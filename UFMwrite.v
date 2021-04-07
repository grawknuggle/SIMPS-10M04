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
	output [31:0] writedata,
	input [7:0] program_data [21:0]
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
	case (writecontrol_) //data addresses and values
			4'b0000 : begin
				write_addr_ <= 16'h0; //psRef and relay resets
				writedata_[31:24] <= program_data[21];
				writedata_[23:16] <= 8'h0;
				writedata_[15:8] <= program_data[1];
				writedata_[7:0] <= program_data[0];
			end
			4'b0001 : begin
				write_addr_ <= 16'h1; //sgRefFreq
				writedata_[31:24] <= 8'h0;
				writedata_[23:16] <= program_data[4];
				writedata_[15:8] <= program_data[3];
				writedata_[7:0] <= program_data[2];
			end
			4'b0010 : begin
				write_addr_ <= 16'h2; //sgDP 0-1
				writedata_[31:24] <= program_data[8];
				writedata_[23:16] <= program_data[7];
				writedata_[15:8] <= program_data[6];
				writedata_[7:0] <= program_data[5];
			end
			4'b0011 : begin
				write_addr_ <= 16'h3; //sgDP 2-3
				writedata_[31:24] <= program_data[12];
				writedata_[23:16] <= program_data[11];
				writedata_[15:8] <= program_data[10];
				writedata_[7:0] <= program_data[9];
			end
			4'b0100 : begin
				write_addr_ <= 16'h4; //sgDP 4-5
				writedata_[31:24] <= program_data[16];
				writedata_[23:16] <= program_data[15];
				writedata_[15:8] <= program_data[14];
				writedata_[7:0] <= program_data[13];
			end
			4'b0101 : begin
				write_addr_ <= 16'h5; //sgDP 6-7
				writedata_[31:24] <= program_data[20];
				writedata_[23:16] <= program_data[19];
				writedata_[15:8] <= program_data[18];
				writedata_[7:0] <= program_data[17];
			end		
	endcase
	
end
	
endmodule

