// 回傳第一個為 0 的 bit 位置（從右到左掃描）
// 若全為 1，回傳 4'd15 作為 "none"
function automatic [3:0] find_first_zero(input logic [8:0] v);
    logic found;
    logic [3:0] pos;
    integer i;
    begin
        found = 1'b0;
        pos   = 4'd15;           // 15 表示沒空位
        // i=0 是最右邊 (LSB)，符合「0 是右邊」的定義
        for (i = 0; i < 9; i = i + 1) begin
            // 只在第一次看到 0 的時候記錄位置
            if (!found && (v[i] == 1'b0)) begin
                pos   = i[3:0];
                found = 1'b1;
            end
        end
        return pos;
    end
endfunction


// Return absolute coordinates for each kernel index 0–8
function automatic void d1_kernel_index_to_xy(
    input  [3:0]  idx,             // 0~8
    input  [5:0]  cur_x, cur_y,    // current kernel center
    output [5:0]  abs_x, abs_y
);
    begin
        case (idx)
            4'd0: begin abs_x = cur_x - 1; abs_y = cur_y - 1; end
            4'd1: begin abs_x = cur_x;     abs_y = cur_y - 1; end
            4'd2: begin abs_x = cur_x + 1; abs_y = cur_y - 1; end
            4'd3: begin abs_x = cur_x - 1; abs_y = cur_y;     end
            4'd4: begin abs_x = cur_x;     abs_y = cur_y;     end
            4'd5: begin abs_x = cur_x + 1; abs_y = cur_y;     end
            4'd6: begin abs_x = cur_x - 1; abs_y = cur_y + 1; end
            4'd7: begin abs_x = cur_x;     abs_y = cur_y + 1; end
            4'd8: begin abs_x = cur_x + 1; abs_y = cur_y + 1; end
            default: begin abs_x = cur_x; abs_y = cur_y; end
        endcase
    end
endfunction

function automatic void d2_kernel_index_to_xy(
    input  [3:0]  idx,             // 0~8
    input  [5:0]  cur_x, cur_y,    // current kernel center
    output [5:0]  abs_x, abs_y
);
    begin
        case (idx)
            4'd0: begin abs_x = cur_x - 2; abs_y = cur_y - 2; end
            4'd1: begin abs_x = cur_x;     abs_y = cur_y - 2; end
            4'd2: begin abs_x = cur_x + 2; abs_y = cur_y - 2; end
            4'd3: begin abs_x = cur_x - 2; abs_y = cur_y;     end
            4'd4: begin abs_x = cur_x;     abs_y = cur_y;     end
            4'd5: begin abs_x = cur_x + 2; abs_y = cur_y;     end
            4'd6: begin abs_x = cur_x - 2; abs_y = cur_y + 2; end
            4'd7: begin abs_x = cur_x;     abs_y = cur_y + 2; end
            4'd8: begin abs_x = cur_x + 2; abs_y = cur_y + 2; end
            default: begin abs_x = cur_x; abs_y = cur_y; end
        endcase
    end
endfunction


// 飽和到 0..255（輸入用 20-bit 有號，夠用）
function automatic [7:0] sat_u8(input signed [19:0] v);
    if (v < 0)           sat_u8 = 8'd0;
    else if (v > 255)    sat_u8 = 8'd255;
    else                 sat_u8 = v[7:0];
endfunction

// 依小數位數做四捨五入到最接近整數，ties away from zero，再飽和到 0..255
function automatic [7:0] round_nearest_sat_u8
(
    input  signed [19:0] acc,        // 你的加總值
    input  int unsigned  FRAC_BITS   // 例：8
);
    localparam int W = 20;
    logic signed [W-1:0] half;
    logic signed [W-1:0] rounded;
begin
    if (FRAC_BITS == 0) begin
        rounded = acc;
    end else begin
        half    = $signed(20'sd1) <<< (FRAC_BITS-1);  // 0.5 的刻度
        // 四捨五入：正數 +half、負數 -half，再做算術右移
        if (acc >= 0)
            rounded = (acc + half) >>> FRAC_BITS;
        else
            rounded = (acc - half) >>> FRAC_BITS;
    end

    // 飽和到 0..255（輸出是無號 8 位）
    if (rounded < 0)          round_nearest_sat_u8 = 8'd0;
    else if (rounded > 255)   round_nearest_sat_u8 = 8'd255;
    else                      round_nearest_sat_u8 = rounded[7:0];
end
endfunction

module ConvCore (
    input         i_clk,
    input         i_rst_n,
    input         i_start,        
    // Input parameters 
    input  [1:0]  i_stride,
    input  [1:0]  i_dilation,
    input  [71:0] i_weight,
    // SRAM read (input feature map)
    output [11:0] o_addr,
    output        o_cen,  // Set 0 to read
    input  [7:0]  i_in_data,
    // Output , 1 byte ervery time
    output        o_out_valid,
    output [7:0]  o_out_data,
    // Finish
    output        o_finish
);

// --------------------------------------------------------------------------
// Parameters 
// --------------------------------------------------------------------------
typedef enum logic [2:0]{
	S_IDLE,
	S_READ,     // Read data from SRAM
	S_CALC,     // Calculate result for current address
	S_WRITE,    // Write data back every 4 pixels
	S_DONE
} state_t;

typedef enum logic [1:0]{
    MODE_S1_D1,
    MODE_S1_D2,
    MODE_S2_D1,
    MODE_S2_D2
} reuse_mode_t;

parameter int FRAC_BITS = 7;
// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
state_t state_r, state_w;
reuse_mode_t reuse_mode;

logic [5:0] cur_x_r, cur_x_w;
logic [5:0] cur_y_r, cur_y_w; // The center current kernal
logic [5:0] x_r    , x_w;
logic [5:0] y_r    , y_w;     // SRAM reading address
logic [8:0] valid_map_r, valid_map_w; // 九宮格每個位置是否已經儲存該存的值
logic [3:0] first_zero_index;         // 九宮格中第一個為 0 的位置
logic [3:0] sending_idx_r, sending_idx_w;
logic [3:0] reading_idx_r, reading_idx_w;

logic [7:0] kernal_r[0:8], kernal_w[0:8]; 
logic [7:0] weight  [0:8];
logic [7:0] out_data_r, out_data_w;

integer i;

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------

assign weight[0]  = i_weight[71 -: 8];
assign weight[1]  = i_weight[63 -: 8];
assign weight[2]  = i_weight[55 -: 8];
assign weight[3]  = i_weight[47 -: 8];
assign weight[4]  = i_weight[39 -: 8];
assign weight[5]  = i_weight[31 -: 8];
assign weight[6]  = i_weight[23 -: 8];
assign weight[7]  = i_weight[15 -: 8];
assign weight[8]  = i_weight[7  -: 8];

assign o_addr      = {y_r, x_r};
assign o_cen       = 0;
assign o_out_data  = out_data_r;
assign o_out_valid = (state_r == S_WRITE);
assign o_finish    = (state_r == S_DONE);

// ---------------------------------------------------------------------------
// Finite State Machine 
// ---------------------------------------------------------------------------
always @(*) begin
    state_w = state_r;
    case (state_r)
        S_IDLE: begin
            if (i_start)        state_w = S_READ;
        end
        S_READ: begin
            if (&(valid_map_r)) state_w = S_CALC;
        end
        S_CALC: begin
                                state_w = S_WRITE;
        end
        S_WRITE: begin
            if (((i_stride == 1) && (cur_x_r == 6'd63) && (cur_y_r == 6'd63)) ||
               ((i_stride == 2) && (cur_x_r == 6'd62) && (cur_y_r == 6'd62)))    state_w = S_DONE;
            else                                          state_w = S_READ;
        end       
    endcase
end

always @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r <= S_IDLE;
	end
	else begin
		state_r <= state_w;
	end
end
// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------

// Memory address (coordinates)
always @(*) begin
    // Default value
    x_w         = x_r;
    y_w         = y_r;
    kernal_w    = kernal_r;
    valid_map_w = valid_map_r;
    first_zero_index = 4'd0;

    sending_idx_w = 4'd15;
    reading_idx_w = 4'd15;    

    if (state_r == S_READ) begin
        // At first cycle, every index is not stored
        // Determine which indexes don't need to read sram according to the center 
        if (valid_map_r == 9'd0) begin
            if  (((i_dilation == 1) && (cur_x_r == 6'd0))||((i_dilation == 2) && (cur_x_r == 6'd0 || cur_x_r == 6'd1))) begin
                // Ignore the left column
                valid_map_w[0] = 1'b1;
                valid_map_w[3] = 1'b1;
                valid_map_w[6] = 1'b1;
                kernal_w   [0] = 1'b0; 
                kernal_w   [3] = 1'b0; 
                kernal_w   [6] = 1'b0; 
            end 
            else if (((i_dilation == 1) && (cur_x_r == 6'd63))||((i_dilation == 2) && (cur_x_r == 6'd62 || cur_x_r == 6'd63))) begin
                // Ignore the right column
                valid_map_w[2] = 1'b1;
                valid_map_w[5] = 1'b1;
                valid_map_w[8] = 1'b1;
                kernal_w   [2] = 1'b0; 
                kernal_w   [5] = 1'b0; 
                kernal_w   [8] = 1'b0;                                                
            end   

            if (((i_dilation == 1) && (cur_y_r == 6'd0))||((i_dilation == 2) && (cur_y_r == 6'd0 || cur_y_r == 6'd1))) begin
                // Ignore the above row
                valid_map_w[0] = 1'b1;
                valid_map_w[1] = 1'b1;
                valid_map_w[2] = 1'b1;
                kernal_w   [0] = 1'b0; 
                kernal_w   [1] = 1'b0; 
                kernal_w   [2] = 1'b0; 
            end 
            else if (((i_dilation == 1) && (cur_y_r == 6'd63))||((i_dilation == 2) && (cur_y_r == 6'd62 || cur_y_r == 6'd63))) begin
                // Ignore the down row
                valid_map_w[6] = 1'b1;
                valid_map_w[7] = 1'b1;
                valid_map_w[8] = 1'b1;
                kernal_w   [6] = 1'b0; 
                kernal_w   [7] = 1'b0; 
                kernal_w   [8] = 1'b0;                                                
            end    

            // Determine the first reading address 
            first_zero_index = find_first_zero(valid_map_w);
            if      (i_dilation == 1) d1_kernel_index_to_xy(first_zero_index, cur_x_r, cur_y_r, x_w, y_w);
            else if (i_dilation == 2) d2_kernel_index_to_xy(first_zero_index, cur_x_r, cur_y_r, x_w, y_w);
            sending_idx_w = first_zero_index;
            valid_map_w[sending_idx_r] = 1'b1;
            reading_idx_w = 4'd15;
        end
        else begin
            // We already have some valid pixels; continue fetching missing ones
            if (|(~valid_map_r)) begin        
                valid_map_w[sending_idx_r] = 1'b1;
                first_zero_index = find_first_zero(valid_map_w);
                if      (i_dilation == 1) d1_kernel_index_to_xy(first_zero_index, cur_x_r, cur_y_r, x_w, y_w);
                else if (i_dilation == 2) d2_kernel_index_to_xy(first_zero_index, cur_x_r, cur_y_r, x_w, y_w);
                sending_idx_w = first_zero_index;
            end
            reading_idx_w = sending_idx_r;

            if (reading_idx_r != 4'd15) begin
                kernal_w[reading_idx_r] = i_in_data;
            end
        end
    end 
    else if ((state_r == S_IDLE) || (state_r == S_WRITE)) begin
        // Reset 
        valid_map_w = 9'd0;
        for (int i = 0; i < 9; i++) begin
            kernal_w[i] = 8'd0;
        end
        sending_idx_w = 4'd15;
        reading_idx_w = 4'd15;  
    end
end
// ===== 在 S_CALC 狀態使用 =====
logic signed [15:0] w0,w1,w2,w3,w4,w5,w6,w7,w8;  // 權重 sign-extend
logic        [7:0]  x0,x1,x2,x3,x4,x5,x6,x7,x8;  // 像素
logic signed [15:0] p0,p1,p2,p3,p4,p5,p6,p7,p8;  // 單項乘積
logic signed [19:0] acc;                         // 9 項加總

// 像素 8u
always @(*) begin
    out_data_w = out_data_r;

    x0=kernal_r[0]; x1=kernal_r[1]; x2=kernal_r[2];
    x3=kernal_r[3]; x4=kernal_r[4]; x5=kernal_r[5];
    x6=kernal_r[6]; x7=kernal_r[7]; x8=kernal_r[8];

    // 權重 8s -> 16s
    w0=$signed(weight[0]); w1=$signed(weight[1]); w2=$signed(weight[2]);
    w3=$signed(weight[3]); w4=$signed(weight[4]); w5=$signed(weight[5]);
    w6=$signed(weight[6]); w7=$signed(weight[7]); w8=$signed(weight[8]);

    // 乘法：有號×（把像素當正數）
    p0 = w0 * $signed({1'b0,x0});
    p1 = w1 * $signed({1'b0,x1});
    p2 = w2 * $signed({1'b0,x2});
    p3 = w3 * $signed({1'b0,x3});
    p4 = w4 * $signed({1'b0,x4});
    p5 = w5 * $signed({1'b0,x5});
    p6 = w6 * $signed({1'b0,x6});
    p7 = w7 * $signed({1'b0,x7});
    p8 = w8 * $signed({1'b0,x8});

    // 9 項加總（20-bit 夠用）
    acc = $signed(p0)+$signed(p1)+$signed(p2)+$signed(p3)+$signed(p4)
    + $signed(p5)+$signed(p6)+$signed(p7)+$signed(p8);

    if (state_r == S_CALC)
        out_data_w = round_nearest_sat_u8(acc, FRAC_BITS);  // FRAC_BITS=8

end



// Output signals and next center location
always @(*) begin
    // Default
    cur_x_w = cur_x_r;
    cur_y_w = cur_y_r;
    
    if (state_r == S_WRITE) begin
        if (i_stride == 1) begin
            if (cur_x_r == 6'd63) begin
                cur_x_w = 6'd0;
                cur_y_w = cur_y_r + 1;
            end
            else begin
                cur_x_w = cur_x_r + 1;
                cur_y_w = cur_y_r;
            end
        end
        else if (i_stride == 2) begin
            if (cur_x_r == 6'd62) begin
                cur_x_w = 6'd0;
                cur_y_w = cur_y_r + 2;
            end
            else begin
                cur_x_w = cur_x_r + 2;
                cur_y_w = cur_y_r;
            end            
        end
    end
end




// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin

        cur_x_r        <= 6'd0;
        cur_y_r        <= 6'd0;

        x_r            <= 6'd0;
        y_r            <= 6'd0;

        valid_map_r    <= 9'd0;
        sending_idx_r  <= 4'd15;
        reading_idx_r  <= 4'd15;

        out_data_r     <= 8'd0;

        for (i = 0; i < 9; i = i + 1)
            kernal_r[i] <= 8'd0;
    end
    else begin

        cur_x_r        <= cur_x_w;
        cur_y_r        <= cur_y_w;

        x_r            <= x_w;
        y_r            <= y_w;

        valid_map_r    <= valid_map_w;
        sending_idx_r  <= sending_idx_w;
        reading_idx_r  <= reading_idx_w;

        out_data_r     <= out_data_w;

        for (i = 0; i < 9; i = i + 1)
            kernal_r[i] <= kernal_w[i];
    end
end

endmodule



