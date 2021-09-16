module m68k_tester(
	 input clk_50,
	 input rst_n,
	 output [7:0] led,

	 // mojo v3 avr interface
	 input avr_cclk,
	 input avr_mosi,
	 output avr_miso,
	 input avr_ss,
	 input avr_sck,
	 output [3:0] avr_adc_channel,
	 input avr_tx,
	 output avr_rx,
	 input avr_rx_busy,

	 // m68k data
	 inout [15:0] m68k_D,
	
	 // m68k outputs
	 input [23:0] m68k_A,
	 input [2:0] m68k_FC,
	 input m68k_AS_n,
	 input m68k_UDS_n,
	 input m68k_LDS_n,
	 input m68k_RW,
	 input m68k_BG_n,
	 input m68k_HALT_out_n,
	 input m68k_RESET_out_n,
	
	 // m68k inputs
	 output [2:0] m68k_IPL_n,
	 output m68k_HALT_in,
	 output m68k_RESET_in,
	 output m68k_DTACK_n,
	 output m68k_BGACK_n,
	 output m68k_BR_n,
	 output m68k_CLK,
	 output m68k_BERR_n
  );

// System Clock Generator (PLL)
wire rst_out_n;
wire clk_sys;
wire clk_m68k;
wire clk_m68k_sample;
clk_wiz_v3_6 pll (
	.clk_50_in(clk_50),
	.clk_50_out(clk_sys),
	.clk_25_out(clk_m68k_sample),
	.clk_12_5_out(clk_m68k),
	.rst_in(~rst_n),
	.rst_out_n(rst_out_n)
);

wire rst;
assign rst = ~rst_out_n;

// M68K clock
ODDR2 m68k_CLK_buffer(
	.C0(clk_m68k),
	.C1(~clk_m68k),
	.CE(1'd1),
	.D0(1'd0),
	.D1(1'd1),
	.R(rst),
	.S(1'd0),
	.Q(m68k_CLK)
);

// M68K data bus control
wire [15:0] m68k_D_out;
wire [15:0] m68k_D_in;
assign m68k_D[7:0] = (m68k_RW & ~m68k_LDS_n) ? m68k_D_out[7:0] : 8'dZ;
assign m68k_D[15:8] = (m68k_RW & ~m68k_UDS_n) ? m68k_D_out[15:8] : 8'dZ;

// AVR ADC control
wire avr_adc_new_sample;
wire [9:0] avr_adc_sample;
wire [3:0] avr_adc_sample_channel;
assign avr_adc_sample_channel = 4'hF;

// AVR UART
wire [7:0] avr_data_out;
wire [7:0] avr_data_in;
wire avr_data_out_ready;
wire avr_data_out_busy;
wire avr_data_in_ready;

avr_interface #(.CLK_RATE(50000000)) avr (
	 .clk(clk_sys),
	 .rst(rst),
	 .cclk(avr_cclk),
	 .spi_miso(avr_miso),
	 .spi_mosi(avr_mosi),
	 .spi_sck(avr_sck),
	 .spi_ss(avr_ss),
	 .tx(avr_rx),
	 .rx(avr_tx),
	 .channel(avr_adc_sample_channel),
	 .new_sample(avr_adc_new_sample),
	 .sample(avr_adc_sample),
	 .sample_channel(avr_adc_channel),
	 .tx_data(avr_data_out),
	 .new_tx_data(avr_data_out_ready),
	 .tx_busy(avr_data_out_busy),
	 .tx_block(avr_rx_busy),
	 .rx_data(avr_data_in),
	 .new_rx_data(avr_data_in_ready)
);

// unused signals
assign m68k_IPL_n = 3'h7;
assign m68k_HALT_in = 1'd0;
assign m68k_BGACK_n = 1'd1;
assign m68k_BR_n = 1'd1;
assign m68k_BERR_n = 1'd1;

// ---- Freerun Test ----

// delay startup by 2^24 sysclk cycles (about 300 milliseconds)
wire error;
reg m68k_RESET_in_n_q;
reg [23:0] startup_delay;
always @(posedge clk_sys) begin
	if (rst | error) begin
		startup_delay <= 24'd0;
		m68k_RESET_in_n_q <= 1'd0;
	end else if (~m68k_RESET_in_n_q) begin
		{m68k_RESET_in_n_q, startup_delay} <= startup_delay + 1;
	end
end

// synchronize the m68k bus signals with the FPGA
reg [23:0] a_sample;
reg as_sample;

always @(posedge clk_m68k_sample) begin
	if (~m68k_RESET_out_n) begin
		a_sample <= 24'd0;
		as_sample <= 1'd0;
	end else begin
		a_sample <= m68k_A; 
		as_sample <= ~m68k_AS_n;
	end
end

// system logic reading synchronized m68k bus signals

// Address Strobe edges
reg as_edge;
always @(posedge clk_sys) begin
	if (rst) begin
		as_edge <= 1'd0;
	end else begin
		as_edge <= as_sample;
	end
end

wire as_asserted;
wire as_deasserted;
assign as_asserted = ~as_edge & as_sample;
assign as_deasserted = as_edge & ~as_sample;

// assign leds on the start of the bus cycle
reg [7:0] leds_q;
assign led = leds_q;
always @(posedge clk_sys) begin
	if (rst) begin
		leds_q <= 8'd0;
	end else if (as_asserted) begin
		leds_q <= m68k_A[23:16];
	end
end

// DTACK_n grounded
assign m68k_DTACK_n = 1'd0;
assign m68k_RESET_in = ~m68k_RESET_in_n_q;
assign m68k_D_out = 16'd0;

// validate received address
reg [23:0] expected_address;
reg has_started;
always @(posedge clk_sys) begin
	// increment expected address after cycle ends
	if (~m68k_RESET_out_n) begin
		expected_address <= 24'd0;
		has_started <= 1'd0;
	end else if (as_deasserted) begin
		if (~has_started & expected_address == 24'd6) begin
			// account for the first 4 reads, reset to zero
			expected_address <= 24'd0;
			has_started <= 1'd1;
		end else
			expected_address <= expected_address + 2;
	end
end

// error if there is an address mismatch
assign error = as_asserted & (expected_address != a_sample);

// send 'E' on error
assign avr_data_out = 8'h45;
assign avr_data_out_ready = error;

endmodule