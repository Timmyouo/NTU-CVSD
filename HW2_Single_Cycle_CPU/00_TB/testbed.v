`timescale 1ns/100ps
`define CYCLE       10.0
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   100000

`ifdef p0
    `define Inst "../00_TB/PATTERN/p0/inst.dat"
    `define Status "../00_TB/PATTERN/p0/status.dat"
    `define Data "../00_TB/PATTERN/p0/data.dat"
`elsif p1
    `define Inst "../00_TB/PATTERN/p1/inst.dat"
    `define Status "../00_TB/PATTERN/p1/status.dat"
    `define Data "../00_TB/PATTERN/p1/data.dat"
`elsif p2
	`define Inst "../00_TB/PATTERN/p2/inst.dat"
    `define Status "../00_TB/PATTERN/p2/status.dat"
    `define Data "../00_TB/PATTERN/p2/data.dat"
`elsif p3
	`define Inst "../00_TB/PATTERN/p3/inst.dat"
    `define Status "../00_TB/PATTERN/p3/status.dat"
    `define Data "../00_TB/PATTERN/p3/data.dat"
`else
	`define Inst "../00_TB/PATTERN/p0/inst.dat"
    `define Status "../00_TB/PATTERN/p0/status.dat"
    `define Data "../00_TB/PATTERN/p0/data.dat"
`endif

module testbed;

	reg  rst_n;
	reg  clk = 0;
	wire            dmem_we;
	wire [ 31 : 0 ] dmem_addr;
	wire [ 31 : 0 ] dmem_wdata;
	wire [ 31 : 0 ] dmem_rdata;
	wire [  2 : 0 ] mips_status;
	wire            mips_status_valid;

    reg  [  2 : 0 ] golden_status [0:1023];
    reg  [ 31 : 0 ] golden_data   [0:2047];

    integer i, count;
    integer error, error_data;

	core u_core (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.o_status(mips_status),
		.o_status_valid(mips_status_valid),
		.o_we(dmem_we),
		.o_addr(dmem_addr),
		.o_wdata(dmem_wdata),
		.i_rdata(dmem_rdata)
	);

	data_mem  u_data_mem (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.i_we(dmem_we),
		.i_addr(dmem_addr),
		.i_wdata(dmem_wdata),
		.o_rdata(dmem_rdata)
	);

    initial begin
        $readmemb(`Status, golden_status);
        $readmemb(`Data, golden_data);
    end

    initial begin
       $fsdbDumpfile("core.fsdb");
       $fsdbDumpvars(0, testbed, "+mda");
    end

	always #(`HCYCLE) clk = ~clk;

	// load data memory
	initial begin 
		rst_n = 1;
		#(0.25 * `CYCLE) rst_n = 0;
		#(`CYCLE) rst_n = 1;
		$readmemb (`Inst, u_data_mem.mem_r);
	end

    // output
    initial begin
        count = 0;
        error = 0;
        error_data = 0;
        @(negedge rst_n);
        @(posedge rst_n);
        for (i=0; i<`MAX_CYCLE; i=i+1) begin
            @(negedge clk);
            if (mips_status_valid) begin
                if (mips_status !== golden_status[count]) begin
                    $display ("--------------------------------------------------------------------------------------------------------------------------------------------");
                    $display ("Error!! Mismatch status at %4d cycle, your status is %b, but the golden status is %b", count+1, mips_status, golden_status[count]);
                    $display ("--------------------------------------------------------------------------------------------------------------------------------------------");
                    error = error + 1;
                end
                if (golden_status[count] === `EOF_TYPE && mips_status === `EOF_TYPE) begin
                    break;
                end
                else if (mips_status === `INVALID_TYPE && golden_status[count] === `INVALID_TYPE) begin
                    break;
                end
                count = count + 1;
            end
            @(posedge clk);
        end
        if (error == 0) begin
            $display ("---------------------------------------------------------------------------------------------------------------------");
            $display ("Congratulations!! All status are correct!");
            $display ("---------------------------------------------------------------------------------------------------------------------");
        end
        else begin
            $display ("---------------------------------------------------------------------------------------------------------------------");
            $display ("There are %d errors in status in total!", error);
            $display ("---------------------------------------------------------------------------------------------------------------------");
        end
        @(negedge clk);
        for (i=0; i<2048; i=i+1) begin
            if (u_data_mem.mem_r[i] !== golden_data[i]) begin
                $display ("--------------------------------------------------------------------------------------------------------------------------------------------");
                $display ("Error!! Mismatch data at address %4d, your data is %h, but the golden data is %h", 4*i, u_data_mem.mem_r[i], golden_data[i]);
                $display ("--------------------------------------------------------------------------------------------------------------------------------------------");
                error_data = error_data + 1;
            end
        end
        if (error_data == 0) begin
            $display ("---------------------------------------------------------------------------------------------------------------------");
            $display ("Congratulations!! All data are correct!");
            $display ("---------------------------------------------------------------------------------------------------------------------");
        end
        else begin
            $display ("---------------------------------------------------------------------------------------------------------------------");
            $display ("There are %d errors in data in total!", error_data);
            $display ("---------------------------------------------------------------------------------------------------------------------");
        end
        #(`CYCLE) $finish;
    end

endmodule