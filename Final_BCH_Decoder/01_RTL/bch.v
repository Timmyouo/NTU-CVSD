module bch(
	input clk,
	input rstn,
	input mode,
	input [1:0] code,
	input set,
	input [63:0] idata,
	output ready,
	output finish,
	output [9:0] odata
);
//hard 63
wire hard_63_en;
wire [7:0] hard_63_r_in;
wire soft_63;
wire [7:0] soft_63_r_in;
wire hard_63_success;
wire hard_63_fail;
wire [1:0] hard_63_error_num;
wire [5:0] hard_63_error_loc_0;
wire [5:0] hard_63_error_loc_1;

//hard 255
wire hard_255_en;
wire [7:0] hard_255_r_in;
wire soft_255;
wire [7:0] soft_255_r_in;
wire hard_255_success;
wire hard_255_fail;
wire [1:0] hard_255_error_num;
wire [7:0] hard_255_error_loc_0;
wire [7:0] hard_255_error_loc_1;

//hard 1023
wire hard_1023_en;
wire [7:0] hard_1023_r_in;
wire soft_1023;
wire [7:0] soft_1023_r_in;
wire hard_1023_success;
wire hard_1023_fail;
wire [2:0] hard_1023_error_num;
wire [9:0] hard_1023_error_loc_0;
wire [9:0] hard_1023_error_loc_1;
wire [9:0] hard_1023_error_loc_2;
wire [9:0] hard_1023_error_loc_3;

controller controller_0(
	.clk(clk), .rstn(rstn), .mode(mode), .code(code), .set(set), .idata(idata),
	.ready(ready), .finish(finish), .odata(odata),

    //63 51 hard decoding
    .hard_63_en(hard_63_en), 
	.hard_63_r_in(hard_63_r_in),
    .soft_63(soft_63),
    .soft_63_r_in(soft_63_r_in),
    .hard_63_success(hard_63_success), 
	.hard_63_fail(hard_63_fail),
    .hard_63_error_num(hard_63_error_num),
    .hard_63_error_loc_0(hard_63_error_loc_0),
    .hard_63_error_loc_1(hard_63_error_loc_1),

    //255 239 hard decoding
    .hard_255_en(hard_255_en), 
	.hard_255_r_in(hard_255_r_in),
    .soft_255(soft_255),
    .soft_255_r_in(soft_255_r_in),
    .hard_255_success(hard_255_success), 
	.hard_255_fail(hard_255_fail),
    .hard_255_error_num(hard_255_error_num),
    .hard_255_error_loc_0(hard_255_error_loc_0),
    .hard_255_error_loc_1(hard_255_error_loc_1),

    //1023 983 hard decoding
    .hard_1023_en(hard_1023_en), 
	.hard_1023_r_in(hard_1023_r_in),
    .soft_1023(soft_1023),
    .soft_1023_r_in(soft_1023_r_in),
    .hard_1023_success(hard_1023_success), 
	.hard_1023_fail(hard_1023_fail),
    .hard_1023_error_num(hard_1023_error_num),
    .hard_1023_error_loc_0(hard_1023_error_loc_0),
    .hard_1023_error_loc_1(hard_1023_error_loc_1),
    .hard_1023_error_loc_2(hard_1023_error_loc_2),
    .hard_1023_error_loc_3(hard_1023_error_loc_3)
);
hard_63 hard_63_0(
	.clk(clk), .rstn(rstn),

    .hard_63_en(hard_63_en), 
	.hard_63_r_in(hard_63_r_in),
    .soft_63(soft_63),
    .soft_63_r_in(soft_63_r_in),

    .hard_63_success(hard_63_success),
    .hard_63_fail(hard_63_fail),
    .hard_63_error_num(hard_63_error_num),
    .hard_63_error_loc_0(hard_63_error_loc_0),
    .hard_63_error_loc_1(hard_63_error_loc_1)
);
hard_255 hard_255_0(
	.clk(clk), .rstn(rstn),

    .hard_255_en(hard_255_en),
    .hard_255_r_in(hard_255_r_in),
    .soft_255(soft_255),
    .soft_255_r_in(soft_255_r_in),

    .hard_255_success(hard_255_success),
    .hard_255_fail(hard_255_fail),
    .hard_255_error_num(hard_255_error_num),
    .hard_255_error_loc_0(hard_255_error_loc_0),
    .hard_255_error_loc_1(hard_255_error_loc_1)
);
hard_1023 hard_1023_0(
	.clk(clk), .rstn(rstn),

    .hard_1023_en(hard_1023_en),
    .hard_1023_r_in(hard_1023_r_in),
    .soft_1023(soft_1023),
    .soft_1023_r_in(soft_1023_r_in),

    .hard_1023_success(hard_1023_success),
    .hard_1023_fail(hard_1023_fail),
    .hard_1023_error_num(hard_1023_error_num),
    .hard_1023_error_loc_0(hard_1023_error_loc_0),
    .hard_1023_error_loc_1(hard_1023_error_loc_1),
    .hard_1023_error_loc_2(hard_1023_error_loc_2),
    .hard_1023_error_loc_3(hard_1023_error_loc_3)
);
endmodule

