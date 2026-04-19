module alu #(
    parameter INST_W = 4,
    parameter INT_W  = 6,
    parameter FRAC_W = 10,
    parameter DATA_W = INT_W + FRAC_W
)(
    input                      i_clk,
    input                      i_rst_n,

    input                      i_in_valid,
    output                     o_busy,
    input         [INST_W-1:0] i_inst,
    input  signed [DATA_W-1:0] i_data_a,
    input  signed [DATA_W-1:0] i_data_b,

    output                     o_out_valid,
    output reg    [DATA_W-1:0] o_data
);
//----------------------------Paramater--------------------------------//
// Instructions
parameter ADD  = 4'b0000;
parameter SUB  = 4'b0001;
parameter MAC  = 4'b0010;
parameter TAY  = 4'b0011;
parameter GRAY = 4'b0100;
parameter LRCW = 4'b0101;
parameter RROT = 4'b0110;
parameter CLZR = 4'b0111;
parameter RM4  = 4'b1000;
parameter MATR = 4'b1001;
// States
parameter S_IDLE     = 3'b000;
parameter S_SIMPLE   = 3'b001;
parameter S_MTX_LOAD = 3'b010;
parameter S_MTX_OUT  = 3'b011;

//--------------------------Wire, Reg Declaration----------------------//
// For FSM
reg  [2:0] state_w;
reg  [2:0] state_r;
// Store the input values of the previous cycle
reg  [INST_W-1:0] inst_r;
reg signed [DATA_W-1:0] data_a_r;
reg signed [DATA_W-1:0] data_b_r;
// Accumulater for MAC result
reg signed [35:0] acc_w;
reg signed [35:0] acc_r; 
// For Matrix Transose Operation
reg [15:0] Matrix_r [0:7]; 
reg [2:0] load_counter_w, out_counter_w;
reg [2:0] load_counter_r, out_counter_r;


//--------------------------Assignment---------------------------------//

assign o_busy  = (state_r == S_SIMPLE)  ||
                 (state_r == S_MTX_OUT);

assign o_out_valid = (state_r == S_SIMPLE) ||
                     (state_r == S_MTX_OUT);

//-------------------------Finite State Machine------------------------//
always @(*) begin
    state_w = state_r;
    case (state_r)
        S_IDLE: begin
            if (i_in_valid) begin
                if (i_inst == MATR) state_w = S_MTX_LOAD;
                else                state_w = S_SIMPLE;
            end
        end
        S_MTX_LOAD: begin
            if ((load_counter_r == 3'd7) && (i_in_valid)) state_w = S_MTX_OUT;
        end
        S_MTX_OUT: begin
            if (out_counter_r == 3'd7) state_w = S_IDLE;
        end
        S_SIMPLE: begin
            state_w = S_IDLE;
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



//-------------------------Combinational Logic-------------------------//
// MAC accumulater updating logic
always @( *) begin
    acc_w = acc_r; // Default : hold the same value
    if (state_r == S_SIMPLE && inst_r == MAC) begin
        acc_w = MAC_acc(data_a_r, data_b_r, acc_r);
    end
end

// Counters for Matrix
always @( *) begin
    load_counter_w = load_counter_r;
    out_counter_w  = out_counter_r;
    if ((state_r == S_IDLE) && (i_in_valid) && (i_inst == MATR)) begin
        load_counter_w = 1;
    end
    else if ((state_r == S_MTX_LOAD) && (i_in_valid)) begin
        if (load_counter_r == 3'd7)
            load_counter_w = 3'd0;   // 收滿一輪
        else
            load_counter_w = load_counter_r + 1;
    end

    if ((state_r == S_MTX_LOAD) && (state_w == S_MTX_OUT)) begin
        out_counter_w = 3'd0;
    end
    else if (state_r == S_MTX_OUT) begin
        if (out_counter_r == 3'd7)
            out_counter_w = 3'd0;    // 輸完一輪
        else
            out_counter_w = out_counter_r + 1;
    end
end

// Output data logic
integer row;
always @(*) begin
    o_data = 16'b0;
    if (state_r == S_SIMPLE) begin
        case (inst_r)
            ADD:  o_data = Signed_Addition(data_a_r, data_b_r);
            SUB:  o_data = Signed_Subtraction(data_a_r, data_b_r);
            MAC:  o_data = MAC_out(data_a_r, data_b_r, acc_r);
            TAY:  o_data = Taylor_out(data_a_r);
            GRAY: o_data = Bin2Gray(data_a_r);
            LRCW: o_data = LRCW_f(data_a_r, data_b_r);
            RROT: o_data = RROT_f(data_a_r, data_b_r[3:0]);
            CLZR: o_data = CLZR_f(data_a_r);
            RM4:  o_data = RM4_f(data_a_r, data_b_r);
        endcase
    end
    else if (state_r == S_MTX_OUT) begin
        for (row = 0; row < 8; row = row + 1)
            o_data[2*row +: 2] = Matrix_r[7-row][15-2*out_counter_r -: 2];
    end
end

//-------------------------------Sequential Logic--------------------------------//
// Fetch Input
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        inst_r   <= 0;
        data_a_r <= 0;
        data_b_r <= 0;
    end
    else if (i_in_valid) begin
        inst_r   <= i_inst;
        data_a_r <= i_data_a;
        data_b_r <= i_data_b;
    end    
end

// Accumulater for MAC and Counters for MTX
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        acc_r <= 0;
        load_counter_r <= 0;
        out_counter_r  <= 0;
    end
    else begin
        acc_r <= acc_w;
        load_counter_r <= load_counter_w;
        out_counter_r  <= out_counter_w;
    end
end

// Load Matrix 
integer i;
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        for (i=0; i<8; i=i+1)
            Matrix_r[i] <= 16'b0;
    end
    else begin
        // Idle 狀態時接收第一筆
        if ((state_r == S_IDLE) && (i_in_valid) && (i_inst == MATR)) begin
            Matrix_r[0] <= i_data_a;
        end
        // Load 狀態時接收後續
        else if ((state_r == S_MTX_LOAD) && (i_in_valid)) begin
            Matrix_r[load_counter_r] <= i_data_a;
        end
    end
end
 

//-----------------------------------Function-------------------------------------//

// Deal with the bit saturation for add and sub instruction 
function automatic signed [15:0] saturation_32to16;
    input signed [31:0] x;
    localparam signed [31:0] MAX = 32'sh00007FFF;
    localparam signed [31:0] MIN = -32'sh00008000;
    begin
        if (x > MAX)      saturation_32to16 = MAX[15:0];
        else if (x < MIN) saturation_32to16 = MIN[15:0];
        else              saturation_32to16 = x[15:0];
    end
endfunction

// Signed Addition
function automatic signed [15:0] Signed_Addition;
    input signed [15:0] a, b;
    reg   signed [16:0] sum17;
    begin
        sum17 = $signed({a[15], a}) + $signed({b[15], b}); // 17-bit
        if (sum17 >  $signed(17'sh07FFF)) Signed_Addition = 16'sh7FFF;
        else if (sum17 < $signed(17'sh18000)) Signed_Addition = -16'sh8000;
        else Signed_Addition = sum17[15:0];
    end
endfunction

// Signed Subtraction
function automatic signed [15:0] Signed_Subtraction;
    input signed [15:0] a, b;
    reg   signed [16:0] diff17;
    begin
        diff17 = $signed({a[15], a}) - $signed({b[15], b});
        if (diff17 >  $signed(17'sh07FFF)) Signed_Subtraction = 16'sh7FFF;
        else if (diff17 < $signed(17'sh18000)) Signed_Subtraction = -16'sh8000;
        else Signed_Subtraction = diff17[15:0];
    end
endfunction

// Update value for the accumulater for MAC operation
// Update value for the accumulator for MAC operation
function automatic signed [35:0] MAC_acc;
    input signed [15:0] a, b;
    input signed [35:0] acc;
    reg   signed [31:0] prod32;
    reg   signed [35:0] prod36;
    reg   signed [36:0] sum37; // one extra bit for overflow
    begin
        // 16x16 multiply
        prod32 = $signed(a) * $signed(b);
        prod36 = {{4{prod32[31]}}, prod32}; // sign-extend to 36-bit

        // add with accumulator
        sum37  = $signed({acc[35], acc}) + $signed({prod36[35], prod36});
        // equivalent: sum37 = $signed(acc) + $signed(prod36);

        // saturation for 36-bit signed range [-2^35, 2^35-1]
        if (sum37 >  $signed(37'sd34359738367))      // +2^35-1
            MAC_acc = 36'sd34359738367;
        else if (sum37 < $signed(-37'sd34359738368)) // -2^35
            MAC_acc = -36'sd34359738368;
        else
            MAC_acc = sum37[35:0];
    end
endfunction

// Output data value of the MAC operation
function automatic signed [15:0] MAC_out;
    input signed [15:0] data_a;
    input signed [15:0] data_b;
    input signed [35:0] acc_old;
    localparam signed [15:0] MAX = 16'sh7FFF;
    localparam signed [15:0] MIN = -16'sh8000;
    reg signed [35:0] acc, acc_round;
    reg signed [25:0] rounded;
    begin
        acc = MAC_acc(data_a, data_b, acc_old);
        acc_round = acc + 36'sd512;
        rounded = acc_round[35:10];
        if (rounded > $signed(MAX)) MAC_out = MAX;
        else if (rounded < $signed(MIN)) MAC_out = MIN;
        else MAC_out = rounded[15:0];        
    end
endfunction

// Taylor Expansion of Sin: y ≈ x - x^3/6 + x^5/120
// in : data_a (Q6.10, 16-bit signed)
// out: Q6.10, 16-bit signed (final rounding + saturation only)
function automatic signed [15:0] Taylor_out;
    input  signed [15:0] data_a;

    // Q6.10 coefficients (ties→+∞ 取整)
    localparam signed [15:0] C_INV6_Q6_10   = 16'b1111_1111_0101_0101; // ≈ 1/6
    localparam signed [15:0] C_INV120_Q6_10 = 16'b0000_0000_0000_1001; // ≈ 1/120

    localparam signed [15:0] MAX16 = 16'sh7FFF;
    localparam signed [15:0] MIN16 = -16'sh8000;

    // powers (保持最大精度，不先縮位)
    reg signed [31:0] x2_q12_20;   // x^2 : Q12.20
    reg signed [47:0] x3_q18_30;   // x^3 : Q18.30
    reg signed [79:0] x5_q30_50;   // x^5 : Q30.50

    // 乘係數（Q6.10）
    reg signed [63:0] t3_prod;     // 48+16=64 Q24.40
    reg signed [95:0] t5_prod;     // 80+16=96 Q36.60

    // 對齊到 Q16.20（36-bit）— 只做對齊，不做 rounding
    reg signed [35:0] x_q16_20;
    reg signed [63:0] t3_shift;    // 暫存右移後的大寬度值
    reg signed [95:0] t5_shift;
    reg signed [35:0] t3_q16_20;
    reg signed [35:0] t5_q16_20;

    // 加總（用稍寬的加總避免進位丟失）
    reg signed [37:0] sum_q16_20;  // 36-bit 加總 → 多留 2 bit
    reg signed [37:0] r_sum;       // 加 half LSB 做最終 rounding
    reg signed [25:0] shr26;       // >>>10 回 Q6.10 的 26-bit 暫存

    begin
        // 1) 次方（最大精度）
        x2_q12_20 = $signed(data_a) * $signed(data_a);       // Q12.20
        x3_q18_30 = $signed(x2_q12_20) * $signed(data_a);    // Q18.30
        x5_q30_50 = $signed(x3_q18_30) * $signed(x2_q12_20); // Q30.50

        // 2) 乘上 Q6.10 係數
        t3_prod = $signed(x3_q18_30) * $signed(C_INV6_Q6_10);      // frac 50
        t5_prod = $signed(x5_q30_50) * $signed(C_INV120_Q6_10);    // frac 70

        // 3) 對齊到 Q16.20（36-bit）
        //    x: Q6.10 → Q16.20 = sign-extend + <<10
        x_q16_20 = { {10{data_a[15]}}, data_a, 10'b0 };  // 36-bit, Q16.20

        t3_shift   = $signed(t3_prod) >>> 20;            
        t3_q16_20  = t3_shift[35:0];                     // 取 LSB 36-bit（Q16.20）

        t5_shift   = $signed(t5_prod) >>> 40;            // 100→(仍 100寬)
        t5_q16_20  = t5_shift[35:0];                     // 取 LSB 36-bit（Q16.20）

        // 4) 加總（仍 Q16.20，不做中途飽和或 rounding）
        sum_q16_20 =  $signed({{2{x_q16_20[35]}},  x_q16_20})
                     +$signed({{2{t3_q16_20[35]}}, t3_q16_20})
                     +$signed({{2{t5_q16_20[35]}}, t5_q16_20});

        // 5) 最終 round (ties→+∞) + 回 Q6.10
        r_sum = sum_q16_20 + 38'sd512;   // +2^9
        shr26 = r_sum[35:10];            // >>>10 → Q6.10（26-bit）

        // 6) 16-bit 飽和
        if (shr26 >  $signed(MAX16))      Taylor_out = MAX16;
        else if (shr26 < $signed(MIN16))  Taylor_out = MIN16;
        else                               Taylor_out = shr26[15:0];
    end
endfunction

// Binary to Gray Code
function automatic [15:0] Bin2Gray;
    input [15:0] data_a;
    begin
        Bin2Gray = data_a ^ (data_a >> 1);
    end
endfunction

// LRCW: Left shift + Reverse Coding + Weight
function automatic [15:0] LRCW_f;
    input [15:0] data_a;
    input [15:0] data_b;
    reg   [4:0]  cpop_a;
    reg   [15:0] b_shift;
    reg   [15:0] b_aligned;
    reg   [15:0] inv_mask;
    reg   [15:0] inv;
    reg   [16:0] sum17; 
    begin
        // 1. 計算 popcount
        cpop_a  = CPOP(data_a);

        // 2. b 左移 cpop_a
        b_shift = data_b << cpop_a;

        // 3. 先把 data_b 的高 cpop_a bits 對齊到 LSB
        b_aligned = data_b >> (16 - cpop_a);

        // 4. 建立一個 mask，低 cpop_a bits = 1，其餘 = 0
        if (cpop_a == 0)
            inv_mask = 16'b0;
        else
            inv_mask = (16'hFFFF >> (16 - cpop_a));

        // 5. 把對齊後的 bits 反相，再用 mask 取出
        inv = (~b_aligned) & inv_mask;

        sum17  = b_shift + inv;   // 先算出 17-bit
        LRCW_f = sum17[15:0];    // 再截斷成 16-bit
    end
endfunction

function automatic [4:0] CPOP;
    input [15:0] data_a;
    reg [4:0] count;
    integer i;
    begin
        count = 0;
        for (i = 0; i < 16; i = i + 1) begin
            count = count + data_a[i];
        end
        CPOP = count;
    end
endfunction

// Right Rotation
function automatic [15:0] RROT_f;
    input [15:0] data_a;
    input [3:0]  shamt;   // shift amount, 0~15
    begin
        if (shamt == 0) begin
            RROT_f = data_a;
        end
        else begin
            // 右移 shamt，再把被移掉的 shamt bits 接到左邊
            RROT_f = (data_a >> shamt) | (data_a << (16 - shamt));
        end
    end
endfunction

// Counting leading zeros
function automatic [15:0] CLZR_f;
    input [15:0] data_a;
    integer i;
    reg found;
    begin
        CLZR_f = 16;   // 預設：全是 0 → leading zeros = 16
        found  = 0;
        for (i = 15; i >= 0; i = i - 1) begin
            if (!found && data_a[i]) begin
                CLZR_f = 15 - i;  // 記錄第一個 1 出現的位置
                found  = 1;       // 鎖住，不再更新
            end
        end
    end
endfunction

// Reverse Match4
function automatic [15:0] RM4_f;
    input [15:0] data_a;
    input [15:0] data_b;
    integer i;
    begin
        RM4_f = 16'b0;
        for (i = 0; i <= 12; i = i + 1) begin
            if (data_a[i +: 4] == data_b[15-i -: 4]) begin
                RM4_f[i] = 1;
            end
            else begin
                RM4_f[i] = 0;
            end
        end
    end
endfunction


endmodule
