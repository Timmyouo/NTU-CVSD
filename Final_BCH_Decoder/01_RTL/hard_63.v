module hard_63(
    input clk,
    input rstn,

    input hard_63_en,
    input [7:0] hard_63_r_in,
    input soft_63,
    input [7:0] soft_63_r_in,

    output reg hard_63_success,
    output reg hard_63_fail,
    output [1:0] hard_63_error_num,
    output [5:0] hard_63_error_loc_0,
    output [5:0] hard_63_error_loc_1
);
localparam S_IDLE       = 3'd0;
localparam S_DIVIDE     = 3'd1;
localparam S_SYNDRONE   = 3'd2;
localparam S_BERLEKAMP  = 3'd3;
localparam S_ROOT       = 3'd4;
localparam S_FAIL       = 3'd5;
localparam S_NO_ERROR   = 3'd6;
localparam S_FINISH     = 3'd7;
reg [2:0] state, state_next;
wire state_IDLE, state_DIVIDE, state_SYNDRONE, state_BERLEKAMP, state_ROOT, state_FAIL, state_NO_ERROR, state_FINISH;
assign state_IDLE       = (state == S_IDLE);
assign state_DIVIDE     = (state == S_DIVIDE);
assign state_SYNDRONE   = (state == S_SYNDRONE);
assign state_BERLEKAMP  = (state == S_BERLEKAMP);
assign state_ROOT       = (state == S_ROOT);
assign state_FAIL       = (state == S_FAIL);
assign state_NO_ERROR   = (state == S_NO_ERROR);
assign state_FINISH     = (state == S_FINISH);

reg [2:0] div_counter, div_counter_next;    //counter for finding b(X)
reg [2:0] itr_counter, itr_counter_next;    //counter for berlekamp
reg [3:0] root_counter, root_counter_next;  //counter for finding roots

reg [1:0] error_num, error_num_next;

//b(X)
reg [7:0] hard_r_in;
reg [6:0] r_in_sel;     //choose hard_r_in[7:1] at first cycle, choose hard_r_in[6:0] at other cycles
//b[1] = b1(X), b2(X), b4(X)
//b[2] = b3(X)
reg [5:0] b [1:2];
reg [5:0] b_next [1:2];
reg [5:0] b_1_cal [0:8];    //8 loop-unrolling calculating b1(X), b2(X), b4(X)
reg [5:0] b_2_cal [0:8];    //8 loop-unrolling calculating b3(X)

//syndrone
reg [5:0] syndrone      [1:3];
reg [5:0] syndrone_next [1:3];

//Berlekamp
reg [5:0] S1S2_cal [0:6];
reg [5:0] S3_add_S1S2;
reg [5:0] S1_square_op;
reg [5:0] S1_square_cal;
reg [5:0] S1_square, S1_square_next;
reg [5:0] S1_inv_cal [0:6];
reg [5:0] S1_inv, S1_inv_next;
reg [5:0] S1invS3_cal [0:6];
reg [5:0] S2_add_S1invS3;
reg [5:0] sigma_poly        [1:2];
reg [5:0] sigma_poly_next   [1:2];
reg [1:0] sigma_deg, sigma_deg_next;

//root
reg [5:0] sigma_1 [0:3];
reg [5:0] sigma_2 [0:3];
reg [5:0] sigma_1_next [0:3];
reg [5:0] sigma_2_next [0:3];
reg [5:0] sigma_1_init  [0:3];
reg [5:0] sigma_2_init  [0:3];
reg [5:0] sigma_init_op_1;
reg [5:0] sigma_init_op_2;
reg [5:0] sigma_1_mul   [0:3];
reg [5:0] sigma_2_mul   [0:3];
reg [5:0] sigma_1_mul_op[0:3];
reg [5:0] sigma_2_mul_op[0:3];
reg [5:0] sigma_cal     [0:3];
reg [5:0] sigma_cal_op_1[0:3];
reg [5:0] sigma_cal_op_2[0:3];
reg equal_zero [0:3];
reg [5:0] error_index [0:3];
reg [5:0] error_loc     [0:1];
reg [5:0] error_loc_next[0:1];

assign hard_63_error_num = error_num;
assign hard_63_error_loc_0 = error_loc[0];
assign hard_63_error_loc_1 = error_loc[1];
//=============================
//          success
//=============================
always@(posedge clk) begin
    if(!rstn) hard_63_success <= 1'b0;
    else hard_63_success <= ((state_next == S_NO_ERROR) | (state_next == S_FINISH));
end
//=============================
//           fail
//=============================
always@(posedge clk) begin
    if(!rstn) hard_63_fail <= 1'b0;
    else hard_63_fail <= (state_next == S_FAIL);
end
//=============================
//             FSM
//=============================
always@(*) begin
    case(state)
        S_IDLE:     state_next = hard_63_en ? S_DIVIDE : S_IDLE;
        S_DIVIDE:   state_next = (&div_counter) ? S_SYNDRONE : S_DIVIDE;
        S_SYNDRONE: state_next = ((~|syndrone_next[1]) &  (|syndrone_next[3])) ? S_FAIL :
                                 ((~|syndrone_next[1]) & (~|syndrone_next[3])) ? S_NO_ERROR : S_BERLEKAMP;
        S_BERLEKAMP:state_next = (itr_counter == 3'd6) ? S_ROOT : S_BERLEKAMP;
        S_ROOT:     state_next = (&root_counter) ? ((sigma_deg != error_num_next) ? S_FAIL : S_FINISH) : S_ROOT;
        S_FAIL:     state_next = S_IDLE;
        S_NO_ERROR: state_next = S_IDLE;
        S_FINISH:   state_next = S_IDLE;
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
    if(state_DIVIDE) div_counter_next = div_counter + 3'd1;
    else div_counter_next = 3'd0;
end
always@(posedge clk) begin
    if(!rstn) div_counter <= 3'd0;
    else if(hard_63_en) div_counter <= div_counter_next;
end
//=============================
//         itr_counter
//=============================
always@(*) begin
    if(state_BERLEKAMP) 
        itr_counter_next = (itr_counter == 3'd6) ? 3'd0 : itr_counter + 3'd1;
    else itr_counter_next = 3'd0;
end
always@(posedge clk) begin
    if(!rstn) itr_counter <= 3'd0;
    else if(hard_63_en) itr_counter <= itr_counter_next;
end
//=============================
//         root_counter
//=============================
always@(*) begin
    if(state_ROOT) 
        root_counter_next = root_counter + 4'd1;
    else root_counter_next = 4'd0;
end
always@(posedge clk) begin
    if(!rstn) root_counter <= 4'd0;
    else if(hard_63_en) root_counter <= root_counter_next;
end
//=============================
//      divider for b(X)
//=============================
integer i1;
always@(*) begin
    hard_r_in = state_DIVIDE ? (soft_63 ? soft_63_r_in : hard_63_r_in) : 8'd0;
    b_1_cal[0] = state_DIVIDE ? b[1] : 6'd0;
    b_2_cal[0] = state_DIVIDE ? b[2] : 6'd0;
    for(i1=0 ; i1<7 ; i1=i1+1) begin
        r_in_sel[i1] = (~|div_counter) ? hard_r_in[i1+1] : hard_r_in[i1]; //neglect first LLR at the first cycle
        b_1_cal[i1+1] = {b_1_cal[i1][4], 
                         b_1_cal[i1][3],
                         b_1_cal[i1][2], 
                         b_1_cal[i1][1], 
                         b_1_cal[i1][0] ^ b_1_cal[i1][5], 
                         r_in_sel[i1]   ^ b_1_cal[i1][5]};
        b_2_cal[i1+1] = {b_2_cal[i1][4],
                         b_2_cal[i1][3] ^ b_2_cal[i1][5], 
                         b_2_cal[i1][2], 
                         b_2_cal[i1][1] ^ b_2_cal[i1][5],
                         b_2_cal[i1][0] ^ b_2_cal[i1][5], 
                         r_in_sel[i1]   ^ b_2_cal[i1][5]};
    end
    b_1_cal[8] = {b_1_cal[7][4], 
                  b_1_cal[7][3],
                  b_1_cal[7][2], 
                  b_1_cal[7][1], 
                  b_1_cal[7][0] ^ b_1_cal[7][5], 
                  hard_r_in[7]  ^ b_1_cal[7][5]};
    b_2_cal[8] = {b_2_cal[7][4],
                  b_2_cal[7][3] ^ b_2_cal[7][5], 
                  b_2_cal[7][2], 
                  b_2_cal[7][1] ^ b_2_cal[7][5],
                  b_2_cal[7][0] ^ b_2_cal[7][5], 
                  hard_r_in[7]  ^ b_2_cal[7][5]};
end
always@(*) begin
    if(state_IDLE) begin
        b_next[1] = 6'd0;
        b_next[2] = 6'd0;
    end
    else if(state_DIVIDE) begin
        if(~|div_counter) begin
            b_next[1] = b_1_cal[7];
            b_next[2] = b_2_cal[7];
        end
        else begin
            b_next[1] = b_1_cal[8];
            b_next[2] = b_2_cal[8];
        end
    end
    else begin
        b_next[1] = b[1];
        b_next[2] = b[2];
    end
end
always@(posedge clk) begin
    if(!rstn) begin
        b[1] <= 6'd0;
        b[2] <= 6'd0;
    end
    else if(hard_63_en) begin
        b[1] <= b_next[1];
        b[2] <= b_next[2];
    end
end
//=============================
//         syndrone
//=============================
always@(*) begin
    if(state_SYNDRONE) begin
        syndrone_next[1] = b[1];
        syndrone_next[2] = {b[1][5], 
                            b[1][2] ^ b[1][5], 
                            b[1][4],
                            b[1][1] ^ b[1][4],
                            b[1][3],
                            b[1][0] ^ b[1][3]};
        syndrone_next[3] = {b[2][5],
                            b[2][3],
                            b[2][1] ^ b[2][3] ^ b[2][5],
                            b[2][4],
                            b[2][2],
                            b[2][0] ^ b[2][2] ^ b[2][4]};
    end
    else begin
        syndrone_next[1] = syndrone[1];
        syndrone_next[2] = syndrone[2];
        syndrone_next[3] = syndrone[3];
    end
end
integer i2;
always@(posedge clk) begin
    if(!rstn) 
        for(i2=1 ; i2<=3 ; i2=i2+1)
            syndrone[i2] <= 6'd0;
    else if(hard_63_en) 
        for(i2=1 ; i2<=3 ; i2=i2+1)
            syndrone[i2] <= syndrone_next[i2];
end
//=============================
//          Berlekamp
//=============================
//S3 + S1S2
integer i3;
reg [5:0] syndrone_1_temp;
reg [5:0] syndrone_2_temp;
always@(*) begin
    syndrone_1_temp = state_BERLEKAMP ? syndrone[1] : 6'd0;
    syndrone_2_temp = state_BERLEKAMP ? syndrone[2] : 6'd0;
    S1S2_cal[0] = 6'd0;
    for(i3=0 ; i3<6 ; i3=i3+1) begin
        S1S2_cal[i3+1] = {(syndrone_1_temp[5] & syndrone_2_temp[5-i3]) ^ S1S2_cal[i3][4], 
                          (syndrone_1_temp[4] & syndrone_2_temp[5-i3]) ^ S1S2_cal[i3][3],
                          (syndrone_1_temp[3] & syndrone_2_temp[5-i3]) ^ S1S2_cal[i3][2],
                          (syndrone_1_temp[2] & syndrone_2_temp[5-i3]) ^ S1S2_cal[i3][1],
                          (syndrone_1_temp[1] & syndrone_2_temp[5-i3]) ^ S1S2_cal[i3][0] ^ S1S2_cal[i3][5],
                          (syndrone_1_temp[0] & syndrone_2_temp[5-i3]) ^                   S1S2_cal[i3][5]};
    end
    S3_add_S1S2 = syndrone[3] ^ S1S2_cal[6];
end
//S1^(-1)
always@(*) begin
    S1_square_op = (!state_BERLEKAMP) ? 6'd0 :
                   (~|itr_counter) ? syndrone[1] : S1_square;
    S1_square_cal = {S1_square_op[5], 
                     S1_square_op[2] ^ S1_square_op[5],
                     S1_square_op[4], 
                     S1_square_op[1] ^ S1_square_op[4],
                     S1_square_op[3],
                     S1_square_op[0] ^ S1_square_op[3]};
    if(itr_counter == 3'd5) S1_square_next = 6'd0;
    else S1_square_next = S1_square_cal;
end
always@(posedge clk) begin
    if(!rstn) S1_square <= 6'd0;
    else if(hard_63_en) S1_square <= S1_square_next;
end
integer i4;
always@(*) begin
    S1_inv_cal[0] = 6'd0;
    for(i4=0 ; i4<6 ; i4=i4+1) begin
        S1_inv_cal[i4+1] = {(S1_inv[5] & S1_square[5-i4]) ^ S1_inv_cal[i4][4],
                            (S1_inv[4] & S1_square[5-i4]) ^ S1_inv_cal[i4][3],
                            (S1_inv[3] & S1_square[5-i4]) ^ S1_inv_cal[i4][2],
                            (S1_inv[2] & S1_square[5-i4]) ^ S1_inv_cal[i4][1],
                            (S1_inv[1] & S1_square[5-i4]) ^ S1_inv_cal[i4][0] ^ S1_inv_cal[i4][5],
                            (S1_inv[0] & S1_square[5-i4]) ^                     S1_inv_cal[i4][5]};
    end
    if(itr_counter == 3'd1) S1_inv_next = S1_square;
    else if(itr_counter == 3'd6) S1_inv_next = 6'd0; 
    else S1_inv_next = S1_inv_cal[6];
end
always@(posedge clk) begin
    if(!rstn) S1_inv <= 6'd0;
    else if(hard_63_en) S1_inv <= S1_inv_next;
end
//S1^(-1)*S3 + S2
integer i5;
reg [5:0] S1_inv_op;
reg [5:0] syndrone_2_op;
reg [5:0] syndrone_3_op;
always@(*) begin
    if(itr_counter == 3'd6) begin
        S1_inv_op = S1_inv;
        syndrone_2_op = syndrone[2];
        syndrone_3_op = syndrone[3];
    end
    else begin
        S1_inv_op = 6'd0;
        syndrone_2_op = 6'd0;
        syndrone_3_op = 6'd0;
    end
    S1invS3_cal[0] = 6'd0;
    for(i5=0 ; i5<6 ; i5=i5+1) begin
        S1invS3_cal[i5+1] = {(S1_inv_op[5] & syndrone_3_op[5-i5]) ^ S1invS3_cal[i5][4],
                             (S1_inv_op[4] & syndrone_3_op[5-i5]) ^ S1invS3_cal[i5][3],
                             (S1_inv_op[3] & syndrone_3_op[5-i5]) ^ S1invS3_cal[i5][2],
                             (S1_inv_op[2] & syndrone_3_op[5-i5]) ^ S1invS3_cal[i5][1],
                             (S1_inv_op[1] & syndrone_3_op[5-i5]) ^ S1invS3_cal[i5][0] ^ S1invS3_cal[i5][5],
                             (S1_inv_op[0] & syndrone_3_op[5-i5]) ^                      S1invS3_cal[i5][5]};
    end
    S2_add_S1invS3 = syndrone_2_op ^ S1invS3_cal[6];
end
//sigma polynomial
always@(*) begin
    if(itr_counter == 3'd6) begin
        //S1 != 0
        if(~|S3_add_S1S2) begin //d1 = S3 + S1*S2 = 0
            //sigma_poly_next[0] = 8'd1;
            sigma_poly_next[1] = syndrone[1];
            sigma_poly_next[2] = 6'd0;
        end
        else begin //d1 = S3 + S1*S2 != 0
            //sigma_poly_next[0] = 8'd1;
            sigma_poly_next[1] = syndrone[1];
            sigma_poly_next[2] = S2_add_S1invS3;
        end
    end
    else begin
        sigma_poly_next[1] = sigma_poly[1];
        sigma_poly_next[2] = sigma_poly[2];
    end
end
always@(posedge clk) begin
    if(!rstn) begin 
        sigma_poly[1] <= 6'd0; 
        sigma_poly[2] <= 6'd0; 
    end
    else if(hard_63_en) begin
        sigma_poly[1] <= sigma_poly_next[1];
        sigma_poly[2] <= sigma_poly_next[2];
    end
end
always@(*) begin
    if(itr_counter == 3'd6) begin
        if(~|S3_add_S1S2) sigma_deg_next = 2'd1;
        else sigma_deg_next = 2'd2;
    end
    else sigma_deg_next = sigma_deg;
end
always@(posedge clk) begin
    if(!rstn) sigma_deg <= 2'd0;
    else sigma_deg <= sigma_deg_next;
end
//=============================
//            ROOT
//=============================
//initial value of sigma registers
always@(*) begin
    sigma_init_op_1 = (state_ROOT & (~|root_counter)) ? sigma_poly[1] : 6'd0;
    sigma_init_op_2 = (state_ROOT & (~|root_counter)) ? sigma_poly[2] : 6'd0;
    sigma_1_init[0] = sigma_init_op_1;
    sigma_2_init[0] = sigma_init_op_2;
    sigma_1_init[1] = {sigma_init_op_1[4],
                       sigma_init_op_1[3],
                       sigma_init_op_1[2],
                       sigma_init_op_1[1],
                       sigma_init_op_1[0] ^ sigma_init_op_1[5],
                       sigma_init_op_1[5]};
    sigma_2_init[1] = {sigma_init_op_2[3],
                       sigma_init_op_2[2],
                       sigma_init_op_2[1],
                       sigma_init_op_2[0] ^ sigma_init_op_2[5],
                       sigma_init_op_2[4] ^ sigma_init_op_2[5],
                       sigma_init_op_2[4]};
    sigma_1_init[2] = {sigma_init_op_1[3], 
                       sigma_init_op_1[2],
                       sigma_init_op_1[1],
                       sigma_init_op_1[0] ^ sigma_init_op_1[5],
                       sigma_init_op_1[4] ^ sigma_init_op_1[5],
                       sigma_init_op_1[4]};
    sigma_2_init[2] = {sigma_init_op_2[1],
                       sigma_init_op_2[0] ^ sigma_init_op_2[5],
                       sigma_init_op_2[4] ^ sigma_init_op_2[5],
                       sigma_init_op_2[3] ^ sigma_init_op_2[4],
                       sigma_init_op_2[2] ^ sigma_init_op_2[3],
                       sigma_init_op_2[2]};
    sigma_1_init[3] = {sigma_init_op_1[2],
                       sigma_init_op_1[1],
                       sigma_init_op_1[0] ^ sigma_init_op_1[5],
                       sigma_init_op_1[4] ^ sigma_init_op_1[5],
                       sigma_init_op_1[3] ^ sigma_init_op_1[4],
                       sigma_init_op_1[3]};
    sigma_2_init[3] = {sigma_init_op_2[4] ^ sigma_init_op_2[5],
                       sigma_init_op_2[3] ^ sigma_init_op_2[4],
                       sigma_init_op_2[2] ^ sigma_init_op_2[3],
                       sigma_init_op_2[1] ^ sigma_init_op_2[2],
                       sigma_init_op_2[0] ^ sigma_init_op_2[1] ^ sigma_init_op_2[5],
                       sigma_init_op_2[0] ^ sigma_init_op_2[5]};
end
//multiplication (sigma_1 multiply by alpha^4, sigma_2 multiply by alpha^8)
integer i6;
always@(*) begin
    for(i6=0 ; i6<4 ; i6=i6+1) begin
        sigma_1_mul_op[i6] = (state_ROOT & (|root_counter)) ? sigma_1[i6] : 6'd0;
        sigma_2_mul_op[i6] = (state_ROOT & (|root_counter)) ? sigma_2[i6] : 6'd0;
        sigma_1_mul[i6] = {sigma_1_mul_op[i6][1], 
                           sigma_1_mul_op[i6][0] ^ sigma_1_mul_op[i6][5],
                           sigma_1_mul_op[i6][4] ^ sigma_1_mul_op[i6][5],
                           sigma_1_mul_op[i6][3] ^ sigma_1_mul_op[i6][4],
                           sigma_1_mul_op[i6][2] ^ sigma_1_mul_op[i6][3],
                           sigma_1_mul_op[i6][2]};
        sigma_2_mul[i6] = {sigma_2_mul_op[i6][2] ^ sigma_2_mul_op[i6][3],
                           sigma_2_mul_op[i6][1] ^ sigma_2_mul_op[i6][2],
                           sigma_2_mul_op[i6][0] ^ sigma_2_mul_op[i6][1] ^ sigma_2_mul_op[i6][5],
                           sigma_2_mul_op[i6][0] ^ sigma_2_mul_op[i6][4],
                           sigma_2_mul_op[i6][3] ^ sigma_2_mul_op[i6][5],
                           sigma_2_mul_op[i6][3] ^ sigma_2_mul_op[i6][4]};
    end
end
integer i7;
always@(*) begin
    if(state_ROOT) begin
        if(~|root_counter) begin
            for(i7=0 ; i7<4 ; i7=i7+1) begin
                sigma_1_next[i7] = sigma_1_init[i7];
                sigma_2_next[i7] = sigma_2_init[i7];
            end
        end
        else begin
            for(i7=0 ; i7<4 ; i7=i7+1) begin
                sigma_1_next[i7] = sigma_1_mul[i7];
                sigma_2_next[i7] = sigma_2_mul[i7];
            end
        end
    end
    else begin
        for(i7=0 ; i7<4 ; i7=i7+1) begin
            sigma_1_next[i7] = sigma_1[i7];
            sigma_2_next[i7] = sigma_2[i7];
        end
    end
end
integer i8;
always@(posedge clk) begin
    if(!rstn) begin
        for(i8=0 ; i8<4 ; i8=i8+1) begin
            sigma_1[i8] <= 6'd0;
            sigma_2[i8] <= 6'd0;
        end
    end
    else if(hard_63_en) begin
        for(i8=0 ; i8<4 ; i8=i8+1) begin
            sigma_1[i8] <= sigma_1_next[i8];
            sigma_2[i8] <= sigma_2_next[i8];
        end
    end
end
//summation and check if it's zero
integer i9;
always@(*) begin
    for(i9=0 ; i9<4 ; i9=i9+1) begin
        sigma_cal_op_1[i9] = (~|root_counter) ? sigma_1_init[i9] : sigma_1_mul[i9];
        sigma_cal_op_2[i9] = (~|root_counter) ? sigma_2_init[i9] : sigma_2_mul[i9];
        sigma_cal[i9] = {sigma_cal_op_1[i9][5] ^ sigma_cal_op_2[i9][5],
                         sigma_cal_op_1[i9][4] ^ sigma_cal_op_2[i9][4],
                         sigma_cal_op_1[i9][3] ^ sigma_cal_op_2[i9][3],
                         sigma_cal_op_1[i9][2] ^ sigma_cal_op_2[i9][2],
                         sigma_cal_op_1[i9][1] ^ sigma_cal_op_2[i9][1],
                         sigma_cal_op_1[i9][0] ^ sigma_cal_op_2[i9][0] ^ 1'b1};
    end
    equal_zero[0] = (~|root_counter) ? 1'b0 : (~|sigma_cal[0]);
    equal_zero[1] = (~|sigma_cal[1]);
    equal_zero[2] = (~|sigma_cal[2]);
    equal_zero[3] = (~|sigma_cal[3]);
    error_index[0] = state_ROOT ? 6'd63 - {root_counter, 2'b00} : 6'd0; //63 59 55 ...... 3
    error_index[1] = state_ROOT ? 6'd63 - {root_counter, 2'b01} : 6'd0; //62 58 54 ...... 2
    error_index[2] = state_ROOT ? 6'd63 - {root_counter, 2'b10} : 6'd0; //61 57 53 ...... 1
    error_index[3] = state_ROOT ? 6'd63 - {root_counter, 2'b11} : 6'd0; //60 56 52 ...... 0
end
//error location
always@(*) begin
    if(state_IDLE) begin
        error_loc_next[0] = 6'd0;
        error_loc_next[1] = 6'd0;
    end
    else if(state_ROOT) begin
        if(equal_zero[0] & equal_zero[1]) begin
            error_loc_next[0] = error_index[1];
            error_loc_next[1] = error_index[0];
        end
        else if(equal_zero[0] & equal_zero[2]) begin
            error_loc_next[0] = error_index[2];
            error_loc_next[1] = error_index[0];
        end
        else if(equal_zero[0] & equal_zero[3]) begin
            error_loc_next[0] = error_index[3];
            error_loc_next[1] = error_index[0];
        end
        else if(equal_zero[1] & equal_zero[2]) begin
            error_loc_next[0] = error_index[2];
            error_loc_next[1] = error_index[1];
        end
        else if(equal_zero[1] & equal_zero[3]) begin
            error_loc_next[0] = error_index[3];
            error_loc_next[1] = error_index[1];
        end
        else if(equal_zero[2] & equal_zero[3]) begin
            error_loc_next[0] = error_index[3];
            error_loc_next[1] = error_index[2];
        end
        else if(equal_zero[0] | equal_zero[1] | equal_zero[2] | equal_zero[3]) begin
            error_loc_next[0] = equal_zero[0] ? error_index[0] :
                                equal_zero[1] ? error_index[1] :
                                equal_zero[2] ? error_index[2] : error_index[3];
            error_loc_next[1] = error_loc[0];
        end
        else begin
            error_loc_next[0] = error_loc[0];
            error_loc_next[1] = error_loc[1];
        end
    end
    else begin
        error_loc_next[0] = error_loc[0];
        error_loc_next[1] = error_loc[1];
    end
end
always@(posedge clk) begin
    if(!rstn) begin
        error_loc[0] <= 6'd0;
        error_loc[1] <= 6'd0;
    end
    else if(hard_63_en) begin
        error_loc[0] <= error_loc_next[0];
        error_loc[1] <= error_loc_next[1];
    end
end
always@(*) begin
    if(state_IDLE) 
        error_num_next = 2'd0;
    else if(state_ROOT) begin
        if((equal_zero[0] & equal_zero[1]) | (equal_zero[0] & equal_zero[2]) | 
           (equal_zero[0] & equal_zero[3]) | (equal_zero[1] & equal_zero[2]) | 
           (equal_zero[1] & equal_zero[3]) | (equal_zero[2] & equal_zero[3])) begin
            error_num_next = 2'd2;
        end
        else if(equal_zero[0] | equal_zero[1] | equal_zero[2] | equal_zero[3]) begin
            error_num_next = error_num + 2'd1;
        end
        else error_num_next = error_num;
    end
    else error_num_next = error_num;
end
always@(posedge clk) begin
    if(!rstn) error_num <= 2'd0;
    else if(hard_63_en) error_num <= error_num_next;
end
endmodule