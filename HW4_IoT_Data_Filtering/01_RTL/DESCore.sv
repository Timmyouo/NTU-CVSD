module DESCore(
    input         i_clk,
    input         i_rst,

    input         i_en,
    input         i_start,
    input         i_mode,    // 0: encrypt, 1: decrypt

    input  [63:0] i_text_in,
    input  [63:0] i_mainkey,

    output [63:0] o_text_out,
    output        o_finish
);
// ---------------------------------------------------------------------------
// Parameters 
// ---------------------------------------------------------------------------
parameter MODE_ENC = 0;
parameter MODE_DEC = 1;

typedef enum logic [1:0] { 
    S_IDLE,
    S_PROC,
    S_DONE
} state_t;

// ---------------------------------------------------------------------------
// LUT and function blocks
// ---------------------------------------------------------------------------

// Initial permutation : 64 to 64
localparam int IP_TABLE [0:63] = '{
    57, 49, 41, 33, 25, 17,  9,  1,
    59, 51, 43, 35, 27, 19, 11,  3,
    61, 53, 45, 37, 29, 21, 13,  5,
    63, 55, 47, 39, 31, 23, 15,  7,
    56, 48, 40, 32, 24, 16,  8,  0,
    58, 50, 42, 34, 26, 18, 10,  2,
    60, 52, 44, 36, 28, 20, 12,  4,
    62, 54, 46, 38, 30, 22, 14,  6 
};

function automatic [63:0] permute_ip (input [63:0] data);
for (int i = 0; i < 64; i++) begin
    permute_ip[i] = data[IP_TABLE[i]];
end
endfunction


// Final permutation : 64 to 64
localparam int FP_TABLE [0:63] = '{
    39,  7, 47, 15, 55, 23, 63, 31,
    38,  6, 46, 14, 54, 22, 62, 30,
    37,  5, 45, 13, 53, 21, 61, 29,
    36,  4, 44, 12, 52, 20, 60, 28,
    35,  3, 43, 11, 51, 19, 59, 27,
    34,  2, 42, 10, 50, 18, 58, 26,
    33,  1, 41,  9, 49, 17, 57, 25,
    32,  0, 40,  8, 48, 16, 56, 24
};

function automatic [63:0] permute_fp (input [63:0] data);
for (int i = 0; i < 64; i++) begin
    permute_fp[i] = data[FP_TABLE[i]];
end
endfunction

// PC1 LUT : 64 to 56
localparam int PC1_TABLE [0:55] = '{
    60, 52, 44, 36, 59, 51, 43, 35,
    27, 19, 11,  3, 58, 50, 42, 34,
    26, 18, 10,  2, 57, 49, 41, 33,
    25, 17,  9,  1, 28, 20, 12,  4,
    61, 53, 45, 37, 29, 21, 13,  5,
    62, 54, 46, 38, 30, 22, 14,  6,
    63, 55, 47, 39, 31, 23, 15,  7
};

function automatic [55:0] permute_pc1 (input [63:0] data);
for (int i = 0; i < 56; i++) begin
    permute_pc1[i] = data[PC1_TABLE[i]];
end
endfunction

// PC2 LUT : 56 to 48
localparam int PC2_TABLE [0:47] = '{
    24, 27, 20,  6, 14, 10,  3, 22,
    0 , 17,  7, 12,  8, 23, 11,  5,
    16, 26,  1,  9, 19, 25,  4, 15, 
    54, 43, 36, 29, 49, 40, 48, 30,
    52, 44, 37, 33, 46, 35, 50, 41,
    28, 53, 51, 55, 32, 45, 39, 42  
};

function automatic [47:0] permute_pc2 (input [55:0] data);
for (int i = 0; i < 48; i++) begin
    permute_pc2[i] = data[PC2_TABLE[i]];
end
endfunction

// Expansion : 32 to 48
localparam int EXP_TABLE [0:47] = '{
    31,  0,  1,  2,  3,  4,  3,  4,  
    5 ,  6,  7,  8,  7,  8,  9, 10,
    11, 12, 11, 12, 13, 14, 15, 16,
    15, 16, 17, 18, 19, 20, 19, 20,
    21, 22, 23, 24, 23, 24, 25, 26,
    27, 28, 27, 28, 29, 30, 31,  0 
};

function automatic [47:0] permute_expansion (input [31:0] data);
for (int i = 0; i < 48; i++) begin
    permute_expansion[i] = data[EXP_TABLE[i]];
end
endfunction

// P function : 32 to 32
localparam int P_TABLE [0:31] = '{
    7 , 28, 21, 10, 26,  2, 19, 13,
    23, 29,  5,  0, 18,  8, 24, 30,
    22,  1, 14, 27,  6,  9, 17, 31,
    15,  4, 20,  3, 11, 12, 25, 16
};

function automatic [31:0] permute_p (input [31:0] data);
for (int i = 0; i < 32; i++) begin
    permute_p[i] = data[P_TABLE[i]];
end
endfunction

// S-boxes : 6 t0 4
// S1
localparam logic [3:0] S1_TABLE [0:3][0:15] = '{
    // row0
    '{ 4'd14, 4'd4 , 4'd13, 4'd1 , 4'd2 , 4'd15, 4'd11, 4'd8 ,
        4'd3, 4'd10, 4'd6 , 4'd12, 4'd5 , 4'd9 , 4'd0 , 4'd7 },
    // row1
    '{ 4'd0 , 4'd15, 4'd7 , 4'd4 , 4'd14, 4'd2 , 4'd13, 4'd1 ,
    4'd10, 4'd6 , 4'd12, 4'd11, 4'd9 , 4'd5 , 4'd3 , 4'd8  },
    // row2
    '{ 4'd4 , 4'd1 , 4'd14, 4'd8 , 4'd13, 4'd6 , 4'd2 , 4'd11,
    4'd15, 4'd12, 4'd9 , 4'd7 , 4'd3 , 4'd10, 4'd5 , 4'd0  },
    // row3
    '{ 4'd15, 4'd12, 4'd8 , 4'd2 , 4'd4 , 4'd9 , 4'd1 , 4'd7 ,
    4'd5 , 4'd11, 4'd3 , 4'd14, 4'd10, 4'd0 , 4'd6 , 4'd13 }
};

function automatic [3:0] s1_lookup (input [5:0] data);
logic [1:0] row;
logic [3:0] col;
begin
    row       = {data[5], data[0]};
    col       = data[4:1];
    s1_lookup = S1_TABLE[row][col];
end
endfunction

// S2 
localparam logic [3:0] S2_TABLE [0:3][0:15] = '{
    // row0
    '{ 4'd15, 4'd1 , 4'd8 , 4'd14, 4'd6 , 4'd11, 4'd3 , 4'd4 ,
        4'd9, 4'd7 , 4'd2 , 4'd13, 4'd12, 4'd0 , 4'd5 , 4'd10 },
    // row1
    '{ 4'd3 , 4'd13, 4'd4 , 4'd7 , 4'd15, 4'd2 , 4'd8 , 4'd14,
    4'd12, 4'd0 , 4'd1 , 4'd10, 4'd6 , 4'd9 , 4'd11, 4'd5  },
    // row2
    '{ 4'd0 , 4'd14, 4'd7 , 4'd11, 4'd10, 4'd4 , 4'd13, 4'd1 ,
        4'd5, 4'd8 , 4'd12, 4'd6 , 4'd9 , 4'd3 , 4'd2 , 4'd15 },
    // row3
    '{ 4'd13, 4'd8 , 4'd10, 4'd1 , 4'd3 , 4'd15, 4'd4 , 4'd2 ,
    4'd11, 4'd6 , 4'd7 , 4'd12, 4'd0 , 4'd5 , 4'd14, 4'd9  }
};

function automatic [3:0] s2_lookup (input [5:0] data);
logic [1:0] row;
logic [3:0] col;
begin
    row       = {data[5], data[0]};
    col       = data[4:1];
    s2_lookup = S2_TABLE[row][col];
end
endfunction

// S3
localparam logic [3:0] S3_TABLE [0:3][0:15] = '{
    // row 0 (0yyyy0)
    '{ 4'd10, 4'd0 , 4'd9 , 4'd14, 4'd6 , 4'd3 , 4'd15, 4'd5 ,
        4'd1 , 4'd13, 4'd12, 4'd7 , 4'd11, 4'd4 , 4'd2 , 4'd8  },
    // row 1 (0yyyy1)
    '{ 4'd13, 4'd7 , 4'd0 , 4'd9 , 4'd3 , 4'd4 , 4'd6 , 4'd10,
        4'd2 , 4'd8 , 4'd5 , 4'd14, 4'd12, 4'd11, 4'd15, 4'd1  },
    // row 2 (1yyyy0)
    '{ 4'd13, 4'd6 , 4'd4 , 4'd9 , 4'd8 , 4'd15, 4'd3 , 4'd0 ,
        4'd11, 4'd1 , 4'd2 , 4'd12, 4'd5 , 4'd10, 4'd14, 4'd7  },
    // row 3 (1yyyy1)
    '{ 4'd1 , 4'd10, 4'd13, 4'd0 , 4'd6 , 4'd9 , 4'd8 , 4'd7 ,
        4'd4 , 4'd15, 4'd14, 4'd3 , 4'd11, 4'd5 , 4'd2 , 4'd12 }
};

function automatic [3:0] s3_lookup (input [5:0] data);
// row = {data[5], data[0]}
// col = data[4:1]
logic [1:0] row;
logic [3:0] col;
begin
    row       = {data[5], data[0]};  
    col       = data[4:1];           
    s3_lookup = S3_TABLE[row][col];
end
endfunction

// S4
localparam logic [3:0] S4_TABLE [0:3][0:15] = '{
    // row0 (0yyyy0)
    '{ 4'd7 , 4'd13, 4'd14, 4'd3 , 4'd0 , 4'd6 , 4'd9 , 4'd10,
        4'd1 , 4'd2 , 4'd8 , 4'd5 , 4'd11, 4'd12, 4'd4 , 4'd15 },
    // row1 (0yyyy1)
    '{ 4'd13, 4'd8 , 4'd11, 4'd5 , 4'd6 , 4'd15, 4'd0 , 4'd3 ,
        4'd4 , 4'd7 , 4'd2 , 4'd12, 4'd1 , 4'd10, 4'd14, 4'd9  },
    // row2 (1yyyy0)
    '{ 4'd10, 4'd6 , 4'd9 , 4'd0 , 4'd12, 4'd11, 4'd7 , 4'd13,
        4'd15, 4'd1 , 4'd3 , 4'd14, 4'd5 , 4'd2 , 4'd8 , 4'd4  },
    // row3 (1yyyy1)
    '{ 4'd3 , 4'd15, 4'd0 , 4'd6 , 4'd10, 4'd1 , 4'd13, 4'd8 ,
        4'd9 , 4'd4 , 4'd5 , 4'd11, 4'd12, 4'd7 , 4'd2 , 4'd14 }
};

function automatic [3:0] s4_lookup (input [5:0] data);
logic [1:0] row;
logic [3:0] col;
begin
    row       = {data[5], data[0]};
    col       = data[4:1];
    s4_lookup = S4_TABLE[row][col];
end
endfunction

// S5
localparam logic [3:0] S5_TABLE [0:3][0:15] = '{
    // row0 (0yyyy0)
    '{ 4'd2 , 4'd12, 4'd4 , 4'd1 , 4'd7 , 4'd10, 4'd11, 4'd6 ,
        4'd8 , 4'd5 , 4'd3 , 4'd15, 4'd13, 4'd0 , 4'd14, 4'd9  },
    // row1 (0yyyy1)
    '{ 4'd14, 4'd11, 4'd2 , 4'd12, 4'd4 , 4'd7 , 4'd13, 4'd1 ,
        4'd5 , 4'd0 , 4'd15, 4'd10, 4'd3 , 4'd9 , 4'd8 , 4'd6  },
    // row2 (1yyyy0)
    '{ 4'd4 , 4'd2 , 4'd1 , 4'd11, 4'd10, 4'd13, 4'd7 , 4'd8 ,
        4'd15, 4'd9 , 4'd12, 4'd5 , 4'd6 , 4'd3 , 4'd0 , 4'd14 },
    // row3 (1yyyy1)
    '{ 4'd11, 4'd8 , 4'd12, 4'd7 , 4'd1 , 4'd14, 4'd2 , 4'd13,
        4'd6 , 4'd15, 4'd0 , 4'd9 , 4'd10, 4'd4 , 4'd5 , 4'd3  }
};

function automatic [3:0] s5_lookup (input [5:0] data);
logic [1:0] row;
logic [3:0] col;
begin
    row       = {data[5], data[0]};  
    col       = data[4:1];           
    s5_lookup = S5_TABLE[row][col];
end
endfunction

// S6
localparam logic [3:0] S6_TABLE [0:3][0:15] = '{
    // row0 (0yyyy0)
    '{ 4'd12, 4'd1 , 4'd10, 4'd15, 4'd9 , 4'd2 , 4'd6 , 4'd8 ,
        4'd0 , 4'd13, 4'd3 , 4'd4 , 4'd14, 4'd7 , 4'd5 , 4'd11 },
    // row1 (0yyyy1)
    '{ 4'd10, 4'd15, 4'd4 , 4'd2 , 4'd7 , 4'd12, 4'd9 , 4'd5 ,
        4'd6 , 4'd1 , 4'd13, 4'd14, 4'd0 , 4'd11, 4'd3 , 4'd8  },
    // row2 (1yyyy0)
    '{ 4'd9 , 4'd14, 4'd15, 4'd5 , 4'd2 , 4'd8 , 4'd12, 4'd3 ,
        4'd7 , 4'd0 , 4'd4 , 4'd10, 4'd1 , 4'd13, 4'd11, 4'd6  },
    // row3 (1yyyy1)
    '{ 4'd4 , 4'd3 , 4'd2 , 4'd12, 4'd9 , 4'd5 , 4'd15, 4'd10,
        4'd11, 4'd14, 4'd1 , 4'd7 , 4'd6 , 4'd0 , 4'd8 , 4'd13 }
};

function automatic [3:0] s6_lookup (input [5:0] data);
logic [1:0] row;
logic [3:0] col;
begin
    row       = {data[5], data[0]};  
    col       = data[4:1];         
    s6_lookup = S6_TABLE[row][col];
end
endfunction

// S7
localparam logic [3:0] S7_TABLE [0:3][0:15] = '{
    // row0 (0yyyy0)
    '{ 4'd4 , 4'd11, 4'd2 , 4'd14, 4'd15, 4'd0 , 4'd8 , 4'd13,
        4'd3 , 4'd12, 4'd9 , 4'd7 , 4'd5 , 4'd10, 4'd6 , 4'd1  },
    // row1 (0yyyy1)
    '{ 4'd13, 4'd0 , 4'd11, 4'd7 , 4'd4 , 4'd9 , 4'd1 , 4'd10,
        4'd14, 4'd3 , 4'd5 , 4'd12, 4'd2 , 4'd15, 4'd8 , 4'd6  },
    // row2 (1yyyy0)
    '{ 4'd1 , 4'd4 , 4'd11, 4'd13, 4'd12, 4'd3 , 4'd7 , 4'd14,
        4'd10, 4'd15, 4'd6 , 4'd8 , 4'd0 , 4'd5 , 4'd9 , 4'd2  },
    // row3 (1yyyy1)
    '{ 4'd6 , 4'd11, 4'd13, 4'd8 , 4'd1 , 4'd4 , 4'd10, 4'd7 ,
        4'd9 , 4'd5 , 4'd0 , 4'd15, 4'd14, 4'd2 , 4'd3 , 4'd12 }
};

function automatic [3:0] s7_lookup (input [5:0] data);
logic [1:0] row;
logic [3:0] col;
begin
    row       = {data[5], data[0]}; 
    col       = data[4:1];           
    s7_lookup = S7_TABLE[row][col];
end
endfunction

// S8
localparam logic [3:0] S8_TABLE [0:3][0:15] = '{
    // row0 (0yyyy0)
    '{ 4'd13, 4'd2 , 4'd8 , 4'd4 , 4'd6 , 4'd15, 4'd11, 4'd1 ,
        4'd10, 4'd9 , 4'd3 , 4'd14, 4'd5 , 4'd0 , 4'd12, 4'd7  },
    // row1 (0yyyy1)
    '{ 4'd1 , 4'd15, 4'd13, 4'd8 , 4'd10, 4'd3 , 4'd7 , 4'd4 ,
        4'd12, 4'd5 , 4'd6 , 4'd11, 4'd0 , 4'd14, 4'd9 , 4'd2  },
    // row2 (1yyyy0)
    '{ 4'd7 , 4'd11, 4'd4 , 4'd1 , 4'd9 , 4'd12, 4'd14, 4'd2 ,
        4'd0 , 4'd6 , 4'd10, 4'd13, 4'd15, 4'd3 , 4'd5 , 4'd8  },
    // row3 (1yyyy1)
    '{ 4'd2 , 4'd1 , 4'd14, 4'd7 , 4'd4 , 4'd10, 4'd8 , 4'd13,
        4'd15, 4'd12, 4'd9 , 4'd0 , 4'd3 , 4'd5 , 4'd6 , 4'd11 }
};

function automatic [3:0] s8_lookup (input [5:0] data);
logic [1:0] row;
logic [3:0] col;
begin
    row       = {data[5], data[0]};  
    col       = data[4:1];           
    s8_lookup = S8_TABLE[row][col];
end
endfunction


// Key Generator
localparam [4:0] SHIFT_TABLE [0:15] = '{
     5'd1,  5'd2,  5'd4,  5'd6,
     5'd8, 5'd10, 5'd12, 5'd14,
    5'd15, 5'd17, 5'd19, 5'd21,
    5'd23, 5'd25, 5'd27, 5'd28
};

function automatic [47:0] key_gen(
    input [63:0] mainkey,
    input [5:0]  round,
    input        mode
); 
parameter MODE_ENC = 0;
parameter MODE_DEC = 1;
logic [27:0] up_key, down_key;
logic [4:0]  shift_bits;
logic [27:0] shifted_up, shifted_down;

begin
    {down_key, up_key} = permute_pc1(mainkey);
    shift_bits         = (mode == MODE_ENC) ? SHIFT_TABLE[round] : 
                                              SHIFT_TABLE[15 - round];
    shifted_up         = (up_key   << shift_bits) | (up_key   >> (28 - shift_bits));
    shifted_down       = (down_key << shift_bits) | (down_key >> (28 - shift_bits));
    key_gen            = permute_pc2({shifted_down, shifted_up});                      
end
endfunction


// F function
function automatic [31:0] F_function(
    input [31:0] R_in,
    input [47:0] K_in
); 

logic [47:0] R_expanded;
logic [47:0] xor_out;
logic [3:0]  Sbox_out [1:8];

begin
    R_expanded  = permute_expansion(R_in);
    xor_out     = R_expanded ^ K_in;
    Sbox_out[1] = s1_lookup(xor_out[47:42]);
    Sbox_out[2] = s2_lookup(xor_out[41:36]);
    Sbox_out[3] = s3_lookup(xor_out[35:30]);
    Sbox_out[4] = s4_lookup(xor_out[29:24]);
    Sbox_out[5] = s5_lookup(xor_out[23:18]);
    Sbox_out[6] = s6_lookup(xor_out[17:12]);
    Sbox_out[7] = s7_lookup(xor_out[11: 6]);
    Sbox_out[8] = s8_lookup(xor_out[ 5: 0]);
    F_function  = permute_p({Sbox_out[1], Sbox_out[2], Sbox_out[3], Sbox_out[4], 
                             Sbox_out[5], Sbox_out[6], Sbox_out[7], Sbox_out[8]});
end
endfunction



// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------

state_t      state_r  , state_w;
logic [4:0]  round_r  , round_w;
logic [47:0] subkey_r , subkey_w;
logic [31:0] R_data_r , R_data_w;
logic [31:0] L_data_r , L_data_w;

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------

assign o_finish   = (state_r == S_DONE);
assign o_text_out = (state_r == S_DONE) ? (permute_fp({L_data_r, R_data_r})) : 0;

// ---------------------------------------------------------------------------
// Finite State Machine 
// ---------------------------------------------------------------------------

always_comb begin 
    state_w = state_r;
    case (state_r)
        S_IDLE: state_w = (i_start)       ? S_PROC : S_IDLE;
        S_PROC: state_w = (round_r == 16) ? S_DONE : S_PROC;
        S_DONE: state_w = S_IDLE;
    endcase
end


// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------

// round counter
always_comb begin 
    // Default
    round_w = round_r;
    // Activated
    if (state_r == S_PROC) begin
        round_w = round_r + 1;
    end else if (state_r == S_IDLE) begin
        round_w = 5'd0;
    end
end

// R, L and subkey
always_comb begin 
    // Default
    R_data_w = R_data_r;
    L_data_w = L_data_r;
    subkey_w = subkey_r;

    if (state_r == S_PROC) begin
        // Generate the key for next round
        subkey_w = key_gen(i_mainkey, round_r, i_mode);

        // Next R and L
        if (round_r == 0) begin
            // Prepare R0, L0
            {L_data_w, R_data_w} = permute_ip(i_text_in);
        end
        else if (round_r == 16) begin
            R_data_w = R_data_r;
            L_data_w = L_data_r ^ (F_function(R_data_r, subkey_r));           
        end
        else begin
            R_data_w = L_data_r ^ (F_function(R_data_r, subkey_r));
            L_data_w = R_data_r;
        end
    end
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
always_ff @( posedge i_clk or posedge i_rst ) begin 
    if (i_rst) begin
        state_r  <= S_IDLE;
        round_r  <= 0;
        subkey_r <= 0;
        R_data_r <= 0;
        L_data_r <= 0;
    end
    else if (i_en) begin
        state_r  <= state_w;
        round_r  <= round_w;
        subkey_r <= subkey_w;
        R_data_r <= R_data_w;
        L_data_r <= L_data_w;
    end
end



endmodule




