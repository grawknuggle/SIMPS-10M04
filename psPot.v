module psPot (
	input [9:0] psDig, //digital from adc
	input [9:0] psRef, //digital from ufm
	input clk,
	output SPI_CLK,
	output SYNC, //active low
	input [3:0] controlstate,
	output DIN, //serial output
	output [3:0] psPot_state,
	input rdy
	);

//reg [2:0] setup;
reg [7:0] pot_command;
//wire comp;
reg [9:0] Dinit; //initial D value - psRef after math
reg [9:0] D; //auto adjusted D value
reg [3:0] psPot_state_;
reg reset;
reg xmit;
wire TX_rdy;
reg [9:0] r_psRef; //save psRef to reg

assign psPot_state = psPot_state_;

SPI_Master_With_Single_CS spi_psPot (
	.i_Rst_L (reset),     // FPGA Reset
   .i_Clk (clk),       // FPGA Clock
   
   // TX (MOSI) Signals
   .i_TX_Count (2'h2),  // # bytes per CS low
   .i_TX_Byte (pot_command),       // Byte to transmit on MOSI
   .i_TX_DV (xmit),         // Data Valid Pulse with i_TX_Byte
   .o_TX_Ready (TX_rdy),      // Transmit Ready for next byte
   
   // RX (MISO) Signals
//   output reg [$clog2(MAX_BYTES_PER_CS+1)-1:0] o_RX_Count,  // Index RX byte
//   output       o_RX_DV,     // Data Valid pulse (1 clock cycle)
//   output [7:0] o_RX_Byte,   // Byte received on MISO

   // SPI Interface
   .o_SPI_Clk (SPI_CLK),
//   input  i_SPI_MISO,
   .o_SPI_MOSI (DIN),
   .o_SPI_CS_n (SYNC)
);



always @(posedge clk) begin 
	case (controlstate) 
		4'h0 : begin //reset
			psPot_state_ <= 4'h0;
			pot_command <= 8'h00;
			reset <= 1'b0;
			xmit <= 1'b0;
			
		end
		4'h1 : begin //reset potentiometer
			reset <= 1'b1;
			case (psPot_state_) 
				4'h0 : begin
					if (TX_rdy == 1'b1 && rdy == 1'b1) begin
						pot_command <= 8'h10;
						xmit <= 1'b1;
						psPot_state_ <= 4'h1;
					end
				end
				4'h1 : begin
					xmit <= 1'b0;
					if (TX_rdy == 1'b1) begin
						xmit <= 1'b1;
						pot_command <= 8'h00;
						psPot_state_ <= 4'h2;
					end
				end
				4'h2 : begin
					xmit <= 1'b0;
					psPot_state_ <= 4'h3;

				end
			endcase
		end
		4'h2 : begin //config potentiometer settings with command 16'h1802
			case (psPot_state_) 
				4'h3 : begin
					if (TX_rdy == 1'b1 && rdy == 1'b1) begin 
						pot_command <= 8'h18; //transmit 8 bits MSB
						xmit <= 1'b1;
						psPot_state_ <= 4'h4;
					end
				end
				4'h4 : begin
					xmit <= 1'b0;
					if (TX_rdy == 1'b1) begin
						xmit <= 1'b1;
						pot_command <= 8'h02; //transmit 8 bits LSB
						psPot_state_ <= 4'h5;
					end
				end
				4'h5 : begin
					xmit <= 1'b0;
					psPot_state_ <= 4'h6;
				end
			endcase
		end
		4'h5 : begin //write initial value to pot
			r_psRef <= psRef;
			Dinit <= 12'd1024/((r_psRef + {2'b00,r_psRef[9:2]})-10'd1); //D math
			case (psPot_state_) 
				4'h6 : begin
					if (TX_rdy == 1'b1 && rdy == 1'b1) begin
						pot_command <= {6'b000001, Dinit[9:8]}; //transmit control bits + 2 bits MSB
						xmit <= 1'b1;
						psPot_state_ <= 4'h7;
					end
				end
				4'h7 : begin
					xmit <= 1'b0;
					if (TX_rdy == 1'b1) begin
						xmit <= 1'b1;
						pot_command <= Dinit[7:0]; //transmit 8 bits LSB
						psPot_state_ <= 4'h8;
					end
				end
				4'h8 : begin
					xmit <= 1'b0;
					psPot_state_ <= 4'h8;
				end
			endcase
		end
		
		//ADD AUTO-ADJUST AND THRESHOLD

	endcase
end
		

endmodule