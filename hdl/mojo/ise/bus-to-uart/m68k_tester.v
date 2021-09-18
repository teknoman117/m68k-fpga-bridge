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

// note: data is sent if "ready" is 1 and "busy" is 0 on any given clock cycle
//assign avr_data_out = 8'h00;
//assign avr_data_out_ready = 1'd0;

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

// ---- Freerun Test ----

// delay startup by 2^24 sysclk cycles (about 300 milliseconds)
reg m68k_RESET_in_n_q;
reg [23:0] startup_delay;
always @(posedge clk_sys) begin
	if (rst) begin
		startup_delay <= 24'd0;
		m68k_RESET_in_n_q <= 1'd0;
	end else if (~m68k_RESET_in_n_q) begin
		{m68k_RESET_in_n_q, startup_delay} <= startup_delay + 1;
	end
end

assign m68k_RESET_in = ~m68k_RESET_in_n_q;

// synchronize the m68k bus signals with the FPGA
reg [23:0] a_sample;
reg [15:0] d_sample;
reg [2:0] fc_sample;
reg as_sample;
reg lds_sample;
reg uds_sample;
reg rw_sample;
reg bg_sample;

always @(posedge clk_m68k_sample) begin
	if (~m68k_RESET_out_n) begin
		a_sample <= 24'hFFFFFF;
		d_sample <= 16'hFFFF;
		fc_sample <= 3'h7;
		as_sample <= 1'd0;
		lds_sample <= 1'd0;
		uds_sample <= 1'd0;
		rw_sample <= 1'd0;
		bg_sample <= 1'd0;
	end else begin
		a_sample <= m68k_A;
		d_sample <= m68k_D_in;
		fc_sample <= m68k_FC;
		as_sample <= ~m68k_AS_n;
		lds_sample <= ~m68k_LDS_n;
		uds_sample <= ~m68k_UDS_n;
		rw_sample <= m68k_RW;
		bg_sample <= ~m68k_BG_n;
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

// DTACK and BERR driver
reg dtack;
reg berr;
wire cycle_end_success;
wire cycle_end_failure;

always @(posedge clk_sys) begin
	if (rst) begin
		dtack <= 1'd0;
		berr <= 1'd0;
	end else if (as_deasserted) begin
		// when AS deasserts, we need to deassert DTACK and BERR
		dtack <= 1'd0;
		berr <= 1'd0;
	end else if (cycle_end_failure) begin
		// if there's an error, assert BERR
		berr <= 1'd1;
	end else if (cycle_end_success) begin
		// if we succeeded, assert DTACK
		dtack <= 1'd1;
	end
end

assign m68k_DTACK_n = ~dtack;
assign m68k_BERR_n = ~berr;

// send uart char on assert
assign avr_data_out = 8'h41;
assign avr_data_out_ready = as_asserted;

// received data state machine
localparam RCVR_STATE_IDLE = 4'd1;
localparam RCVR_STATE_LOAD_BYTE_1 = 4'd2;
localparam RCVR_STATE_LOAD_BYTE_2 = 4'd4;
localparam RCVR_STATE_LOAD_BYTE_L = 4'd8;

reg [15:0] m68k_D_out_buffer;
reg [3:0] RCVR_state;

always @(posedge clk_sys) begin
	if (rst) begin
		RCVR_state <= RCVR_STATE_IDLE;
		m68k_D_out_buffer <= 16'd0;
	end else if (avr_data_in_ready) begin
		// we only have state transitions on a data byte being ready
		if (RCVR_state[0] & (avr_data_in == 8'h42)) begin
			// transition to load both upper and lower data buffers
			RCVR_state <= RCVR_STATE_LOAD_BYTE_1;
		end else if (RCVR_state[0] & (avr_data_in == 8'h4C)) begin
			// transition to load only the lower data buffer
			RCVR_state <= RCVR_STATE_LOAD_BYTE_L;
		end else if (RCVR_state[0] & (avr_data_in == 8'h48)) begin
			// transition to load only the upper data buffer
			RCVR_state <= RCVR_STATE_LOAD_BYTE_2;
		end else if (RCVR_state[1]) begin
			// load lower data buffer and transition to loading upper buffer
			m68k_D_out_buffer[7:0] <= avr_data_in;
			RCVR_state <= RCVR_STATE_LOAD_BYTE_2;
		end else if (RCVR_state[3]) begin
			// load lower data buffer and transition back to idle
			m68k_D_out_buffer[7:0] <= avr_data_in;
			RCVR_state <= RCVR_STATE_IDLE;
		end else if (RCVR_state[2]) begin
			// load upper data buffer and transition back to idle
			m68k_D_out_buffer[15:8] <= avr_data_in;
			RCVR_state <= RCVR_STATE_IDLE;
		end
	end
end

assign m68k_D_out = m68k_D_out_buffer;
assign cycle_end_success = RCVR_state[0] & avr_data_in_ready & (avr_data_in == 8'h44);
assign cycle_end_failure = RCVR_state[0] & avr_data_in_ready & (avr_data_in == 8'h45);

// assign leds on the start of the bus cycle
reg [7:0] leds_q;
assign led = leds_q;
always @(posedge clk_sys) begin
	if (rst) begin
		leds_q <= 8'd0;
	end else if (as_asserted) begin
		leds_q <= m68k_A[8:1];
	end
end

endmodule