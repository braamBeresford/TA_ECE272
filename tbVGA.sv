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

`timescale 10ns/10ns

module tbVGA;

	//50 MHz (20 ns) master clock
	parameter M_CYCLE = 20; 

	//25 MHz (40 ns) local clock
	parameter L_CYCLE = 40; 



	// Create master clock, active low reset, and local clock
	logic m_clk, reset_n, l_clk;

	// Colour control buses
	logic blue_control, red_control, green_control;

	// Colour output buses
	logic [3:0] blue_display, red_display, green_display;

	logic h_sync, v_sync;

	logic synced;
	logic in_h_display, in_v_display;

	// TB internal signals
	logic reset_tb;

	// Interface under development
	vgaDriver DUT(
			.red(red_control), .green(green_control), .blue(blue_control),
			.red_(red_display), .green_(green_display), .blue_(blue_display),
			.h_sync(h_sync), .v_sync(v_sync), .reset(reset_n),
			.clk(m_clk)
		);


	//Create master 50MHz clock, used only by DUT
	initial begin
		m_clk = 1'b0;
		forever #(M_CYCLE/2)  m_clk = ~m_clk; 
	end

	//Create 25MHz clock, common between DUT and TB
	initial begin
		l_clk = 1'b1;
		#(L_CYCLE);
		@(posedge v_sync); 
		forever #(L_CYCLE/2) l_clk = ~l_clk;
	end


	// Sync to VSYNC intially
	initial begin
		in_h_display = 0;
		in_v_display = 0;
		synced = 0;
		blue_control = '0;
		green_control = '0;
		red_control = '0;
		reset_tb = 0;
		reset_n = 1;		//TODO: Remove


		#(L_CYCLE*2);
		
		

		reset_n = 0;		//TODO: Remove

	

		#(L_CYCLE*2)
		reset_n =1;
		reset_tb = 0;

		//May want to seperate reset and syncing logic
		//Reset testbench counters
		@(posedge v_sync); 
		reset_tb = 1;
		#(L_CYCLE) 
		reset_tb = 0;

		$display("HELLO");
		synced = 1;
		// reset_n = 1;		//TODO: Remove
		#(L_CYCLE/2) reset_tb = 0;

		//Check for blue only
		#1ms;
		blue_control = '1;
		#100ms;
		blue_control = '0;	

		//Check green only
		green_control = '1;
		#100ms

		green_control = '0;

		// Check red only
		red_control = '1;
		#100ms
	
		// Check all three colors together
		blue_control = '1;
		green_control = '1;
		#100ms
		// assert (green_display == 1'h0 && blue_display == 1'h0 && red_display ==1'hF ) 
		// 		else $error("@%d not all colours asserted simultaneously", $time);

		//Done!
		$display("Test bench passes");
		$finish;
	 
	end


		always @(h_clk_count) begin
		#(L_CYCLE/9)
		if( in_v_display && in_h_display) begin
					assert(!(blue_control^ blue_display == 4'b1111))
						 else $error("@%d Blue wasn't active when blue_control asserted", $time);
					assert(!(red_control^ red_display == 4'b1111))
						 else $error("@%d Red wasn't active when blue_control asserted", $time);
					assert(!(green_control^ green_display == 4'b1111))
						 else $error("@%d Green wasn't active when blue_control asserted", $time);
		end
	end

	// always @(h_clk_count) begin
	// 	#(L_CYCLE/9)
	// 	if(blue_control && h_clk_count <= 784 && h_clk_count > 144) begin
	// 				if(v_clk_count >= 35 && v_clk_count < 515)
	// 				assert(blue_display == 4'b1111)
	// 					 else $error("@%d Blue wasn't active when blue_control asserted", $time);
	// 	end
	// end

	//Count clock cycles of both HSYNC and VSYN
	int v_clk_count;
	int h_clk_count;
	always @(posedge l_clk, posedge reset_tb) begin
		if(reset_tb) begin
			v_clk_count = 2;
			h_clk_count = 0;
		end
		else h_clk_count = h_clk_count +1;

		//Reached end of row
		if(h_clk_count >= 800) begin
			//Check for end of screen
			if(v_clk_count <524)
				v_clk_count = v_clk_count +1;
			else 
				v_clk_count = 0;

			h_clk_count = 0;
		end
		
	end


	//Check VSYNC
	always @ (v_clk_count) begin
		//Cause delay as to not sample on the clock face, 
		//I think there must be a cleaner way of doing this (maybe clocking)
		#(L_CYCLE/15)
		//Always assert low color during SYNC period
		// assert (!(!v_sync && (blue_display || red_display || green_display)))
		// 	else $error("@%d a colour was active during the VSYNC sync period. ", v_clk_count);

		
		if(v_clk_count < 2) begin
			in_v_display = 0;
			assert (v_sync == 0) else $error("@%d VSYNC was not LOW during sync period", v_clk_count);
		end

		else if(v_clk_count < 35)begin
			in_v_display = 0;

			assert(v_sync == 1) else $error("@%d VSYNC was LOW during back porch", v_clk_count);

			assert(blue_display == red_display == green_display == 0) 
				else $error("@%d a colour is non-zero during VSYNC back porch", v_clk_count);
		end


		else if(v_clk_count < 515) begin
			in_v_display = 1;
			assert(v_sync == 1) else $error("@%d VSYNC was LOW during display", v_clk_count);
		end
		else if(v_clk_count < 525) begin
			in_v_display = 0;
			assert(v_sync == 1) else $error("@%d VSYNC was LOW during front porch", v_clk_count);
			assert(blue_display == red_display == green_display == 0) 
				else $error("@%d a colour is non-zero during VSYNC front porch", v_clk_count);
		end

		else
			$error("Testbench v_clk_count too large");
	end
	

	//Check HSYNC
	always  @ (h_clk_count)  begin
		//Cause delay as to not sample on the clock face
		#(L_CYCLE/15)
		if(synced) begin
			//Always assert low color during SYNC period
			// assert (!(!h_sync && (blue_display || red_display) || green_display)) 
			// 	else $display("@%d a colour was active during the VSYNC sync period. ", $time);


			if(h_clk_count <= 96) begin
				in_h_display = 0;
				assert (h_sync == 0) else $error("@%d HSYNC was not LOW during sync period", $time);
			end
			
			else if(h_clk_count <= 144)begin
				assert(h_sync == 1) else $error("@%d HSYNC was LOW during HSYNC front porch", $time);

				assert(blue_display == red_display == green_display == 0) 
					else $error("@%d a colour is non-zero during back porch", $time);
			end


			else if(h_clk_count <= 784)	begin
				in_h_display = 1;
				assert(h_sync == 1) else $error("@%d HSYNC was LOW during display", $time);
			end

			else if(h_clk_count < 800) begin
				in_h_display = 0;
				assert(h_sync == 1) else $error("@%d HSYNC was LOW during HSYNC front porch", $time);
				assert(blue_display == red_display == green_display == 0) 
					else $display("@%d a colour is non-zero during HSYNC front porch", $time);
			end

			else
				$error("Testbench h_clk_count too large");

			end
	end


endmodule 