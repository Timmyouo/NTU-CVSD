module hard_255(
    input clk,
    input rstn,

    input hard_255_en,
    input [7:0] hard_255_r_in,
    input soft_255,
    input [7:0] soft_255_r_in,

    output reg hard_255_success,
    output reg hard_255_fail,
    output [1:0] hard_255_error_num,
    output [7:0] hard_255_error_loc_0,
    output [7:0] hard_255_error_loc_1
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

reg [4:0] div_counter, div_counter_next;    //counter for finding b(X)
reg [3:0] itr_counter, itr_counter_next;    //counter for berlekamp
reg [5:0] root_counter, root_counter_next;  //counter for finding roots

reg [1:0] error_num, error_num_next;

//b(X)
reg [7:0] hard_r_in;
reg [6:0] r_in_sel;     //choose hard_r_in[7:1] at first cycle, choose hard_r_in[6:0] at other cycles
//b[1] = b1(X), b2(X), b4(X)
//b[2] = b3(X)
reg [7:0] b [1:2];
reg [7:0] b_next [1:2];
reg [7:0] b_1_cal [0:8];    //8 loop-unrolling calculating b1(X), b2(X), b4(X)
reg [7:0] b_2_cal [0:8];    //8 loop-unrolling calculating b3(X)

//syndrone
reg [7:0] syndrone      [1:3];
reg [7:0] syndrone_next [1:3];

//Berlekamp
reg [7:0] S1S2_cal [0:8];
reg [7:0] S3_add_S1S2;
reg [7:0] S1_square_op;
reg [7:0] S1_square_cal;
reg [7:0] S1_square, S1_square_next;
reg [7:0] S1_inv_cal [0:8];
reg [7:0] S1_inv, S1_inv_next;
reg [7:0] S1invS3_cal [0:8];
reg [7:0] S2_add_S1invS3;
reg [7:0] sigma_poly        [1:2];
reg [7:0] sigma_poly_next   [1:2];
reg [1:0] sigma_deg, sigma_deg_next;

//root
reg [7:0] sigma_1 [0:3];
reg [7:0] sigma_2 [0:3];
reg [7:0] sigma_1_next [0:3];
reg [7:0] sigma_2_next [0:3];
reg [7:0] sigma_1_init  [0:3];
reg [7:0] sigma_2_init  [0:3];
reg [7:0] sigma_init_op_1;
reg [7:0] sigma_init_op_2;
reg [7:0] sigma_1_mul   [0:3];
reg [7:0] sigma_2_mul   [0:3];
reg [7:0] sigma_1_mul_op[0:3];
reg [7:0] sigma_2_mul_op[0:3];
reg [7:0] sigma_cal     [0:3];
reg [7:0] sigma_cal_op_1[0:3];
reg [7:0] sigma_cal_op_2[0:3];
reg equal_zero [0:3];
reg [7:0] error_index [0:3];
reg [7:0] error_loc     [0:1];
reg [7:0] error_loc_next[0:1];

assign hard_255_error_num = error_num;
assign hard_255_error_loc_0 = error_loc[0];
assign hard_255_error_loc_1 = error_loc[1];
//=============================
//          success
//=============================
always@(posedge clk) begin
    if(!rstn) hard_255_success <= 1'b0;
    else hard_255_success <= ((state_next == S_NO_ERROR) | (state_next == S_FINISH));
end
//=============================
//           fail
//=============================
always@(posedge clk) begin
    if(!rstn) hard_255_fail <= 1'b0;
    else hard_255_fail <= (state_next == S_FAIL);
end
//=============================
//             FSM
//=============================
always@(*) begin
    case(state)
        S_IDLE:     state_next = hard_255_en ? S_DIVIDE : S_IDLE;
        S_DIVIDE:   state_next = (&div_counter) ? S_SYNDRONE : S_DIVIDE;
        S_SYNDRONE: state_next = ((~|syndrone_next[1]) &  (|syndrone_next[3])) ? S_FAIL :
                                 ((~|syndrone_next[1]) & (~|syndrone_next[3])) ? S_NO_ERROR : S_BERLEKAMP;
        S_BERLEKAMP:state_next = (itr_counter[3]) ? S_ROOT : S_BERLEKAMP;
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
    if(state_DIVIDE) div_counter_next = div_counter + 5'd1;
    else div_counter_next = 5'd0;
end
always@(posedge clk) begin
    if(!rstn) div_counter <= 5'd0;
    else if(hard_255_en) div_counter <= div_counter_next;
end
//=============================
//         itr_counter
//=============================
always@(*) begin
    if(state_BERLEKAMP) 
        itr_counter_next = (itr_counter == 4'd8) ? 4'd0 : itr_counter + 4'd1;
    else itr_counter_next = 4'd0;
end
always@(posedge clk) begin
    if(!rstn) itr_counter <= 4'd0;
    else if(hard_255_en) itr_counter <= itr_counter_next;
end
//=============================
//         root_counter
//=============================
always@(*) begin
    if(state_ROOT) 
        root_counter_next = root_counter + 6'd1;
    else root_counter_next = 6'd0;
end
always@(posedge clk) begin
    if(!rstn) root_counter <= 6'd0;
    else if(hard_255_en) root_counter <= root_counter_next;
end
//=============================
//      divider for b(X)
//=============================
integer i;
always@(*) begin
    hard_r_in = state_DIVIDE ? (soft_255 ? soft_255_r_in : hard_255_r_in) : 8'd0;
    b_1_cal[0] = state_DIVIDE ? b[1] : 8'd0;
    b_2_cal[0] = state_DIVIDE ? b[2] : 8'd0;
    for(i=0 ; i<7 ; i=i+1) begin
        r_in_sel[i] = (~|div_counter) ? hard_r_in[i+1] : hard_r_in[i]; //neglect first LLR at the first cycle
        b_1_cal[i+1] = {b_1_cal[i][6], 
                        b_1_cal[i][5], 
                        b_1_cal[i][4], 
                        b_1_cal[i][3] ^ b_1_cal[i][7],
                        b_1_cal[i][2] ^ b_1_cal[i][7], 
                        b_1_cal[i][1] ^ b_1_cal[i][7], 
                        b_1_cal[i][0], 
                        r_in_sel[i]   ^ b_1_cal[i][7]};
        b_2_cal[i+1] = {b_2_cal[i][6], 
                        b_2_cal[i][5] ^ b_2_cal[i][7], 
                        b_2_cal[i][4] ^ b_2_cal[i][7],
                        b_2_cal[i][3] ^ b_2_cal[i][7], 
                        b_2_cal[i][2], 
                        b_2_cal[i][1] ^ b_2_cal[i][7],
                        b_2_cal[i][0] ^ b_2_cal[i][7], 
                        r_in_sel[i]   ^ b_2_cal[i][7]};
    end
    b_1_cal[8] = {b_1_cal[7][6], 
                  b_1_cal[7][5], 
                  b_1_cal[7][4], 
                  b_1_cal[7][3] ^ b_1_cal[7][7],
                  b_1_cal[7][2] ^ b_1_cal[7][7], 
                  b_1_cal[7][1] ^ b_1_cal[7][7], 
                  b_1_cal[7][0], 
                  hard_r_in[7]  ^ b_1_cal[7][7]};
    b_2_cal[8] = {b_2_cal[7][6], 
                  b_2_cal[7][5] ^ b_2_cal[7][7], 
                  b_2_cal[7][4] ^ b_2_cal[7][7],
                  b_2_cal[7][3] ^ b_2_cal[7][7], 
                  b_2_cal[7][2], 
                  b_2_cal[7][1] ^ b_2_cal[7][7],
                  b_2_cal[7][0] ^ b_2_cal[7][7], 
                  hard_r_in[7]  ^ b_2_cal[7][7]};
end
always@(*) begin
    if(state_IDLE) begin
        b_next[1] = 8'd0;
        b_next[2] = 8'd0;
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
        b[1] <= 8'd0;
        b[2] <= 8'd0;
    end
    else if(hard_255_en) begin
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
        syndrone_next[2] = {b[1][6], 
                            b[1][3] ^ b[1][5] ^ b[1][6], 
                            b[1][5], 
                            b[1][2] ^ b[1][4] ^ b[1][5] ^ b[1][7],
                            b[1][4] ^ b[1][6], 
                            b[1][1] ^ b[1][4] ^ b[1][5] ^ b[1][6], 
                            b[1][7], 
                            b[1][0] ^ b[1][4] ^ b[1][6] ^ b[1][7]};
        syndrone_next[3] = {b[2][4], 
                            b[2][2] ^ b[2][4] ^ b[2][7], 
                            b[2][3] ^ b[2][5] ^ b[2][6] ^ b[2][7], 
                            b[2][3] ^ b[2][7], 
                            b[2][1] ^ b[2][3] ^ b[2][4] ^ b[2][6], 
                            b[2][4] ^ b[2][5] ^ b[2][6] ^ b[2][7], 
                            b[2][3] ^ b[2][5], 
                            b[2][0] ^ b[2][4] ^ b[2][6] ^ b[2][7]};
    end
    else begin
        syndrone_next[1] = syndrone[1];
        syndrone_next[2] = syndrone[2];
        syndrone_next[3] = syndrone[3];
    end
end
integer j;
always@(posedge clk) begin
    if(!rstn) 
        for(j=1 ; j<=3 ; j=j+1)
            syndrone[j] <= 8'd0;
    else if(hard_255_en) 
        for(j=1 ; j<=3 ; j=j+1)
            syndrone[j] <= syndrone_next[j];
end
//=============================
//          Berlekamp
//=============================
integer k;
//S3 + S1S2
reg [7:0] syndrone_1_temp;
reg [7:0] syndrone_2_temp;
always@(*) begin
    syndrone_1_temp = state_BERLEKAMP ? syndrone[1] : 8'd0;
    syndrone_2_temp = state_BERLEKAMP ? syndrone[2] : 8'd0;
    S1S2_cal[0] = 8'd0;
    for(k=0 ; k<8 ; k=k+1) begin
        S1S2_cal[k+1] = {(syndrone_1_temp[7] & syndrone_2_temp[7-k]) ^ S1S2_cal[k][6], 
                         (syndrone_1_temp[6] & syndrone_2_temp[7-k]) ^ S1S2_cal[k][5],
                         (syndrone_1_temp[5] & syndrone_2_temp[7-k]) ^ S1S2_cal[k][4], 
                         (syndrone_1_temp[4] & syndrone_2_temp[7-k]) ^ S1S2_cal[k][3] ^ S1S2_cal[k][7],
                         (syndrone_1_temp[3] & syndrone_2_temp[7-k]) ^ S1S2_cal[k][2] ^ S1S2_cal[k][7],
                         (syndrone_1_temp[2] & syndrone_2_temp[7-k]) ^ S1S2_cal[k][1] ^ S1S2_cal[k][7],
                         (syndrone_1_temp[1] & syndrone_2_temp[7-k]) ^ S1S2_cal[k][0],
                         (syndrone_1_temp[0] & syndrone_2_temp[7-k]) ^                  S1S2_cal[k][7]};
    end
    S3_add_S1S2 = syndrone[3] ^ S1S2_cal[8];
end
//S1^(-1)
always@(*) begin
    S1_square_op = (!state_BERLEKAMP) ? 8'd0 :
                   (~|itr_counter) ? syndrone[1] : S1_square;
    S1_square_cal = {S1_square_op[6],
                     S1_square_op[3] ^ S1_square_op[5] ^ S1_square_op[6], 
                     S1_square_op[5],
                     S1_square_op[2] ^ S1_square_op[4] ^ S1_square_op[5] ^ S1_square_op[7], 
                     S1_square_op[4] ^ S1_square_op[6], 
                     S1_square_op[1] ^ S1_square_op[4] ^ S1_square_op[5] ^ S1_square_op[6],
                     S1_square_op[7],
                     S1_square_op[0] ^ S1_square_op[4] ^ S1_square_op[6] ^ S1_square_op[7]};
    if(itr_counter == 4'd7) S1_square_next = 8'd0;
    else S1_square_next = S1_square_cal;
end
always@(posedge clk) begin
    if(!rstn) S1_square <= 8'd0;
    else if(hard_255_en) S1_square <= S1_square_next;
end
integer l;
always@(*) begin
    S1_inv_cal[0] = 8'd0;
    for(l=0 ; l<8 ; l=l+1) begin
        S1_inv_cal[l+1] = {(S1_inv[7] & S1_square[7-l]) ^ S1_inv_cal[l][6], 
                           (S1_inv[6] & S1_square[7-l]) ^ S1_inv_cal[l][5],
                           (S1_inv[5] & S1_square[7-l]) ^ S1_inv_cal[l][4],
                           (S1_inv[4] & S1_square[7-l]) ^ S1_inv_cal[l][3] ^ S1_inv_cal[l][7],
                           (S1_inv[3] & S1_square[7-l]) ^ S1_inv_cal[l][2] ^ S1_inv_cal[l][7],
                           (S1_inv[2] & S1_square[7-l]) ^ S1_inv_cal[l][1] ^ S1_inv_cal[l][7],
                           (S1_inv[1] & S1_square[7-l]) ^ S1_inv_cal[l][0],
                           (S1_inv[0] & S1_square[7-l]) ^                    S1_inv_cal[l][7]};
    end
    if(itr_counter == 4'd1) S1_inv_next = S1_square;
    else if(itr_counter == 4'd8) S1_inv_next = 8'd0; 
    else S1_inv_next = S1_inv_cal[8];
end
always@(posedge clk) begin
    if(!rstn) S1_inv <= 8'd0;
    else if(hard_255_en) S1_inv <= S1_inv_next;
end
//S1^(-1)*S3 + S2
integer index3;
reg [7:0] S1_inv_op;
reg [7:0] syndrone_2_op;
reg [7:0] syndrone_3_op;
always@(*) begin
    if(itr_counter == 4'd8) begin
        S1_inv_op = S1_inv;
        syndrone_2_op = syndrone[2];
        syndrone_3_op = syndrone[3];
    end
    else begin
        S1_inv_op = 8'd0;
        syndrone_2_op = 8'd0;
        syndrone_3_op = 8'd0;
    end
    S1invS3_cal[0] = 8'd0;
    for(index3=0 ; index3<8 ; index3=index3+1) begin
        S1invS3_cal[index3+1] = {(S1_inv_op[7] & syndrone_3_op[7-index3]) ^ S1invS3_cal[index3][6], 
            (S1_inv_op[6] & syndrone_3_op[7-index3]) ^ S1invS3_cal[index3][5],
            (S1_inv_op[5] & syndrone_3_op[7-index3]) ^ S1invS3_cal[index3][4],
            (S1_inv_op[4] & syndrone_3_op[7-index3]) ^ S1invS3_cal[index3][3] ^ S1invS3_cal[index3][7],
            (S1_inv_op[3] & syndrone_3_op[7-index3]) ^ S1invS3_cal[index3][2] ^ S1invS3_cal[index3][7],
            (S1_inv_op[2] & syndrone_3_op[7-index3]) ^ S1invS3_cal[index3][1] ^ S1invS3_cal[index3][7],
            (S1_inv_op[1] & syndrone_3_op[7-index3]) ^ S1invS3_cal[index3][0],
            (S1_inv_op[0] & syndrone_3_op[7-index3]) ^                          S1invS3_cal[index3][7]};
    end
    S2_add_S1invS3 = syndrone_2_op ^ S1invS3_cal[8];
end
//sigma polynomial
integer index1, index2;
always@(*) begin
    if(itr_counter == 4'd8) begin
        //S1 != 0
        if(~|S3_add_S1S2) begin //d1 = S3 + S1*S2 = 0
            //sigma_poly_next[0] = 8'd1;
            sigma_poly_next[1] = syndrone[1];
            sigma_poly_next[2] = 8'd0;
        end
        else begin //d1 = S3 + S1*S2 != 0
            //sigma_poly_next[0] = 8'd1;
            sigma_poly_next[1] = syndrone[1];
            sigma_poly_next[2] = S2_add_S1invS3;
        end
    end
    else begin
        for(index2=1 ; index2<3 ; index2=index2+1)
            sigma_poly_next[index2] = sigma_poly[index2];
    end
end
always@(posedge clk) begin
    if(!rstn) begin
        for(index2=1 ; index2<3 ; index2=index2+1) 
            sigma_poly[index2] <= 8'd0; 
    end
    else if(hard_255_en) begin
        for(index2=1 ; index2<3 ; index2=index2+1)
            sigma_poly[index2] <= sigma_poly_next[index2];
    end
end
always@(*) begin
    if(itr_counter == 4'd8) begin
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
    sigma_init_op_1 = (state_ROOT & (~|root_counter)) ? sigma_poly[1] : 8'd0;
    sigma_init_op_2 = (state_ROOT & (~|root_counter)) ? sigma_poly[2] : 8'd0;
    sigma_1_init[0] = sigma_init_op_1;
    sigma_2_init[0] = sigma_init_op_2;
    sigma_1_init[1] = {sigma_init_op_1[6],
                       sigma_init_op_1[5],
                       sigma_init_op_1[4], 
                       sigma_init_op_1[3] ^ sigma_init_op_1[7], 
                       sigma_init_op_1[2] ^ sigma_init_op_1[7], 
                       sigma_init_op_1[1] ^ sigma_init_op_1[7], 
                       sigma_init_op_1[0], 
                       sigma_init_op_1[7]};
    sigma_2_init[1] = {sigma_init_op_2[5], 
                       sigma_init_op_2[4], 
                       sigma_init_op_2[3] ^ sigma_init_op_2[7],
                       sigma_init_op_2[2] ^ sigma_init_op_2[6] ^ sigma_init_op_2[7], 
                       sigma_init_op_2[1] ^ sigma_init_op_2[6] ^ sigma_init_op_2[7], 
                       sigma_init_op_2[0] ^ sigma_init_op_2[6], 
                       sigma_init_op_2[7], 
                       sigma_init_op_2[6]};
    sigma_1_init[2] = {sigma_init_op_1[5], 
                       sigma_init_op_1[4], 
                       sigma_init_op_1[3] ^ sigma_init_op_1[7], 
                       sigma_init_op_1[2] ^ sigma_init_op_1[6] ^ sigma_init_op_1[7], 
                       sigma_init_op_1[1] ^ sigma_init_op_1[6] ^ sigma_init_op_1[7],
                       sigma_init_op_1[0] ^ sigma_init_op_1[6], 
                       sigma_init_op_1[7], 
                       sigma_init_op_1[6]};
    sigma_2_init[2] = {sigma_init_op_2[3] ^ sigma_init_op_2[7], 
                       sigma_init_op_2[2] ^ sigma_init_op_2[6] ^ sigma_init_op_2[7],
                       sigma_init_op_2[1] ^ sigma_init_op_2[5] ^ sigma_init_op_2[6] ^ sigma_init_op_2[7],
                       sigma_init_op_2[0] ^ sigma_init_op_2[4] ^ sigma_init_op_2[5] ^ sigma_init_op_2[6], 
                       sigma_init_op_2[4] ^ sigma_init_op_2[5] ^ sigma_init_op_2[7], 
                       sigma_init_op_2[4] ^ sigma_init_op_2[6], 
                       sigma_init_op_2[5], 
                       sigma_init_op_2[4]};
    sigma_1_init[3] = {sigma_init_op_1[4], 
                       sigma_init_op_1[3] ^ sigma_init_op_1[7],
                       sigma_init_op_1[2] ^ sigma_init_op_1[6] ^ sigma_init_op_1[7], 
                       sigma_init_op_1[1] ^ sigma_init_op_1[5] ^ sigma_init_op_1[6] ^ sigma_init_op_1[7],
                       sigma_init_op_1[0] ^ sigma_init_op_1[5] ^ sigma_init_op_1[6], 
                       sigma_init_op_1[5] ^ sigma_init_op_1[7], 
                       sigma_init_op_1[6], 
                       sigma_init_op_1[5]};
    sigma_2_init[3] = {sigma_init_op_2[1] ^ sigma_init_op_2[5] ^ sigma_init_op_2[6] ^ sigma_init_op_2[7], 
                       sigma_init_op_2[0] ^ sigma_init_op_2[4] ^ sigma_init_op_2[5] ^ sigma_init_op_2[6],
                       sigma_init_op_2[3] ^ sigma_init_op_2[4] ^ sigma_init_op_2[5], 
                       sigma_init_op_2[2] ^ sigma_init_op_2[3] ^ sigma_init_op_2[4], 
                       sigma_init_op_2[2] ^ sigma_init_op_2[3] ^ sigma_init_op_2[5] ^ sigma_init_op_2[6],
                       sigma_init_op_2[2] ^ sigma_init_op_2[4] ^ sigma_init_op_2[6] ^ sigma_init_op_2[7],
                       sigma_init_op_2[3] ^ sigma_init_op_2[7], 
                       sigma_init_op_2[2] ^ sigma_init_op_2[6] ^ sigma_init_op_2[7]};
end
//multiplication (sigma_1 multiply by alpha^4, sigma_2 multiply by alpha^8)
integer index7;
always@(*) begin
    for(index7=0 ; index7<4 ; index7=index7+1) begin
        sigma_1_mul_op[index7] = (state_ROOT & (|root_counter)) ? sigma_1[index7] : 8'd0;
        sigma_2_mul_op[index7] = (state_ROOT & (|root_counter)) ? sigma_2[index7] : 8'd0;
        sigma_1_mul[index7] = {sigma_1_mul_op[index7][3] ^ sigma_1_mul_op[index7][7], 
            sigma_1_mul_op[index7][2] ^ sigma_1_mul_op[index7][6] ^ sigma_1_mul_op[index7][7],
            sigma_1_mul_op[index7][1] ^ sigma_1_mul_op[index7][5] ^ sigma_1_mul_op[index7][6] ^ sigma_1_mul_op[index7][7],
            sigma_1_mul_op[index7][0] ^ sigma_1_mul_op[index7][4] ^ sigma_1_mul_op[index7][5] ^ sigma_1_mul_op[index7][6],
            sigma_1_mul_op[index7][4] ^ sigma_1_mul_op[index7][5] ^ sigma_1_mul_op[index7][7], 
            sigma_1_mul_op[index7][4] ^ sigma_1_mul_op[index7][6],
            sigma_1_mul_op[index7][5], 
            sigma_1_mul_op[index7][4]};
        sigma_2_mul[index7] = {sigma_2_mul_op[index7][3] ^ sigma_2_mul_op[index7][4] ^ sigma_2_mul_op[index7][5], 
            sigma_2_mul_op[index7][2] ^ sigma_2_mul_op[index7][3] ^ sigma_2_mul_op[index7][4],
            sigma_2_mul_op[index7][1] ^ sigma_2_mul_op[index7][2] ^ sigma_2_mul_op[index7][3] ^ sigma_2_mul_op[index7][7],
            sigma_2_mul_op[index7][0] ^ sigma_2_mul_op[index7][1] ^ sigma_2_mul_op[index7][2] ^ sigma_2_mul_op[index7][6],
            sigma_2_mul_op[index7][0] ^ sigma_2_mul_op[index7][1] ^ sigma_2_mul_op[index7][3] ^ sigma_2_mul_op[index7][4],
            sigma_2_mul_op[index7][0] ^ sigma_2_mul_op[index7][2] ^ sigma_2_mul_op[index7][4] ^ sigma_2_mul_op[index7][5] ^ sigma_2_mul_op[index7][7],
            sigma_2_mul_op[index7][1] ^ sigma_2_mul_op[index7][5] ^ sigma_2_mul_op[index7][6] ^ sigma_2_mul_op[index7][7],
            sigma_2_mul_op[index7][0] ^ sigma_2_mul_op[index7][4] ^ sigma_2_mul_op[index7][5] ^ sigma_2_mul_op[index7][6]};
    end
end
integer index5;
always@(*) begin
    if(state_ROOT) begin
        if(~|root_counter) begin
            for(index5=0 ; index5<4 ; index5=index5+1) begin
                sigma_1_next[index5] = sigma_1_init[index5];
                sigma_2_next[index5] = sigma_2_init[index5];
            end
        end
        else begin
            for(index5=0 ; index5<4 ; index5=index5+1) begin
                sigma_1_next[index5] = sigma_1_mul[index5];
                sigma_2_next[index5] = sigma_2_mul[index5];
            end
        end
    end
    else begin
        for(index5=0 ; index5<4 ; index5=index5+1) begin
            sigma_1_next[index5] = sigma_1[index5];
            sigma_2_next[index5] = sigma_2[index5];
        end
    end
end
integer index4;
always@(posedge clk) begin
    if(!rstn) begin
        for(index4=0 ; index4<4 ; index4=index4+1) begin
            sigma_1[index4] <= 8'd0;
            sigma_2[index4] <= 8'd0;
        end
    end
    else if(hard_255_en) begin
        for(index4=0 ; index4<4 ; index4=index4+1) begin
            sigma_1[index4] <= sigma_1_next[index4];
            sigma_2[index4] <= sigma_2_next[index4];
        end
    end
end
//summation and check if it's zero
integer index6;
always@(*) begin
    for(index6=0 ; index6<4 ; index6=index6+1) begin
        sigma_cal_op_1[index6] = (~|root_counter) ? sigma_1_init[index6] : sigma_1_mul[index6];
        sigma_cal_op_2[index6] = (~|root_counter) ? sigma_2_init[index6] : sigma_2_mul[index6];
        sigma_cal[index6] = {sigma_cal_op_1[index6][7] ^ sigma_cal_op_2[index6][7], 
                             sigma_cal_op_1[index6][6] ^ sigma_cal_op_2[index6][6],
                             sigma_cal_op_1[index6][5] ^ sigma_cal_op_2[index6][5],
                             sigma_cal_op_1[index6][4] ^ sigma_cal_op_2[index6][4],
                             sigma_cal_op_1[index6][3] ^ sigma_cal_op_2[index6][3],
                             sigma_cal_op_1[index6][2] ^ sigma_cal_op_2[index6][2],
                             sigma_cal_op_1[index6][1] ^ sigma_cal_op_2[index6][1],
                             sigma_cal_op_1[index6][0] ^ sigma_cal_op_2[index6][0] ^ 1'b1};
    end
    equal_zero[0] = (~|root_counter) ? 1'b0 : (~|sigma_cal[0]);
    equal_zero[1] = (~|sigma_cal[1]);
    equal_zero[2] = (~|sigma_cal[2]);
    equal_zero[3] = (~|sigma_cal[3]);
    error_index[0] = state_ROOT ? 8'd255 - {root_counter, 2'b00} : 8'd0; //255 251 247 ...... 3
    error_index[1] = state_ROOT ? 8'd255 - {root_counter, 2'b01} : 8'd0; //254 250 246 ...... 2
    error_index[2] = state_ROOT ? 8'd255 - {root_counter, 2'b10} : 8'd0; //253 249 245 ...... 1
    error_index[3] = state_ROOT ? 8'd255 - {root_counter, 2'b11} : 8'd0; //252 248 244 ...... 0
end
//error location
always@(*) begin
    if(state_IDLE) begin
        error_loc_next[0] = 8'd0;
        error_loc_next[1] = 8'd0;
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
        error_loc[0] <= 8'd0;
        error_loc[1] <= 8'd0;
    end
    else if(hard_255_en) begin
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
    else if(hard_255_en) error_num <= error_num_next;
end
endmodule