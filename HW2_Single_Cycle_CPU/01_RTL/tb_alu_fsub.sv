`timescale 1ns/1ps

module tb_alu_fsub ();

    logic        clk;
    logic        rst_n;
    logic [4:0]  op;
    logic [31:0] in1, in2;
    logic [31:0] out;
    logic        invalid;

    real r_in1, r_in2, r_out, r_exp;
    logic [31:0] expected;
    integer error_count = 0;

    parameter FSUB = 5'd10;  // FSUB opcode

    // DUT
    alu u_alu (
        .i_clk    (clk),
        .i_rst_n  (rst_n),
        .i_op     (op),
        .i_data1  (in1),
        .i_data2  (in2),
        .o_data   (out),
        .o_invalid(invalid)
    );

    // clock
    always #5 clk = ~clk;

    // float helper
    function real f32_to_real(input [31:0] f);
        begin
            f32_to_real = $bitstoshortreal(f);  // SystemVerilog 轉 float
        end
    endfunction

    // Test開始
    initial begin
        clk = 0;
        rst_n = 0;
        op = FSUB;
        in1 = 0;
        in2 = 0;

        #12 rst_n = 1;
        $display("===== FSUB TEST START =====\n");

        // ---------------- Test Cases ---------------- //
        apply_fsub("5.5 - 2.0",       32'h40B00000, 32'h40000000, 32'h40600000); // +3.5
        apply_fsub("-10 - 3",        32'hC1200000, 32'h40400000, 32'hC1500000); // -13
        apply_fsub("1 - 1",          32'h3F800000, 32'h3F800000, 32'h00000000); // 0
        apply_fsub("3 - (-2)",       32'h40400000, 32'hC0000000, 32'h40A00000); // 5
        apply_fsub("Inf - 1",        32'h7F800000, 32'h3F800000, 32'h7FC00000); // invalid
        apply_fsub("NaN - 1",        32'h7FC00000, 32'h3F800000, 32'h7FC00000); // invalid
        apply_fsub("Subnormal case", 32'h000000F0, 32'h00000010, 32'h000000E0); // small numbers

        $display("\n===== TEST END, total errors = %0d =====\n", error_count);
        #10 $finish;
    end

    task apply_fsub(
        input string name,
        input [31:0] a,
        input [31:0] b,
        input [31:0] exp_val
    );
        begin
            in1 = a; in2 = b; expected = exp_val; op = FSUB;
            #10;

            r_in1 = f32_to_real(a);
            r_in2 = f32_to_real(b);
            r_out = f32_to_real(out);
            r_exp = f32_to_real(exp_val);

            $display("[%-12s] %f - %f = %f (dut) | exp = %f | out=0x%h exp=0x%h invalid=%b",
                name, r_in1, r_in2, r_out, r_exp, out, expected, invalid);

            if (out !== expected) begin
                $display("  => ❌ ERROR: MISMATCH!");
                error_count++;
            end else begin
                $display("  => ✅ PASS");
            end
        end
    endtask

endmodule