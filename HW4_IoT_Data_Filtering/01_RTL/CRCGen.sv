module CRCGen (
    input          i_clk,
    input          i_rst,

    input          i_en,
    input          i_start,

    input  [127:0] i_indata,

    output [127:0] o_outdata,
    output         o_finish
);
// Parameters 
typedef enum logic [1:0] {
    S_IDLE,
    S_PROC,
    S_DONE
} state_t;

// Wires and Registers
state_t       state_r, state_w;
logic [6:0]   idx_r  , idx_w;     // 0~127
logic [2:0]   crc_r  , crc_w;
logic [127:0] data_r , data_w;
logic [130:0] data_ext;

// -------- CRC next function --------
function automatic [2:0] crc3_next(
    input bit      data_bit,
    input [2:0]    crc_in
);
begin
    if (crc_in[2] != 1'b1) begin
        crc3_next = {crc_in[1:0], data_bit};
    end
    else begin
        crc3_next[2] = ~crc_in[1];
        crc3_next[1] = crc_in[0];
        crc3_next[0] = ~data_bit;
    end
end
endfunction

// Continuous Assignment
assign o_finish  = (state_r == S_DONE);
assign o_outdata = {125'd0, crc_r};
assign data_ext  = {data_r, 3'd0};

// Finite State Machine 
always_comb begin
    state_w = state_r;
    case (state_r)
        S_IDLE:  state_w = (i_start)         ? S_PROC : state_r;
        S_PROC:  state_w = (idx_r == 7'd127) ? S_DONE : state_r;
        S_DONE:  state_w = S_IDLE;
    endcase
end

// Combinational Blocks
always_comb begin 
    // default
    idx_w     = idx_r;
    crc_w     = crc_r;
    data_w    = data_r;

    case (state_r)
        S_IDLE: begin
            if (i_start) begin
                data_w = i_indata;
                crc_w  = i_indata[127 -: 3];
            end
            idx_w  = 7'd0;
        end 
        S_PROC: begin
            crc_w = crc3_next(data_ext[127 - idx_r], crc_r);
            idx_w = idx_r + 1;
        end 
    endcase
end

// Sequential Block
always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
        state_r <= S_IDLE;
        idx_r   <= 7'd0;
        crc_r   <= 3'd0;
        data_r  <= 128'd0;
    end
    else if (i_en) begin  // clock gating enable
        state_r <= state_w;
        idx_r   <= idx_w;
        crc_r   <= crc_w;
        data_r  <= data_w;
    end
end
endmodule



