module hard_1023(
    input clk,
    input rstn,
  
    input hard_1023_en,
    input [7:0] hard_1023_r_in,
    input soft_1023,
    input [7:0] soft_1023_r_in,

    output reg hard_1023_success,
    output reg hard_1023_fail,
    output [2:0] hard_1023_error_num,
    output [9:0] hard_1023_error_loc_0,
    output [9:0] hard_1023_error_loc_1,
    output [9:0] hard_1023_error_loc_2,
    output [9:0] hard_1023_error_loc_3
);
localparam S_IDLE       = 4'd0;
localparam S_DIVIDE     = 4'd1;
localparam S_SYNDRONE   = 4'd2;
localparam S_SINV       = 4'd3;
localparam S_DINV1      = 4'd4;
localparam S_DINV2      = 4'd5;  
localparam S_DCALC      = 4'd6;  
localparam S_BERLEKAMP  = 4'd7;
localparam S_ROOT       = 4'd8;
localparam S_FAIL       = 4'd9;
localparam S_NO_ERROR   = 4'd10;
localparam S_FINISH     = 4'd11;
reg [3:0] state, state_next;
wire state_IDLE, state_DIVIDE, state_SYNDRONE, state_SINV, state_DINV1, state_DINV2, state_DCALC, state_BERLEKAMP, state_ROOT, state_FAIL, state_NO_ERROR, state_FINISH;
assign state_IDLE       = (state == S_IDLE);
assign state_DIVIDE     = (state == S_DIVIDE);
assign state_SYNDRONE   = (state == S_SYNDRONE);
assign state_SINV       = (state == S_SINV);
assign state_DINV1      = (state == S_DINV1);
assign state_DINV2      = (state == S_DINV2);
assign state_DCALC      = (state == S_DCALC);
assign state_BERLEKAMP  = (state == S_BERLEKAMP);
assign state_ROOT       = (state == S_ROOT);
assign state_FAIL       = (state == S_FAIL);
assign state_NO_ERROR   = (state == S_NO_ERROR);
assign state_FINISH     = (state == S_FINISH);

reg [6:0] div_counter, div_counter_next;    //counter for finding b(X)
reg [3:0] itr_counter, itr_counter_next;    //counter for berlekamp
reg [7:0] root_counter, root_counter_next;  //counter for finding roots
wire itr_0, itr_1, itr_2, itr_3, itr_4, itr_5, itr_6, itr_7, itr_8, itr_9;

reg [2:0] error_num, error_num_next;

//b(X)
reg [7:0] hard_r_in;    
reg [6:0] r_in_sel;     //choose hard_r_in[7:1] at first cycle, choose hard_r_in[6:0] at other cycles
//b[1] = b1(X), b2(X), b4(X), b8(X)
//b[2] = b3(X), b6(X) 
//b[3] = b5(X)
//b[4] = b7(X)
reg [9:0] b [1:4];          
reg [9:0] b_next [1:4];     
reg [9:0] b_1_cal [0:8];    //8 loop-unrolling calculating b1(X), b2(X), b4(X), b8(X)
reg [9:0] b_2_cal [0:8];    //8 loop-unrolling calculating b3(X), b6(X)
reg [9:0] b_3_cal [0:8];    //8 loop-unrolling calculating b5(X)
reg [9:0] b_4_cal [0:8];    //8 loop-unrolling calculating b7(X)

//syndrone
reg [9:0] syndrone      [1:7];
reg [9:0] syndrone_next [1:7];

//Berlekamp
wire [3:0] fail_case;
wire [9:0] success_case;
reg [2:0] sigma_deg, sigma_deg_next;

//root
reg [9:0] sigma [1:4][0:3];
reg [9:0] sigma_next [1:4][0:3];
reg [9:0] sigma_init [1:4][0:3];
reg [9:0] sigma_init_op[1:4];
reg [9:0] sigma_mul   [1:4][0:3];
reg [9:0] sigma_mul_op [1:4][0:3];
reg [9:0] sigma_cal    [0:3];
reg [9:0] sigma_cal_op[1:4][0:3];
reg equal_zero [0:3];
reg [9:0] error_index [0:3];
reg [9:0] error_loc     [0:3];
reg [9:0] error_loc_next[0:3];

assign hard_1023_error_num = error_num;
assign hard_1023_error_loc_0 = error_loc[0];
assign hard_1023_error_loc_1 = error_loc[1];
assign hard_1023_error_loc_2 = error_loc[2];
assign hard_1023_error_loc_3 = error_loc[3];
//=============================
//          success
//=============================
always@(posedge clk) begin
    if(!rstn) hard_1023_success <= 1'b0;
    else hard_1023_success <= ((state_next == S_NO_ERROR) | (state_next == S_FINISH));
end
//=============================
//           fail
//=============================
always@(posedge clk) begin
    if(!rstn) hard_1023_fail <= 1'b0;
    else hard_1023_fail <= (state_next == S_FAIL);
end
//=============================
//             FSM
//=============================
wire no_error_case;
assign no_error_case = ((~|syndrone_next[1]) & (~|syndrone_next[3]) & 
                        (~|syndrone_next[5]) & (~|syndrone_next[7]));
always@(*) begin
    case(state)
        S_IDLE:     state_next = hard_1023_en ? S_DIVIDE : S_IDLE;
        S_DIVIDE:   state_next = (&div_counter) ? S_SYNDRONE : S_DIVIDE;
        S_SYNDRONE: state_next = no_error_case ? S_NO_ERROR : S_SINV;
        S_SINV:     state_next = itr_9 ? S_DINV1 : S_SINV;
        S_DINV1:    state_next = itr_9 ? S_DINV2 : S_DINV1; 
        S_DINV2:    state_next = itr_9 ? S_DCALC : S_DINV2;
        S_DCALC:    state_next = S_BERLEKAMP;
        S_BERLEKAMP:state_next = (|fail_case) ? S_FAIL : S_ROOT;
        S_ROOT:     state_next = (&root_counter) ? ((sigma_deg != error_num_next) ? S_FAIL : S_FINISH) : S_ROOT;
        S_FAIL:     state_next = S_IDLE;
        S_NO_ERROR: state_next = S_IDLE;
        S_FINISH:   state_next = S_IDLE;
        default:    state_next = state;
    endcase
end
always@(posedge clk) begin
    if(!rstn) state <= S_IDLE;
    else state <= state_next;
end
//=============================
//        div_counter
//=============================
always@(*) begin
    if(state_DIVIDE) div_counter_next = div_counter + 7'd1;
    else div_counter_next = 7'd0;
end
always@(posedge clk) begin
    if(!rstn) div_counter <= 7'd0;
    else if(hard_1023_en) div_counter <= div_counter_next;
end
//=============================
//         itr_counter
//=============================
wire [3:0] itr_inc;
assign itr_0 = (~|itr_counter);
assign itr_1 = (itr_counter == 4'd1);
assign itr_2 = (itr_counter == 4'd2);
assign itr_3 = (itr_counter == 4'd3);
assign itr_4 = (itr_counter == 4'd4);
assign itr_5 = (itr_counter == 4'd5);
assign itr_6 = (itr_counter == 4'd6);
assign itr_7 = (itr_counter == 4'd7);
assign itr_8 = (itr_counter == 4'd8);
assign itr_9 = (itr_counter == 4'd9);
assign itr_inc = itr_counter + 4'd1;
always@(*) begin
    if(state_SINV) 
        itr_counter_next = itr_9 ? 4'd0 : itr_inc;
    else if(state_DINV1) 
        itr_counter_next = itr_9 ? 4'd0 : itr_inc;
    else if(state_DINV2) 
        itr_counter_next = itr_9 ? 4'd0 : itr_inc;
    else itr_counter_next = 4'd0;
end
always@(posedge clk) begin
    if(!rstn) itr_counter <= 4'd0;
    else if(hard_1023_en) itr_counter <= itr_counter_next;
end
//=============================
//         root_counter
//=============================
always@(*) begin
    if(state_ROOT) 
        root_counter_next = root_counter + 8'd1;
    else root_counter_next = 8'd0;
end
always@(posedge clk) begin
    if(!rstn) root_counter <= 8'd0;
    else if(hard_1023_en) root_counter <= root_counter_next;
end
//=============================
//      divider for b(X)
//=============================
integer i1;
always@(*) begin
    hard_r_in = state_DIVIDE ? (soft_1023 ? soft_1023_r_in : hard_1023_r_in) : 8'd0;
    b_1_cal[0] = state_DIVIDE ? b[1] : 10'd0;
    b_2_cal[0] = state_DIVIDE ? b[2] : 10'd0;
    b_3_cal[0] = state_DIVIDE ? b[3] : 10'd0;
    b_4_cal[0] = state_DIVIDE ? b[4] : 10'd0;
    for(i1=0 ; i1<7 ; i1=i1+1) begin
        r_in_sel[i1] = (~|div_counter) ? hard_r_in[i1+1] : hard_r_in[i1]; //neglect first LLR at the first cycle
        b_1_cal[i1+1] = {b_1_cal[i1][8],
                         b_1_cal[i1][7],
                         b_1_cal[i1][6],
                         b_1_cal[i1][5],
                         b_1_cal[i1][4],
                         b_1_cal[i1][3],
                         b_1_cal[i1][2] ^ b_1_cal[i1][9],
                         b_1_cal[i1][1],
                         b_1_cal[i1][0],
                         r_in_sel[i1]   ^ b_1_cal[i1][9]};
        b_2_cal[i1+1] = {b_2_cal[i1][8],
                         b_2_cal[i1][7],
                         b_2_cal[i1][6],
                         b_2_cal[i1][5],
                         b_2_cal[i1][4],
                         b_2_cal[i1][3],
                         b_2_cal[i1][2] ^ b_2_cal[i1][9],
                         b_2_cal[i1][1] ^ b_2_cal[i1][9],
                         b_2_cal[i1][0] ^ b_2_cal[i1][9], 
                         r_in_sel[i1]   ^ b_2_cal[i1][9]};
        b_3_cal[i1+1] = {b_3_cal[i1][8],
                         b_3_cal[i1][7] ^ b_3_cal[i1][9],
                         b_3_cal[i1][6],
                         b_3_cal[i1][5],
                         b_3_cal[i1][4],
                         b_3_cal[i1][3],
                         b_3_cal[i1][2] ^ b_3_cal[i1][9],
                         b_3_cal[i1][1] ^ b_3_cal[i1][9],
                         b_3_cal[i1][0],
                         r_in_sel[i1]   ^ b_3_cal[i1][9]};
        b_4_cal[i1+1] = {b_4_cal[i1][8] ^ b_4_cal[i1][9],
                         b_4_cal[i1][7] ^ b_4_cal[i1][9],
                         b_4_cal[i1][6] ^ b_4_cal[i1][9],
                         b_4_cal[i1][5] ^ b_4_cal[i1][9],
                         b_4_cal[i1][4] ^ b_4_cal[i1][9],
                         b_4_cal[i1][3] ^ b_4_cal[i1][9],
                         b_4_cal[i1][2] ^ b_4_cal[i1][9],
                         b_4_cal[i1][1],
                         b_4_cal[i1][0],
                         r_in_sel[i1]   ^ b_4_cal[i1][9]};
    end
    b_1_cal[8] = {b_1_cal[7][8],
                  b_1_cal[7][7],
                  b_1_cal[7][6],
                  b_1_cal[7][5],
                  b_1_cal[7][4],
                  b_1_cal[7][3],
                  b_1_cal[7][2] ^ b_1_cal[7][9],
                  b_1_cal[7][1],
                  b_1_cal[7][0],
                  hard_r_in[7]  ^ b_1_cal[7][9]};
    b_2_cal[8] = {b_2_cal[7][8],
                  b_2_cal[7][7],
                  b_2_cal[7][6],
                  b_2_cal[7][5],
                  b_2_cal[7][4],
                  b_2_cal[7][3],
                  b_2_cal[7][2] ^ b_2_cal[7][9],
                  b_2_cal[7][1] ^ b_2_cal[7][9],
                  b_2_cal[7][0] ^ b_2_cal[7][9], 
                  hard_r_in[7]  ^ b_2_cal[7][9]};
    b_3_cal[8] = {b_3_cal[7][8],
                  b_3_cal[7][7] ^ b_3_cal[7][9],
                  b_3_cal[7][6],
                  b_3_cal[7][5],
                  b_3_cal[7][4],
                  b_3_cal[7][3],
                  b_3_cal[7][2] ^ b_3_cal[7][9],
                  b_3_cal[7][1] ^ b_3_cal[7][9],
                  b_3_cal[7][0],
                  hard_r_in[7]  ^ b_3_cal[7][9]};
    b_4_cal[8] = {b_4_cal[7][8] ^ b_4_cal[7][9],
                  b_4_cal[7][7] ^ b_4_cal[7][9],
                  b_4_cal[7][6] ^ b_4_cal[7][9],
                  b_4_cal[7][5] ^ b_4_cal[7][9],
                  b_4_cal[7][4] ^ b_4_cal[7][9],
                  b_4_cal[7][3] ^ b_4_cal[7][9],
                  b_4_cal[7][2] ^ b_4_cal[7][9],
                  b_4_cal[7][1],
                  b_4_cal[7][0],
                  hard_r_in[7]  ^ b_4_cal[7][9]};
end
integer i2;
always@(*) begin
    if(state_IDLE)
        for(i2=1 ; i2<=4 ; i2=i2+1) 
            b_next[i2] = 10'd0;
    else if(state_DIVIDE) begin
        if(~|div_counter) begin //neglect first LLR at the first cycle
            b_next[1] = b_1_cal[7];
            b_next[2] = b_2_cal[7];
            b_next[3] = b_3_cal[7];
            b_next[4] = b_4_cal[7];
        end
        else begin
            b_next[1] = b_1_cal[8];
            b_next[2] = b_2_cal[8];
            b_next[3] = b_3_cal[8];
            b_next[4] = b_4_cal[8];
        end
    end
    else begin
        for(i2=1 ; i2<=4 ; i2=i2+1) 
            b_next[i2] = b[i2];
    end
end
integer i3;
always@(posedge clk) begin
    if(!rstn)
        for(i3=1 ; i3<=4 ; i3=i3+1) 
            b[i3] <= 10'd0;
    else if(hard_1023_en)
        for(i3=1 ; i3<=4 ; i3=i3+1) 
            b[i3] <= b_next[i3];
end
//=============================
//         syndrone
//=============================
integer i4;
always@(*) begin
    if(state_SYNDRONE) begin
        syndrone_next[1] = b[1];
        syndrone_next[2] = {b[1][8], 
                            b[1][4] ^ b[1][9],
                            b[1][7],
                            b[1][3] ^ b[1][8],
                            b[1][6],
                            b[1][2] ^ b[1][7] ^ b[1][9],
                            b[1][5],
                            b[1][1] ^ b[1][6],
                            b[1][9],
                            b[1][0] ^ b[1][5]};
        syndrone_next[3] = {b[2][3],
                            b[2][5] ^ b[2][6],
                            b[2][7] ^ b[2][9],
                            b[2][2] ^ b[2][9],
                            b[2][4] ^ b[2][5],
                            b[2][6] ^ b[2][8],
                            b[2][1] ^ b[2][8] ^ b[2][9],
                            b[2][4],
                            b[2][6] ^ b[2][7],
                            b[2][0] ^ b[2][8]};
        syndrone_next[4] = {b[1][4] ^ b[1][9],
                            b[1][2] ^ b[1][7] ^ b[1][8] ^ b[1][9],
                            b[1][7],
                            b[1][4] ^ b[1][5] ^ b[1][9],
                            b[1][3] ^ b[1][8],
                            b[1][1] ^ b[1][6] ^ b[1][7] ^ b[1][8],
                            b[1][6],
                            b[1][3] ^ b[1][8] ^ b[1][9],
                            b[1][8],
                            b[1][0] ^ b[1][5] ^ b[1][6]};
        syndrone_next[5] = {b[3][6],
                            b[3][3] ^ b[3][7],
                            b[3][7] ^ b[3][9],
                            b[3][4] ^ b[3][6],
                            b[3][1] ^ b[3][3] ^ b[3][5] ^ b[3][7] ^ b[3][8] ^ b[3][9],
                            b[3][5],
                            b[3][2] ^ b[3][6] ^ b[3][9],
                            b[3][8],
                            b[3][5] ^ b[3][7],
                            b[3][0] ^ b[3][2] ^ b[3][4] ^ b[3][6] ^ b[3][8] ^ b[3][9]};
        syndrone_next[6] = {b[2][5] ^ b[2][6],
                            b[2][3] ^ b[2][6] ^ b[2][8],
                            b[2][7] ^ b[2][9],
                            b[2][1] ^ b[2][5] ^ b[2][6] ^ b[2][8] ^ b[2][9],
                            b[2][2] ^ b[2][9],
                            b[2][3] ^ b[2][4] ^ b[2][7] ^ b[2][9],
                            b[2][4] ^ b[2][5],
                            b[2][2] ^ b[2][6] ^ b[2][7] ^ b[2][9],
                            b[2][3],
                            b[2][0] ^ b[2][4] ^ b[2][5] ^ b[2][8]};
        syndrone_next[7] = {b[4][7] ^ b[4][8] ^ b[4][9],
                            b[4][4] ^ b[4][5] ^ b[4][8] ^ b[4][9],
                            b[4][1] ^ b[4][2] ^ b[4][3] ^ b[4][4] ^ b[4][5] ^ b[4][6] ^ b[4][7] ^ b[4][8] ^ b[4][9],
                            b[4][8],
                            b[4][5] ^ b[4][9],
                            b[4][2] ^ b[4][4] ^ b[4][6] ^ b[4][8],
                            b[4][9],
                            b[4][6],
                            b[4][3] ^ b[4][5] ^ b[4][7] ^ b[4][9],
                            b[4][0]};
    end
    else
        for(i4=1 ; i4<=7 ; i4=i4+1) 
            syndrone_next[i4] = syndrone[i4];
end
integer i5;
always@(posedge clk) begin
    if(!rstn)
        for(i5=1 ; i5<=7 ; i5=i5+1) 
            syndrone[i5] <= 10'd0;
    else if(hard_1023_en) 
        for(i5=1 ; i5<=7 ; i5=i5+1) 
            syndrone[i5] <= syndrone_next[i5];
end
//=============================
//          BERLEKAMP
//=============================
//multiplication
integer mul_b, mul_w;
reg [9:0] mul [0:10][0:3];
reg [9:0] mul_op1 [0:3];
reg [9:0] mul_op2 [0:3];
reg [9:0] mul_op3 [0:3];
reg [9:0] add_mul [0:3];
//square
integer sqr_i0;
reg [9:0] square_op [0:1];
reg [9:0] square [0:1];
reg [9:0] square_next [0:1];
reg [9:0] inv_cal [0:1];
reg [9:0] inv_op [0:1];
reg [9:0] inv [0:1];
//arithmetic result register
reg [9:0] S1inv, S3inv, S1inv_next, S3inv_next;
reg [9:0] S7_S5S2, S7_S5S2_next;    //d3 = S7 + S5S2
reg [9:0] S5_S3S2, S5_S3S2_next;    //d2 = S5 + S3S2
reg [9:0] S7_S3S4, S7_S3S4_next;    //d3 = S7 + S3S4
reg [9:0] S3_S1S2, S3_S1S2_next;    //d1 = S3 + S1S2
reg [9:0] S5_S1S4, S5_S1S4_next;    //d2 = S5 + S1S4
reg [9:0] S7_S1S6, S7_S1S6_next;    //d3 = S7 + S1S6
//d_reg[0]: //S_SINV: (S5+S3S2)S5, S_DINV1: itr_1->S7 + S3S4 + (S5+S3S2)S3^(-1)S5 
//d_reg[1]: //S_SINV: (S3+S1S2)S3, S_DINV1: itr_1->S5 + S1S4 + (S3+S1S2)S1^(-1)S3 
//d_reg[2]: //S_SINV: (S3+S1S2)S5, S_DINV1: itr_1->S7 + S1S6 + (S3+S1S2)S1^(-1)S5
//d_reg[3]: //S_SINV: (S5+S1S4)S3, S_DINV1: itr_1->S7 + S1S6 + (S5+S1S4)S1^(-1)S3
//d_reg[4]: //S_DINV1: [S5 + S1S4 + (S3+S1S2)S1^(-1)S3](S5+S1S4), S_DINV2: S7 + S1S6 + (S3+S1S2)S1^(-1)S5 + [S5 + S1S4 + (S3+S1S2)S1^(-1)S3](S3+S1S2)^(-1)(S5+S1S4)
//d_reg[5]: //S_DINV1: d1S1^(-1) = (S3+S1S2)S1^(-1)
//d_reg[6]: //S_DINV1: d2S1^(-1) = (S5+S1S4)S1^(-1)
//d_reg[7]: //S_DINV1: d3S1^(-1) = (S7+S1S6)S1^(-1)
//d_reg[8]: //S_DINV1: d3S3^(-1) = [S7 + S3S4 + (S5+S3S2)S3^(-1)S5]S3^(-1)
//d_reg[9]: //S_DINV1: d2S3^(-1) = (S5+S3S2)S3^(-1)
//d_reg[10]://S_DINV1: d3S3^(-1) = (S7+S3S4)S3^(-1)
//d_reg[11]://S_DINV2: d2d1^(-1) = [S5+S1S4+(S3+S1S2)S1^(-1)S3](S3+S1S2)^(-1)
//d_reg[12]://S_DINV2: d3d2^(-1) = [S7+S1S6+(S5+S1S4)S1^(-1)S3](S5+S1S4)^(-1)
//d_reg[13]://S_DCALC: d3d2^(-1) for last sigma4
reg [9:0] d_reg [0:13];
reg [9:0] d_reg_next [0:13];
reg [9:0] S3_S1S2inv, S3_S1S2inv_next;  //d1^(-1) = (S3+S1S2)^(-1)
reg [9:0] S5_S1S4inv, S5_S1S4inv_next;  //d2^(-1) = (S5+S1S4)^(-1)
reg [9:0] d2inv, d2inv_next;            //d2^(-1) = [S5+S1S4+(S3+S1S2)S1^(-1)S3]^(-1) 
wire [9:0] d3d2invd1S1inv, d2d1invS1, d3d2invS1, S1_d2d1inv_d3d2inv; //realtime multiplication result
assign d3d2invd1S1inv       = mul[10][0];
assign d2d1invS1            = mul[10][1];
assign d3d2invS1            = mul[10][2];
assign S1_d2d1inv_d3d2inv   = mul[10][3];
wire [9:0] d2d1inv_d3d2inv, d1S1inv_d2d1inv_d3d2inv, d1S1inv_d2d1inv;
assign d2d1inv_d3d2inv = d_reg[11] ^ d_reg[13];
assign d1S1inv_d2d1inv_d3d2inv = d2d1inv_d3d2inv ^ d_reg[5];
assign d1S1inv_d2d1inv = d_reg[5] ^ d_reg[11];
//multiplier
always@(*) begin
    for(mul_b=0 ; mul_b<4 ; mul_b=mul_b+1) begin
        mul[0][mul_b] = 10'd0;
        for(mul_w=0 ; mul_w<10 ; mul_w=mul_w+1) begin
            mul[mul_w+1][mul_b] = {
            (mul_op1[mul_b][9] & mul_op2[mul_b][9-mul_w]) ^ mul[mul_w][mul_b][8],
            (mul_op1[mul_b][8] & mul_op2[mul_b][9-mul_w]) ^ mul[mul_w][mul_b][7],
            (mul_op1[mul_b][7] & mul_op2[mul_b][9-mul_w]) ^ mul[mul_w][mul_b][6],
            (mul_op1[mul_b][6] & mul_op2[mul_b][9-mul_w]) ^ mul[mul_w][mul_b][5],
            (mul_op1[mul_b][5] & mul_op2[mul_b][9-mul_w]) ^ mul[mul_w][mul_b][4],
            (mul_op1[mul_b][4] & mul_op2[mul_b][9-mul_w]) ^ mul[mul_w][mul_b][3],
            (mul_op1[mul_b][3] & mul_op2[mul_b][9-mul_w]) ^ mul[mul_w][mul_b][2] ^ mul[mul_w][mul_b][9],
            (mul_op1[mul_b][2] & mul_op2[mul_b][9-mul_w]) ^ mul[mul_w][mul_b][1],
            (mul_op1[mul_b][1] & mul_op2[mul_b][9-mul_w]) ^ mul[mul_w][mul_b][0],
            (mul_op1[mul_b][0] & mul_op2[mul_b][9-mul_w]) ^                        mul[mul_w][mul_b][9]};
        end
        add_mul[mul_b] = mul_op3[mul_b] ^ mul[10][mul_b];
    end
end
always@(*) begin
    mul_op1[0] = (state_SINV | state_DINV1 | state_DINV2) ? square[0] : 
                 state_BERLEKAMP                          ? d_reg[13] : 10'd0;
    mul_op2[0] = state_SINV      ? S1inv      : 
                 state_DINV1     ? S3_S1S2inv : 
                 state_DINV2     ? d2inv      : 
                 state_BERLEKAMP ? d_reg[5]   : 10'd0;
    mul_op3[0] = 10'd0;
    mul_op1[1] = (state_SINV | state_DINV1) ? square[1]   : 
                 state_BERLEKAMP            ? d_reg[11]   : 10'd0;
    mul_op2[1] = state_SINV                 ? S3inv       : 
                 state_DINV1                ? S5_S1S4inv  : 
                 state_BERLEKAMP            ? syndrone[1] : 10'd0;
    mul_op3[1] = 10'd0;
    if(state_SINV) begin
        case(itr_counter)
            4'd0: begin
                mul_op1[2] = syndrone[5];
                mul_op2[2] = syndrone[2];
                mul_op3[2] = syndrone[7];
                mul_op1[3] = syndrone[3];
                mul_op2[3] = syndrone[2];
                mul_op3[3] = syndrone[5];
            end
            4'd1: begin
                mul_op1[2] = syndrone[3];
                mul_op2[2] = syndrone[4];
                mul_op3[2] = syndrone[7];
                mul_op1[3] = syndrone[1];
                mul_op2[3] = syndrone[2];
                mul_op3[3] = syndrone[3];
            end
            4'd2: begin
                mul_op1[2] = syndrone[1];
                mul_op2[2] = syndrone[4];
                mul_op3[2] = syndrone[5];
                mul_op1[3] = syndrone[1];
                mul_op2[3] = syndrone[6];
                mul_op3[3] = syndrone[7];
            end
            4'd3: begin
                mul_op1[2] = S5_S3S2;
                mul_op2[2] = syndrone[5];
                mul_op3[2] = 10'd0;
                mul_op1[3] = S3_S1S2;
                mul_op2[3] = syndrone[3];
                mul_op3[3] = 10'd0;
            end
            4'd4: begin
                mul_op1[2] = S3_S1S2;
                mul_op2[2] = syndrone[5];
                mul_op3[2] = 10'd0;
                mul_op1[3] = S5_S1S4;
                mul_op2[3] = syndrone[3];
                mul_op3[3] = 10'd0;
            end
            default: begin
                mul_op1[2] = 10'd0;
                mul_op2[2] = 10'd0;
                mul_op3[2] = 10'd0;
                mul_op1[3] = 10'd0;
                mul_op2[3] = 10'd0;
                mul_op3[3] = 10'd0;
            end
        endcase
    end
    else if(state_DINV1) begin
        case(itr_counter) 
            4'd0: begin
                mul_op1[2] = d_reg[0];
                mul_op2[2] = S3inv;
                mul_op3[2] = S7_S3S4;
                mul_op1[3] = d_reg[1];
                mul_op2[3] = S1inv;
                mul_op3[3] = S5_S1S4;
            end
            4'd1: begin
                mul_op1[2] = d_reg[2];
                mul_op2[2] = S1inv;
                mul_op3[2] = S7_S1S6;
                mul_op1[3] = d_reg[3];
                mul_op2[3] = S1inv;
                mul_op3[3] = S7_S1S6;
            end
            4'd2: begin
                mul_op1[2] = d_reg[1];
                mul_op2[2] = S5_S1S4;
                mul_op3[2] = 10'd0;
                mul_op1[3] = S3_S1S2;
                mul_op2[3] = S1inv;
                mul_op3[3] = 10'd0;
            end
            4'd3: begin
                mul_op1[2] = S5_S1S4;
                mul_op2[2] = S1inv;
                mul_op3[2] = 10'd0;
                mul_op1[3] = S7_S1S6;
                mul_op2[3] = S1inv;
                mul_op3[3] = 10'd0;
            end
            4'd4: begin
                mul_op1[2] = d_reg[0];
                mul_op2[2] = S3inv;
                mul_op3[2] = 10'd0;
                mul_op1[3] = S5_S3S2;
                mul_op2[3] = S3inv;
                mul_op3[3] = 10'd0;
            end
            4'd5: begin
                mul_op1[2] = S7_S3S4;
                mul_op2[2] = S3inv;
                mul_op3[2] = 10'd0;
                mul_op1[3] = 10'd0;
                mul_op2[3] = 10'd0;
                mul_op3[3] = 10'd0;
            end
            default: begin
                mul_op1[2] = 10'd0;
                mul_op2[2] = 10'd0;
                mul_op3[2] = 10'd0;
                mul_op1[3] = 10'd0;
                mul_op2[3] = 10'd0;
                mul_op3[3] = 10'd0;
            end
        endcase
    end
    else if(state_DINV2) begin
        case(itr_counter) 
            4'd0: begin
                mul_op1[2] = d_reg[1];
                mul_op2[2] = S3_S1S2inv;
                mul_op3[2] = 10'd0;
                mul_op1[3] = d_reg[4];
                mul_op2[3] = S3_S1S2inv;
                mul_op3[3] = d_reg[2];
            end
            4'd1: begin
                mul_op1[2] = d_reg[3];
                mul_op2[2] = S5_S1S4inv;
                mul_op3[2] = 10'd0;
                mul_op1[3] = 10'd0;
                mul_op2[3] = 10'd0;
                mul_op3[3] = 10'd0;
            end
            default: begin
                mul_op1[2] = 10'd0;
                mul_op2[2] = 10'd0;
                mul_op3[2] = 10'd0;
                mul_op1[3] = 10'd0;
                mul_op2[3] = 10'd0;
                mul_op3[3] = 10'd0;
            end
        endcase
    end
    else if(state_DCALC) begin
        mul_op1[2] = d_reg[4];
        mul_op2[2] = d2inv;
        mul_op3[2] = 10'd0;
        mul_op1[3] = 10'd0;
        mul_op2[3] = 10'd0;
        mul_op3[3] = 10'd0;
    end
    else if(state_BERLEKAMP) begin
        mul_op1[2] = d_reg[12];
        mul_op2[2] = syndrone[1];
        mul_op3[2] = 10'd0;
        mul_op1[3] = syndrone[1];
        mul_op2[3] = d2d1inv_d3d2inv;
        mul_op3[3] = 10'd0;
    end
    else begin
        mul_op1[2] = 10'd0;
        mul_op2[2] = 10'd0;
        mul_op3[2] = 10'd0;
        mul_op1[3] = 10'd0;
        mul_op2[3] = 10'd0;
        mul_op3[3] = 10'd0;
    end
end
//inversion
always@(*) begin
    square_op[0] = state_SINV  ? (itr_0 ? syndrone[1] : square[0]) : 
                   state_DINV1 ? (itr_0 ? S3_S1S2     : square[0]) : 
                   state_DINV2 ? (itr_0 ? d_reg[1]    : square[0]) : 10'd0;
    square_op[1] = state_SINV  ? (itr_0 ? syndrone[3] : square[1]) : 
                   state_DINV1 ? (itr_0 ? S5_S1S4     : square[1]) : 10'd0;
    for(sqr_i0=0 ; sqr_i0<2 ; sqr_i0=sqr_i0+1) begin
        square_next[sqr_i0] = {square_op[sqr_i0][8],
                               square_op[sqr_i0][4] ^ square_op[sqr_i0][9],
                               square_op[sqr_i0][7],
                               square_op[sqr_i0][3] ^ square_op[sqr_i0][8],
                               square_op[sqr_i0][6],
                               square_op[sqr_i0][2] ^ square_op[sqr_i0][7] ^ square_op[sqr_i0][9],
                               square_op[sqr_i0][5],
                               square_op[sqr_i0][1] ^ square_op[sqr_i0][6],
                               square_op[sqr_i0][9],
                               square_op[sqr_i0][0] ^ square_op[sqr_i0][5]};
    end
end
always@(posedge clk) begin
    if(!rstn) begin
        square[0] <= 10'd0;
        square[1] <= 10'd0;
    end
    else if(hard_1023_en) begin
        square[0] <= square_next[0];
        square[1] <= square_next[1];
    end
end
//S inverse
always@(*) begin
    if(state_SINV) begin
        if(itr_1) begin
            S1inv_next = square[0];
            S3inv_next = square[1];
        end
        else begin
            S1inv_next = mul[10][0];
            S3inv_next = mul[10][1];
        end
    end
    else begin
        S1inv_next = S1inv;
        S3inv_next = S3inv;
    end
end
always@(posedge clk) begin
    if(!rstn) begin
        S1inv <= 10'd0;
        S3inv <= 10'd0;
    end
    else if(hard_1023_en) begin
        S1inv <= S1inv_next;
        S3inv <= S3inv_next;
    end
end
//d inverse
always@(*) begin
    if(state_DINV1) begin
        if(itr_1) begin
            S3_S1S2inv_next = square[0];
            S5_S1S4inv_next = square[1];
        end
        else begin
            S3_S1S2inv_next = mul[10][0];
            S5_S1S4inv_next = mul[10][1];
        end
    end
    else begin
        S3_S1S2inv_next = S3_S1S2inv;
        S5_S1S4inv_next = S5_S1S4inv;
    end
end
always@(posedge clk) begin
    if(!rstn) begin
        S3_S1S2inv <= 10'd0;
        S5_S1S4inv <= 10'd0;
    end
    else if(hard_1023_en) begin
        S3_S1S2inv <= S3_S1S2inv_next;
        S5_S1S4inv <= S5_S1S4inv_next;
    end
end
always@(*) begin
    if(state_DINV2) begin
        if(itr_1) d2inv_next = square[0];
        else d2inv_next = mul[10][0];
    end
    else d2inv_next = d2inv;
end
always@(posedge clk) begin
    if(!rstn) 
        d2inv <= 10'd0;
    else if(hard_1023_en) 
        d2inv <= d2inv_next;
end
wire state_SINV_itr_0, state_SINV_itr_1, state_SINV_itr_2, state_SINV_itr_3, state_SINV_itr_4;
wire state_DINV1_itr_0,state_DINV1_itr_1,state_DINV1_itr_2, state_DINV1_itr_3, state_DINV1_itr_4, state_DINV1_itr_5;
wire state_DINV2_itr_0, state_DINV2_itr_1;
assign state_SINV_itr_0 = (state_SINV & itr_0);
assign state_SINV_itr_1 = (state_SINV & itr_1);
assign state_SINV_itr_2 = (state_SINV & itr_2);
assign state_SINV_itr_3 = (state_SINV & itr_3);
assign state_SINV_itr_4 = (state_SINV & itr_4);
assign state_DINV1_itr_0 = (state_DINV1 & itr_0);
assign state_DINV1_itr_1 = (state_DINV1 & itr_1);
assign state_DINV1_itr_2 = (state_DINV1 & itr_2);
assign state_DINV1_itr_3 = (state_DINV1 & itr_3);
assign state_DINV1_itr_4 = (state_DINV1 & itr_4);
assign state_DINV1_itr_5 = (state_DINV1 & itr_5);
assign state_DINV2_itr_0 = (state_DINV2 & itr_0);
assign state_DINV2_itr_1 = (state_DINV2 & itr_1);
always@(*) begin
    S7_S5S2_next = state_SINV_itr_0 ? add_mul[2] : S7_S5S2; //d3 = S7 + S5S2
    S5_S3S2_next = state_SINV_itr_0 ? add_mul[3] : S5_S3S2; //d2 = S5 + S3S2
    S7_S3S4_next = state_SINV_itr_1 ? add_mul[2] : S7_S3S4; //d3 = S7 + S3S4
    S3_S1S2_next = state_SINV_itr_1 ? add_mul[3] : S3_S1S2; //d1 = S3 + S1S2
    S5_S1S4_next = state_SINV_itr_2 ? add_mul[2] : S5_S1S4; //d2 = S5 + S1S4
    S7_S1S6_next = state_SINV_itr_2 ? add_mul[3] : S7_S1S6; //d3 = S7 + S1S6
end
always@(posedge clk) begin
    if(!rstn) begin
        S7_S5S2 <= 10'd0;
        S5_S3S2 <= 10'd0;
        S7_S3S4 <= 10'd0;
        S3_S1S2 <= 10'd0;
        S5_S1S4 <= 10'd0;
        S7_S1S6 <= 10'd0;
    end
    else if(hard_1023_en) begin
        S7_S5S2 <= S7_S5S2_next;
        S5_S3S2 <= S5_S3S2_next;
        S7_S3S4 <= S7_S3S4_next;
        S3_S1S2 <= S3_S1S2_next;
        S5_S1S4 <= S5_S1S4_next;
        S7_S1S6 <= S7_S1S6_next;
    end
end

assign fail_case[0] = ((~|syndrone[1]) & (~|syndrone[3]) & (~|syndrone[5]) & (|syndrone[7]));
assign fail_case[1] = ((~|syndrone[1]) & (~|syndrone[3]) & (|syndrone[5]));
assign fail_case[2] = ((|syndrone[1]) & (~|S3_S1S2) & (~|S5_S1S4) & (|S7_S1S6));
assign fail_case[3] = ((|syndrone[1]) & (|S3_S1S2) & (~|d_reg[1]) & (|d_reg[2]));
assign success_case[0] = ((~|syndrone[1]) & (|syndrone[3]) & (~|S5_S3S2) & (~|S7_S3S4));    //deg = 3
assign success_case[1] = ((~|syndrone[1]) & (|syndrone[3]) & (~|S5_S3S2) & (|S7_S3S4));     //deg = 4
assign success_case[2] = ((~|syndrone[1]) & (|syndrone[3]) & (|S5_S3S2) & (~|d_reg[0]));    //deg = 3
assign success_case[3] = ((~|syndrone[1]) & (|syndrone[3]) & (|S5_S3S2) & (|d_reg[0]));     //deg = 4
assign success_case[4] = ((|syndrone[1]) & (~|S3_S1S2) & (~|S5_S1S4) & (~|S7_S1S6));        //deg = 1
assign success_case[5] = ((|syndrone[1]) & (~|S3_S1S2) & (|S5_S1S4) & (~|d_reg[3]));        //deg = 4
assign success_case[6] = ((|syndrone[1]) & (~|S3_S1S2) & (|S5_S1S4) & (|d_reg[3]));         //deg = 4
assign success_case[7] = ((|syndrone[1]) & (|S3_S1S2) & (~|d_reg[1]) & (~|d_reg[2]));       //deg = 2
assign success_case[8] = ((|syndrone[1]) & (|S3_S1S2) & (|d_reg[1]) & (~|d_reg[4]));        //deg = 3
assign success_case[9] = ((|syndrone[1]) & (|S3_S1S2) & (|d_reg[1]) & (|d_reg[4]));         //deg = 4

always@(*) begin
    if(state_SINV_itr_3) begin
        d_reg_next[0] = mul[10][2];
        d_reg_next[1] = mul[10][3];
    end
    else if(state_DINV1_itr_0) begin
        d_reg_next[0] = add_mul[2];
        d_reg_next[1] = add_mul[3];
    end
    else if(state_BERLEKAMP) begin
        if(success_case[0]) begin
            d_reg_next[0] = 10'd0;
            d_reg_next[1] = 10'd0;
        end
        else if(success_case[1]) begin
            d_reg_next[0] = 10'd0;
            d_reg_next[1] = 10'd0;
        end
        else if(success_case[2]) begin
            d_reg_next[0] = 10'd0;
            d_reg_next[1] = d_reg[9];
        end
        else if(success_case[3]) begin
            d_reg_next[0] = 10'd0;
            d_reg_next[1] = d_reg[9];
        end
        else if(success_case[4]) begin
            d_reg_next[0] = syndrone[1];
            d_reg_next[1] = 10'd0;
        end
        else if(success_case[5]) begin
            d_reg_next[0] = syndrone[1];
            d_reg_next[1] = 10'd0;
        end
        else if(success_case[6]) begin
            d_reg_next[0] = syndrone[1];
            d_reg_next[1] = d_reg[12];
        end
        else if(success_case[7]) begin
            d_reg_next[0] = syndrone[1];
            d_reg_next[1] = d_reg[5];
        end
        else if(success_case[8]) begin
            d_reg_next[0] = syndrone[1];
            d_reg_next[1] = d1S1inv_d2d1inv;
        end
        else if(success_case[9]) begin
            d_reg_next[0] = syndrone[1];
            d_reg_next[1] = d1S1inv_d2d1inv_d3d2inv;
        end
        else begin
            d_reg_next[0] = 10'd0;
            d_reg_next[1] = 10'd0;
        end
    end
    else begin
        d_reg_next[0] = d_reg[0];
        d_reg_next[1] = d_reg[1];
    end

    if(state_SINV_itr_4) begin
        d_reg_next[2] = mul[10][2];
        d_reg_next[3] = mul[10][3];
    end
    else if(state_DINV1_itr_1) begin
        d_reg_next[2] = add_mul[2];
        d_reg_next[3] = add_mul[3];
    end
    else if(state_BERLEKAMP) begin
        if(success_case[0]) begin
            d_reg_next[2] = syndrone[3];
            d_reg_next[3] = 10'd0;
        end
        else if(success_case[1]) begin
            d_reg_next[2] = syndrone[3];
            d_reg_next[3] = d_reg[10];
        end
        else if(success_case[2]) begin
            d_reg_next[2] = syndrone[3];
            d_reg_next[3] = 10'd0;
        end
        else if(success_case[3]) begin
            d_reg_next[2] = syndrone[3];
            d_reg_next[3] = d_reg[8];
        end
        else if(success_case[4]) begin
            d_reg_next[2] = 10'd0;
            d_reg_next[3] = 10'd0;
        end
        else if(success_case[5]) begin
            d_reg_next[2] = 10'd0;
            d_reg_next[3] = d_reg[6];
        end
        else if(success_case[6]) begin
            d_reg_next[2] = d3d2invS1;
            d_reg_next[3] = d_reg[6];
        end
        else if(success_case[7]) begin
            d_reg_next[2] = 10'd0;
            d_reg_next[3] = 10'd0;
        end
        else if(success_case[8]) begin
            d_reg_next[2] = d2d1invS1;
            d_reg_next[3] = 10'd0;
        end
        else if(success_case[9]) begin
            d_reg_next[2] = S1_d2d1inv_d3d2inv;
            d_reg_next[3] = d3d2invd1S1inv;
        end
        else begin
            d_reg_next[2] = 10'd0;
            d_reg_next[3] = 10'd0;
        end
    end
    else begin
        d_reg_next[2] = d_reg[2];
        d_reg_next[3] = d_reg[3];
    end
    d_reg_next[4] = state_DINV1_itr_2 ? mul[10][2] : 
                    state_DINV2_itr_0 ? add_mul[3] : d_reg[4]; 
    d_reg_next[5] = state_DINV1_itr_2 ? mul[10][3] : d_reg[5];
    d_reg_next[6] = state_DINV1_itr_3 ? mul[10][2] : d_reg[6];
    d_reg_next[7] = state_DINV1_itr_3 ? mul[10][3] : d_reg[7];
    d_reg_next[8] = state_DINV1_itr_4 ? mul[10][2] : d_reg[8];
    d_reg_next[9] = state_DINV1_itr_4 ? mul[10][3] : d_reg[9];
    d_reg_next[10]= state_DINV1_itr_5 ? mul[10][2] : d_reg[10];
    d_reg_next[11]= state_DINV2_itr_0 ? mul[10][2] : d_reg[11];
    d_reg_next[12]= state_DINV2_itr_1 ? mul[10][2] : d_reg[12];
    d_reg_next[13]= state_DCALC       ? mul[10][2] : d_reg[13];
end
integer i6;
always@(posedge clk) begin
    if(!rstn)
        for(i6=0 ; i6<14 ; i6=i6+1) 
            d_reg[i6] <= 10'd0;
    else if(hard_1023_en)
        for(i6=0 ; i6<14 ; i6=i6+1) 
            d_reg[i6] <= d_reg_next[i6];
end
always@(*) begin
    if(state_BERLEKAMP) begin
        if(success_case[4])
            sigma_deg_next = 3'd1;
        else if(success_case[7])
            sigma_deg_next = 3'd2;
        else if(success_case[0] | success_case[2] | success_case[8]) 
            sigma_deg_next = 3'd3;
        else if(success_case[1] | success_case[3] | success_case[5] | success_case[6] | success_case[9])
            sigma_deg_next = 3'd4;
        else sigma_deg_next = sigma_deg;
    end
    else sigma_deg_next = sigma_deg;
end
always@(posedge clk) begin
    if(!rstn) sigma_deg <= 3'd0;
    else if(hard_1023_en) sigma_deg <= sigma_deg_next;
end 
//=============================
//             ROOT
//=============================
integer i7;
wire init_condition;
assign init_condition = (state_ROOT & (~|root_counter));
always@(*) begin
    for(i7=1 ; i7<=4 ; i7=i7+1) begin
        sigma_init_op[i7] = init_condition ? d_reg[i7-1] : 10'd0;
        sigma_init[i7][0] = sigma_init_op[i7];
    end 
    sigma_init[1][1] = {sigma_init_op[1][8],
                        sigma_init_op[1][7],
                        sigma_init_op[1][6],
                        sigma_init_op[1][5],
                        sigma_init_op[1][4],
                        sigma_init_op[1][3],
                        sigma_init_op[1][2] ^ sigma_init_op[1][9],
                        sigma_init_op[1][1],
                        sigma_init_op[1][0],
                        sigma_init_op[1][9]};
    sigma_init[2][1] = {sigma_init_op[2][7],
                        sigma_init_op[2][6],
                        sigma_init_op[2][5],
                        sigma_init_op[2][4],
                        sigma_init_op[2][3],
                        sigma_init_op[2][2] ^ sigma_init_op[2][9],
                        sigma_init_op[2][1] ^ sigma_init_op[2][8],
                        sigma_init_op[2][0],
                        sigma_init_op[2][9],
                        sigma_init_op[2][8]};
    sigma_init[3][1] = {sigma_init_op[3][6],
                        sigma_init_op[3][5],
                        sigma_init_op[3][4],
                        sigma_init_op[3][3],
                        sigma_init_op[3][2] ^ sigma_init_op[3][9],
                        sigma_init_op[3][1] ^ sigma_init_op[3][8],
                        sigma_init_op[3][0] ^ sigma_init_op[3][7],
                        sigma_init_op[3][9],
                        sigma_init_op[3][8],
                        sigma_init_op[3][7]};
    sigma_init[4][1] = {sigma_init_op[4][5],
                        sigma_init_op[4][4],
                        sigma_init_op[4][3],
                        sigma_init_op[4][2] ^ sigma_init_op[4][9],
                        sigma_init_op[4][1] ^ sigma_init_op[4][8],
                        sigma_init_op[4][0] ^ sigma_init_op[4][7],
                        sigma_init_op[4][6] ^ sigma_init_op[4][9],
                        sigma_init_op[4][8],
                        sigma_init_op[4][7],
                        sigma_init_op[4][6]};
    sigma_init[1][2] = {sigma_init_op[1][7],
                        sigma_init_op[1][6],
                        sigma_init_op[1][5],
                        sigma_init_op[1][4],
                        sigma_init_op[1][3],
                        sigma_init_op[1][2] ^ sigma_init_op[1][9],
                        sigma_init_op[1][1] ^ sigma_init_op[1][8],
                        sigma_init_op[1][0],
                        sigma_init_op[1][9],
                        sigma_init_op[1][8]};
    sigma_init[2][2] = {sigma_init_op[2][5],
                        sigma_init_op[2][4],
                        sigma_init_op[2][3],
                        sigma_init_op[2][2] ^ sigma_init_op[2][9],
                        sigma_init_op[2][1] ^ sigma_init_op[2][8],
                        sigma_init_op[2][0] ^ sigma_init_op[2][7],
                        sigma_init_op[2][6] ^ sigma_init_op[2][9],
                        sigma_init_op[2][8],
                        sigma_init_op[2][7],
                        sigma_init_op[2][6]};
    sigma_init[3][2] = {sigma_init_op[3][3],
                        sigma_init_op[3][2] ^ sigma_init_op[3][9],
                        sigma_init_op[3][1] ^ sigma_init_op[3][8],
                        sigma_init_op[3][0] ^ sigma_init_op[3][7],
                        sigma_init_op[3][6] ^ sigma_init_op[3][9],
                        sigma_init_op[3][5] ^ sigma_init_op[3][8],
                        sigma_init_op[3][4] ^ sigma_init_op[3][7],
                        sigma_init_op[3][6],
                        sigma_init_op[3][5],
                        sigma_init_op[3][4]};
    sigma_init[4][2] = {sigma_init_op[4][1] ^ sigma_init_op[4][8],
                        sigma_init_op[4][0] ^ sigma_init_op[4][7],
                        sigma_init_op[4][6] ^ sigma_init_op[4][9],
                        sigma_init_op[4][5] ^ sigma_init_op[4][8],
                        sigma_init_op[4][4] ^ sigma_init_op[4][7],
                        sigma_init_op[4][3] ^ sigma_init_op[4][6],
                        sigma_init_op[4][2] ^ sigma_init_op[4][5] ^ sigma_init_op[4][9],
                        sigma_init_op[4][4],
                        sigma_init_op[4][3],
                        sigma_init_op[4][2] ^ sigma_init_op[4][9]};
    sigma_init[1][3] = {sigma_init_op[1][6],
                        sigma_init_op[1][5],
                        sigma_init_op[1][4],
                        sigma_init_op[1][3],
                        sigma_init_op[1][2] ^ sigma_init_op[1][9],
                        sigma_init_op[1][1] ^ sigma_init_op[1][8],
                        sigma_init_op[1][0] ^ sigma_init_op[1][7],
                        sigma_init_op[1][9],
                        sigma_init_op[1][8],
                        sigma_init_op[1][7]};
    sigma_init[2][3] = {sigma_init_op[2][3],
                        sigma_init_op[2][2] ^ sigma_init_op[2][9],
                        sigma_init_op[2][1] ^ sigma_init_op[2][8],
                        sigma_init_op[2][0] ^ sigma_init_op[2][7],
                        sigma_init_op[2][6] ^ sigma_init_op[2][9],
                        sigma_init_op[2][5] ^ sigma_init_op[2][8],
                        sigma_init_op[2][4] ^ sigma_init_op[2][7],
                        sigma_init_op[2][6],
                        sigma_init_op[2][5],
                        sigma_init_op[2][4]};
    sigma_init[3][3] = {sigma_init_op[3][0] ^ sigma_init_op[3][7],
                        sigma_init_op[3][6] ^ sigma_init_op[3][9],
                        sigma_init_op[3][5] ^ sigma_init_op[3][8],
                        sigma_init_op[3][4] ^ sigma_init_op[3][7],
                        sigma_init_op[3][3] ^ sigma_init_op[3][6],
                        sigma_init_op[3][2] ^ sigma_init_op[3][5] ^ sigma_init_op[3][9],
                        sigma_init_op[3][1] ^ sigma_init_op[3][4] ^ sigma_init_op[3][8],
                        sigma_init_op[3][3],
                        sigma_init_op[3][2] ^ sigma_init_op[3][9],
                        sigma_init_op[3][1] ^ sigma_init_op[3][8]};
    sigma_init[4][3] = {sigma_init_op[4][4] ^ sigma_init_op[4][7],
                        sigma_init_op[4][3] ^ sigma_init_op[4][6],
                        sigma_init_op[4][2] ^ sigma_init_op[4][5] ^ sigma_init_op[4][9],
                        sigma_init_op[4][1] ^ sigma_init_op[4][4] ^ sigma_init_op[4][8],
                        sigma_init_op[4][0] ^ sigma_init_op[4][3] ^ sigma_init_op[4][7],
                        sigma_init_op[4][2] ^ sigma_init_op[4][6],
                        sigma_init_op[4][1] ^ sigma_init_op[4][5],
                        sigma_init_op[4][0] ^ sigma_init_op[4][7],
                        sigma_init_op[4][6] ^ sigma_init_op[4][9],
                        sigma_init_op[4][5] ^ sigma_init_op[4][8]};
end
integer i8,i9;
wire itr_condition;
assign itr_condition = (state_ROOT & (|root_counter));
always@(*) begin
    for(i8=0 ; i8<4 ; i8=i8+1) begin
        for(i9=1 ; i9<=4 ; i9=i9+1) begin
            sigma_mul_op[i9][i8] = itr_condition ? sigma[i9][i8] : 10'd0;
        end
        sigma_mul[1][i8] = {sigma_mul_op[1][i8][5],
                            sigma_mul_op[1][i8][4],
                            sigma_mul_op[1][i8][3],
                            sigma_mul_op[1][i8][2] ^ sigma_mul_op[1][i8][9],
                            sigma_mul_op[1][i8][1] ^ sigma_mul_op[1][i8][8],
                            sigma_mul_op[1][i8][0] ^ sigma_mul_op[1][i8][7],
                            sigma_mul_op[1][i8][6] ^ sigma_mul_op[1][i8][9],
                            sigma_mul_op[1][i8][8],
                            sigma_mul_op[1][i8][7],
                            sigma_mul_op[1][i8][6]};
        sigma_mul[2][i8] = {sigma_mul_op[2][i8][1] ^ sigma_mul_op[2][i8][8],
                            sigma_mul_op[2][i8][0] ^ sigma_mul_op[2][i8][7],
                            sigma_mul_op[2][i8][6] ^ sigma_mul_op[2][i8][9],
                            sigma_mul_op[2][i8][5] ^ sigma_mul_op[2][i8][8],
                            sigma_mul_op[2][i8][4] ^ sigma_mul_op[2][i8][7],
                            sigma_mul_op[2][i8][3] ^ sigma_mul_op[2][i8][6],
                            sigma_mul_op[2][i8][2] ^ sigma_mul_op[2][i8][5] ^ sigma_mul_op[2][i8][9],
                            sigma_mul_op[2][i8][4],
                            sigma_mul_op[2][i8][3],
                            sigma_mul_op[2][i8][2] ^ sigma_mul_op[2][i8][9]};
        sigma_mul[3][i8] = {sigma_mul_op[3][i8][4] ^ sigma_mul_op[3][i8][7],
                            sigma_mul_op[3][i8][3] ^ sigma_mul_op[3][i8][6],
                            sigma_mul_op[3][i8][2] ^ sigma_mul_op[3][i8][5] ^ sigma_mul_op[3][i8][9],
                            sigma_mul_op[3][i8][1] ^ sigma_mul_op[3][i8][4] ^ sigma_mul_op[3][i8][8],
                            sigma_mul_op[3][i8][0] ^ sigma_mul_op[3][i8][3] ^ sigma_mul_op[3][i8][7],
                            sigma_mul_op[3][i8][2] ^ sigma_mul_op[3][i8][6],
                            sigma_mul_op[3][i8][1] ^ sigma_mul_op[3][i8][5],
                            sigma_mul_op[3][i8][0] ^ sigma_mul_op[3][i8][7],
                            sigma_mul_op[3][i8][6] ^ sigma_mul_op[3][i8][9],
                            sigma_mul_op[3][i8][5] ^ sigma_mul_op[3][i8][8]};
        sigma_mul[4][i8] = {sigma_mul_op[4][i8][0] ^ sigma_mul_op[4][i8][3] ^ sigma_mul_op[4][i8][7],
                            sigma_mul_op[4][i8][2] ^ sigma_mul_op[4][i8][6],
                            sigma_mul_op[4][i8][1] ^ sigma_mul_op[4][i8][5],
                            sigma_mul_op[4][i8][0] ^ sigma_mul_op[4][i8][4],
                            sigma_mul_op[4][i8][3] ^ sigma_mul_op[4][i8][9],
                            sigma_mul_op[4][i8][2] ^ sigma_mul_op[4][i8][8] ^ sigma_mul_op[4][i8][9],
                            sigma_mul_op[4][i8][1] ^ sigma_mul_op[4][i8][7] ^ sigma_mul_op[4][i8][8],
                            sigma_mul_op[4][i8][3] ^ sigma_mul_op[4][i8][6],
                            sigma_mul_op[4][i8][2] ^ sigma_mul_op[4][i8][5] ^ sigma_mul_op[4][i8][9],
                            sigma_mul_op[4][i8][1] ^ sigma_mul_op[4][i8][4] ^ sigma_mul_op[4][i8][8]};
    end
end
integer i10, i11, i12, i13;
always@(*) begin
    if(state_ROOT) begin
        if(~|root_counter) begin
            for(i12=0 ; i12<4 ; i12=i12+1) begin
                for(i13=1 ; i13<=4 ; i13=i13+1) 
                    sigma_next[i13][i12] = sigma_init[i13][i12];
            end
        end
        else begin
            for(i12=0 ; i12<4 ; i12=i12+1) begin
                for(i13=1 ; i13<=4 ; i13=i13+1) 
                    sigma_next[i13][i12] = sigma_mul[i13][i12];
            end
        end
    end
    else begin
        for(i12=0 ; i12<4 ; i12=i12+1) begin
            for(i13=1 ; i13<=4 ; i13=i13+1) 
                sigma_next[i13][i12] = sigma[i13][i12];
        end
    end
end
always@(posedge clk) begin
    if(!rstn) begin
        for(i10=0 ; i10<4 ; i10=i10+1) begin
            for(i11=1 ; i11<=4 ; i11=i11+1) 
                sigma[i11][i10] <= 10'd0;
        end
    end
    else if(hard_1023_en) begin
        for(i10=0 ; i10<4 ; i10=i10+1) begin
            for(i11=1 ; i11<=4 ; i11=i11+1) 
                sigma[i11][i10] <= sigma_next[i11][i10];
        end
    end
end
integer i14, i15;
always@(*) begin
    for(i14=0 ; i14<4 ; i14=i14+1) begin
        for(i15=1 ; i15<=4 ; i15=i15+1) begin
            sigma_cal_op[i15][i14] = (~|root_counter) ? sigma_init[i15][i14] : sigma_mul[i15][i14];
        end
        sigma_cal[i14] = {sigma_cal_op[1][i14][9] ^ sigma_cal_op[2][i14][9] ^ sigma_cal_op[3][i14][9] ^ sigma_cal_op[4][i14][9],
                          sigma_cal_op[1][i14][8] ^ sigma_cal_op[2][i14][8] ^ sigma_cal_op[3][i14][8] ^ sigma_cal_op[4][i14][8],
                          sigma_cal_op[1][i14][7] ^ sigma_cal_op[2][i14][7] ^ sigma_cal_op[3][i14][7] ^ sigma_cal_op[4][i14][7],
                          sigma_cal_op[1][i14][6] ^ sigma_cal_op[2][i14][6] ^ sigma_cal_op[3][i14][6] ^ sigma_cal_op[4][i14][6],
                          sigma_cal_op[1][i14][5] ^ sigma_cal_op[2][i14][5] ^ sigma_cal_op[3][i14][5] ^ sigma_cal_op[4][i14][5],
                          sigma_cal_op[1][i14][4] ^ sigma_cal_op[2][i14][4] ^ sigma_cal_op[3][i14][4] ^ sigma_cal_op[4][i14][4],
                          sigma_cal_op[1][i14][3] ^ sigma_cal_op[2][i14][3] ^ sigma_cal_op[3][i14][3] ^ sigma_cal_op[4][i14][3],
                          sigma_cal_op[1][i14][2] ^ sigma_cal_op[2][i14][2] ^ sigma_cal_op[3][i14][2] ^ sigma_cal_op[4][i14][2],
                          sigma_cal_op[1][i14][1] ^ sigma_cal_op[2][i14][1] ^ sigma_cal_op[3][i14][1] ^ sigma_cal_op[4][i14][1],
                          sigma_cal_op[1][i14][0] ^ sigma_cal_op[2][i14][0] ^ sigma_cal_op[3][i14][0] ^ sigma_cal_op[4][i14][0] ^ 1'b1};
    end
    equal_zero[0] = (~|root_counter) ? 1'b0 : (~|sigma_cal[0]);
    equal_zero[1] = (~|sigma_cal[1]);
    equal_zero[2] = (~|sigma_cal[2]);
    equal_zero[3] = (~|sigma_cal[3]);
    error_index[0] = state_ROOT ? 10'd1023 - {root_counter, 2'b00} : 10'd0; //1023 1019 1015 ...... 3
    error_index[1] = state_ROOT ? 10'd1023 - {root_counter, 2'b01} : 10'd0; //1022 1018 1014 ...... 2
    error_index[2] = state_ROOT ? 10'd1023 - {root_counter, 2'b10} : 10'd0; //1021 1017 1013 ...... 1
    error_index[3] = state_ROOT ? 10'd1023 - {root_counter, 2'b11} : 10'd0; //1020 1016 1012 ...... 0
end
integer i16;
always@(*) begin
    if(state_IDLE) 
        for(i16=0 ; i16<4 ; i16=i16+1) 
            error_loc_next[i16] = 10'd0;
    else if(state_ROOT) begin
        if(equal_zero[0] & equal_zero[1] & equal_zero[2] & equal_zero[3]) begin
            error_loc_next[0] = error_index[3];
            error_loc_next[1] = error_index[2];
            error_loc_next[2] = error_index[1];
            error_loc_next[3] = error_index[0]; 
        end
        else if(equal_zero[0] & equal_zero[1] & equal_zero[2]) begin
            error_loc_next[0] = error_index[2];
            error_loc_next[1] = error_index[1];
            error_loc_next[2] = error_index[0];
            error_loc_next[3] = error_loc[0]; 
        end
        else if(equal_zero[0] & equal_zero[1] & equal_zero[3]) begin
            error_loc_next[0] = error_index[3];
            error_loc_next[1] = error_index[1];
            error_loc_next[2] = error_index[0];
            error_loc_next[3] = error_loc[0]; 
        end
        else if(equal_zero[0] & equal_zero[2] & equal_zero[3]) begin
            error_loc_next[0] = error_index[3];
            error_loc_next[1] = error_index[2];
            error_loc_next[2] = error_index[0];
            error_loc_next[3] = error_loc[0]; 
        end
        else if(equal_zero[1] & equal_zero[2] & equal_zero[3]) begin
            error_loc_next[0] = error_index[3];
            error_loc_next[1] = error_index[2];
            error_loc_next[2] = error_index[1];
            error_loc_next[3] = error_loc[0]; 
        end
        else if(equal_zero[0] & equal_zero[1]) begin
            error_loc_next[0] = error_index[1];
            error_loc_next[1] = error_index[0];
            error_loc_next[2] = error_loc[0];
            error_loc_next[3] = error_loc[1]; 
        end
        else if(equal_zero[0] & equal_zero[2]) begin
            error_loc_next[0] = error_index[2];
            error_loc_next[1] = error_index[0];
            error_loc_next[2] = error_loc[0];
            error_loc_next[3] = error_loc[1]; 
        end
        else if(equal_zero[0] & equal_zero[3]) begin
            error_loc_next[0] = error_index[3];
            error_loc_next[1] = error_index[0];
            error_loc_next[2] = error_loc[0];
            error_loc_next[3] = error_loc[1]; 
        end
        else if(equal_zero[1] & equal_zero[2]) begin
            error_loc_next[0] = error_index[2];
            error_loc_next[1] = error_index[1];
            error_loc_next[2] = error_loc[0];
            error_loc_next[3] = error_loc[1]; 
        end
        else if(equal_zero[1] & equal_zero[3]) begin
            error_loc_next[0] = error_index[3];
            error_loc_next[1] = error_index[1];
            error_loc_next[2] = error_loc[0];
            error_loc_next[3] = error_loc[1]; 
        end
        else if(equal_zero[2] & equal_zero[3]) begin
            error_loc_next[0] = error_index[3];
            error_loc_next[1] = error_index[2];
            error_loc_next[2] = error_loc[0];
            error_loc_next[3] = error_loc[1]; 
        end
        else if(equal_zero[0] | equal_zero[1] | equal_zero[2] | equal_zero[3]) begin
            error_loc_next[0] = equal_zero[0] ? error_index[0] : 
                                equal_zero[1] ? error_index[1] : 
                                equal_zero[2] ? error_index[2] : error_index[3];
            error_loc_next[1] = error_loc[0];
            error_loc_next[2] = error_loc[1];
            error_loc_next[3] = error_loc[2]; 
        end
        else begin
            for(i16=0 ; i16<4 ; i16=i16+1) 
                error_loc_next[i16] = error_loc[i16];
        end
    end
    else begin
        for(i16=0 ; i16<4 ; i16=i16+1) 
            error_loc_next[i16] = error_loc[i16];
    end
end
integer i17;
always@(posedge clk) begin
    if(!rstn) 
        for(i17=0 ; i17<4 ; i17=i17+1) 
            error_loc[i17] <= 10'd0;
    else if(hard_1023_en) 
        for(i17=0 ; i17<4 ; i17=i17+1) 
            error_loc[i17] <= error_loc_next[i17];
end
always@(*) begin
    if(state_IDLE) 
        error_num_next = 3'd0;
    else if(state_ROOT) begin
        if(equal_zero[0] & equal_zero[1] & equal_zero[2] & equal_zero[3]) 
            error_num_next = 3'd4;
        else if((equal_zero[0] & equal_zero[1] & equal_zero[2]) | 
                (equal_zero[0] & equal_zero[1] & equal_zero[3]) | 
                (equal_zero[0] & equal_zero[2] & equal_zero[3]) | 
                (equal_zero[1] & equal_zero[2] & equal_zero[3])) begin
            error_num_next = error_num + 3'd3;
        end
        else if((equal_zero[0] & equal_zero[1]) | (equal_zero[0] & equal_zero[2]) | 
                (equal_zero[0] & equal_zero[3]) | (equal_zero[1] & equal_zero[2]) |
                (equal_zero[1] & equal_zero[3]) | (equal_zero[2] & equal_zero[3])) begin
            error_num_next = error_num + 3'd2;
        end
        else if(equal_zero[0] | equal_zero[1] | equal_zero[2] | equal_zero[3]) 
            error_num_next = error_num + 3'd1;
        else error_num_next = error_num;
    end
    else error_num_next = error_num;
end
always@(posedge clk) begin
    if(!rstn) 
        error_num <= 3'd0;
    else if(hard_1023_en) 
        error_num <= error_num_next;
end
endmodule