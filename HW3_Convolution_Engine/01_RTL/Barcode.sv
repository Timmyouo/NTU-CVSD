module Barcode (
    input        i_clk,
    input        i_rst_n,
    input        i_start,       
    // SRAM interface (Read-only)
    output [11:0] o_sram_addr,
    output        o_sram_cen,    // Set 0 to read, fetch data at next cycle
    input  [7:0]  i_sram_data,   // Only LSB will be used
    // Output parameters
    output reg [1:0] o_stride,   // Limited to 1, 2
    output reg [1:0] o_dilation, // Limited to 1, 2
    output reg       o_invalid,  // Invalid configuration
    output reg       o_finish
);

/*
運作方式：
用x, y座標來運算，讀SRAM時將座標 mapping 到正確位址。

從最左上角開始，每次讀長度22 bits 的window做判斷 （因為 kernal 固定為3），讀完 shift right 存下個bit，
若整行讀完則重新讀取下一行開頭的22 bits。下一行可以隔個五行後之類的，例如現在讀第一行，則接下來讀第六行，因
為會做 double check。

若長度22 bits match，則存取下面幾行平行同位置的window做確認，讀個五行好了 22 * 5。如果沒中就繼續讀。如果
中了則跳到下面的行數去解碼，避免第一行是碰巧一樣。

往右讀22 bits，看是否對應到 1 或 2 的 pattern。如果中了則輸出結果。
如果是不合法的 pattern ，則一樣輸出但是將 invalid 拉起來。
*/

// ---------------------------------------------------------------------------
// Parameters 
// --------------------------------------------------------------------------
// Decode patterns
localparam  CODE_START = 11'b 110_1001_1100;
localparam  CODE_01    = 11'b 110_0110_1100;
localparam  CODE_02    = 11'b 110_0110_0110;
localparam  CODE_03    = 11'b 100_1001_1000;

typedef enum logic [2:0]{
	S_IDLE,
	S_SCAN,
	S_CHECK,
	S_DECODE,
	S_DONE
} state_t;

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
state_t      state_r    , state_w;

logic        bit_in;                  // Current input bit from sram
logic [21:0] window_r   , window_w;   // 22 bits sliding window 
logic [5:0]  x_r        , x_w;
logic [5:0]  y_r        , y_w;        // 0~63 , decide current reading address

// Match flag
logic        window_matched;

// For check state
logic [4:0]  check_counter_r, check_counter_w;
logic [3:0]  compare_index;
logic        check_fail, check_pass;

// For decoding
logic [4:0]  decode_counter_r, decode_counter_w;
logic [21:0] decode_pattern;
logic        decode_finish;

// Output regs
logic [1:0] stride_r  , stride_w;
logic [1:0] dilation_r, dilation_w;
logic [1:0] invalid_r , invalid_w;

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
assign o_sram_addr    = {y_r, x_r};     // Equals (y_r * 64 + x_r)  Mapping coordinates to memory address
assign o_sram_cen     = 1'b0;           // Always reading
assign bit_in         = i_sram_data[0]; // LSB of input data
assign window_matched = ({window_r[20:0], bit_in} == {CODE_START, CODE_03}); 
assign no_match       = (state_r == S_SCAN) && (y_r == 6'd2) && (x_r == 6'd0) && (!window_matched);

assign compare_index  = (check_counter_r > 11) ? (check_counter_r - 12) : (check_counter_r - 1); 
assign check_fail     = ((state_r == S_CHECK) && (check_counter_r != 0)  && (bit_in != window_r[21 - compare_index]));
assign check_pass     = ((state_r == S_CHECK) && (check_counter_r == 22) && (bit_in == window_r[21 - compare_index]));

assign decode_finish  = ((state_r == S_DECODE)&& (decode_counter_r == 21));
assign decode_pattern = {window_r[20:0], bit_in};

assign o_stride       = stride_r;
assign o_dilation     = dilation_r;
assign o_invalid      = invalid_r;
assign o_finish       = (state_r  == S_DONE);

// ---------------------------------------------------------------------------
// Finite State Machine 
// ---------------------------------------------------------------------------
always @(*) begin
	state_w = state_r;
	case (state_r)
		S_IDLE:  begin
            if      (i_start)        state_w = S_SCAN;
        end
        S_SCAN:  begin
            if      (window_matched) state_w = S_CHECK;
            else if (no_match)       state_w = S_DONE;
        end
        S_CHECK: begin
            if      (check_fail)     state_w = S_SCAN;
            else if (check_pass)     state_w = S_DECODE;
        end
        S_DECODE: begin
            if      (decode_finish)  state_w = S_DONE;
        end
		S_DONE: begin
			state_w = S_IDLE;
		end 
	endcase
end

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------

always @(*) begin
    // Default
    x_w              = x_r;
    y_w              = y_r;
    window_w         = window_r;
    check_counter_w  = check_counter_r;
    decode_counter_w = decode_counter_r;

    stride_w         = stride_r;
    dilation_w       = dilation_r;
    invalid_w        = invalid_r;

    if (state_r == S_SCAN) begin
        if (window_matched) begin
            // Remember current x, y and window , in case we need to come back 
            window_w  = {window_r[20:0], bit_in};       
            // Change x and y to the first index of next row of matched window (x-22,y+1)
            if (x_r == 0) begin
                // Exception
                x_w = 7;
                y_w = y_r;
            end else begin
                x_w = x_r - 22;
                y_w = y_r + 1;
            end
            // Reset check_counter
            check_counter_w = 0;
        end
        else if (no_match) begin
            invalid_w = 1;
        end
        else begin
            if (x_r == 6'd0) begin
                x_w      = x_r + 1;
                y_w      = y_r;
                window_w = 22'd0;
            end
            else if (x_r == 6'd28) begin
                // Next (11 + 11 + 13) 35 bits for paramaters and stop code
                // Only need to check startcode and kernal = 3 until index 28
                x_w      = 6'd0;
                y_w      = y_r + 6;
                window_w = {window_r[20:0], bit_in};
            end
            else begin
                x_w      = x_r + 1;
                y_w      = y_r;
                window_w = {window_r[20:0], bit_in};
            end
        end
    end 
    // 二次確認
    else if (state_r == S_CHECK) begin
        // 看往下兩行的 start code 是否吻合
        // 用 counter 判斷現在位置
        if (check_counter_r == 0) begin
            // 資料下一回合才進來
            x_w             = x_r + 1;
            y_w             = y_r;
            check_counter_w = check_counter_r + 1;
        end 
        else if (check_counter_r == 5'd10) begin
            // 換行
            x_w             = x_r - 10;
            y_w             = y_r + 1;
            check_counter_w = check_counter_r + 1;
        end     
        else begin
            // 讀下個值
            x_w             = x_r + 1;
            y_w             = y_r;
            check_counter_w = check_counter_r + 1;               
        end

        if (check_fail) begin
        // Switch x, y back to scanning 
            x_w             = 0;
            y_w             = y_r; 
            window_w        = 22'd0;
            check_counter_w = 0;    
        end else if (check_pass) begin
        // Directly decode from the next bit of current x, y
            x_w              = x_r + 12;
            y_w              = y_r;
            window_w         = 22'd0; // Use window to store new patterns   
            check_counter_w  = 0;    
            decode_counter_w = 0;         
        end 


    end else if (state_r == S_DECODE) begin
        // 跟 check 不一樣，一開始 counter 為 0 時，第一筆就進來了
        if (decode_counter_r == 21) begin
            // Compare with real patterns
            invalid_w = 1;
            case (decode_pattern)
                {CODE_01, CODE_01}: begin
                    stride_w   = 2'd1;
                    dilation_w = 2'd1;
                    invalid_w  = 0;
                end
                {CODE_01, CODE_02}: begin
                    stride_w   = 2'd1;
                    dilation_w = 2'd2;  
                    invalid_w  = 0;                  
                end
                {CODE_02, CODE_01}: begin
                    stride_w   = 2'd2;
                    dilation_w = 2'd1; 
                    invalid_w  = 0;                   
                end
                {CODE_02, CODE_02}: begin
                    stride_w   = 2'd2;
                    dilation_w = 2'd2; 
                    invalid_w  = 0;                  
                end
            endcase
        end else begin
            x_w      = x_r + 1;
            y_w      = y_r;            
            window_w = {window_r[20:0], bit_in};
            decode_counter_w = decode_counter_r + 1;
        end
    end else if (state_r == S_DONE) begin
        // Reset all regs
        x_w              = 0;
        y_w              = 0;
        window_w         = 22'd0; 
        check_counter_w  = 0;
        decode_counter_w = 0;
        stride_w         = 2'd0;
        dilation_w       = 2'd0;
        invalid_w        = 0;
    end
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------

always @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r          <= S_IDLE;
        window_r         <= 0;
        x_r              <= 0;
        y_r              <= 0;
        check_counter_r  <= 0;
        decode_counter_r <= 0;
        stride_r         <= 0;
        dilation_r       <= 0;
        invalid_r        <= 0;
	end
	else begin
		state_r          <= state_w;
        window_r         <= window_w;
        x_r              <= x_w;
        y_r              <= y_w;
        check_counter_r  <= check_counter_w;
        decode_counter_r <= decode_counter_w;
        stride_r         <= stride_w;
        dilation_r       <= dilation_w;
        invalid_r        <= invalid_w;
	end
end

endmodule