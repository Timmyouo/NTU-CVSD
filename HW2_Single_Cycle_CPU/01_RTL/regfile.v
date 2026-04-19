module regfile (
    input         i_clk,
    input         i_rst_n,

    // signed integer $r0 ~ $r31
    input  [4:0]  i_raddr1,
    output [31:0] o_data1,
    input  [4:0]  i_raddr2,
    output [31:0] o_data2,

    input         i_wen,
    input  [4:0]  i_waddr,
    input  [31:0] i_wdata,

    //  floating - point $f0 ~ $f31
    input  [4:0]  i_fraddr1,
    output [31:0] o_fdata1,
    input  [4:0]  i_fraddr2,
    output [31:0] o_fdata2,

    input         i_fwen,
    input  [4:0]  i_fwaddr,
    input  [31:0] i_fwdata
);

reg [31:0] int_regs [31:0];
reg [31:0] fp_regs  [31:0];
integer i;

// Assign reading data outputs
assign o_data1 = int_regs[i_raddr1];
assign o_data2 = int_regs[i_raddr2];
assign o_fdata1= fp_regs[i_fraddr1];
assign o_fdata2= fp_regs[i_fraddr2];

always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        for (i = 0; i < 32; i=i+1 ) begin
            int_regs[i] <= 32'd0;
            fp_regs[i]  <= 32'd0;
        end
    end
    else begin
        // integer reg write
        if (i_wen) begin
            int_regs[i_waddr] <= i_wdata;
        end
        // floating point reg write
        if (i_fwen) begin
            fp_regs[i_fwaddr] <= i_fwdata;
        end
    end
end

endmodule //regfile