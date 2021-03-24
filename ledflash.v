module ledflash #(COUNT = 16'd3000)(
	input clk,
	output pulse,
	input [1:0] toggle //00 = off, 01 = blink, 10 = solid
);

reg [15:0] countup;
wire [15:0] target;
reg pulse_;

assign target = COUNT;
assign pulse = toggle[0] ? pulse_ : (toggle[1] ? 1'b1 : 1'b0);

always @(posedge clk) begin
	if (countup < target) begin
		countup <= countup + 1'b1;
	end else begin
		pulse_ <= !pulse_;
		countup <= 16'h0000;
	end
end

endmodule