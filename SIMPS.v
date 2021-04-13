module SIMPS(
output CLK100k,
output PSU_POT_DIN,
output PSU_POT_SCLK,
output PSU_POT_SYNC,
input PSU_POT_RDY,
output PS_EN,
input CLK_25M, 
output FG_EN,
output CLK_FSYNC,
output CLK_SCLK,
output CLK_SDI,
output ADC_PDN,

input [11:0] MeasIn,
input ADC_DCO,
output DAC_RW,
output DAC_CS,
output [11:0] SGout,
input CLK_COMPARATOR,
output Relay1Reset,
output Relay2Reset,
inout [7:0] DATA_BUS,
input RXFn,
input TXEn,
output RDn,
output RWn,
output SIWU,
input FTDI_CLK,
output OEN,
input SG_ANA_IN,
input PS_ANA_IN,
output LED_dev,
output LED_prog,
output LED_sig,
output LED_pow,
input SW_res,
input SW_ena

);

//clocks
wire CLK10M;
wire CLK50M;
wire CLK100k_;
wire pll_locked;

assign DAC_CS = CLK_COMPARATOR;
assign DAC_RW = DAC_CS;
assign CLK100k = CLK100k_;

//hardware
wire res_sync;
wire ena_sync;
wire reset;
wire enable;
wire reset_rise;
wire enable_rise;
reg PS_en_;
reg FG_en_;

//assign LED_dev = 1'b1;
//assign LED_pow = PS_en_;
//assign LED_sig = FG_en_;
assign PS_EN = PS_en_;
assign FG_EN = FG_en_;

//top-level FSM
reg [3:0] controlstate;
reg [1:0] reset_timer;
reg [1:0] progLEDstat;
reg ufmreset_r;
wire ufmreset_n;

assign ufmreset_n = !ufmreset_r;

//UFM
wire [15:0] data_addr;
wire ufmread;
wire [31:0] writedata;
wire ufmwrite;
reg [31:0] readdata;
reg waitrequest;
wire readdatavalid;
wire [4:0] burstcount;
wire csr_addr;
wire csrread;
wire [31:0] csr_writedata;
wire csrwrite;
reg [31:0] csr_readdata;
wire [1:0] writestate;
wire [3:0] csr_state;
wire dataready;
wire [7:0] readstate;
wire [15:0] read_addr;
wire [15:0] write_addr;


assign data_addr = controlstate[2] ? read_addr : write_addr; //SETS DATA_ADDR BASED ON CONTROLSTATE
assign burstcount = controlstate[2] ?5'h6 : 5'h1; //SETS BURSTCOUNT BASED ON CONTROLSTATE - MUST BE 1 WHEN WRITING

//ADC
wire [9:0] psDig;
reg [11:0] sgDig;

//PSU
wire [9:0] psRef;
wire [3:0] psPot_state;

//Sig Gen
wire [23:0] sgRefFreq;
wire [11:0] sgDP [7:0];
wire [3:0] SGclock_state;


//////////////////////
//////////////////////
//////////////////////
//DEBUG STUFF
wire debugLED;
//wire CLK_25M;
wire LED_prog_flash;

//	clkctrl clkctrl0 ( //GLOBAL CLOCK BUFFER, MAY OR MAY NOT DO ANYTHING
//		.inclk  (CLK_IN),  //  altclkctrl_input.inclk
//		.outclk (CLK_25M)  // altclkctrl_output.outclk
//	);

//CHANGE THESE FOR DEBUGGING
assign dataready = 1'b1; //TEMP ENABLE DATAREADY. WILL BE REPLACED AFTER SERIAL COMMUNICATION IMPLEMENTATION. SET TO 0 TO DISABLE UFM WRITE. IF SET TO 0, LED_prog WILL BLINK WHEN RESET AND ENABLE ARE TAKEN HIGH	
assign debugLED = 1'b0; //SET TO 0 FOR NORMAL LED FUNCTION. SET TO 1 TO FORCE LEDS TO DISPLAY CONTROLSTATE
assign ADC_PDN = 1'b1; //DISABLE EXTERNAL ADC WHEN HIGH

//DON'T CHANGE THESE
assign LED_dev = debugLED ? controlstate[0] : 1'b1;
assign LED_prog = debugLED ? controlstate[1] : LED_prog_flash;
assign LED_pow = debugLED ? controlstate[2] : PS_en_;
assign LED_sig = debugLED ? controlstate[3] : FG_en_;

//END DEBUG
//////////////////////
//////////////////////
//////////////////////
			
			
	ADC_INT ADC0 ( //NOT CURRENTLY FUNCTIONAL
		.adc_pll_clock_clk      (CLK_25M),      //  adc_pll_clock.clk
		.adc_pll_locked_export  (pll_locked),  // adc_pll_locked.export
		.clock_clk              (CLK10M),              //          clock.clk
//		.command_valid          (<connected-to-command_valid>),          //        command.valid
		.command_channel        (5'h0),        //               .channel
//		.command_startofpacket  (<connected-to-command_startofpacket>),  //               .startofpacket NOT USED
//		.command_endofpacket    (<connected-to-command_endofpacket>),    //               .endofpacket NOT USED
//		.command_ready          (<connected-to-command_ready>),          //               .ready
		.reset_sink_reset_n     (ufmreset_n),     //     reset_sink.reset_n
//		.response_valid         (<connected-to-response_valid>),         //       response.valid
//		.response_channel       (<connected-to-response_channel>),       //               .channel
		.response_data          (psDig)          //               .data
//		.response_startofpacket (<connected-to-response_startofpacket>), //               .startofpacket
//		.response_endofpacket   (<connected-to-response_endofpacket>)    //               .endofpacket
	);

PLL	PLL_inst (
	.inclk0 (CLK_25M), //25M in from crystal MAKE SURE TO CHANGE THIS BACK TO 25M IN THE IP
	.c0 (CLK10M), //ADC 10M clk
	.c1 (CLK50M), //PS_Pot 10k clk
	.c2 (CLK100k_), //PSU 100k clk
	.locked (pll_locked) //lock for ADC
	);

sync s_r ( //sync reset switch input to internal clock
	.clk (CLK_25M),
	.in (SW_res),
	.out (res_sync)
);

sync s_e ( //sync enable switch input to internal clock
	.clk (CLK_25M),
	.in (SW_ena),
	.out (ena_sync)
);

debounce #(.MAX_COUNT(6)) d_r ( //debounce reset
	.clk (CLK_25M),
	.in (res_sync),
	.out (reset),
	.rise (reset_rise) //high for 1 clock period on posedge reset
);

debounce #(.MAX_COUNT(6)) d_e ( //debounce enable
	.clk (CLK_25M),
	.in (ena_sync),
	.out (enable),
	.rise (enable_rise) //high for 1 clock period on posedge enable
);

ledflash #(.COUNT(16'd30000)) progStat ( //LED control - currently only for prog LED
	.clk (CLK100k),
	.toggle (progLEDstat), //00=off, 01=blink at .clk/.COUNT hz, 10=on
	.pulse (LED_prog_flash)
);

	ufm ufm0 (
		.clock                   (CLK_25M),                   //    clk.clk
		.reset_n                 (ufmreset_n),                 // nreset.reset_n
		.avmm_data_addr          (data_addr),          //   data.address
		.avmm_data_read          (ufmread),          //       .read
		.avmm_data_writedata     (writedata),     //       .writedata
		.avmm_data_write         (ufmwrite),         //       .write
		.avmm_data_readdata      (readdata),      //       .readdata
		.avmm_data_waitrequest   (waitrequest),   //       .waitrequest
		.avmm_data_readdatavalid (readdatavalid), //       .readdatavalid
		.avmm_data_burstcount    (burstcount),    //       .burstcount
		.avmm_csr_addr           (csr_addr),           //    csr.address
		.avmm_csr_read           (csrread),           //       .read
		.avmm_csr_writedata      (csr_writedata),      //       .writedata
		.avmm_csr_write          (csrwrite),          //       .write
		.avmm_csr_readdata       (csr_readdata)        //       .readdata
	);

psPot p0 ( //potentiometer control
	.psDig (psDig),
	.psRef (psRef),
	.SYNC (PSU_POT_SYNC),
	.DIN (PSU_POT_DIN),
	.clk (CLK100k),
	.SPI_CLK (PSU_POT_SCLK),
	.controlstate (controlstate),
	.psPot_state (psPot_state)
);

SGclock SGC0 ( //variable clock control
	.clk(CLK_25M),
	.SGFSYNC(CLK_FSYNC),
	.SGDIN(CLK_SDI),
	.SGSPI_CLK (CLK_SCLK),
	.controlstate(controlstate),
	.sgRefFreq (sgRefFreq),
	.SGclk_state (SGclock_state)
);

CSR csr0 ( //UFM CSR control
	.controlstate (controlstate),
	.clk (CLK_25M),
	.csr_addr (csr_addr),
	.csrread (csrread),
	.csrstate (csr_state),
	.csr_writedata (csr_writedata),
	.csr_readdata (csr_readdata),
	.csrwrite (csrwrite)
);

UFMwrite UFMwrite0 ( //write to UFM
	.clk (CLK_25M),
	.controlstate (controlstate),
	.dataready (dataready), //high when serial read is complete and registers are full
	.waitrequest (waitrequest),
	.ufmwrite (ufmwrite),
	.writestate (writestate),
	.write_addr (write_addr),
	.csr_status (csr_readdata[1:0]),
	.writedata (writedata)

);

UFMread UFMread0 ( //read from UFM
	.clk (CLK_25M),
	.readdata (readdata),
	.readdatavalid (readdatavalid),
	.controlstate (controlstate),
	.ufmread (ufmread),
	.read_addr (read_addr),
	.psRef (psRef),
	.sgRefFreq (sgRefFreq),
	.sgDP0 (sgDP[0]),
	.sgDP1 (sgDP[1]),
	.sgDP2 (sgDP[2]),
	.sgDP3 (sgDP[3]),
	.sgDP4 (sgDP[4]),
	.sgDP5 (sgDP[5]),
	.sgDP6 (sgDP[6]),
	.sgDP7 (sgDP[7]),
	.relay1 (Relay1Reset),
	.relay2 (Relay2Reset),
	.waitrequest (waitrequest),
	.counter (readstate)
);

sigGen SG0 ( //sigGen loop
	.clk (CLK_COMPARATOR),
	.controlstate (controlstate),
	.sgDP0 (sgDP[0]),
	.sgDP1 (sgDP[1]),
	.sgDP2 (sgDP[2]),
	.sgDP3 (sgDP[3]),
	.sgDP4 (sgDP[4]),
	.sgDP5 (sgDP[5]),
	.sgDP6 (sgDP[6]),
	.sgDP7 (sgDP[7]),
	.sgOut (SGout)
);

always @(posedge CLK_25M) begin
	if (reset_rise) begin //TRIGGER RESET PROCESS WHEN RESET SW GOES HIGH
		controlstate <= 4'h0;
		reset_timer <= 2'b00;
	end else begin
		case (controlstate)
			4'h0 : begin //RESET STATE 1 - TURN OFF PROG LED, RESET UFM, WAIT FOR USER TO TAKE ENABLE HIGH
				progLEDstat <= 2'b00;
				ufmreset_r <= 1'b0;
				//ADD SEND RESET STATE TO FRONT END
				if (enable_rise && reset)
					controlstate <= 4'h1;
			end
			4'h1 : begin //RESET STATE 2 - INITIATE TIMER DELAY TO ALLOW UFM RESET TO COMPLETE, WAIT FOR PSPOT AND SGCLOCK TO FINISH RESET SEQUENCE
				if (reset_timer == 2'b11) begin
					ufmreset_r <= 1'b0;
				end else begin
					ufmreset_r <= 1'b1;
					reset_timer <= reset_timer + 1'b1;
				end
				if ((psPot_state == 4'h3 && SGclock_state == 4'h3)) begin
					controlstate <= 4'h2;
				end
			end
			4'h2 : begin //RESET STATE 3 - WAIT FOR CSR CONFIG TO COMPLETE, WAIT FOR PSPOT INITIAL CONFIG TO COMPLETE
				if (csr_state == 4'hc && psPot_state == 4'h6)
					controlstate <= 4'h3;
			end
			4'h3 : begin //PROGRAM STATE 1 - FLASH PROG LED, WRITE SERIAL DATA TO UFM, TURN PROG LED ON WHEN WRITE IS COMPLETE
				//ADD SEND PROGRAM STATE TO FRONT END
				progLEDstat <= 2'b01;
				if (writestate == 2'h3) begin
					controlstate <= 4'h4;
					progLEDstat <= 2'b10;
				end
			end
			4'h4 : begin //PROGRAM STATE 2 - READ DATA FROM UFM TO APPROPRIATE REGISTERS
				if (readstate >= 4'h6)
					controlstate <= 4'h5;
			end
			4'h5 : begin //PROGRAM STATE 3 - WRITE REFERENCE VOLTAGE TO PSPOT, WRITE FREQUENCY AND PHASE TO SGCLOCK, WAIT FOR RESET AND ENABLE TO BE LOW
				if (psPot_state == 4'h8 && SGclock_state == 4'ha && !reset && !enable)
					controlstate <= 4'h6;
			end
			4'h6 : begin //INACTIVE MODE - DISABLE POWER SUPPLY, DISABLE FUNCTION GEN, DISABLE SGCLOCK, WAIT FOR ENABLE TO GO HIGH
				PS_en_ <= 1'b0;	
				FG_en_ <= 1'b0;
				//ADD SEND INACTIVE STATE TO FRONT END
				if (SGclock_state == 4'hd && !reset && enable_rise)
					controlstate <= 4'h7;
			end
			4'h7 : begin //ACTIVE MODE - ENABLE POWER SUPPLY, ENABLE SGCLOCK, ENABLE FUNCTION GEN AFTER SGCLOCK IS ENABLED, WAIT FOR ENABLE TO GO LOW
				PS_en_ <= 1'b1;
				if (SGclock_state == 4'ha && !reset && enable)
					FG_en_ <= 1'b1;
				//ADD SEND ACTIVE STATE TO FRONT END
				if (SGclock_state == 4'ha && !reset && !enable)
					controlstate <= 4'h4;
			end
		endcase
	end

end

endmodule
