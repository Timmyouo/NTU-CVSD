module Sort (
    input          i_clk,
    input          i_rst,

    input          i_en,
    input          i_start,

    input  [127:0] i_indata,

    output [127:0] o_outdata,
    output         o_finish
);
// ---------------------------------------------------------------------------
// Parameters 
// ---------------------------------------------------------------------------
typedef enum logic [2:0] { 
    S_IDLE,
    S_FIND_MIN,
    S_SWAP,
    S_DONE
} state_t;

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
state_t     state_r     , state_w;
logic [3:0] index_i_r   , index_i_w;
logic [3:0] index_j_r   , index_j_w;
logic [3:0] min_index_r , min_index_w;
logic [7:0] data_r[0:15], data_w[0:15];

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
assign o_finish  = (state_r == S_DONE);
assign o_outdata = (state_r == S_DONE) ?
                   {data_r[15], data_r[14], data_r[13], data_r[12], data_r[11], data_r[10], data_r[9], data_r[8],
                    data_r[7] , data_r[6] , data_r[5] , data_r[4] , data_r[3] , data_r[2] , data_r[1], data_r[0] } : 0;

// ---------------------------------------------------------------------------
// Finite State Machine 
// ---------------------------------------------------------------------------
always_comb begin
    state_w = state_r;
    case (state_r)
        S_IDLE: begin
            state_w = (i_start)            ? S_FIND_MIN : state_r;
        end
        S_FIND_MIN: begin
            state_w = (index_j_r == 4'd15) ? S_SWAP     : state_r;
        end
        S_SWAP: begin
            state_w = (index_i_r == 4'd14) ? S_DONE     : S_FIND_MIN;
        end
        S_DONE: begin
            state_w = S_IDLE;
        end
    endcase
end

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------

// i, j and min_index
always_comb begin
    // Default
    index_i_w       = index_i_r;
    index_j_w       = index_j_r;
    min_index_w     = min_index_r;

    if (state_r == S_IDLE) begin
        // Reset value
        index_i_w   = 0;
        index_j_w   = 0;
        min_index_w = 0;   
    end
    else if (state_r == S_FIND_MIN) begin
        // Find the minimum index from i to 15
        if (data_r[index_j_r] < data_r[min_index_r]) begin
            min_index_w = index_j_r;
        end 
        index_j_w   = index_j_r + 1;
    end
    else if (state_r == S_SWAP) begin
        // Update i index
        index_i_w   = index_i_r + 1;
        // Set j and min
        index_j_w   = index_i_r + 2;
        min_index_w = index_i_r + 1;
    end
end

// Data array
always_comb begin
    // Default 
    for (int i=0; i<16; i++) begin
        data_w[i] = data_r[i];
    end
    
    if ((state_r == S_IDLE) && (i_start))begin
        // Fetch input data
        for (int i=0; i<16; i++) begin
            data_w[i]       = i_indata[(127-i*8) -: 8];
        end
    end
    else if (state_r == S_SWAP) begin
        // Swap data accrding to current i and min_index
        data_w[index_i_r]   = data_r[min_index_r];
        data_w[min_index_r] = data_r[index_i_r];
    end
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
always_ff @( posedge i_clk or posedge i_rst ) begin 
    if (i_rst) begin
        state_r       <= S_IDLE;
        index_i_r     <= 0;
        index_j_r     <= 0;
        min_index_r   <= 0;
        for (int i=0; i<16; i++) begin
            data_r[i] <= 0;
        end
    end
    else if (i_en) begin
        state_r       <= state_w;
        index_i_r     <= index_i_w;
        index_j_r     <= index_j_w;
        min_index_r   <= min_index_w;
        for (int i=0; i<16; i++) begin
            data_r[i] <= data_w[i];
        end
    end
end

    
endmodule