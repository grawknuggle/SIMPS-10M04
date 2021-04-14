
/*

SIMPS Device - Top Level Module for testing the interface.

*/


module simps_pv(input clk_50mhz, RXFn, TXEn, inout [7:0] data_bus, output RDn, WRn, SIWUn, input resetn, output [7:0] leds);
	
	wire reset;
	wire clk;
	
	/* Invert Reset - Pushbutton... */
	assign reset = ~resetn;
	
	// Create a slower clock for testing at 25MHz
	frequency_divider #(8) fd1 (clk_50mhz, reset, 8'd2, clk);
	
	/* Define ft245_async_fifo stuff */
	reg fifo_rd_en;
	reg fifo_wr_en;
	wire fifo_rd_empty;
	wire fifo_wr_full;
	reg [7:0] fifo_wr_data;
	wire [7:0] fifo_rd_data;
	wire program_ready;
	
	/* Define protocol/config stuff */
	wire [3:0] op_mode = 4'd3;								// Hardcoded to the inactive mode.
	reg ps_en = 0;												// Powersupply Enable
	reg fg_en = 0;												// Function Generator Enable
	reg [1:0] range = 2'b00;								// Range bits, Make sure this is the default we want.
	reg [7:0] program_data [0:21];						// Program Data
	reg [11:0] ps_sp;											// Powersupply Setpoint
	
	// The programming data was kept separate because it goes into memory...? Can change if you want...
	// The bits of the program data are as follows: (see protocol sheet for more info)
	/*
	wire [11:0] ps_sp_p;
	wire [23:0] frequency;
	wire [11:0] waveform_1, waveform_2, waveform_3, waveform_4, waveform_5, waveform_6, waveform_7, waveform_8;
	wire [1:0] range_p;
	
	assign ps_sp_p = {program_data[0][3:0], program_data[1]};
	assign frequency = {program_data[2], program_data[3], program_data[4]};
	assign waveform_1 = {program_data[5][3:0], program_data[6]};
	assign range_p = program_data[21][1:0];
	*/
	
	// Test measurement data.
	wire [7:0] measurement_data [0:97];
	
	// Function Generator Measured Values.
	// First period
	assign measurement_data[0] = 8'h00; // <- MSB of value
	assign measurement_data[1] = 8'h00; // <- LSB of value
	assign measurement_data[2] = 8'h00;
	assign measurement_data[3] = 8'h00;
	assign measurement_data[4] = 8'h00;
	assign measurement_data[5] = 8'h00;
	assign measurement_data[6] = 8'h00;
	assign measurement_data[7] = 8'h00;
	assign measurement_data[8] = 8'h0f;
	assign measurement_data[9] = 8'hff;
	assign measurement_data[10] = 8'h0f;
	assign measurement_data[11] = 8'hff;
	assign measurement_data[12] = 8'h0f;
	assign measurement_data[13] = 8'hff;
	assign measurement_data[14] = 8'h0f;
	assign measurement_data[15] = 8'hff;
	// Second Period
	assign measurement_data[16] = 8'h00;
	assign measurement_data[17] = 8'h00;
	assign measurement_data[18] = 8'h00;
	assign measurement_data[19] = 8'h00;
	assign measurement_data[20] = 8'h00;
	assign measurement_data[21] = 8'h00;
	assign measurement_data[22] = 8'h00;
	assign measurement_data[23] = 8'h00;
	assign measurement_data[24] = 8'h0f;
	assign measurement_data[25] = 8'hff;
	assign measurement_data[26] = 8'h0f;
	assign measurement_data[27] = 8'hff;
	assign measurement_data[28] = 8'h0f;
	assign measurement_data[29] = 8'hff;
	assign measurement_data[30] = 8'h0f;
	assign measurement_data[31] = 8'hff;
	// Third Period
	assign measurement_data[32] = 8'h00;
	assign measurement_data[33] = 8'h00;
	assign measurement_data[34] = 8'h00;
	assign measurement_data[35] = 8'h00;
	assign measurement_data[36] = 8'h00;
	assign measurement_data[37] = 8'h00;
	assign measurement_data[38] = 8'h00;
	assign measurement_data[39] = 8'h00;
	assign measurement_data[40] = 8'h0f;
	assign measurement_data[41] = 8'hff;
	assign measurement_data[42] = 8'h0f;
	assign measurement_data[43] = 8'hff;
	assign measurement_data[44] = 8'h0f;
	assign measurement_data[45] = 8'hff;
	assign measurement_data[46] = 8'h0f;
	assign measurement_data[47] = 8'hff;
	
	// Function Generator Measured Values.
	// First period
	assign measurement_data[48] = 8'h00; // <- MSB of value
	assign measurement_data[49] = 8'h00; // <- LSB of value
	assign measurement_data[50] = 8'h00;
	assign measurement_data[51] = 8'h00;
	assign measurement_data[52] = 8'h00;
	assign measurement_data[53] = 8'h00;
	assign measurement_data[54] = 8'h00;
	assign measurement_data[55] = 8'h00;
	assign measurement_data[56] = 8'h0f;
	assign measurement_data[57] = 8'hff;
	assign measurement_data[58] = 8'h0f;
	assign measurement_data[59] = 8'hff;
	assign measurement_data[60] = 8'h0f;
	assign measurement_data[61] = 8'hff;
	assign measurement_data[62] = 8'h0f;
	assign measurement_data[63] = 8'hff;
	// Second Period
	assign measurement_data[64] = 8'h00;
	assign measurement_data[65] = 8'h00;
	assign measurement_data[66] = 8'h00;
	assign measurement_data[67] = 8'h00;
	assign measurement_data[68] = 8'h00;
	assign measurement_data[69] = 8'h00;
	assign measurement_data[70] = 8'h00;
	assign measurement_data[71] = 8'h00;
	assign measurement_data[72] = 8'h0f;
	assign measurement_data[73] = 8'hff;
	assign measurement_data[74] = 8'h0f;
	assign measurement_data[75] = 8'hff;
	assign measurement_data[76] = 8'h0f;
	assign measurement_data[77] = 8'hff;
	assign measurement_data[78] = 8'h0f;
	assign measurement_data[79] = 8'hff;
	// Third Period
	assign measurement_data[80] = 8'h00;
	assign measurement_data[81] = 8'h00;
	assign measurement_data[82] = 8'h00;
	assign measurement_data[83] = 8'h00;
	assign measurement_data[84] = 8'h00;
	assign measurement_data[85] = 8'h00;
	assign measurement_data[86] = 8'h00;
	assign measurement_data[87] = 8'h00;
	assign measurement_data[88] = 8'h0f;
	assign measurement_data[89] = 8'hff;
	assign measurement_data[90] = 8'h0f;
	assign measurement_data[91] = 8'hff;
	assign measurement_data[92] = 8'h0f;
	assign measurement_data[93] = 8'hff;
	assign measurement_data[94] = 8'h0f;
	assign measurement_data[95] = 8'hff;
	
	
	// Power supply voltage value.
	assign measurement_data[96][7:4] = 4'h0;
	assign measurement_data[96][3:0] = ps_sp[11:8];
	assign measurement_data[97] = ps_sp[7:0];
	
	// Pull up SIWUn as we don't need it.
	assign SIWUn = 1'b1;
	
	/* Instantiate Interface */
	ft245_async_fifo #(.read_depth(3), .write_depth(3), .same_clocks(0)) com1 (
		.reset(reset),
		// Physical Pins
		.D(data_bus),
		.RXFn(RXFn),
		.TXEn(TXEn),
		.RDn(RDn),
		.WRn(WRn),
		// Clocks
		.clk_50mhz(clk_50mhz),	// This needs to be a 50MHz clock.
		.rw_clk(clk),				// This is what the protocol module runs at. Can be anything. USing 25MHz
		// Exposed stuff
		.rd_en(fifo_rd_en),
		.rd_data(fifo_rd_data),
		.rd_empty(fifo_rd_empty),
		.wr_en(fifo_wr_en),
		.wr_data(fifo_wr_data),
		.wr_full(fifo_wr_full)
	);
	
	protocol com2 (
		reset,
		clk,
		// Stuff exposed by ft245_async_fifo
		fifo_rd_en,
		fifo_wr_en,
		fifo_rd_empty,
		fifo_wr_full,
		fifo_wr_data,
		fifo_rd_data,
		// Wires
		op_mode,
		// Registers
		ps_en,
		fg_en,
		ps_sp,
		range,
		program_data,
		program_ready,
		measurement_data
	);
	
endmodule

module frequency_divider #(parameter size=8) (input clk, reset, input [size-1:0] count_max, output logic _clk);
	logic [size-1:0] count;
	always_ff @ (posedge clk or posedge reset)
		if (reset) begin
			count <= {size{1'b0}};
			_clk <= 1'b0;
			end
		else if (count < count_max)
			count <= count + {{(size-1){1'b0}},1'b1};
		else begin
			count <= {size{1'b0}};
			_clk <= ~_clk;
			end
endmodule
