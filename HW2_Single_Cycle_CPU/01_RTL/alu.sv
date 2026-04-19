// -----------------------------------------------------------------------------
// Simple pseudo ALU for verification
// Supports basic integer arithmetic and comparison.
// Floating ops (FSUB, FMUL, FCVT, FCLASS) are simplified or mocked.
// -----------------------------------------------------------------------------
module alu (
    input  logic        i_clk,
    input  logic        i_rst_n,

    input  logic [4:0]  i_op,        // operation code (shared with core op_t)
    input  logic [31:0] i_data1,
    input  logic [31:0] i_data2,

    output logic [31:0] o_data,
    output logic        o_invalid
);

    // -------------------------------------------------------------------------
    // Local op definitions (must match core)
    // -------------------------------------------------------------------------
    localparam SUB     = 5'd0;
    localparam ADDI    = 5'd1;
    localparam LW      = 5'd2;
    localparam SW      = 5'd3;
    localparam BEQ     = 5'd4;
    localparam BLT     = 5'd5;
    localparam JALR    = 5'd6;
    localparam AUIPC   = 5'd7;
    localparam SLT     = 5'd8;
    localparam OP_SRL     = 5'd9;
    localparam FSUB    = 5'd10;
    localparam FMUL    = 5'd11;
    localparam FCVT    = 5'd12;
    localparam FLW     = 5'd13;
    localparam FSW     = 5'd14;
    localparam FCLASS  = 5'd15;
    localparam EOF_OP  = 5'd16;
    // -------------------------------------------------------------------------
    // Submodules for FP operation
    // -------------------------------------------------------------------------
    logic [31:0] fcvt_result, fclass_result, fsub_result, fmul_result;
    logic fcvt_invalid, fsub_invalid, fmul_invalid;
    logic signed [31:0] sum32;
    logic signed [32:0] sum33; 
    
    fcvt_w_s u_fcvt(
        .i_float(i_data1),
        .o_int(fcvt_result),
        .o_invalid(fcvt_invalid)
    );

    fclass_s u_fclass (
        .a(i_data1),
        .y(fclass_result)
    );

    fsub_sp u_fsub(
        .i_a(i_data1),
        .i_b(i_data2),
        .o_y(fsub_result),
        .o_invalid(fsub_invalid)
    );

    fmul_sp u_fmul(
        .i_a(i_data1),
        .i_b(i_data2),
        .o_y(fmul_result),
        .o_invalid(fmul_invalid)
    );

    // -------------------------------------------------------------------------
    // Combinational ALU Logic
    // -------------------------------------------------------------------------
    always_comb begin
        o_data    = 32'd0;
        o_invalid = 1'b0;
        sum33     = 33'd0;
        sum32     = 32'd0;

        case (i_op)
            // ---------------- Integer / ALU ----------------
            ADDI: begin
                sum33 = {i_data1[31], i_data1} + {i_data2[31], i_data2}; // sign extend
                sum32 = sum33[31:0];
                // overflow detection: same sign input, different sign output
                if ((i_data1[31] == i_data2[31]) && (sum32[31] != i_data1[31]))
                    o_invalid = 1'b1;
                o_data = sum32;
            end

            SUB: begin
                sum33 = {i_data1[31], i_data1} - {i_data2[31], i_data2};
                sum32 = sum33[31:0];
                // overflow detection: operands different sign and result flips wrong
                if ((i_data1[31] != i_data2[31]) && (sum32[31] != i_data1[31]))
                    o_invalid = 1'b1;
                o_data = sum32;
            end
            SLT:    o_data = ($signed(i_data1) < $signed(i_data2)) ? 32'd1 : 32'd0;
            OP_SRL:    o_data = i_data1 >> i_data2;  // shift right logical

            // ---------------- Memory address calc ----------------
            LW, SW, FLW, FSW, JALR: begin
                o_data = $signed(i_data1) + $signed(i_data2);  // address or branch target
            end

            // ---------------- Branch compare (result unused) ----------------
            BEQ, BLT: begin
                o_data = 32'd0;
            end

            // ---------------- AUIPC ----------------
            AUIPC:  o_data = $signed(i_data1) + $signed(i_data2);

            // ---------------- Pseudo Floating Ops ----------------
            FSUB: begin
                o_data = fsub_result;
                o_invalid = fsub_invalid;
            end
            FMUL: begin
                o_data = fmul_result;
                o_invalid = fmul_invalid;                   
            end
            FCVT: begin
                o_data    = fcvt_result;
                o_invalid = fcvt_invalid;
            end
            FCLASS: o_data = fclass_result; 

            // ---------------- EOF / Invalid ----------------
            EOF_OP: begin
                o_data = 32'd0;
            end
        endcase
    end

endmodule


module fcvt_w_s (
    input  [31:0] i_float,     // IEEE754 single precision float
    output reg [31:0] o_int,   // converted signed integer
    output reg        o_invalid
);

    // Extract fields
    wire sign      = i_float[31];
    wire [7:0] exp = i_float[30:23];
    wire [22:0] frac = i_float[22:0];
    wire [23:0] mant = {1'b1, frac};  // normalized mantissa

    // Bias
    integer shift;
    reg [55:0] shifted;
    reg guard, round_bit, sticky;
    reg [31:0] int_val;

    always @(*) begin
        // default
        o_int     = 32'd0;
        o_invalid = 1'b0;
        int_val   = 32'd0;

        // Special case: NaN or INF
        if (exp == 8'hFF) begin
            o_invalid = 1;
            o_int = 32'h80000000;
        end
        // Zero or subnormal
        else if (exp == 0) begin
            o_int = 0;
        end
        else begin
            // Calculate unbiased exponent
            shift = { 24'd0, exp - 127};

            // Too large → overflow
            if (shift > 31) begin
                o_invalid = 1;
                o_int = 32'h80000000;
            end
            // |value| < 1 => 0
            else if (shift < 0) begin
                o_int = 0;
            end
            else begin
                // Align mantissa
                shifted = { {32{1'b0}}, mant } << (shift + 1);

                // Round-to-nearest-even
                int_val = shifted[55:24];         // integer bits
                guard   = shifted[24];
                round_bit = shifted[23];
                sticky  = |shifted[22:0];

                if (round_bit && (sticky || guard)) begin
                    int_val = int_val + 1;
                end

                // Add sign
                o_int = sign ? (~int_val + 1) : int_val;
            end
        end
    end
endmodule


module fclass_s (
    input  logic [31:0] a,
    output logic [31:0] y   // low 10 bits valid
);
    logic sign;
    logic [7:0] exp;
    logic [22:0] frac;

    assign sign = a[31];
    assign exp  = a[30:23];
    assign frac = a[22:0];

    always_comb begin
        y = 32'd0;
        if (exp == 8'hFF && frac != 0) begin
            // NaN
            if (frac[22] == 0) y[8] = 1; // signaling NaN
            else               y[9] = 1; // quiet NaN
        end
        else if (exp == 8'hFF && frac == 0) begin
            // Infinity
            y[sign ? 0 : 7] = 1;
        end
        else if (exp == 8'h00 && frac == 0) begin
            // Zero
            y[sign ? 3 : 4] = 1;
        end
        else if (exp == 8'h00) begin
            // Subnormal
            y[sign ? 2 : 5] = 1;
        end
        else begin
            // Normal
            y[sign ? 1 : 6] = 1;
        end
    end
endmodule



