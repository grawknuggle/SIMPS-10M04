module CSR (
	input [3:0] controlstate,
	input clk,
	output csr_addr,
	output csrread,
	output [3:0] csrstate,
	output [31:0] csr_writedata,
	input [31:0] csr_readdata,
	output csrwrite

);

reg [3:0] csrstate_;
reg [31:0] csr_writedata_;
reg csrwrite_;
reg csr_addr_;
reg csrread_;
reg [31:0] csr_readdata_;

assign csrstate = csrstate_;
assign csrread = csrread_;
assign csr_addr = csr_addr_;
assign csrwrite = csrwrite_;
assign csr_writedata = csr_writedata_;


always @(posedge clk) begin  //prep UFM on reset

	case (controlstate)
		4'h0 : begin
			csrstate_ <= 4'h0;
			csrwrite_ <= 1'b0;
			csr_addr_ <= 1'b0;
			csr_writedata_ <= 32'hffffffff;
			csr_readdata_ <= 32'h0;
		end
		4'h2 : begin
			case (csrstate_)
				4'h0 : begin
					csr_addr_ <= 1'b1;				
					csrwrite_ <= 1'b1;
					csr_writedata_[23] <= 1'b0; //disable sector 1 write protection
					csrstate_ <=  4'h1;
				end
				4'h1 : begin
					csrwrite_ <= 1'b0;
					csrstate_ <=  4'h2;
				end
				4'h2 : begin
					csrread_ <= 1'b1;
					csr_addr_ <= 1'b0;
					csrstate_ <= 4'h3;
				end
				4'h3 : begin
					csrread_ <= 1'b0;
					csr_readdata_ <= csr_readdata; //check for disabled write protection
					if (csr_readdata_[5] == 1'b0)
						csrstate_ <= 4'h4;
					else
						csrstate_ <= 4'h0;
				end
				4'h4 : begin
					csr_addr_ <= 1'b1;
					csrwrite_ <= 1'b1;
					csr_writedata_ [22:20] <= 3'b001; //erase sector 1
					csrstate_ <=  4'h5;
				end
				4'h5 : begin
					csrwrite_ <= 1'b0;
					csrstate_ <= 4'h6;
				end
				4'h6 : begin
					csrread_ <= 1'b1;
					csr_addr_ <= 1'b0;
					csrstate_ <= 4'h7;
				end
				4'h7 : begin
					csrread_ <= 1'b0;
					csr_readdata_ <= csr_readdata;
					if (csr_readdata_[4] == 1'b1 && csr_readdata_[1:0] == 2'b00) //check for successful erase and idle ufm
						csrstate_ <= 4'h8;
					else
						csrstate_ <= 4'h7;
				end
				4'h8 : begin
					csr_addr_ <= 1'b1;
					csrwrite_ <= 1'b1;
					csr_writedata_ [22:20] <= 3'b111; //end erase
					csrstate_ <= 4'h9;
				end
				4'h9 : begin
					csrwrite_ <= 1'b0;
					csrstate_ <= 4'ha;
				end
				4'ha : begin
					csrread_ <= 1'b1;
					csr_addr_ <= 1'b0;
					csrstate_ <= 4'hb;
				end
				4'hb : begin
					csrread_ <= 1'b0;
					csr_readdata_ <= csr_readdata;
					if (csr_readdata_[1:0] == 2'b00) //check for idle ufm
						csrstate_ <= 4'hc;
					else
						csrstate_ <= 4'hb;
				end
				4'hc : begin
					csrstate_ <= 4'hc;
				end
			endcase
		end 
	endcase
			
end

endmodule
	