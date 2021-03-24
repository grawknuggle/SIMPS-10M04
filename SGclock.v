module SGclock (
	input clk, 
	output SGFSYNC,
	output SGDIN,
	output SGSPI_CLK,
	input [3:0] controlstate,
	input [23:0] sgRefFreq,
	output [3:0] SGclk_state
	
);

reg reset; //fpga reset
reg [2:0] burst; //number of bytes to transmit
reg [7:0] sg_command;
reg xmit;
wire TX_rdy;
reg [3:0] SGclk_state_;
wire [27:0] FREQREG;
reg [13:0] FREQMSB;
reg [13:0] FREQLSB;

assign SGclk_state = SGclk_state_;
	
	SPI_Master_With_Single_CS #(.MAX_BYTES_PER_CS (3'h6)) spi_sgClk (
	.i_Rst_L (reset),     // FPGA Reset
   .i_Clk (clk),       // FPGA Clock
   
   // TX (MOSI) Signals
   .i_TX_Count (burst),  // # bytes per CS low
   .i_TX_Byte (sg_command),       // Byte to transmit on MOSI
   .i_TX_DV (xmit),         // Data Valid Pulse with i_TX_Byte
   .o_TX_Ready (TX_rdy),      // Transmit Ready for next byte
   
   // RX (MISO) Signals
//   output reg [$clog2(MAX_BYTES_PER_CS+1)-1:0] o_RX_Count,  // Index RX byte
//   output       o_RX_DV,     // Data Valid pulse (1 clock cycle)
//   output [7:0] o_RX_Byte,   // Byte received on MISO

   // SPI Interface
   .o_SPI_Clk (SGSPI_CLK),
//   input  i_SPI_MISO,
   .o_SPI_MOSI (SGDIN),
   .o_SPI_CS_n (SGFSYNC)
);
	
			//FREQREG = sgRefFreq * 2^28/25MHz
			//FREQREG = sgRefFreq * 10.737
			//FREQREG ~ sgRefFreq * 10.75
			//FREQREG ~ sgRefFreq * 10 + (SGrefFreq * 0.75)
			//FREQREG ~ sgRefFreq * 10 + (SGrefFreq - (SGrefFreq * 0.25))	
assign FREQREG = (sgRefFreq * 4'd10) + (sgRefFreq - {2'b00,sgRefFreq[23:2]});	//DUBIOUS MATH - IF SGCLOCK FREQUENCY IS WRONG, THIS IS LIKELY THE CULPRIT

always @(posedge clk) begin
	case (controlstate)
		4'h0 : begin
			reset <= 1'b0;
			xmit <= 1'b0;
			sg_command <= 8'h00;
			SGclk_state_ <= 4'h0;
		end
		4'h1 : begin //prep sine gen for data, activate reset with 16'h2100 command
			reset <= 1'b1;
			burst <= 3'h2;
			case (SGclk_state_)
				4'h0 : begin
					if (TX_rdy) begin
						xmit <=1'b1;
						sg_command <= 8'h21; //RESET FIRST WORD
						SGclk_state_ <= 4'h1;
					end
				end
				4'h1 : begin
					xmit <= 1'b0;
					if (TX_rdy) begin
						xmit <= 1'b1;
						sg_command <= 8'h00; //RESET SECOND WORD
						SGclk_state_ <= 4'h2;
					end
				end
				4'h2 : begin
					xmit <= 1'b0;
					SGclk_state_ <= 4'h3;
				end
			endcase
		end
		4'h5 : begin //write frequency and phase data to sig gen 
			burst <= 3'h6;
			FREQMSB <= FREQREG[27:14];
			FREQLSB <= FREQREG[13:0];

			case (SGclk_state_)
				4'h3 : begin
					if (TX_rdy) begin
						xmit <= 1'b1;
						sg_command <= {2'b01, FREQLSB[13:8]}; //FREQ LSB CONTROL BITS PLUS FISRT WORD
						SGclk_state_ <= 4'h4;
					end
				end
				4'h4 : begin
					xmit <= 1'b0;
					if (TX_rdy) begin
						xmit <= 1'b1;
						sg_command <= FREQLSB[7:0]; //FREQ LSB SECOND WORD
						SGclk_state_ <= 4'h5;
					end
				end
				4'h5 : begin
					xmit <= 1'b0;
					if (TX_rdy) begin
						xmit <= 1'b1;
						sg_command <= {2'b01, FREQMSB[13:8]}; //FREQ MSB CONTROL BITS PLUS FIRST WORD
						SGclk_state_ <= 4'h6;
					end
				end
				4'h6 : begin
					xmit <= 1'b0;
					if (TX_rdy) begin
						xmit <= 1'b1;
						sg_command <= FREQMSB[7:0]; //FREQ MSB SECOND WORD
						SGclk_state_ <= 4'h7;
					end
				end
				4'h7 : begin
					xmit <= 1'b0;
					if (TX_rdy) begin
						xmit <= 1'b1;
						sg_command <= 8'hc0; //PHASE CONTROL BITS PLUS FIRST WORD - DO NOT CHANGE
						SGclk_state_ <= 4'h8;
					end
				end
				4'h8 : begin
					xmit <= 1'b0;
					if (TX_rdy) begin
						xmit <= 1'b1;
						sg_command <= 8'h00; //PHASE CONTROL BITS PLUS SECOND WORD - DO NOT CHANGE
						SGclk_state_ <= 4'h9;
					end
				end
				4'h9 : begin
					xmit <= 1'b0;
					SGclk_state_ <= 4'ha;
				end
			endcase
		end
		4'h6 : begin //disable sine gen by activating reset with command 16'h2100
			burst <= 3'h2;
			case (SGclk_state_)
				4'ha : begin
					if (TX_rdy) begin
						xmit <= 1'b1;
						sg_command <= 8'h21;
						SGclk_state_ <= 4'hb;
					end
				end
				4'hb : begin
					xmit <= 1'b0;
					if (TX_rdy) begin
						xmit <= 1'b1;
						sg_command <= 8'h00;
						SGclk_state_ <= 4'hc;
					end
				end
				4'hc : begin
					xmit <= 1'b0;
					SGclk_state_ <= 4'hd; //advance to 4'hd to prep for sine gen enable
				end
			endcase

		end
		4'h7 : begin //enable sine gen by disabling reset with command 16'h2000
			burst <= 3'h2;
			case (SGclk_state_)
				4'hd : begin
					if (TX_rdy) begin
						xmit <= 1'b1;
						sg_command <= 8'h20;
						SGclk_state_ <= 4'he;
					end
				end
				4'he : begin
					xmit <= 1'b0;
					if (TX_rdy) begin
						xmit <= 1'b1;
						sg_command <= 8'h00;
						SGclk_state_ <= 4'hf;
					end
				end
				4'hf : begin
					xmit <= 1'b0;
					SGclk_state_ <= 4'ha; //return to 4'ha to prep for sine gen disable
				end
			endcase
		end
	endcase
end



endmodule