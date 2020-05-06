/*
*	Filname: tbVGA.sv
*	Purpose: Test VGA timings and basic color
*	
*	Created: 05/03/2020
*	Update:  05/06/2020
*	
*	Author(s): Braam Beresford
*
*/

`timescale 1ns/1ps

module tbVGA;

	//50 MHz (20 ns) master clock
	parameter M_CYCLE = 20; 

	//25 MHz (20 ns) local clock
	parameter L_CYCLE = 10; 



	// Create master clock, active low reset, and local clock
	logic m_clk, reset_n, l_clk, enable;

	// Colour control buses
	logic blue_control, red_control, green_control;

	// Colour output buses
	logic [3:0] blue_display, red_display, green_display;

	logic h_sync, v_sync;


	// TB internal signals
	logic reset_tb;

	// Interface under development
	vgaDriver DUT(
			.red(red_control), .green(green_control), .blue(blue_control),
			.red_(red_display), .green_(green_display), .blue_(blue_display),
			.h_sync(h_sync), .v_sync(v_sync), .reset(reset_n), .enable(enable),
			.clk(m_clk)
		);


	//Create master 50MHz clock, used only by DUT
	initial begin
		m_clk = 1'b1;
		forever #(M_CYCLE/2)  m_clk = ~m_clk; 
	end

	//Create 25MHz clock, common between DUT and TB
	initial begin
		l_clk = 1'b1;
		forever #(L_CYCLE/2) l_clk = ~l_clk;
	end


	// Sync to VSYNC intially
	initial begin
		blue_control = '0;
		green_control = '0;
		red_control = '0;

		enable = 0;			//TODO: Remove
		reset_n = 0;		//TODO: Remove

		#(L_CYCLE*2);

		enable = 1;			//TODO: Remove
		reset_n = 1;		//TODO: Remove

		//Reset testbench counters
		@(negedge v_sync); reset_tb = 1;
		#(L_CYCLE) reset_tb = 0;

		//Check for blue only
		blue_control = '1;
		#(L_CYCLE)
		assert (green_display == 1'h0 && blue_display == 1'hF && red_display ==1'h0) 
			else $error("@%d blue failed to assert alone", $time);
		blue_control = '0;	

		//Check green only
		green_control = '1;
		#(L_CYCLE)
		assert (green_display == 1'hF && blue_display == 1'h0 && red_display ==1'h0 ) 
				else $error("@%d green failed to assert alone", $time);
		green_control = '0;

		//Check red only
		red_control = '1;
		#(L_CYCLE)
		assert (green_display == 1'h0 && blue_display == 1'h0 && red_display ==1'hF ) 
				else $error("@%d red failed to assert alone", $time);
		
		//Check all three colors together
		blue_control = '1;
		green_control = '1;
		#(L_CYCLE)
		assert (green_display == 1'h0 && blue_display == 1'h0 && red_display ==1'hF ) 
				else $error("@%d not all colours asserted simultaneously", $time);

		//Done!
		$stop;

	end

	//Count clock cycles of both HSYNC and VSYN
	int v_clk_count;
	int h_clk_count;
	always @(posedge l_clk, posedge reset_tb) begin
		if(reset_tb) begin
			v_clk_count = 0;
			h_clk_count = 0;
		end
		else h_clk_count = h_clk_count +1;

		//Reached end of row
		if(h_clk_count >= 800) begin
			//Check for end of screen
			if(v_clk_count <525)
				v_clk_count = v_clk_count +1;
			else 
				v_clk_count = 0;

			h_clk_count = 0;
		end
	end


	// Check VSYNC
	always @(v_clk_count) begin
		//Always assert low color during SYNC period
		assert (!(!v_sync && (blue_display || red_display) || green_display))
			else $error("@%d a colour was active during the VSYNC sync period. ", $time);

		
		if(v_clk_count < 2) 
			assert (v_sync == 0) else $error("@%d VSYNC was not LOW during sync period", $time);
		
		else if(v_clk_count < 35)begin
			assert(v_sync == 1) else $error("@%d VSYNC was LOW during front porch", $time);

			assert(blue_display == red_display == green_display == 0) 
				else $error("@%d a colour is non-zero during back porch", $time);
		end


		else if(v_clk_count < 515)
			assert(v_sync == 1) else $error("@%d VSYNC was LOW during display", $time);

		else if(v_clk_count < 525) begin
			assert(v_sync == 1) else $error("@%d VSYNC was LOW during front porch", $time);
			assert(blue_display == red_display == green_display == 0) 
				else $error("@%d a colour is non-zero during front porch", $time);
		end

		else
			$error("Testbench v_clk_count too large");
	end


	// Check HSYNC
	always @(h_clk_count) begin
		//Always assert low color during SYNC period
		assert (!(!h_sync && (blue_display || red_display) || green_display)) 
			else $display("@%d a colour was active during the VSYNC sync period. ", $time);


		if(h_clk_count < 96) 
			assert (h_sync == 0) else $display("@%d HSYNC was not LOW during sync period", $time);
		
		else if(h_clk_count < 144)begin
			assert(h_sync == 1) else $display("@%d HSYNC was LOW during front porch", $time);

			assert(blue_display == red_display == green_display == 0) 
				else $display("@%d a colour is non-zero during back porch", $time);
		end


		else if(h_clk_count < 784)
			assert(h_sync == 1) else $display("@%d HSYNC was LOW during display", $time);

		else if(h_clk_count < 800) begin
			assert(h_sync == 1) else $display("@%d HSYNC was LOW during front porch", $time);
			assert(blue_display == red_display == green_display == 0) 
				else $display("@%d a colour is non-zero during front porch", $time);
		end

		else
			$error("Testbench h_clk_count too large");
	end


endmodule 