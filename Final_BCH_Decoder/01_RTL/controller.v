module controller(
    input clk,
	input rstn,
	input mode,
	input [1:0] code,
	input set,
	input [63:0] idata,
	output reg ready,
	output reg finish,
	output [9:0] odata,

    //63 51 hard decoding
    output reg hard_63_en,
    output [7:0] hard_63_r_in,
    output reg soft_63,
    output [7:0] soft_63_r_in,

    input hard_63_success,
    input hard_63_fail,
    input [1:0] hard_63_error_num,
    input [5:0] hard_63_error_loc_0,
    input [5:0] hard_63_error_loc_1,

    //255 239 hard decoding
    output reg hard_255_en,
    output [7:0] hard_255_r_in,
    output reg soft_255,
    output [7:0] soft_255_r_in,

    input hard_255_success,
    input hard_255_fail,
    input [1:0] hard_255_error_num,
    input [7:0] hard_255_error_loc_0,
    input [7:0] hard_255_error_loc_1,

    //1023 983 hard decoding
    output reg hard_1023_en,
    output [7:0] hard_1023_r_in,
    output reg soft_1023,
    output [7:0] soft_1023_r_in,

    input hard_1023_success,
    input hard_1023_fail,
    input [2:0] hard_1023_error_num,
    input [9:0] hard_1023_error_loc_0,
    input [9:0] hard_1023_error_loc_1,
    input [9:0] hard_1023_error_loc_2,
    input [9:0] hard_1023_error_loc_3
);
localparam S_IDLE   = 4'd0;
localparam S_HARD   = 4'd1;
localparam S_LEAST  = 4'd2; //collect least reliable bits and hard decode first pattern
localparam S_WAIT   = 4'd3; //wait for the hard decoding result
localparam S_GAP    = 4'd4; //delay state between S_WAIT and S_FLIP
localparam S_LRB    = 4'd5; //sort LLR and find the least reliable bits
localparam S_FLIP   = 4'd6; //flip least reliable bits and output to hard decode submodules
localparam S_CORR   = 4'd7; //compute correlation
localparam S_DELAY  = 4'd8; //delay after S_CORR and jump to S_SORT
localparam S_SORT   = 4'd9; //sort the error locations
localparam S_FINISH = 4'd10; 
reg [3:0] state, state_next;
wire state_IDLE, state_HARD, state_LEAST, state_WAIT, state_LRB, state_FLIP, state_CORR, state_DELAY, state_SORT, state_FINISH;
assign state_IDLE   = (state == S_IDLE);
assign state_HARD   = (state == S_HARD);
assign state_LEAST  = (state == S_LEAST);
assign state_WAIT   = (state == S_WAIT);
assign state_LRB    = (state == S_LRB);
assign state_FLIP   = (state == S_FLIP);
assign state_CORR   = (state == S_CORR);
assign state_DELAY  = (state == S_DELAY);
assign state_SORT   = (state == S_SORT);
assign state_FINISH = (state == S_FINISH);

reg decode_mode, decode_mode_next;      //0:hard-decision decoding, 1:soft-decision decoding
reg [1:0] code_type, code_type_next;    //1:(63,51), 2:(255,239), 3:(1023,983)
wire code_type_63, code_type_255, code_type_1023;
assign code_type_63     = (code_type == 2'd1);
assign code_type_255    = (code_type == 2'd2);
assign code_type_1023   = (code_type == 2'd3);

//output signal to bch
reg ready_next;
reg [9:0] out_data, out_data_next;

//enable signals of hard decoding submodules
reg hard_63_en_next, hard_255_en_next, hard_1023_en_next;

reg [7:0] input_counter, input_counter_next;
reg [2:0] finish_counter, finish_counter_next;
reg [1:0] ptr_counter, ptr_counter_next;    //pattern counter

//error number and location for hard decoding
reg [2:0] error_num_hard;               //error_num = 7 if the pattern is failed
reg [2:0] error_num_hard_next;
reg [9:0] error_loc_hard [0:3];         //error location 0~3 of hard decoding result
reg [9:0] error_loc_hard_next [0:3];    //error location 0~3 of hard decoding result

//LLR
reg [63:0] LLR [0:127];
reg [63:0] LLR_next [0:127];

//LRB 
reg [9:0] LRB [0:1];
reg [9:0] LRB_next [0:1];
reg [9:0] LRB_candidate [0:1][0:3];
reg [9:0] LRB_candidate_next [0:1][0:3];
reg [6:0] LLR_candidate [0:1][0:3];
reg [6:0] LLR_candidate_next [0:1][0:3];
reg [7:0] idata_abs [0:1][0:3];

//bitonic sorter
reg [10:0] sort_reg [0:7];
reg [10:0] sort_reg_next [0:7]; 
reg [ 3:0] sort_comp;
reg [10:0] sort_comp_op1 [0:3];
reg [10:0] sort_comp_op2 [0:3]; 
reg [ 2:0] sort_counter, sort_counter_next;
wire sort_0, sort_1, sort_2, sort_3, sort_4, sort_5, sort_6;

//flip
reg [7:0] flip, flip_next;  

//correlation
reg signed [12:0] correlation [1:4];
reg signed [12:0] correlation_next [1:4];
reg corr_case [1:3];


//error number and location for soft decoding result
reg hard_fail [1:4];                    //record the hard decode fail pattern
reg hard_fail_next [1:4];
reg [2:0] error_num_soft [1:4];         //error_num = 7 if the pattern is failed
reg [2:0] error_num_soft_next [1:4];
reg [10:0] error_loc_soft [0:5][1:4];   //error location 0~3 of pattern 1~4
reg [10:0] error_loc_soft_next [0:5][1:4];

assign odata = out_data;
assign hard_63_r_in   = {idata[7], idata[15], idata[23], idata[31], idata[39], idata[47], idata[55], idata[63]};
assign hard_255_r_in  = {idata[7], idata[15], idata[23], idata[31], idata[39], idata[47], idata[55], idata[63]};
assign hard_1023_r_in = {idata[7], idata[15], idata[23], idata[31], idata[39], idata[47], idata[55], idata[63]};
assign soft_63_r_in   = {flip[0], flip[1], flip[2], flip[3], flip[4], flip[5], flip[6], flip[7]};
assign soft_255_r_in  = {flip[0], flip[1], flip[2], flip[3], flip[4], flip[5], flip[6], flip[7]};
assign soft_1023_r_in = {flip[0], flip[1], flip[2], flip[3], flip[4], flip[5], flip[6], flip[7]};

wire hard_finish, wait_finish, decode_success, decode_fail, ready_end, corr_finish;
assign hard_finish      = decode_success | decode_fail;
assign wait_finish      = (state_WAIT & hard_finish);
assign decode_success   = (hard_63_success | hard_255_success | hard_1023_success);
assign decode_fail      = (hard_63_fail    | hard_255_fail    | hard_1023_fail);
assign ready_end = ((code_type_63   & (input_counter == 8'd8  )) | 
                    (code_type_255  & (input_counter == 8'd32 )) | 
                    (code_type_1023 & (input_counter == 8'd128)));
assign corr_finish = ((code_type_63   & (input_counter == 8'd7  )) | 
                      (code_type_255  & (input_counter == 8'd31 )) | 
                      (code_type_1023 & (input_counter == 8'd127)));
//=============================
//       decode setting
//=============================
always@(*) begin
    if(set) decode_mode_next = mode;
    else decode_mode_next = decode_mode;
end
always@(posedge clk) begin
    if(!rstn) decode_mode <= 1'b0;
    else decode_mode <= decode_mode_next;
end
always@(*) begin
    if(set) code_type_next = code;
    else code_type_next = code_type;
end
always@(posedge clk) begin
    if(!rstn) code_type <= 2'd0;
    else code_type <= code_type_next;
end
//=============================
//             FSM
//=============================
always@(*) begin
    case(state)
        S_IDLE:     state_next = set ? (mode ? S_LEAST : S_HARD) : S_IDLE;
        S_HARD:     state_next = hard_finish ? S_FINISH : S_HARD; //hard decoding case
        S_LEAST:    state_next = ready_end ? S_WAIT : S_LEAST;
        S_WAIT: begin
            if(hard_finish) begin
                if(~|ptr_counter) state_next = S_LRB;
                else if(&ptr_counter) state_next = S_CORR;
                else state_next = S_GAP;
            end
            else state_next = S_WAIT;
        end
        S_GAP:      state_next = S_FLIP;
        S_LRB:      state_next = sort_6 ? S_FLIP : S_LRB;
        S_FLIP:     state_next = ready_end ? S_WAIT : S_FLIP;
        S_CORR:     state_next = corr_finish ? S_DELAY : S_CORR;
        S_DELAY:    state_next = S_SORT;
        S_SORT:     state_next = sort_6 ? S_FINISH : S_SORT;
        S_FINISH: begin
            if(!decode_mode) begin //hard decoding
                //1.no error, error_num_hard = 0  2.fail  3.error
                if((~|error_num_hard) | (&error_num_hard) | (error_num_hard == finish_counter)) 
                    state_next = S_IDLE; 
                else state_next = S_FINISH;
            end
            else begin  //soft decoding
                if((~|error_num_soft[4]) | (error_num_soft[4] == finish_counter)) 
                    state_next = S_IDLE;
                else state_next = S_FINISH;
            end
        end
        default:    state_next = state;
    endcase
end
always@(posedge clk) begin
    if(!rstn) state <= S_IDLE;
    else state <= state_next;
end
//=============================
//        input_counter
//=============================
wire [7:0] input_counter_inc;
assign input_counter_inc = input_counter + 8'd1;
always@(*) begin
    if(state_HARD | state_LEAST | state_FLIP) begin
        if(code_type_63) 
            input_counter_next = (input_counter == 8'd8) ? 8'd8 : input_counter_inc;
        else if(code_type_255)
            input_counter_next = (input_counter == 8'd32) ? 8'd32 : input_counter_inc;
        else input_counter_next = (input_counter == 8'd128) ? 8'd128 : input_counter_inc;
    end
    else if(state_CORR) begin
        if(code_type_63) 
            input_counter_next = (input_counter == 8'd7) ? 8'd0 : input_counter_inc;
        else if(code_type_255) 
            input_counter_next = (input_counter == 8'd31) ? 8'd0 : input_counter_inc;
        else input_counter_next = (input_counter == 8'd127) ? 8'd0 : input_counter_inc;
    end
    else input_counter_next = 8'd0;
end
always@(posedge clk) begin
    if(!rstn) input_counter <= 8'd0;
    else input_counter <= input_counter_next;
end
//index
reg [10:0] index_1023 [0:7];
reg [ 8:0] index_255  [0:7];
reg [ 6:0] index_63   [0:7];
reg [ 9:0] LRB_index  [0:1][0:3];
reg [ 9:0] LLR_index  [0:7];
wire FLIP_CORR;
assign FLIP_CORR = (state_FLIP | state_CORR);
integer i24;
always@(*) begin
    index_1023[0] = 11'd1031 - {input_counter, 3'b000}; //1023 1015 ...... 7
    index_1023[1] = 11'd1031 - {input_counter, 3'b001}; //1022 1014 ...... 6
    index_1023[2] = 11'd1031 - {input_counter, 3'b010}; //1021 1013 ...... 5
    index_1023[3] = 11'd1031 - {input_counter, 3'b011}; //1020 1012 ...... 4
    index_1023[4] = 11'd1031 - {input_counter, 3'b100}; //1019 1011 ...... 3
    index_1023[5] = 11'd1031 - {input_counter, 3'b101}; //1018 1010 ...... 2
    index_1023[6] = 11'd1031 - {input_counter, 3'b110}; //1017 1009 ...... 1
    index_1023[7] = 11'd1031 - {input_counter, 3'b111}; //1016 1008 ...... 0
    index_255[0] = 9'd263 - {input_counter[5:0], 3'b000}; //255  ...... 7
    index_255[1] = 9'd263 - {input_counter[5:0], 3'b001}; //254  ...... 6
    index_255[2] = 9'd263 - {input_counter[5:0], 3'b010}; //253  ...... 5
    index_255[3] = 9'd263 - {input_counter[5:0], 3'b011}; //252  ...... 4
    index_255[4] = 9'd263 - {input_counter[5:0], 3'b100}; //251  ...... 3
    index_255[5] = 9'd263 - {input_counter[5:0], 3'b101}; //250  ...... 2
    index_255[6] = 9'd263 - {input_counter[5:0], 3'b110}; //249  ...... 1
    index_255[7] = 9'd263 - {input_counter[5:0], 3'b111}; //248  ...... 0
    index_63[0] = 7'd71 - {input_counter[3:0], 3'b000}; //63  ...... 7
    index_63[1] = 7'd71 - {input_counter[3:0], 3'b001}; //62  ...... 6
    index_63[2] = 7'd71 - {input_counter[3:0], 3'b010}; //61  ...... 5
    index_63[3] = 7'd71 - {input_counter[3:0], 3'b011}; //60  ...... 4
    index_63[4] = 7'd71 - {input_counter[3:0], 3'b100}; //59  ...... 3
    index_63[5] = 7'd71 - {input_counter[3:0], 3'b101}; //58  ...... 2
    index_63[6] = 7'd71 - {input_counter[3:0], 3'b110}; //57  ...... 1
    index_63[7] = 7'd71 - {input_counter[3:0], 3'b111}; //56  ...... 0
    LRB_index[0][0] = decode_mode ? (code_type_63 ? {3'd0,index_63[0]} : 
                                     code_type_255 ? {1'd0, index_255[0]} : index_1023[0][9:0]) : 10'd0;
    LRB_index[1][0] = decode_mode ? (code_type_63 ? {3'd0,index_63[1]} : 
                                     code_type_255 ? {1'd0, index_255[1]} : index_1023[1][9:0]) : 10'd0;
    LRB_index[0][1] = decode_mode ? (code_type_63 ? {3'd0,index_63[2]} : 
                                     code_type_255 ? {1'd0, index_255[2]} : index_1023[2][9:0]) : 10'd0;
    LRB_index[1][1] = decode_mode ? (code_type_63 ? {3'd0,index_63[3]} : 
                                     code_type_255 ? {1'd0, index_255[3]} : index_1023[3][9:0]) : 10'd0;
    LRB_index[0][2] = decode_mode ? (code_type_63 ? {3'd0,index_63[4]} : 
                                     code_type_255 ? {1'd0, index_255[4]} : index_1023[4][9:0]) : 10'd0;
    LRB_index[1][2] = decode_mode ? (code_type_63 ? {3'd0,index_63[5]} : 
                                     code_type_255 ? {1'd0, index_255[5]} : index_1023[5][9:0]) : 10'd0;
    LRB_index[0][3] = decode_mode ? (code_type_63 ? {3'd0,index_63[6]} : 
                                     code_type_255 ? {1'd0, index_255[6]} : index_1023[6][9:0]) : 10'd0;
    LRB_index[1][3] = decode_mode ? (code_type_63 ? {3'd0,index_63[7]} : 
                                     code_type_255 ? {1'd0, index_255[7]} : index_1023[7][9:0]) : 10'd0;
    LLR_index[7] = FLIP_CORR ? LRB_index[0][0] - 10'd8 : 10'd0;
    LLR_index[6] = FLIP_CORR ? LRB_index[1][0] - 10'd8 : 10'd0;
    LLR_index[5] = FLIP_CORR ? LRB_index[0][1] - 10'd8 : 10'd0;
    LLR_index[4] = FLIP_CORR ? LRB_index[1][1] - 10'd8 : 10'd0;
    LLR_index[3] = FLIP_CORR ? LRB_index[0][2] - 10'd8 : 10'd0;
    LLR_index[2] = FLIP_CORR ? LRB_index[1][2] - 10'd8 : 10'd0;
    LLR_index[1] = FLIP_CORR ? LRB_index[0][3] - 10'd8 : 10'd0;
    LLR_index[0] = FLIP_CORR ? LRB_index[1][3] - 10'd8 : 10'd0;
end
//=============================
//           finish
//=============================
always@(posedge clk) begin
    if(!rstn) finish <= 1'b0;
    else finish <= (state_next == S_FINISH);
end
//=============================
//        finish_counter
//=============================
always@(*) begin
    if(state_FINISH) finish_counter_next = finish_counter + 3'd1;
    else finish_counter_next = 3'd1;
end
always@(posedge clk) begin
    if(!rstn) finish_counter <= 3'd1;
    else finish_counter <= finish_counter_next;
end
//=============================
//           ready
//=============================
always@(*) begin
    if(state_HARD | state_LEAST) begin
        if(~|input_counter) ready_next = 1'b1;
        else if(ready_end) ready_next = 1'b0;
        else ready_next = ready;
    end
    else ready_next = 1'b0;
end
always@(posedge clk) begin
    if(!rstn) ready <= 1'b0;
    else ready <= ready_next;
end
//=============================
//         out_data
//=============================
always@(*) begin
    if(state_next == S_FINISH) begin
        if(!decode_mode) begin //hard
            if(~|error_num_hard_next)
                out_data_next = 10'd1023;
            else out_data_next = error_loc_hard_next[0];
        end
        else begin //soft
            if(~|error_num_soft[4]) 
                out_data_next = 10'd1023;
            else out_data_next = sort_reg[0][9:0];
        end
    end
    else out_data_next = 10'd0;
end
always@(posedge clk) begin
    if(!rstn) out_data <= 10'd0;
    else out_data <= out_data_next;
end
//=============================
//         ptr_counter
//=============================
always@(*) begin
    if(wait_finish) ptr_counter_next = ptr_counter + 2'd1;
    else ptr_counter_next = ptr_counter;
end
always@(posedge clk) begin
    if(!rstn) ptr_counter <= 2'd0;
    else ptr_counter <= ptr_counter_next;
end
//=============================
//         hard_63_en
//=============================
always@(*) begin
    if(hard_63_success | hard_63_fail)
        hard_63_en_next = 1'b0;
    else if((state_next == S_FLIP) & code_type_63)
        hard_63_en_next = 1'b1;
    else if(((state_next == S_HARD) | (state_next == S_LEAST)) & set & (code == 2'd1))
        hard_63_en_next = 1'b1;
    else hard_63_en_next = hard_63_en;
end
always@(posedge clk) begin
    if(!rstn) hard_63_en <= 1'b0;
    else hard_63_en <= hard_63_en_next;
end
//=============================
//        hard_255_en
//=============================
always@(*) begin
    if(hard_255_success | hard_255_fail)
        hard_255_en_next = 1'b0;
    else if((state_next == S_FLIP) & code_type_255)
        hard_255_en_next = 1'b1;
    else if(((state_next == S_HARD) | (state_next == S_LEAST)) & set & (code == 2'd2))
        hard_255_en_next = 1'b1;
    else hard_255_en_next = hard_255_en;
end
always@(posedge clk) begin
    if(!rstn) hard_255_en <= 1'b0;
    else hard_255_en <= hard_255_en_next;
end
//=============================
//        hard_1023_en
//=============================
always@(*) begin
    if(hard_1023_success | hard_1023_fail)
        hard_1023_en_next = 1'b0;
    else if((state_next == S_FLIP) & code_type_1023)
        hard_1023_en_next = 1'b1;
    else if(((state_next == S_HARD) | (state_next == S_LEAST)) & set & (code == 2'd3))
        hard_1023_en_next = 1'b1;
    else hard_1023_en_next = hard_1023_en;
end
always@(posedge clk) begin
    if(!rstn) hard_1023_en <= 1'b0;
    else hard_1023_en <= hard_1023_en_next;
end
//=============================
// soft_63 soft_255 soft_1023
//=============================
always@(posedge clk) begin
    if(!rstn) soft_63 <= 1'b0;
    else soft_63 <= (state_FLIP & code_type_63);
end
always@(posedge clk) begin
    if(!rstn) soft_255 <= 1'b0;
    else soft_255 <= (state_FLIP & code_type_255);
end
always@(posedge clk) begin
    if(!rstn) soft_1023 <= 1'b0;
    else soft_1023 <= (state_FLIP & code_type_1023);
end
//=============================
//       error_loc_hard
//=============================
integer i1, i2;
always@(*) begin
    if(!decode_mode) begin
        if(decode_success) begin
            error_loc_hard_next[0] = hard_63_success  ? {4'd0, hard_63_error_loc_0}  : 
                                     hard_255_success ? {2'd0, hard_255_error_loc_0} : hard_1023_error_loc_0;
            error_loc_hard_next[1] = hard_63_success  ? {4'd0, hard_63_error_loc_1}  : 
                                     hard_255_success ? {2'd0, hard_255_error_loc_1} : hard_1023_error_loc_1;
            error_loc_hard_next[2] = hard_1023_success? hard_1023_error_loc_2 : error_loc_hard[2];
            error_loc_hard_next[3] = hard_1023_success? hard_1023_error_loc_3 : error_loc_hard[3];
        end
        else if(state_FINISH) begin
            error_loc_hard_next[0] = error_loc_hard[1];
            error_loc_hard_next[1] = error_loc_hard[2];
            error_loc_hard_next[2] = error_loc_hard[3];
            error_loc_hard_next[3] = error_loc_hard[3];
        end
        else begin
            for(i1=0 ; i1<4 ; i1=i1+1)
                error_loc_hard_next[i1] = error_loc_hard[i1];
        end  
    end
    else begin
        for(i1=0 ; i1<4 ; i1=i1+1)
            error_loc_hard_next[i1] = error_loc_hard[i1];
    end
end
always@(posedge clk) begin
    if(!rstn)
        for(i2=0 ; i2<4 ; i2=i2+1) 
            error_loc_hard[i2] <= 10'd0;
    else
        for(i2=0 ; i2<4 ; i2=i2+1) 
            error_loc_hard[i2] <= error_loc_hard_next[i2];
end
//=============================
//        error_num_hard
//=============================
always@(*) begin
    if(!decode_mode) begin
        if(decode_fail)
            error_num_hard_next = 3'd7;
        else if(decode_success) begin
            error_num_hard_next = hard_63_success   ? {1'b0, hard_63_error_num} :
                                  hard_255_success  ? {1'b0, hard_255_error_num} : hard_1023_error_num;
        end
        else error_num_hard_next = error_num_hard;
    end
    else error_num_hard_next = error_num_hard;
end
always@(posedge clk) begin
    if(!rstn) error_num_hard <= 3'd0;
    else error_num_hard <= error_num_hard_next;
end
//=============================
//  store hard output for soft
//=============================
//check these signal when success or fail 
reg [2:0] error_num_sel;
reg [10:0] error_loc_sel [0:3];
//select the error locations after checking which error location 
//from hard decode is the same as least reliable bits
reg [3:0] same_error [0:1];
reg [5:0] discard_loc;
always@(*) begin
    error_num_sel = code_type_63  ? {1'b0, hard_63_error_num} :  
                    code_type_255 ? {1'b0, hard_255_error_num}: hard_1023_error_num;
end
integer i3;
always@(*) begin
    if(decode_mode) begin
        case(error_num_sel)
            3'd1: begin
                error_loc_sel[0] = hard_63_success  ? {5'd0, hard_63_error_loc_0} : 
                                   hard_255_success ? {3'd0, hard_255_error_loc_0}: {1'b0, hard_1023_error_loc_0};
                for(i3=1 ; i3<4 ; i3=i3+1) 
                    error_loc_sel[i3] = 11'd1024;
            end
            3'd2: begin
                error_loc_sel[0] = hard_63_success  ? {5'd0, hard_63_error_loc_0} : 
                                   hard_255_success ? {3'd0, hard_255_error_loc_0}: {1'b0, hard_1023_error_loc_0};
                error_loc_sel[1] = hard_63_success  ? {5'd0, hard_63_error_loc_1} : 
                                   hard_255_success ? {3'd0, hard_255_error_loc_1}: {1'b0, hard_1023_error_loc_1};
                error_loc_sel[2] = 11'd1024;
                error_loc_sel[3] = 11'd1024;
            end
            3'd3: begin
                error_loc_sel[0] = {1'b0, hard_1023_error_loc_0};
                error_loc_sel[1] = {1'b0, hard_1023_error_loc_1};
                error_loc_sel[2] = {1'b0, hard_1023_error_loc_2};
                error_loc_sel[3] = 11'd1024;
            end
            3'd4: begin
                error_loc_sel[0] = {1'b0, hard_1023_error_loc_0};
                error_loc_sel[1] = {1'b0, hard_1023_error_loc_1};
                error_loc_sel[2] = {1'b0, hard_1023_error_loc_2};
                error_loc_sel[3] = {1'b0, hard_1023_error_loc_3};
            end
            default: begin //3'd0
                for(i3=0 ; i3<4 ; i3=i3+1) 
                    error_loc_sel[i3] = 11'd1024;
            end
        endcase
    end
    else
        for(i3=0 ; i3<4 ; i3=i3+1) 
            error_loc_sel[i3] = 11'd0;
end
//same error
integer i12, i13;
always@(*) begin
    //check LRB[0] and error_loc from hard-decoding
    for(i12=0 ; i12<2 ; i12=i12+1) begin
        for(i13=0 ; i13<4 ; i13=i13+1) 
            same_error[i12][i13] = (({1'b0, LRB[i12]}) == error_loc_sel[i13]);
    end
end
//discard loc
always@(*) begin
    discard_loc[0] = (same_error[0][0] | same_error[1][0]);
    discard_loc[1] = (same_error[0][1] | same_error[1][1]);
    discard_loc[2] = (same_error[0][2] | same_error[1][2]);
    discard_loc[3] = (same_error[0][3] | same_error[1][3]);
    discard_loc[4] = (same_error[0][0] | same_error[0][1] | same_error[0][2] | same_error[0][3]);
    discard_loc[5] = (same_error[1][0] | same_error[1][1] | same_error[1][2] | same_error[1][3]);
end
//fail 
integer i4, i5;
always@(*) begin
    if(wait_finish) begin
        hard_fail_next[4] = decode_fail;
        for(i4=1 ; i4<=3 ; i4=i4+1) 
            hard_fail_next[i4] = hard_fail[i4+1];
    end
    else begin
        for(i4=1 ; i4<=4 ; i4=i4+1) 
            hard_fail_next[i4] = hard_fail[i4];
    end
end
always@(posedge clk) begin
    if(!rstn) 
        for(i5=1 ; i5<=4 ; i5=i5+1)
            hard_fail[i5] <= 1'b0;
    else 
        for(i5=1 ; i5<=4 ; i5=i5+1)
            hard_fail[i5] <= hard_fail_next[i5];
end
//error_num
//error_num need to update after checking identical locations
integer i6; 
wire [2:0] error_num_dec_1, error_num_dec_2, error_num_inc_1, error_num_inc_2;
assign error_num_dec_1 = error_num_sel - 3'd1;
assign error_num_dec_2 = error_num_sel - 3'd2;
assign error_num_inc_1 = error_num_sel + 3'd1;
assign error_num_inc_2 = error_num_sel + 3'd2;
always@(*) begin
    if(wait_finish) begin
        if(decode_fail) 
            error_num_soft_next[4] = 3'd7;
        else begin //success
            case(ptr_counter) 
                2'd0: error_num_soft_next[4] = error_num_sel;
                2'd1: begin
                    if(discard_loc[4]) error_num_soft_next[4] = error_num_dec_1;
                    else error_num_soft_next[4] = error_num_inc_1;
                end
                2'd2: begin
                    if(discard_loc[5]) error_num_soft_next[4] = error_num_dec_1;
                    else error_num_soft_next[4] = error_num_inc_1;
                end
                2'd3: begin
                    if(discard_loc[4] & discard_loc[5]) error_num_soft_next[4] = error_num_dec_2;
                    else if((discard_loc[4] & (!discard_loc[5])) | ((!discard_loc[4]) & discard_loc[5]))
                        error_num_soft_next[4] = error_num_sel;
                    else error_num_soft_next[4] = error_num_inc_2;
                end
            endcase
        end
        for(i6=1 ; i6<=3 ; i6=i6+1) 
            error_num_soft_next[i6] = error_num_soft[i6+1];
    end
    else if(state_DELAY) begin
        if(corr_case[1]) error_num_soft_next[4] = error_num_soft[1];
        else if(corr_case[2]) error_num_soft_next[4] = error_num_soft[2];
        else if(corr_case[3]) error_num_soft_next[4] = error_num_soft[3];
        else error_num_soft_next[4] = error_num_soft[4];

        for(i6=1 ; i6<=3 ; i6=i6+1) 
            error_num_soft_next[i6] = error_num_soft[i6];
    end
    else 
        for(i6=1 ; i6<=4 ; i6=i6+1) 
            error_num_soft_next[i6] = error_num_soft[i6];
end
integer i7;
always@(posedge clk) begin
    if(!rstn) 
        for(i7=1 ; i7<=4 ; i7=i7+1) 
            error_num_soft[i7] <= 3'd0;
    else
        for(i7=1 ; i7<=4 ; i7=i7+1) 
            error_num_soft[i7] <= error_num_soft_next[i7];
end
//error_location
integer i8, i9;
always@(*) begin
    if(wait_finish) begin
        if(decode_fail) begin
            for(i9=0 ; i9<6 ; i9=i9+1) 
                error_loc_soft_next[i9][4] = 11'd1024;
        end
        else begin  //success
            case(ptr_counter) 
                2'd0: begin
                    for(i9=0 ; i9<4 ; i9=i9+1) 
                        error_loc_soft_next[i9][4] = error_loc_sel[i9];
                    error_loc_soft_next[4][4] = 11'd1024;
                    error_loc_soft_next[5][4] = 11'd1024;
                end
                2'd1: begin
                    error_loc_soft_next[0][4] = same_error[0][0] ? 11'd1024 : error_loc_sel[0];
                    error_loc_soft_next[1][4] = same_error[0][1] ? 11'd1024 : error_loc_sel[1];
                    error_loc_soft_next[2][4] = same_error[0][2] ? 11'd1024 : error_loc_sel[2];
                    error_loc_soft_next[3][4] = same_error[0][3] ? 11'd1024 : error_loc_sel[3];
                    error_loc_soft_next[4][4] = discard_loc[4]   ? 11'd1024 : {1'b0,LRB[0]};
                    error_loc_soft_next[5][4] = 11'd1024;
                end
                2'd2: begin
                    error_loc_soft_next[0][4] = same_error[1][0] ? 11'd1024 : error_loc_sel[0];
                    error_loc_soft_next[1][4] = same_error[1][1] ? 11'd1024 : error_loc_sel[1];
                    error_loc_soft_next[2][4] = same_error[1][2] ? 11'd1024 : error_loc_sel[2];
                    error_loc_soft_next[3][4] = same_error[1][3] ? 11'd1024 : error_loc_sel[3];
                    error_loc_soft_next[4][4] = 11'd1024;
                    error_loc_soft_next[5][4] = discard_loc[5] ? 11'd1024 : {1'b0,LRB[1]};
                end
                2'd3: begin
                    error_loc_soft_next[0][4] = discard_loc[0] ? 11'd1024 : error_loc_sel[0];
                    error_loc_soft_next[1][4] = discard_loc[1] ? 11'd1024 : error_loc_sel[1];
                    error_loc_soft_next[2][4] = discard_loc[2] ? 11'd1024 : error_loc_sel[2];
                    error_loc_soft_next[3][4] = discard_loc[3] ? 11'd1024 : error_loc_sel[3];
                    error_loc_soft_next[4][4] = discard_loc[4] ? 11'd1024 : {1'b0,LRB[0]};
                    error_loc_soft_next[5][4] = discard_loc[5] ? 11'd1024 : {1'b0,LRB[1]};
                end
            endcase
        end
        for(i8=1 ; i8<=3 ; i8=i8+1) begin
            error_loc_soft_next[0][i8] = error_loc_soft[0][i8+1];
            error_loc_soft_next[1][i8] = error_loc_soft[1][i8+1];
            error_loc_soft_next[2][i8] = error_loc_soft[2][i8+1];
            error_loc_soft_next[3][i8] = error_loc_soft[3][i8+1];
            error_loc_soft_next[4][i8] = error_loc_soft[4][i8+1];
            error_loc_soft_next[5][i8] = error_loc_soft[5][i8+1];
        end
    end
    else begin
        for(i8=1 ; i8<=4 ; i8=i8+1) begin
            for(i9=0 ; i9<6 ; i9=i9+1) 
                error_loc_soft_next[i9][i8] = error_loc_soft[i9][i8];
        end
    end
end
integer i10, i11;
always@(posedge clk) begin
    if(!rstn) begin
        for(i10=1 ; i10<=4 ; i10=i10+1) begin
            for(i11=0 ; i11<6 ; i11=i11+1) 
                error_loc_soft[i11][i10] <= 11'd1024;
        end
    end
    else begin
        for(i10=1 ; i10<=4 ; i10=i10+1) begin
            for(i11=0 ; i11<6 ; i11=i11+1) 
                error_loc_soft[i11][i10] <= error_loc_soft_next[i11][i10];
        end
    end
end
//=============================
//    Least Reliable Bits
//=============================
always@(*) begin
    idata_abs[0][0] = idata[63] ? (~idata[63:56]) + 8'd1 : idata[63:56];
    idata_abs[1][0] = idata[55] ? (~idata[55:48]) + 8'd1 : idata[55:48];
    idata_abs[0][1] = idata[47] ? (~idata[47:40]) + 8'd1 : idata[47:40];
    idata_abs[1][1] = idata[39] ? (~idata[39:32]) + 8'd1 : idata[39:32];
    idata_abs[0][2] = idata[31] ? (~idata[31:24]) + 8'd1 : idata[31:24];
    idata_abs[1][2] = idata[23] ? (~idata[23:16]) + 8'd1 : idata[23:16];
    idata_abs[0][3] = idata[15] ? (~idata[15: 8]) + 8'd1 : idata[15: 8];
    idata_abs[1][3] = idata[ 7] ? (~idata[ 7: 0]) + 8'd1 : idata[ 7: 0];
end
//less than
reg comp_LLR0_LLR1 [0:3];
reg comp_idata0_idata1 [0:3];
reg comp_idata0_LLR0 [0:3];
reg comp_idata1_LLR0 [0:3];
reg comp_idata0_LLR1 [0:3];
reg comp_idata1_LLR1 [0:3];

//equal to
reg equal_LLR [0:3];
reg equal_idata [0:3];
reg equal_idata0_LLR0 [0:3];
reg equal_idata1_LLR0 [0:3];
reg equal_idata0_LLR1 [0:3];
reg equal_idata1_LLR1 [0:3];

//less than or equal to
reg less_LLR0_LLR1 [0:3];
reg less_LLR1_LLR0 [0:3];
reg less_idata0_idata1 [0:3];
reg less_idata1_idata0 [0:3];
reg less_idata0_LLR0 [0:3];
reg less_LLR0_idata0 [0:3];
reg less_idata1_LLR0 [0:3];
reg less_LLR0_idata1 [0:3];
reg less_idata0_LLR1 [0:3];
reg less_LLR1_idata0 [0:3];
reg less_idata1_LLR1 [0:3];
reg less_LLR1_idata1 [0:3];

//case 0: choose LLR0 LLR1
//case 1: choose idata0 idata1
//case 2: choose LLR0 idata0
//case 3: choose LLR0 idata1
//case 4: choose LLR1 idata0
//case 5: choose LLR1 idata1
reg [4:0] LLR_case [0:3]; 
reg [9:0] LRB_op1 [0:3];
reg [9:0] LRB_op2 [0:3];
//comparison
integer i22;
always@(*) begin
    for(i22=0 ; i22<4 ; i22=i22+1) begin
        comp_LLR0_LLR1[i22] = (LLR_candidate[0][i22] < LLR_candidate[1][i22]);
        comp_idata0_idata1[i22] = (idata_abs[0][i22][6:0] < idata_abs[1][i22][6:0]);
        comp_idata0_LLR0[i22] = (idata_abs[0][i22][6:0] < LLR_candidate[0][i22]);
        comp_idata1_LLR0[i22] = (idata_abs[1][i22][6:0] < LLR_candidate[0][i22]);
        comp_idata0_LLR1[i22] = (idata_abs[0][i22][6:0] < LLR_candidate[1][i22]);
        comp_idata1_LLR1[i22] = (idata_abs[1][i22][6:0] < LLR_candidate[1][i22]);

        equal_LLR[i22] = (LLR_candidate[0][i22] == LLR_candidate[1][i22]);
        equal_idata[i22] = (idata_abs[0][i22][6:0] == idata_abs[1][i22][6:0]);
        equal_idata0_LLR0[i22] = (idata_abs[0][i22][6:0] == LLR_candidate[0][i22]);
        equal_idata1_LLR0[i22] = (idata_abs[1][i22][6:0] == LLR_candidate[0][i22]);
        equal_idata0_LLR1[i22] = (idata_abs[0][i22][6:0] == LLR_candidate[1][i22]);
        equal_idata1_LLR1[i22] = (idata_abs[1][i22][6:0] == LLR_candidate[1][i22]);
        
        less_LLR0_LLR1[i22] = (comp_LLR0_LLR1[i22] | equal_LLR[i22]);
        less_LLR1_LLR0[i22] = (!comp_LLR0_LLR1[i22]);
        less_idata0_idata1[i22] = (comp_idata0_idata1[i22] | equal_idata[i22]);
        less_idata1_idata0[i22] = (!comp_idata0_idata1[i22]);
        less_idata0_LLR0[i22] = (comp_idata0_LLR0[i22] | equal_idata0_LLR0[i22]);
        less_LLR0_idata0[i22] = (!comp_idata0_LLR0[i22]);
        less_idata1_LLR0[i22] = (comp_idata1_LLR0[i22] | equal_idata1_LLR0[i22]);
        less_LLR0_idata1[i22] = (!comp_idata1_LLR0[i22]);
        less_idata0_LLR1[i22] = (comp_idata0_LLR1[i22] | equal_idata0_LLR1[i22]);
        less_LLR1_idata0[i22] = (!comp_idata0_LLR1[i22]);
        less_idata1_LLR1[i22] = (comp_idata1_LLR1[i22] | equal_idata1_LLR1[i22]);
        less_LLR1_idata1[i22] = (!comp_idata1_LLR1[i22]);

        //case 5: choose LLR0 LLR1
        /*LLR_case[i22][0] = (less_LLR0_idata0[i22] & less_LLR0_idata1[i22]) & 
                           (less_LLR1_idata0[i22] & less_LLR1_idata1[i22]);*/  
        //case 0: choose idata0 idata1   
        LLR_case[i22][0] = (less_idata0_LLR0[i22] & less_idata0_LLR1[i22]) & 
                           (less_idata1_LLR0[i22] & less_idata1_LLR1[i22]); 
        //case 1: choose LLR1 idata0
        LLR_case[i22][1] = (less_LLR1_LLR0[i22]   & less_LLR1_idata1[i22]) & 
                           (less_idata0_LLR0[i22] & less_idata0_idata1[i22]);  
        //case 2: choose LLR1 idata1
        LLR_case[i22][2] = (less_LLR1_LLR0[i22]   & less_LLR1_idata0[i22]) & 
                           (less_idata1_LLR0[i22] & less_idata1_idata0[i22]);  
        //case 3: choose LLR0 idata0   
        LLR_case[i22][3] = (less_LLR0_LLR1[i22]   & less_LLR0_idata1[i22]) & 
                           (less_idata0_LLR1[i22] & less_idata0_idata1[i22]);   
        //case 4: choose LLR0 idata1
        LLR_case[i22][4] = (less_LLR0_LLR1[i22]   & less_LLR0_idata0[i22]) & 
                           (less_idata1_LLR1[i22] & less_idata1_idata0[i22]);   
    end
end
//LLR candidate
integer i23;
always@(*) begin
    if(state_LEAST & (|input_counter)) begin
        if(input_counter == 8'd1) begin
            LLR_candidate_next[0][0] = 7'd127;
            LLR_candidate_next[1][0] = idata_abs[1][0][6:0];
            for(i23=1 ; i23<4 ; i23=i23+1) begin
                LLR_candidate_next[0][i23] = idata_abs[0][i23][6:0];
                LLR_candidate_next[1][i23] = idata_abs[1][i23][6:0];
            end
        end
        else begin
            for(i23=0 ; i23<4 ; i23=i23+1) begin
                if(LLR_case[i23][0]) begin //case 0: choose idata0 idata1  
                    LLR_candidate_next[0][i23] = idata_abs[0][i23][6:0];
                    LLR_candidate_next[1][i23] = idata_abs[1][i23][6:0];
                end
                else if(LLR_case[i23][1]) begin //case 1: choose LLR1 idata0
                    LLR_candidate_next[0][i23] = idata_abs[0][i23][6:0];
                    LLR_candidate_next[1][i23] = LLR_candidate[1][i23];
                end
                else if(LLR_case[i23][2]) begin //case 2: choose LLR1 idata1
                    LLR_candidate_next[0][i23] = idata_abs[1][i23][6:0];
                    LLR_candidate_next[1][i23] = LLR_candidate[1][i23];
                end
                else if(LLR_case[i23][3]) begin //case 3: choose LLR0 idata0
                    LLR_candidate_next[0][i23] = LLR_candidate[0][i23];
                    LLR_candidate_next[1][i23] = idata_abs[0][i23][6:0];
                end
                else if(LLR_case[i23][4]) begin //case 4: choose LLR0 idata1
                    LLR_candidate_next[0][i23] = LLR_candidate[0][i23];
                    LLR_candidate_next[1][i23] = idata_abs[1][i23][6:0];
                end
                else begin //case 5: choose LLR0 LLR1
                    LLR_candidate_next[0][i23] = LLR_candidate[0][i23];
                    LLR_candidate_next[1][i23] = LLR_candidate[1][i23];
                end
            end
        end
    end
    else begin
        for(i23=0 ; i23<4 ; i23=i23+1) begin
            LLR_candidate_next[0][i23] = LLR_candidate[0][i23];
            LLR_candidate_next[1][i23] = LLR_candidate[1][i23];
        end
    end
end
integer i20;
always@(posedge clk) begin
    if(!rstn) begin
        for(i20=0 ; i20<4 ; i20=i20+1) begin
            LLR_candidate[0][i20] <= 7'd0;
            LLR_candidate[1][i20] <= 7'd0;
        end
    end
    else begin
        for(i20=0 ; i20<4 ; i20=i20+1) begin
            LLR_candidate[0][i20] <= LLR_candidate_next[0][i20];
            LLR_candidate[1][i20] <= LLR_candidate_next[1][i20];
        end
    end
end
//LRB candidate
integer i21, i25;
always@(*) begin
    if(state_LEAST & (|input_counter)) begin
        if(input_counter == 8'd1) begin
            LRB_candidate_next[0][0] = 10'd0;
            LRB_candidate_next[1][0] = LRB_index[1][0];
            for(i25=1 ; i25<4 ; i25=i25+1) begin
                LRB_candidate_next[0][i25] = LRB_index[0][i25];
                LRB_candidate_next[1][i25] = LRB_index[1][i25];
            end
        end
        else begin
            for(i25=0 ; i25<4 ; i25=i25+1) begin
                if(LLR_case[i25][0]) begin //case 0: choose idata0 idata1  
                    LRB_candidate_next[0][i25] = LRB_index[0][i25];
                    LRB_candidate_next[1][i25] = LRB_index[1][i25];
                end
                else if(LLR_case[i25][1]) begin //case 1: choose LLR1 idata0
                    LRB_candidate_next[0][i25] = LRB_index[0][i25];
                    LRB_candidate_next[1][i25] = LRB_candidate[1][i25];
                end
                else if(LLR_case[i25][2]) begin //case 2: choose LLR1 idata1
                    LRB_candidate_next[0][i25] = LRB_index[1][i25];
                    LRB_candidate_next[1][i25] = LRB_candidate[1][i25];
                end
                else if(LLR_case[i25][3]) begin //case 3: choose LLR0 idata0
                    LRB_candidate_next[0][i25] = LRB_candidate[0][i25];
                    LRB_candidate_next[1][i25] = LRB_index[0][i25];
                end
                else if(LLR_case[i25][4]) begin //case 4: choose LLR0 idata1
                    LRB_candidate_next[0][i25] = LRB_candidate[0][i25];
                    LRB_candidate_next[1][i25] = LRB_index[1][i25];
                end
                else begin //case 5: choose LLR0 LLR1
                    LRB_candidate_next[0][i25] = LRB_candidate[0][i25];
                    LRB_candidate_next[1][i25] = LRB_candidate[1][i25];
                end
            end
        end
    end 
    else if(state_LRB) begin
        //LRB canditate 0
        if(sort_0 | sort_1 | sort_2 | sort_3 | sort_4 | sort_5) 
            LRB_candidate_next[0][0] = sort_comp[0] ? LRB_op1[0] : LRB_op2[0];
        else LRB_candidate_next[0][0] = LRB_candidate[0][0];
        
        //LRB canditate 1
        if(sort_0 | sort_2 | sort_5)
            LRB_candidate_next[1][0] = sort_comp[0] ? LRB_op2[0] : LRB_op1[0];
        else if(sort_1 | sort_3 | sort_4) 
            LRB_candidate_next[1][0] = sort_comp[1] ? LRB_op1[1] : LRB_op2[1];
        else LRB_candidate_next[1][0] = LRB_candidate[1][0];

        //LRB canditate 2
        if(sort_0) 
            LRB_candidate_next[0][1] = sort_comp[1] ? LRB_op2[1] : LRB_op1[1];
        else if(sort_1 | sort_4) 
            LRB_candidate_next[0][1] = sort_comp[0] ? LRB_op2[0] : LRB_op1[0];
        else if(sort_2 | sort_5)
            LRB_candidate_next[0][1] = sort_comp[1] ? LRB_op1[1] : LRB_op2[1];
        else if(sort_3) 
            LRB_candidate_next[0][1] = sort_comp[2] ? LRB_op1[2] : LRB_op2[2];
        else LRB_candidate_next[0][1] = LRB_candidate[0][1];

        //LRB canditate 3
        if(sort_0) 
            LRB_candidate_next[1][1] = sort_comp[1] ? LRB_op1[1] : LRB_op2[1];
        else if(sort_1 | sort_2 | sort_4 | sort_5) 
            LRB_candidate_next[1][1] = sort_comp[1] ? LRB_op2[1] : LRB_op1[1];
        else if(sort_3)
            LRB_candidate_next[1][1] = sort_comp[3] ? LRB_op1[3] : LRB_op2[3];
        else LRB_candidate_next[1][1] = LRB_candidate[1][1];

        //LRB canditate 4
        if(sort_0 | sort_4 | sort_5) 
            LRB_candidate_next[0][2] = sort_comp[2] ? LRB_op1[2] : LRB_op2[2];
        else if(sort_1 | sort_2) 
            LRB_candidate_next[0][2] = sort_comp[2] ? LRB_op2[2] : LRB_op1[2];
        else if(sort_3) 
            LRB_candidate_next[0][2] = sort_comp[0] ? LRB_op2[0] : LRB_op1[0];
        else LRB_candidate_next[0][2] = LRB_candidate[0][2];

        //LRB canditate 5
        if(sort_0 | sort_5) 
            LRB_candidate_next[1][2] = sort_comp[2] ? LRB_op2[2] : LRB_op1[2];
        else if(sort_1) 
            LRB_candidate_next[1][2] = sort_comp[3] ? LRB_op2[3] : LRB_op1[3];
        else if(sort_2) 
            LRB_candidate_next[1][2] = sort_comp[2] ? LRB_op1[2] : LRB_op2[2];
        else if(sort_3) 
            LRB_candidate_next[1][2] = sort_comp[1] ? LRB_op2[1] : LRB_op1[1];
        else if(sort_4) 
            LRB_candidate_next[1][2] = sort_comp[3] ? LRB_op1[3] : LRB_op2[3];
        else LRB_candidate_next[1][2] = LRB_candidate[1][2];

        //LRB canditate 6
        if(sort_0 | sort_2)
            LRB_candidate_next[0][3] = sort_comp[3] ? LRB_op2[3] : LRB_op1[3];
        else if(sort_1) 
            LRB_candidate_next[0][3] = sort_comp[2] ? LRB_op1[2] : LRB_op2[2];
        else if(sort_3 | sort_4) 
            LRB_candidate_next[0][3] = sort_comp[2] ? LRB_op2[2] : LRB_op1[2];
        else if(sort_5)
            LRB_candidate_next[0][3] = sort_comp[3] ? LRB_op1[3] : LRB_op2[3];
        else LRB_candidate_next[0][3] = LRB_candidate[0][3];

        //LRB canditate 7
        if(sort_0 | sort_1 | sort_2) 
            LRB_candidate_next[1][3] = sort_comp[3] ? LRB_op1[3] : LRB_op2[3];
        else if(sort_3 | sort_4 | sort_5) 
            LRB_candidate_next[1][3] = sort_comp[3] ? LRB_op2[3] : LRB_op1[3];
        else LRB_candidate_next[1][3] = LRB_candidate[1][3];
    end
    else begin
        for(i25=0 ; i25<4 ; i25=i25+1) begin
            LRB_candidate_next[0][i25] = LRB_candidate[0][i25];
            LRB_candidate_next[1][i25] = LRB_candidate[1][i25];
        end
    end
end
always@(posedge clk) begin
    if(!rstn) begin
        for(i21=0 ; i21<4 ; i21=i21+1) begin
            LRB_candidate[0][i21] <= 10'd0;
            LRB_candidate[1][i21] <= 10'd0;
        end
    end
    else begin
        for(i21=0 ; i21<4 ; i21=i21+1) begin
            LRB_candidate[0][i21] <= LRB_candidate_next[0][i21];
            LRB_candidate[1][i21] <= LRB_candidate_next[1][i21];
        end
    end 
end
//LRB_op
integer i30;
always@(*) begin
    if(sort_0 | sort_2 | sort_5) begin
        LRB_op1[0] = LRB_candidate[0][0];
        LRB_op2[0] = LRB_candidate[1][0];
        LRB_op1[1] = LRB_candidate[0][1];
        LRB_op2[1] = LRB_candidate[1][1];
        LRB_op1[2] = LRB_candidate[0][2];
        LRB_op2[2] = LRB_candidate[1][2];
        LRB_op1[3] = LRB_candidate[0][3];
        LRB_op2[3] = LRB_candidate[1][3];
    end
    else if(sort_1 | sort_4) begin
        LRB_op1[0] = LRB_candidate[0][0]; 
        LRB_op2[0] = LRB_candidate[0][1]; 
        LRB_op1[1] = LRB_candidate[1][0]; 
        LRB_op2[1] = LRB_candidate[1][1]; 
        LRB_op1[2] = LRB_candidate[0][2]; 
        LRB_op2[2] = LRB_candidate[0][3]; 
        LRB_op1[3] = LRB_candidate[1][2]; 
        LRB_op2[3] = LRB_candidate[1][3];
    end
    else if(sort_3) begin
        LRB_op1[0] = LRB_candidate[0][0]; 
        LRB_op2[0] = LRB_candidate[0][2]; 
        LRB_op1[1] = LRB_candidate[1][0]; 
        LRB_op2[1] = LRB_candidate[1][2]; 
        LRB_op1[2] = LRB_candidate[0][1]; 
        LRB_op2[2] = LRB_candidate[0][3]; 
        LRB_op1[3] = LRB_candidate[1][1];
        LRB_op2[3] = LRB_candidate[1][3];
    end
    else begin
        for(i30=0 ; i30<4 ; i30=i30+1) begin
            LRB_op1[i30] = 10'd0;
            LRB_op2[i30] = 10'd0;
        end
    end
end
//LRB
always@(*) begin
    if(state_LRB & sort_6) begin
        LRB_next[0] = LRB_candidate[0][0];
        LRB_next[1] = LRB_candidate[1][0];
    end
    else begin
        LRB_next[0] = LRB[0];
        LRB_next[1] = LRB[1];
    end
end
always@(posedge clk) begin
    if(!rstn) begin
        LRB[0] <= 10'd0;
        LRB[1] <= 10'd0;
    end
    else begin
        LRB[0] <= LRB_next[0];
        LRB[1] <= LRB_next[1];
    end 
end
//=============================
//       Bitonic Sorter
//=============================
//sort_deg
integer i26;
always@(*) begin
    if(state_WAIT & (state_next == S_LRB)) begin
        sort_reg_next[0] = {4'd0, LLR_candidate[0][0]};
        sort_reg_next[1] = {4'd0, LLR_candidate[1][0]};
        sort_reg_next[2] = {4'd0, LLR_candidate[0][1]};
        sort_reg_next[3] = {4'd0, LLR_candidate[1][1]};
        sort_reg_next[4] = {4'd0, LLR_candidate[0][2]};
        sort_reg_next[5] = {4'd0, LLR_candidate[1][2]};
        sort_reg_next[6] = {4'd0, LLR_candidate[0][3]};
        sort_reg_next[7] = {4'd0, LLR_candidate[1][3]};
    end
    else if(state_DELAY) begin
        if(corr_case[1])
            for(i26=0 ; i26<6 ; i26=i26+1)
                sort_reg_next[i26] = error_loc_soft[i26][1];
        else if(corr_case[2]) 
            for(i26=0 ; i26<6 ; i26=i26+1)
                sort_reg_next[i26] = error_loc_soft[i26][2];
        else if(corr_case[3])
            for(i26=0 ; i26<6 ; i26=i26+1)
                sort_reg_next[i26] = error_loc_soft[i26][3];
        else 
            for(i26=0 ; i26<6 ; i26=i26+1)
                sort_reg_next[i26] = error_loc_soft[i26][4]; 
        sort_reg_next[6] = 11'd1024;
        sort_reg_next[7] = 11'd1024;
    end
    else if(state_next == S_FINISH) begin
        for(i26=0 ; i26<5 ; i26=i26+1) 
            sort_reg_next[i26] = sort_reg[i26+1];
        sort_reg_next[5] = sort_reg[5];
        sort_reg_next[6] = sort_reg[6];
        sort_reg_next[7] = sort_reg[7];
    end
    else if(state_LRB | state_SORT) begin
        //sort_reg_0
        if(sort_0 | sort_1 | sort_2 | sort_3 | sort_4 | sort_5) 
            sort_reg_next[0] = sort_comp[0] ? sort_comp_op1[0] : sort_comp_op2[0];
        else sort_reg_next[0] = sort_reg[0];
        //sort_reg_1
        if(sort_0 | sort_2 | sort_5)
            sort_reg_next[1] = sort_comp[0] ? sort_comp_op2[0] : sort_comp_op1[0];
        else if(sort_1 | sort_3 | sort_4) 
            sort_reg_next[1] = sort_comp[1] ? sort_comp_op1[1] : sort_comp_op2[1];
        else sort_reg_next[1] = sort_reg[1];
        //sort_reg_2
        if(sort_0) 
            sort_reg_next[2] = sort_comp[1] ? sort_comp_op2[1] : sort_comp_op1[1];
        else if(sort_1 | sort_4) 
            sort_reg_next[2] = sort_comp[0] ? sort_comp_op2[0] : sort_comp_op1[0];
        else if(sort_2 | sort_5)
            sort_reg_next[2] = sort_comp[1] ? sort_comp_op1[1] : sort_comp_op2[1];
        else if(sort_3) 
            sort_reg_next[2] = sort_comp[2] ? sort_comp_op1[2] : sort_comp_op2[2];
        else sort_reg_next[2] = sort_reg[2];
        //sort_reg_3
        if(sort_0) 
            sort_reg_next[3] = sort_comp[1] ? sort_comp_op1[1] : sort_comp_op2[1];
        else if(sort_1 | sort_2 | sort_4 | sort_5) 
            sort_reg_next[3] = sort_comp[1] ? sort_comp_op2[1] : sort_comp_op1[1];
        else if(sort_3)
            sort_reg_next[3] = sort_comp[3] ? sort_comp_op1[3] : sort_comp_op2[3];
        else sort_reg_next[3] = sort_reg[3];
        //sort_reg_4
        if(sort_0 | sort_4 | sort_5) 
            sort_reg_next[4] = sort_comp[2] ? sort_comp_op1[2] : sort_comp_op2[2];
        else if(sort_1 | sort_2) 
            sort_reg_next[4] = sort_comp[2] ? sort_comp_op2[2] : sort_comp_op1[2];
        else if(sort_3) 
            sort_reg_next[4] = sort_comp[0] ? sort_comp_op2[0] : sort_comp_op1[0];
        else sort_reg_next[4] = sort_reg[4];
        //sort_reg_5
        if(sort_0 | sort_5) 
            sort_reg_next[5] = sort_comp[2] ? sort_comp_op2[2] : sort_comp_op1[2];
        else if(sort_1) 
            sort_reg_next[5] = sort_comp[3] ? sort_comp_op2[3] : sort_comp_op1[3];
        else if(sort_2) 
            sort_reg_next[5] = sort_comp[2] ? sort_comp_op1[2] : sort_comp_op2[2];
        else if(sort_3) 
            sort_reg_next[5] = sort_comp[1] ? sort_comp_op2[1] : sort_comp_op1[1];
        else if(sort_4) 
            sort_reg_next[5] = sort_comp[3] ? sort_comp_op1[3] : sort_comp_op2[3];
        else sort_reg_next[5] = sort_reg[5];
        //sort_reg_6
        if(sort_0 | sort_2)
            sort_reg_next[6] = sort_comp[3] ? sort_comp_op2[3] : sort_comp_op1[3];
        else if(sort_1) 
            sort_reg_next[6] = sort_comp[2] ? sort_comp_op1[2] : sort_comp_op2[2];
        else if(sort_3 | sort_4) 
            sort_reg_next[6] = sort_comp[2] ? sort_comp_op2[2] : sort_comp_op1[2];
        else if(sort_5)
            sort_reg_next[6] = sort_comp[3] ? sort_comp_op1[3] : sort_comp_op2[3];
        else sort_reg_next[6] = sort_reg[6];
        //sort_reg_7
        if(sort_0 | sort_1 | sort_2) 
            sort_reg_next[7] = sort_comp[3] ? sort_comp_op1[3] : sort_comp_op2[3];
        else if(sort_3 | sort_4 | sort_5) 
            sort_reg_next[7] = sort_comp[3] ? sort_comp_op2[3] : sort_comp_op1[3];
        else sort_reg_next[7] = sort_reg[7];
    end
    else begin
        for(i26=0 ; i26<8 ; i26=i26+1) 
            sort_reg_next[i26] = sort_reg[i26];
    end
end
integer i27;
always@(posedge clk) begin
    if(!rstn)
        for(i27=0 ; i27<8 ; i27=i27+1) 
            sort_reg[i27] <= 11'd0;
    else 
        for(i27=0 ; i27<8 ; i27=i27+1) 
            sort_reg[i27] <= sort_reg_next[i27];
end
//sort_counter
assign sort_0 = (~|sort_counter);
assign sort_1 = (sort_counter == 3'd1);
assign sort_2 = (sort_counter == 3'd2);
assign sort_3 = (sort_counter == 3'd3);
assign sort_4 = (sort_counter == 3'd4);
assign sort_5 = (sort_counter == 3'd5);
assign sort_6 = (sort_counter == 3'd6);
always@(*) begin
    if(state_LRB | state_SORT) 
        sort_counter_next = sort_6 ? 3'd0 : sort_counter + 3'd1;
    else sort_counter_next = 3'd0;
end
always@(posedge clk) begin
    if(!rstn) sort_counter <= 3'd0;
    else sort_counter <= sort_counter_next;
end
//comp_op
integer i28, i29;
always@(*) begin
    if(state_LRB | state_SORT) begin
        if(sort_0 | sort_2 | sort_5) begin
            sort_comp_op1[0] = sort_reg[0];
            sort_comp_op2[0] = sort_reg[1];
            sort_comp_op1[1] = sort_reg[2];
            sort_comp_op2[1] = sort_reg[3];
            sort_comp_op1[2] = sort_reg[4];
            sort_comp_op2[2] = sort_reg[5];
            sort_comp_op1[3] = sort_reg[6];
            sort_comp_op2[3] = sort_reg[7];
        end
        else if(sort_1 | sort_4) begin
            sort_comp_op1[0] = sort_reg[0];
            sort_comp_op2[0] = sort_reg[2];
            sort_comp_op1[1] = sort_reg[1];
            sort_comp_op2[1] = sort_reg[3];
            sort_comp_op1[2] = sort_reg[4];
            sort_comp_op2[2] = sort_reg[6];
            sort_comp_op1[3] = sort_reg[5];
            sort_comp_op2[3] = sort_reg[7];
        end
        else if(sort_3) begin
            sort_comp_op1[0] = sort_reg[0];
            sort_comp_op2[0] = sort_reg[4];
            sort_comp_op1[1] = sort_reg[1];
            sort_comp_op2[1] = sort_reg[5];
            sort_comp_op1[2] = sort_reg[2];
            sort_comp_op2[2] = sort_reg[6];
            sort_comp_op1[3] = sort_reg[3];
            sort_comp_op2[3] = sort_reg[7];
        end
        else begin
            for(i28=0 ; i28<4 ; i28=i28+1) begin
                sort_comp_op1[i28] = 11'd0;
                sort_comp_op2[i28] = 11'd0;
            end
        end
    end
    else begin
        for(i28=0 ; i28<4 ; i28=i28+1) begin
            sort_comp_op1[i28] = 11'd0;
            sort_comp_op2[i28] = 11'd0;
        end
    end
    for(i29=0 ; i29<4 ; i29=i29+1) 
        sort_comp[i29] = (sort_comp_op1[i29] < sort_comp_op2[i29]);
end
//=============================
//             flip
//=============================
integer i18, i19, i32, i33;
always@(*) begin
    if(state_LEAST) begin
        for(i18=1 ; i18<128 ; i18=i18+1) 
            LLR_next[i18] = LLR[i18-1];
        LLR_next[0] = idata;
    end
    else if(state_FLIP & (!ready_end)) begin
        if(code_type_63) begin
            LLR_next[0] = LLR[7];
            for(i32=1 ; i32<=7 ; i32=i32+1) 
                LLR_next[i32] = LLR[i32-1];
            for(i18=8 ; i18<=127 ; i18=i18+1) 
                LLR_next[i18] = LLR[i18];
        end
        else if(code_type_255) begin
            LLR_next[0] = LLR[31];
            for(i32=1 ; i32<=31 ; i32=i32+1) 
                LLR_next[i32] = LLR[i32-1];
            for(i18=32 ; i18<=127 ; i18=i18+1)
                LLR_next[i18] = LLR[i18];
        end
        else begin
            LLR_next[0] = LLR[127];
            for(i32=1 ; i32<=127 ; i32=i32+1) 
                LLR_next[i32] = LLR[i32-1];
        end
    end
    else if(state_CORR) begin
        if(code_type_63) LLR_next[8] = LLR[8];
        else LLR_next[8] = LLR[7];

        if(code_type_255) LLR_next[32] = LLR[32];
        else LLR_next[32] = LLR[31];

        LLR_next[0] = LLR[0];

        for(i33=1 ; i33<=7 ; i33=i33+1) 
            LLR_next[i33] = LLR[i33-1];

        for(i32=9 ; i32<=31 ; i32=i32+1) 
            LLR_next[i32] = LLR[i32-1];

        for(i18=33 ; i18<=127 ; i18=i18+1)
            LLR_next[i18] = LLR[i18-1];
    end
    else 
        for(i18=0 ; i18<128 ; i18=i18+1) 
            LLR_next[i18] = LLR[i18];
end
always@(posedge clk) begin
    if(!rstn) 
        for(i19=0 ; i19<128 ; i19=i19+1) 
            LLR[i19] <= 64'd0;
    else 
        for(i19=0 ; i19<128 ; i19=i19+1) 
            LLR[i19] <= LLR_next[i19];
end
integer i31;
reg idata_LRB [0:7][0:1];
reg [7:0] flip_en;
wire [7:0] r_63, r_255, r_1023;
wire [7:0] r_sel;
assign r_63 = {LLR[7][63], LLR[7][55], LLR[7][47], LLR[7][39], 
               LLR[7][31], LLR[7][23], LLR[7][15], LLR[7][7]};
assign r_255 = {LLR[31][63], LLR[31][55], LLR[31][47], LLR[31][39], 
                LLR[31][31], LLR[31][23], LLR[31][15], LLR[31][7]};
assign r_1023 = {LLR[127][63], LLR[127][55], LLR[127][47], LLR[127][39], 
                 LLR[127][31], LLR[127][23], LLR[127][15], LLR[127][7]};
assign r_sel = code_type_63  ? r_63  : 
               code_type_255 ? r_255 : r_1023;
always@(*) begin
    for(i31=0 ; i31<8 ; i31=i31+1) begin 
        idata_LRB[i31][0] = (LLR_index[i31] == LRB[0]);
        idata_LRB[i31][1] = (LLR_index[i31] == LRB[1]); 
        if(ptr_counter == 2'd1) //flip LRB[0]
            flip_en[i31] = idata_LRB[i31][0]; 
        else if(ptr_counter == 2'd2) //flip LRB[1]
            flip_en[i31] = idata_LRB[i31][1]; 
        else flip_en[i31] = (idata_LRB[i31][0] | idata_LRB[i31][1]);
        //ptr_counter == 2'd3, flip LRB[0] and LRB[1]
    end
end
always@(*) begin
    if(state_FLIP) flip_next = flip_en ^ r_sel;
    else flip_next = 8'd0;
end
always@(posedge clk) begin
    if(!rstn) flip <= 8'd0;
    else flip <= flip_next;
end
//=============================
//        correlation
//=============================
reg [7:0] LLR_63   [0:7];
reg [7:0] LLR_255  [0:7];
reg [7:0] LLR_1023 [0:7];
reg [7:0] LLR_sel  [0:7];
reg [7:0] LLR_neg  [0:7];
reg [7:0] equal_sel[0:5][1:4];  //1-to-1 check of every error_loc of every pattern and LLR index
reg [7:0] error_sel_0 [1:4];    //decide which bit each pattern need 
reg [7:0] error_sel_1;          //decide which bit need to be added
reg [7:0] negation [1:4]; 
reg signed [ 7:0] adder_0_op [0:7][1:4];
reg signed [ 8:0] adder_0 [0:3][1:4];
reg signed [ 9:0] adder_1 [0:1][1:4];
reg signed [10:0] adder_2 [1:4];
reg signed [12:0] adder_3 [1:4];

integer i34;
always@(*) begin
    for(i34=0 ; i34<8 ; i34=i34+1) begin
        LLR_63[i34]   = LLR[  7][(i34*8)+:8];
        LLR_255[i34]  = LLR[ 31][(i34*8)+:8];
        LLR_1023[i34] = LLR[127][(i34*8)+:8];
        LLR_sel[i34] = state_CORR ? (code_type_63  ? LLR_63[i34]  :
                                     code_type_255 ? LLR_255[i34] : LLR_1023[i34]) : 8'd0;
        LLR_neg[i34] = (~LLR_sel[i34]) + 8'd1;
    end
end
integer i35, i36, i37, i38, i39, i40, i41, i42, i49, i50;
reg [10:0] error_loc_soft_sel [0:5][1:4];
always@(*) begin
    for(i49=1 ; i49<=4 ; i49=i49+1) 
        for(i50=0 ; i50<6 ; i50=i50+1)
            error_loc_soft_sel[i50][i49] = state_CORR ? error_loc_soft[i50][i49] : 11'd0;

    for(i35=1 ; i35<=4 ; i35=i35+1)
        for(i36=0 ; i36<6 ; i36=i36+1) 
            for(i37=0 ; i37<8 ; i37=i37+1) 
                equal_sel[i36][i35][i37] = (error_loc_soft_sel[i36][i35] == {1'b0,LLR_index[i37]});

    for(i38=1 ; i38<=4 ; i38=i38+1) 
        for(i39=0 ; i39<8 ; i39=i39+1) 
            error_sel_0[i38][i39] = (equal_sel[0][i38][i39] | equal_sel[1][i38][i39] |
                                     equal_sel[2][i38][i39] | equal_sel[3][i38][i39] |
                                     equal_sel[4][i38][i39] | equal_sel[5][i38][i39]);
    for(i40=0 ; i40<8 ; i40=i40+1) 
        error_sel_1[i40] = (error_sel_0[1][i40] | error_sel_0[2][i40] | 
                            error_sel_0[3][i40] | error_sel_0[4][i40]);
    
    for(i41=1 ; i41<=4 ; i41=i41+1) 
        for(i42=0 ; i42<8 ; i42=i42+1) 
            negation[i41][i42] = r_sel[i42] ^ error_sel_0[i41][i42];
end
//adder tree
integer i43, i44, i45, i46;
always@(*) begin
    for(i43=1 ; i43<=4 ; i43=i43+1) 
        for(i44=0 ; i44<8 ; i44=i44+1) 
            adder_0_op[i44][i43] = error_sel_1[i44] ? (negation[i43][i44] ? LLR_neg[i44] : LLR_sel[i44]) : 8'd0;
    for(i45=1 ; i45<=4 ; i45=i45+1) begin
        for(i46=0 ; i46<4 ; i46=i46+1)
            adder_0[i46][i45] = adder_0_op[2*i46][i45] + adder_0_op[2*i46+1][i45];
        adder_1[0][i45] = adder_0[0][i45] + adder_0[1][i45];
        adder_1[1][i45] = adder_0[2][i45] + adder_0[3][i45];
        adder_2[i45] = adder_1[0][i45] + adder_1[1][i45];
        adder_3[i45] = adder_2[i45] + correlation[i45];
    end
end
//correlation
integer i47, i48;
always@(*) begin
    if(state_IDLE) 
        for(i47=1 ; i47<=4 ; i47=i47+1)
            correlation_next[i47] = 13'd0;
    else if(state_CORR)
        for(i47=1 ; i47<=4 ; i47=i47+1) 
            correlation_next[i47] = hard_fail[i47] ? 13'd4096 : adder_3[i47];
    else 
        for(i47=1 ; i47<=4 ; i47=i47+1)
            correlation_next[i47] = correlation[i47];
end
always@(posedge clk) begin
    if(!rstn) 
        for(i48=1 ; i48<=4 ; i48=i48+1) 
            correlation[i48] <= 13'd0;
    else 
        for(i48=1 ; i48<=4 ; i48=i48+1) 
            correlation[i48] <= correlation_next[i48];
end
reg comp_corr_12, comp_corr_13, comp_corr_14, comp_corr_23, comp_corr_24, comp_corr_34;
reg equal_corr_12, equal_corr_13, equal_corr_14, equal_corr_23, equal_corr_24, equal_corr_34;
reg larger_corr_12, larger_corr_13, larger_corr_14, larger_corr_23, larger_corr_24, larger_corr_34;
reg larger_corr_21, larger_corr_31, larger_corr_32;
always@(*) begin
    comp_corr_12 = (correlation[1] > correlation[2]);
    comp_corr_13 = (correlation[1] > correlation[3]);
    comp_corr_14 = (correlation[1] > correlation[4]);
    comp_corr_23 = (correlation[2] > correlation[3]);
    comp_corr_24 = (correlation[2] > correlation[4]);
    comp_corr_34 = (correlation[3] > correlation[4]);

    equal_corr_12 = (correlation[1] == correlation[2]);
    equal_corr_13 = (correlation[1] == correlation[3]);
    equal_corr_14 = (correlation[1] == correlation[4]);
    equal_corr_23 = (correlation[2] == correlation[3]);
    equal_corr_24 = (correlation[2] == correlation[4]);
    equal_corr_34 = (correlation[3] == correlation[4]);

    larger_corr_12 = (comp_corr_12 | equal_corr_12);
    larger_corr_13 = (comp_corr_13 | equal_corr_13);
    larger_corr_14 = (comp_corr_14 | equal_corr_14);
    larger_corr_23 = (comp_corr_23 | equal_corr_23);
    larger_corr_24 = (comp_corr_24 | equal_corr_24);
    larger_corr_34 = (comp_corr_34 | equal_corr_34);
    
    larger_corr_21 = (!comp_corr_12);
    larger_corr_31 = (!comp_corr_13);
    //larger_corr_41 = (!comp_corr_14);
    larger_corr_32 = (!comp_corr_23);
    //larger_corr_42 = (!comp_corr_24);
    //larger_corr_43 = (!comp_corr_34);
    
    corr_case[1] = (larger_corr_12 & larger_corr_13 & larger_corr_14);
    corr_case[2] = (larger_corr_21 & larger_corr_23 & larger_corr_24);
    corr_case[3] = (larger_corr_31 & larger_corr_32 & larger_corr_34);
end
endmodule