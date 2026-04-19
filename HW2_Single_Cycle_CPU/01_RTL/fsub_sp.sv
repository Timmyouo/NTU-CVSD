
// Single-precision FSUB: y = a - b
// - Round to nearest even (GRS)
// - Detect overflow/underflow BEFORE rounding -> o_invalid = 1
// - Treat NaN/Inf as invalid in this homework
module fsub_sp (
    input  [31:0] i_a,
    input  [31:0] i_b,
    output reg [31:0] o_y,
    output reg        o_invalid
);

    // ---------------- Unpack ----------------
    wire s_a = i_a[31];
    wire [7:0] e_a = i_a[30:23];
    wire [22:0] f_a = i_a[22:0];

    wire s_b0 = i_b[31];
    wire [7:0] e_b = i_b[30:23];
    wire [22:0] f_b = i_b[22:0];

    // b' = -b  (a - b == a + (-b))
    wire s_b = ~s_b0;

    // classify
    wire a_is_nan  = (e_a == 8'hFF) && (f_a != 0);
    wire a_is_inf  = (e_a == 8'hFF) && (f_a == 0);
    wire a_is_zero = (e_a == 0)     && (f_a == 0);
    wire a_is_subn = (e_a == 0)     && (f_a != 0);

    wire b_is_nan  = (e_b == 8'hFF) && (f_b != 0);
    wire b_is_inf  = (e_b == 8'hFF) && (f_b == 0);
    wire b_is_zero = (e_b == 0)     && (f_b == 0);
    wire b_is_subn = (e_b == 0)     && (f_b != 0);

    // effective exponent (subnormal 當作 exponent = 1，mantissa 無 hidden 1)
    wire [7:0] e_a_eff = (e_a == 0) ? 8'd1 : e_a;
    wire [7:0] e_b_eff = (e_b == 0) ? 8'd1 : e_b;

    // 24-bit mantissa（含 hidden 1；subnormal 沒 hidden 1）
    wire [23:0] m_a = (e_a == 0) ? {1'b0, f_a} : {1'b1, f_a};
    wire [23:0] m_b = (e_b == 0) ? {1'b0, f_b} : {1'b1, f_b};

    // ---------------- Special cases -> invalid ----------------
    // 本作業規則：只要遇到 NaN/Inf 就視為 invalid（不做 IEEE 完整例外分類）
    wire special_invalid = a_is_nan | b_is_nan | a_is_inf | b_is_inf;

    // ---------------- 對齊：讓 X 是較大指數的一邊 ----------------
    // 若 e 相同，則用 mantissa 比較，確保 X 的幅度 >= Y
    wire  x_sel_bigger =
        (e_b_eff > e_a_eff) ? 1'b1 :
        (e_b_eff < e_a_eff) ? 1'b0 :
        (m_b > m_a)         ? 1'b1 : 1'b0;

    wire       s_X   = x_sel_bigger ? s_b     : s_a;
    wire [7:0] e_X   = x_sel_bigger ? e_b_eff : e_a_eff;
    wire [23:0]M_X   = x_sel_bigger ? m_b     : m_a;

    wire       s_Y   = x_sel_bigger ? s_a     : s_b;
    wire [7:0] e_Y   = x_sel_bigger ? e_a_eff : e_b_eff;
    wire [23:0]M_Y   = x_sel_bigger ? m_a     : m_b;

    wire [8:0] ediff_u = {1'b0, e_X} - {1'b0, e_Y};  // 0..255
    wire [7:0] ediff   = ediff_u[7:0];

    // 產生對齊後 Y 的 G/R/S（三位），保持 X 是未移位（之後幾乎都用 X 當基準）
    // 我們把 Y 擴成 27位：{23:0 mantissa, G, R, S}
    reg [26:0] Y_align;  // [26:3]=mantissa(24b), [2]=G, [1]=R, [0]=S
    integer k;
    reg [50:0] tmp;  // 足夠大
    reg sticky_or;

    wire [4:0] idx_g = (ediff > 0) ? ediff - 1 : 5'd0;
    wire [4:0] idx_r = (ediff > 1) ? ediff - 2 : 5'd0;

    always_comb begin
        if (ediff == 0) begin
            // 完全對齊：沒有被丟掉的位
            Y_align = {M_Y, 3'b000};
        end else if (ediff >= 8'd27) begin
            // 全部被移出，只有 sticky=1（只要原來 M_Y 非零）
            Y_align = {24'd0, 3'b001} & {27{ |M_Y }};
        end else begin
            // 右移 ediff 位，組出 G/R/S
            // 先拼成 27+ (最大用到 27) 的暫存：{M_Y, 27個 0}
            tmp = {M_Y, 27'd0} >> ediff;

            // 取對齊後的 27b 主體
            Y_align[26:3] = tmp[50:27];              // 24b mantissa

            Y_align[2] = (ediff > 0 && ediff <= 24) ? M_Y[idx_g] : 1'b0;
            Y_align[1] = (ediff > 1 && ediff <= 25) ? M_Y[idx_r] : 1'b0;             // R
            // S = 被移掉的其餘所有位的 OR
            // sticky = OR of bits below guard/round
            sticky_or = 1'b0;
            if (ediff != 0) begin
                // 只允許 k <= 23，避免超出 M_Y 位寬
                for (k = 0; k < 24; k = k + 1) begin
                    if (k < ediff-1) begin
                        sticky_or = sticky_or | M_Y[k];
                    end
                end
            end
            Y_align[0] = sticky_or;
        end
    end

    // X 也補成 27位：mantissa + 3 個 0（預留做加減與 GRS）
    wire [26:0] X_align = {M_X, 3'b000};

    // ---------------- 加/減 mantissa ----------------
    // a - b = a + (-b)，因此若 s_X == s_Y → 做加法；否則做減法（大幅度減小幅度）
    reg [27:0] sum28;       // 多 1 位抓進位
    reg        res_sign;    // 結果符號
    always_comb begin
        if (s_X == s_Y) begin
            // 同號 → 加法
            sum28    = {1'b0, X_align} + {1'b0, Y_align};
            res_sign = s_X; // 符號同 X
        end else begin
            // 異號 → 大 - 小
            // X 幅度 >= Y 幅度（前面保證了），所以不會負
            sum28    = {1'b0, X_align} - {1'b0, Y_align};
            res_sign = s_X; // 符號取大的那邊
        end
    end

    // ---------------- Normalize（不做 rounding）----------------
    // 我們要把 27b 的主體（不含最前面那個進位）規範化到：
    //   若加法產生進位 → 右移 1、exp+1
    //   若沒有進位 → 找 leading one 左移、exp 減少
    reg [26:0] frac27;      // 規範化後的 27b（含 mantissa + GRS）
    reg  [8:0] exp_work;    // biased exponent 工作值（9b 防溢位）
    reg        is_zero_mag; // 結果是否為 0（幅度）

    // 回傳 v 從 MSB 開始第一個 '1' 前面有幾個 leading zero
    // Input: 27 bits
    // Output: 5 bits (0~27)
    function automatic [4:0] lz27;
        input [26:0] v;
        integer i;
        reg found;
        begin
            lz27 = 27;  // 預設沒有 1（全 0）
            found = 0;
            for (i = 26; i >= 0; i = i - 1) begin
                if (!found && v[i]) begin
                    lz27 = 26 - i;
                    // 用 loop 結束條件提前結束 for（合成安全）
                    found = 1;
                end
            end
        end
    endfunction

    always_comb begin
        is_zero_mag = (sum28[26:0] == 27'd0);
        exp_work    = {1'b0, e_X}; // 1..254（biased）

        if (sum28[27]) begin
            // 產生進位：右移 1，exp+1
            frac27   = {1'b0, sum28[27:1]}; // 仍保有 GRS 結構
            exp_work = exp_work + 9'd1;
        end else if (!is_zero_mag) begin
            // 沒進位且非零：向左規範化
            // 找到最高位 1 的位置
            reg [4:0] lz;
            lz = lz27(sum28[26:0]);  // 要左移 lz
            frac27   = sum28[26:0] << lz;
            exp_work = exp_work - {4'd0, lz}; // biased exponent 減少
        end else begin
            // 真的等於 0
            frac27   = 27'd0;
            exp_work = 9'd0; // 隨便放；最後輸出 0
        end
    end

    // ---------------- 在 rounding 之前判定 overflow / underflow ----------------
    // 注意：Underflow 不包含 0
    wire overflow_pre  = (!is_zero_mag) && (exp_work > 9'd254); // >254 代表超過正常最大 exponent
    wire underflow_pre = (!is_zero_mag) && (exp_work < 9'd1 );  // <1 代表落在 subnormal 以下

    // ---------------- Rounding to nearest even（GRS on 27b）----------------
    // 27b 排列： [26:3] = mant24（含 hidden 1），[2]=G,[1]=R,[0]=S
    reg [23:0] mant24;   // rounding 後的（可能進位到 2.0）
    reg  [8:0] exp_rnd;  // rounding 後 exponent（可能 +1）
    reg        carry_to_exp;

    wire G = frac27[2];
    wire R = frac27[1];
    wire S = frac27[0];

    // RN-Even：加 1 的條件
    // tie（恰好半）→ 看 mant24 LSB 是否為 1（偶捨奇入）
    wire lsb_pre = frac27[3]; 
    wire round_up = (G && (R | S)) || (G && !R && !S && lsb_pre);

    logic carry;
    logic [23:0] mant24_sum;

    always_comb begin
        mant24  = frac27[26:3];
        exp_rnd = exp_work;
        carry_to_exp = 1'b0;

        if (!is_zero_mag && !overflow_pre && !underflow_pre) begin
            if (round_up) begin
                // 用 carry 偵測 mantissa overflow
                {carry, mant24_sum} = mant24 + 24'd1;
                if (carry) begin
                    mant24  = 24'h800000;      // 1.000000...
                    exp_rnd = exp_rnd + 9'd1;  // exponent +1
                    carry_to_exp = 1'b1;
                end else begin
                    mant24 = mant24_sum;
                end
            end
        end
    end

    // ---------------- Pack / Output ----------------
    // invalid 規則（四捨五入「之前」就看出 overflow/underflow/special）：
    //   special_invalid | overflow_pre | underflow_pre
    // zero 不算 underflow
    always @(*) begin
        o_invalid = 1'b0;
        o_y       = 32'd0;

        if (special_invalid || overflow_pre || underflow_pre) begin
            o_invalid = 1'b1;
            // 值任意（測資只看 status）；可丟 0 或 qNaN
            o_y = 32'h7FC0_0000; // qNaN（好辨識）
        end else if (is_zero_mag) begin
            // 真正算出 0：符號依「大數符號」（IEEE 可保留 sign，作業通常不考）
            o_y = 32'd0;
        end else begin
            // 正常包裝：exp_rnd 在 [1..254]，mant24 = 1.xxxx（含 hidden 1）
            // 注意：IEEE 格式不存 hidden 1，故存 mant24[22:0]
            o_y = {res_sign, exp_rnd[7:0], mant24[22:0]};
        end
    end

endmodule