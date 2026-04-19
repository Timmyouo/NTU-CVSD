
module core (                       //Don't modify interface
	input      		i_clk,
	input      		i_rst_n,
	input    	  	i_in_valid,
	input 	[31: 0] i_in_data,

	output			o_in_ready,

	output	[ 7: 0]	o_out_data1,
	output	[ 7: 0]	o_out_data2,
	output	[ 7: 0]	o_out_data3,
	output	[ 7: 0]	o_out_data4,

	output	[11: 0] o_out_addr1,
	output	[11: 0] o_out_addr2,
	output	[11: 0] o_out_addr3,
	output	[11: 0] o_out_addr4,

	output 			o_out_valid1,
	output 			o_out_valid2,
	output 			o_out_valid3,
	output 			o_out_valid4,

	output 			o_exe_finish
);
// ---------------------------------------------------------------------------
// Parameters 
// ---------------------------------------------------------------------------
typedef enum logic [2:0]{
	S_IDLE,
	S_READ_IMG,
	S_BARCODE,
	S_READ_WEIGHT,
	S_CONV,
	S_DONE
} state_t;

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------

// For FSM
state_t      state_r, state_w;

// For Image Memory (origibal)
logic [7:0]  imem_rdata;
logic [7:0]  imem_wdata;
logic [11:0] imem_addr;
logic 		 imem_cen;
logic        imem_wen;

// Input Image Memory ports for image loader
logic [7:0]  loader_wdata_r, loader_wdata_w;
logic [11:0] loader_addr_r , loader_addr_w;
logic 		 loader_cen_r  , loader_cen_w;
logic        loader_wen_r  , loader_wen_w;

// Input Image Memory ports for barcode module
logic [11:0] barcode_addr;
logic 		 barcode_cen;

// Input Image Memory ports for convcore
logic [11:0] conv_addr;
logic 		 conv_cen;

// For image reading
logic 		 in_ready_r		, in_ready_w; 		// Connected to o_in_ready Set high if ready to fetch next 32 bits
logic [9:0]  word_counter_r , word_counter_w; 	// Record how many times the in_data has been fetched
logic [1:0]  pixel_counter_r, pixel_counter_w;	// Record how many bytes has been stored in each input word
logic [31:0] img_data_r		, img_data_w;		// Temporarily store the input data for image loading

// Barcode
logic		 barcode_start_r, barcode_start_w ;
logic [1:0]  barcode_stride , barcode_dilation;
logic 		 barcode_finish , barcode_invalid ;

// Output regs
logic [7:0]  out_data1_r , out_data2_r , out_data3_r , out_data4_r ;
logic [7:0]  out_data1_w , out_data2_w , out_data3_w , out_data4_w ;
logic [11:0] out_addr1_r , out_addr2_r , out_addr3_r , out_addr4_r ;
logic [11:0] out_addr1_w , out_addr2_w , out_addr3_w , out_addr4_w ;
logic        out_valid1_r, out_valid2_r, out_valid3_r, out_valid4_r;
logic        out_valid1_w, out_valid2_w, out_valid3_w, out_valid4_w;

// Convolution
logic [1:0]  stride_r    , stride_w;
logic [1:0]  dilation_r  , dilation_w;
logic [1:0]  w_count_r   , w_count_w;
logic [71:0] weight_r    , weight_w; 
logic        conv_start_r, conv_start_w;
logic		 conv_valid  , conv_finish;
logic [7:0]  conv_data;

// ---------------------------------------------------------------------------
// Submodule, task and function
// ---------------------------------------------------------------------------
// Memory for original iamage (64 * 64 * int8)
sram_4096x8 img_mem(
	.Q  (imem_rdata),
	.CLK(i_clk),
	.CEN(imem_cen),
	.WEN(imem_wen),
	.A  (imem_addr),
	.D  (imem_wdata)
);

// Barcode parser
Barcode u_barcode(
	.i_clk  	(i_clk),
	.i_rst_n	(i_rst_n),
	.i_start    (barcode_start_r),

	.o_sram_addr(barcode_addr),
	.o_sram_cen (barcode_cen),
	.i_sram_data(imem_rdata),

	.o_stride   (barcode_stride),
	.o_dilation (barcode_dilation),
	.o_invalid  (barcode_invalid),

	.o_finish   (barcode_finish)
);


// Concolutional machine
ConvCore u_convcore(
	.i_clk	     (i_clk),
	.i_rst_n     (i_rst_n),
	.i_start     (conv_start_r),
	
	.i_stride    (stride_r),
	.i_dilation  (dilation_r),
	.i_weight    (weight_r),

    .o_addr      (conv_addr),
    .o_cen       (conv_cen),
    .i_in_data   (imem_rdata),

    .o_out_valid (conv_valid),
    .o_out_data  (conv_data),

	.o_finish    (conv_finish)
);


task automatic loader_write;
    input [11:0] addr;
    input [7:0]  data;
    begin
        loader_addr_w  = addr;
		loader_cen_w   = 1'b0;
		loader_wen_w   = 1'b0;
		loader_wdata_w = data;
    end
endtask


// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
assign o_in_ready   = in_ready_r;

assign o_out_data1  = out_data1_r;
assign o_out_data2  = out_data2_r;
assign o_out_data3  = out_data3_r;
assign o_out_data4  = out_data4_r;

assign o_out_addr1  = out_addr1_r;
assign o_out_addr2  = out_addr2_r;
assign o_out_addr3  = out_addr3_r;
assign o_out_addr4  = out_addr4_r;

assign o_out_valid1 = out_valid1_r;
assign o_out_valid2 = out_valid2_r;
assign o_out_valid3 = out_valid3_r;
assign o_out_valid4 = out_valid4_r;

assign o_exe_finish = (state_r == S_DONE);

// ---------------------------------------------------------------------------
// Finite State Machine 
// ---------------------------------------------------------------------------
always @(*) begin
	state_w = state_r;
	case (state_r)
		S_IDLE: begin
			state_w = S_READ_IMG;
		end 
		S_READ_IMG: begin
			if (barcode_start_r) begin
				state_w = S_BARCODE;
			end
		end 
		S_BARCODE: begin
			if (barcode_finish) begin
				if (barcode_invalid) state_w = S_DONE;
				else			     state_w = S_READ_WEIGHT;
			end
		end 
		S_READ_WEIGHT: begin
			if (conv_start_r) begin
				state_w = S_CONV;
			end
		end 		
		S_CONV: begin
			if (conv_finish) begin
				state_w = S_DONE;
			end
		end 
	endcase
end

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------

// Memory control: decide who to connect sram 
always @(*) begin
	// Default : memory closed
	imem_addr  = 12'd0;
	imem_cen   = 1'b1;
	imem_wen   = 1'b1;
	imem_wdata = 8'd0;

	// Input image memory
	if (state_r == S_READ_IMG) begin
		// Loader using IMEM
        imem_addr     = loader_addr_r;
        imem_cen      = loader_cen_r;
        imem_wen      = loader_wen_r;
        imem_wdata    = loader_wdata_r;
    end else if (state_r == S_BARCODE) begin
        // Barcode using IMEM
        imem_addr     = barcode_addr;
        imem_cen      = barcode_cen;
        imem_wen      = 1'b1;           // barcode only read
        imem_wdata    = 8'd0;
	end else if (state_r == S_CONV) begin
		// Convcore using IMEM
        imem_addr     = conv_addr;
        imem_cen      = conv_cen;
        imem_wen      = 1'b1;           // convcore only read
        imem_wdata    = 8'd0;
	end
end

// Input image loading
always @(*) begin
	// Default values
	in_ready_w 		= 0;
	word_counter_w  = word_counter_r;
	pixel_counter_w = pixel_counter_r;

	loader_addr_w   = loader_addr_r;
	loader_cen_w	= 1'b1;
	loader_wen_w 	= 1'b1;
	loader_wdata_w  = 0;

	img_data_w		= img_data_r; // Store 32 bits input

	barcode_start_w = 0;
	
	// IDLE : Fetch input at next cycle  
	if (state_r == S_IDLE) begin
		in_ready_w 		= 1;
		word_counter_w  = 0;
		pixel_counter_w = 0;
	end
	// Load input image
	else if (state_r == S_READ_IMG) begin
		if (word_counter_r == 10'd1023 && pixel_counter_r == 2'd3) begin
			// The last input data : Reset counters 
			pixel_counter_w = 0;
			word_counter_w  = 0;
			loader_write(word_counter_r * 4 + pixel_counter_r, img_data_r[(31 - pixel_counter_r * 8) -: 8]);
			barcode_start_w = 1;			
		end
		else begin
			if (pixel_counter_r == 2'd0 ) begin
				// First : Set in_valid_w 0, directly store the byte from input, and store all 4 bytes in a reg
				in_ready_w = 0;
				img_data_w = i_in_data;
				loader_addr_w  = word_counter_r * 4 + pixel_counter_r;
				pixel_counter_w = pixel_counter_r + 1;
				loader_cen_w   = 1'b0;
				loader_wen_w   = 1'b0;
				loader_wdata_w = i_in_data[31:24];
			end
			else if (pixel_counter_r == 3) begin
				// Fourth: Set in_valid_w 1, update word_counter and reset pixel_counter
				in_ready_w		= 1;
				pixel_counter_w = 0;
				word_counter_w  = word_counter_r + 1;
				loader_write(word_counter_r * 4 + pixel_counter_r, img_data_r[(31 - pixel_counter_r * 8) -: 8]);
			end
			// Second and third: Simply store the byte and update pixel_counter
			else begin
				loader_write(word_counter_r * 4 + pixel_counter_r, img_data_r[(31 - pixel_counter_r * 8) -: 8]);
				pixel_counter_w = pixel_counter_r + 1;	
			end	
		end
	end
	else if (state_r == S_READ_WEIGHT) begin
		in_ready_w 		= 1;
	end
end


// Barcode decoded parameters and outputs
always @(*) begin
	// Default
	stride_w     = stride_r;
	dilation_w   = dilation_r;

	out_data1_w  = out_data1_r;
	out_data2_w  = out_data2_r;
	out_data3_w  = out_data3_r;
	out_data4_w  = out_data4_r;

	out_addr1_w  = out_addr1_r;
	out_addr2_w  = out_addr2_r;
	out_addr3_w  = out_addr3_r;
	out_addr4_w  = out_addr4_r;

	out_valid1_w = 0;
	out_valid2_w = 0;
	out_valid3_w = 0;
	out_valid4_w = 0;

	if (state_r == S_BARCODE && barcode_finish)begin
		stride_w     = barcode_stride;
		dilation_w   = barcode_dilation;
		out_valid1_w = 1;
		out_valid2_w = 1;
		out_valid3_w = 1;
		if (barcode_invalid) begin
			out_data1_w = 0;
			out_data2_w = 0;
			out_data3_w = 0;
		end else begin
			out_data1_w = 8'd3;
			out_data2_w = {6'd0, barcode_stride};
			out_data3_w = {6'd0, barcode_dilation};			
		end
	end else if (state_r == S_CONV) begin
		// Output 1 pixel each time
		if (conv_valid) begin
			out_valid1_w = 1;
			out_data1_w  = conv_data;
		end
		if (out_valid1_r) out_addr1_w = out_addr1_r + 1;
	end
end

// Load weight and start convolution
always @(*) begin
	// Default
	weight_w     = weight_r;
	w_count_w    = 0;
	conv_start_w = 0;

	if (state_r == S_READ_WEIGHT) begin
		// Load weight values
		if (i_in_valid) begin
			w_count_w = w_count_r + 1;
			case (w_count_r)
				2'd0: weight_w[71:40] = i_in_data;
				2'd1: weight_w[39:8 ] = i_in_data;
				2'd2: begin
					weight_w[7 :0 ] = i_in_data[31:24];
					conv_start_w	= 1;
				end
			endcase
		end
	end

end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------

always @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r		    <= S_IDLE;

		loader_wdata_r  <= 0;
		loader_addr_r   <= 0;
		loader_cen_r    <= 1;
		loader_wen_r    <= 1;

		in_ready_r	    <= 0;
		word_counter_r  <= 0;
		pixel_counter_r <= 0;
		img_data_r	    <= 0;
		barcode_start_r <= 0;

		out_data1_r     <= 0;
		out_data2_r     <= 0;
		out_data3_r     <= 0;
		out_data4_r     <= 0;
		out_addr1_r		<= 0;
		out_addr2_r		<= 0;
		out_addr3_r		<= 0;
		out_addr4_r		<= 0;
		out_valid1_r	<= 0;
		out_valid2_r	<= 0;
		out_valid3_r	<= 0;
		out_valid4_r	<= 0;

		stride_r        <= 0;
		dilation_r      <= 0;
		weight_r		<= 0;
		w_count_r       <= 0;
		conv_start_r    <= 0;

	end
	else begin
		state_r		    <= state_w;

		loader_wdata_r  <= loader_wdata_w;
		loader_addr_r   <= loader_addr_w;
		loader_cen_r    <= loader_cen_w;
		loader_wen_r    <= loader_wen_w;

		in_ready_r	    <= in_ready_w;
		word_counter_r  <= word_counter_w;
		pixel_counter_r <= pixel_counter_w;
		img_data_r	    <= img_data_w;
		barcode_start_r <= barcode_start_w;

		out_data1_r     <= out_data1_w;
		out_data2_r     <= out_data2_w;
		out_data3_r     <= out_data3_w;
		out_data4_r     <= out_data4_w;
		out_addr1_r		<= out_addr1_w;
		out_addr2_r		<= out_addr2_w;
		out_addr3_r		<= out_addr3_w;
		out_addr4_r		<= out_addr4_w;
		out_valid1_r	<= out_valid1_w;
		out_valid2_r	<= out_valid2_w;
		out_valid3_r	<= out_valid3_w;
		out_valid4_r	<= out_valid4_w;

		stride_r        <= stride_w;
		dilation_r      <= dilation_w;
		weight_r		<= weight_w;
		w_count_r       <= w_count_w;
	    conv_start_r    <= conv_start_w;

	end
end

endmodule
