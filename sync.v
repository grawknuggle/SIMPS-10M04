module sync #( parameter SYNC_BITS = 3) (
	input clk,
	input in,
	output out
);
	localparam SYNC_MSB = SYNC_BITS - 1;
	
	reg [SYNC_MSB : 0] sync_buffer;
	
	assign out = sync_buffer[SYNC_MSB];
	
	always @(posedge clk) begin
		sync_buffer[SYNC_MSB : 0] <= {sync_buffer[SYNC_MSB-1 : 0], in};
	end
endmodule