
// Single-precision float multiply: o_y = a * b
// Policy (aligned with your fsub_sp):
// - Inputs classified; any NaN/Inf → invalid
// - Subnormal: exp_eff=1, mantissa no hidden-1
// - Exponent work: e = e_a_eff + e_b_eff - 127 (biased domain)
// - Normalize product (48-bit) → mant24 + G/R/S
// - Decide overflow/underflow BEFORE rounding (zero is not underflow)
// - Round to nearest-even (RN-E) with G/R/S
// - If invalid → o_y=32'h7FC0_0000 (qNaN), o_invalid=1
module fmul_sp (
    input  logic [31:0] i_a,
    input  logic [31:0] i_b,
    output logic [31:0] o_y,
    output logic        o_invalid
);
    // ---------------- Unpack A ----------------
    wire        s_a  = i_a[31];
    wire [7:0]  e_a  = i_a[30:23];
    wire [22:0] f_a  = i_a[22:0];

    // ---------------- Unpack B ----------------
    wire        s_b  = i_b[31];
    wire [7:0]  e_b  = i_b[30:23];
    wire [22:0] f_b  = i_b[22:0];

    // ---------------- Classify ----------------
    wire a_is_nan  = (e_a == 8'hFF) && (f_a != 0);
    wire a_is_inf  = (e_a == 8'hFF) && (f_a == 0);
    wire a_is_zero = (e_a == 8'h00) && (f_a == 0);
    // 次正規：exp=0 且 frac!=0
    wire a_is_subn = (e_a == 8'h00) && (f_a != 0);

    wire b_is_nan  = (e_b == 8'hFF) && (f_b != 0);
    wire b_is_inf  = (e_b == 8'hFF) && (f_b == 0);
    wire b_is_zero = (e_b == 8'h00) && (f_b == 0);
    wire b_is_subn = (e_b == 8'h00) && (f_b != 0);

    // 本作業規則：遇到 NaN/Inf 就視為 invalid（不做完整 IEEE 例外分類）
    wire special_invalid = a_is_nan | b_is_nan | a_is_inf | b_is_inf;

    // ---------------- Effective exponent & mantissa ----------------
    // subnormal 視為 exponent=1；mantissa 沒有 hidden 1
    wire [7:0]  e_a_eff = (e_a == 8'h00) ? 8'd1 : e_a;
    wire [7:0]  e_b_eff = (e_b == 8'h00) ? 8'd1 : e_b;
    wire [23:0] m_a     = (e_a == 8'h00) ? {1'b0, f_a} : {1'b1, f_a};
    wire [23:0] m_b     = (e_b == 8'h00) ? {1'b0, f_b} : {1'b1, f_b};

    // 結果符號
    wire s_res = s_a ^ s_b;

    // ---------------- Zero short-cut ----------------
    wire inputs_zero = a_is_zero | b_is_zero;

    // ---------------- 24x24 → 48-bit product ----------------
    wire [47:0] prod48 = m_a * m_b;

    // ---------------- Exponent work (biased) ----------------
    // true_sum_exp = (e_a-127)+(e_b-127) = e_a+e_b-254
    // biased back  = true_sum_exp + 127 = e_a + e_b - 127
    // 注意：我們用的是 e_eff（1..254）
    wire [9:0] exp_sum_biased = {2'b00, e_a_eff} + {2'b00, e_b_eff} - 10'd127; // 0..(254+254-127)=381

    // ---------------- Normalize product & extract mant24+GRS ----------------
    // prod48 範圍：
    //  - 若兩邊正常：m_a,m_b ∈ [1.0,2.0)，乘積 ∈ [1.0,4.0)
    //  - 最高兩位可能是：01.xx 或 10.xx / 11.xx
    // 若 prod48[47]==1 → ≥2.0，需要右移 1 位，exp+1
    // 否則用 prod48[46:...]，exp 不變
    logic [23:0] mant24_pre;  // 未四捨五入前的 1.xxx（含 hidden 1）
    logic        G, R, S;     // guard/round/sticky
    logic [9:0]  exp_work;    // 規範化後的 biased exponent

    always_comb begin
        if (prod48[47]) begin
            // ≥ 2.0 → 右移 1，exp+1
            mant24_pre = prod48[47:24];              // 24 bits
            G          = prod48[23];
            R          = prod48[22];
            S          = |prod48[21:0];
            exp_work   = exp_sum_biased + 10'd1;
        end else begin
            // [1.0, 2.0)
            mant24_pre = prod48[46:23];
            G          = prod48[22];
            R          = prod48[21];
            S          = |prod48[20:0];
            exp_work   = exp_sum_biased;
        end
    end

    // ---------------- Pre overflow / underflow (before rounding) ----------------
    // zero 不算 underflow
    wire is_zero_mag   = inputs_zero || (mant24_pre == 24'd0);
    wire overflow_pre  = (!is_zero_mag) && (exp_work > 10'd254);
    wire underflow_pre = (!is_zero_mag) && (exp_work < 10'd1);

    // ---------------- Round to nearest even (with G/R/S) ----------------
    logic [23:0] mant24;   // 四捨五入後 mantissa（可能進位到 2.0）
    logic [9:0]  exp_rnd;  // 四捨五入後 exponent（可能 +1）

    // RN-even 決策： 進位條件 = (G && (R|S)) || (G && !R && !S && mant24_pre[0])
    wire round_up = (G && (R | S)) || (G && !R && !S && mant24_pre[0]);
    logic carry;
    logic [23:0] mant24_sum;

    always_comb begin
        mant24  = mant24_pre;
        exp_rnd = exp_work;

        if (!is_zero_mag && !overflow_pre && !underflow_pre) begin
            if (round_up) begin
                {carry, mant24_sum} = mant24_pre + 24'd1;
                if (carry) begin
                    // mantissa 溢位 → 進位到 2.0 → 規範化成 1.000...
                    mant24  = 24'h800000;
                    exp_rnd = exp_rnd + 10'd1;
                end else begin
                    mant24 = mant24_sum;
                end
            end
        end
    end

    // ---------------- Pack / Output ----------------
    always_comb  begin
        o_invalid = 1'b0;
        o_y       = 32'd0;

        if (special_invalid || overflow_pre || underflow_pre) begin
            o_invalid = 1'b1;
            o_y       = 32'h7FC0_0000; // qNaN（題目僅檢狀態，數值給 NaN 較直觀）
        end else if (is_zero_mag) begin
            o_y = 32'd0;               // 0（符號不考）
        end else begin
            // 正常：exp_rnd ∈ [1..254]，mant24 = 1.xxxxx（含 hidden 1）
            // IEEE 存 frac 不存 hidden 1
            o_y = {s_res, exp_rnd[7:0], mant24[22:0]};
        end
    end

endmodule
