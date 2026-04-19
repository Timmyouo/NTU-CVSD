module pc (
    input  i_clk,
    input  i_rst_n,
    input  [31:0] i_next_pc,
    output reg [31:0] o_pc
);

reg [31:0] pc;

assign o_pc = pc;

always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        pc <= 32'd0;
    end
    else begin
        pc <= i_next_pc;
    end
end
 
endmodule //pc