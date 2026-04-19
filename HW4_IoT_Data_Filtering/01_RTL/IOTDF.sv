`timescale 1ns/10ps
module IOTDF( clk, rst, in_en, iot_in, fn_sel, busy, valid, iot_out);
input          clk;
input          rst;
input          in_en;
input  [7:0]   iot_in;
input  [2:0]   fn_sel;
output         busy;
output         valid;
output [127:0] iot_out;

// ---------------------------------------------------------------------------
// Parameters 
// ---------------------------------------------------------------------------
typedef enum logic [2:0]{
    S_IDLE,
    S_LOAD,
    S_ENC,
    S_DEC,
    S_CRC,
    S_SORT,
    S_OUT
} state_t;

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------

state_t       state_r       , state_w;

logic [127:0] data_r        , data_w;         // 128-bit input data
logic [4:0]   load_counter_r, load_counter_w; // 16 cycles input
logic [127:0] outdata_r     , outdata_w;

// DES related
logic         des_en;
logic         des_start;
logic         des_mode;
logic [63:0]  des_text_out;
logic         des_finish;

// CRC related
logic         crc_en;
logic         crc_start;
logic [127:0] crc_out;
logic         crc_finish;

// Sort related
logic         sort_en;
logic         sort_start;
logic [127:0] sort_out;
logic         sort_finish;

// ---------------------------------------------------------------------------
// Submodule, task and function
// ---------------------------------------------------------------------------
DESCore u_descore(
    .i_clk      (clk),
    .i_rst      (rst),
    .i_en       (des_en),
    .i_start    (des_start),
    .i_mode     (des_mode),
    .i_text_in  (data_r[63:0]),
    .i_mainkey  (data_r[127:64]),
    .o_text_out (des_text_out),
    .o_finish   (des_finish)
);

CRCGen u_crcgen(
    .i_clk      (clk),
    .i_rst      (rst),
    .i_en       (crc_en),
    .i_start    (crc_start),
    .i_indata   (data_r),
    .o_outdata  (crc_out),
    .o_finish   (crc_finish)
);

Sort u_sort(
    .i_clk      (clk),
    .i_rst      (rst),
    .i_en       (sort_en),
    .i_start    (sort_start),
    .i_indata   (data_r),
    .o_outdata  (sort_out),
    .o_finish   (sort_finish)
);

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------

// Output ports
assign busy       = ((state_r != S_LOAD) || ((state_r == S_LOAD) && (load_counter_r == 5'd15))); // Allowed input only at S_LOAD state
assign valid      = (state_r == S_OUT); 
assign iot_out    = outdata_r;


// DES control signal
assign des_en     = ((state_r == S_ENC ) || (state_r == S_DEC));
assign des_start  = des_en;
assign des_mode   = (fn_sel == 3'b001) ? 0 : 
                    (fn_sel == 3'b010) ? 1 : 0;

// CRC control signal
assign crc_en     = (state_r == S_CRC);
assign crc_start  = crc_en;

// SORT control signal
assign sort_en    = (state_r == S_SORT);
assign sort_start = sort_en;

// ---------------------------------------------------------------------------
// Finite State Machine 
// ---------------------------------------------------------------------------
always_comb begin 
    state_w = state_r;
    case (state_r)
        S_IDLE: begin
            state_w  = S_LOAD;
        end 
        S_LOAD: begin
            state_w  =  (load_counter_r == 5'd15)   ? 
                        (fn_sel == 3'b001)          ? S_ENC  :
                        (fn_sel == 3'b010)          ? S_DEC  :
                        (fn_sel == 3'b011)          ? S_CRC  :
                        (fn_sel == 3'b100)          ? S_SORT : S_LOAD : S_LOAD;
        end 
        S_ENC: begin
            state_w  = (des_finish)  ? S_OUT : state_r;
        end         
        S_DEC: begin
            state_w  = (des_finish)  ? S_OUT : state_r;
        end 
        S_CRC: begin
            state_w  = (crc_finish)  ? S_OUT : state_r;
        end 
        S_SORT: begin
            state_w  = (sort_finish) ? S_OUT : state_r;
        end 
        S_OUT: begin
            state_w  = S_LOAD;
        end         
    endcase
end


// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------

// Input loading 
always_comb begin

    data_w         = data_r;
    load_counter_w = load_counter_r;

    if (state_r == S_LOAD) begin
        if (in_en) begin
            data_w         = {iot_in, data_r[127:8]};
            load_counter_w = load_counter_r + 1;
        end
    end 
    else if ((state_r == S_IDLE) || (state_r == S_OUT)) begin
        data_w         = 0;
        load_counter_w = 0;
    end
end

// Output data
always_comb begin
    outdata_w     = outdata_r;
    if (((state_r == S_ENC)  && (des_finish)) || ((state_r == S_DEC) && (des_finish))) begin
        outdata_w = {data_r[127:64], des_text_out};
    end
    else if ((state_r == S_CRC)  && (crc_finish)) begin
        outdata_w = crc_out; 
    end
    else if ((state_r == S_SORT) && (sort_finish)) begin
        outdata_w = sort_out;
    end
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------

always_ff @( posedge clk or posedge rst ) begin 
    if (rst) begin
        state_r        <= S_IDLE;
        data_r         <= 0;
        load_counter_r <= 0;
        outdata_r      <= 0;
    end
    else begin
        state_r        <= state_w;
        data_r         <= data_w;
        load_counter_r <= load_counter_w;
        outdata_r      <= outdata_w;
    end
end
endmodule

