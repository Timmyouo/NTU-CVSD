module core #( // DO NOT MODIFY INTERFACE!!!
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) ( 
    input i_clk,
    input i_rst_n,

    // Testbench IOs
    output [2:0] o_status, 
    output       o_status_valid,

    // Memory IOs
    output [ADDR_WIDTH-1:0] o_addr,
    output [DATA_WIDTH-1:0] o_wdata,
    output                  o_we,
    input  [DATA_WIDTH-1:0] i_rdata
);
// ---------------------------------------------------------------------------
// Parameters 
// ---------------------------------------------------------------------------
typedef enum logic [2:0] {
    S_IDLE,
    S_IF,
    S_ID,
    S_EX,
    S_WB,
    S_NPC,
    S_END
} state_t;

typedef enum logic [4:0] {
    SUB,
    ADDI,
    LW,
    SW,
    BEQ,
    BLT,
    JALR,
    AUIPC,
    SLT,
    OP_SRL,
    FSUB,
    FMUL,
    FCVT,
    FLW,
    FSW,
    FCLASS,
    EOF 
} op_t;

// operation type
parameter TYPE_ALU     = 3'd0;  // sub, addi, slt, srl
parameter TYPE_BRANCH  = 3'd1;  // beq, blt
parameter TYPE_MEM     = 3'd2;  // lw, sw, flw, fsw
parameter TYPE_PC      = 3'd3;  // jalr, auipc
parameter TYPE_FPU     = 3'd4;  // fsub, fmul, fcvt, fclass
parameter TYPE_EOF     = 3'd5;  // eof
parameter TYPE_INVALID = 3'd6;

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------

// FSM and output status
state_t    state_r, state_w;
reg [2:0]  status_r, status_w;
// Memory related
reg [ADDR_WIDTH-1:0] MEM_addr_r , MEM_addr_w;
reg [DATA_WIDTH-1:0] MEM_wdata_r, MEM_wdata_w;
reg MEM_we_r, MEM_we_w, MEM_invalid;
reg [1:0] MEM_cnt_r, MEM_cnt_w; // 等待 memory data 準備好再讀進來
// Instruction Decode
reg [31:0]inst_r, inst_w; 
op_t      op_r, op_w;  
reg [2:0] optype_r, optype_w; 
reg [6:0] opcode;
reg [2:0] funct3;
reg [6:0] funct7;
reg [4:0] r1_r, r2_r, rd_r, f1_r, f2_r, fd_r;
reg [4:0] r1_w, r2_w, rd_w, f1_w, f2_w, fd_w;
reg [31:0] imm_r, imm_w;
// Regfile related
reg [4:0] reg_addr1, reg_addr2, reg_faddr1, reg_faddr2;
wire[31:0]reg_data1, reg_data2, reg_fdata1, reg_fdata2;
reg reg_wen_r, reg_wen_w, reg_fwen_r, reg_fwen_w;
reg [4:0] reg_waddr_r, reg_waddr_w, reg_fwaddr_r, reg_fwaddr_w;
reg [31:0]reg_wdata_r, reg_wdata_w, reg_fwdata_r, reg_fwdata_w;
//  ALU related
op_t alu_op;
reg [31:0] alu_in1, alu_in2;
wire[31:0] alu_result;
wire alu_invalid;
// PC related
wire[31:0] pc;         
reg [31:0] next_pc;       
reg [31:0] branch_pc_r, branch_pc_w; // Store the reslt of B-type op at EX stage

// ---------------------------------------------------------------------------
// Submodules
// ---------------------------------------------------------------------------

// Progeam Counter
pc u_pc (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_next_pc(next_pc),
    .o_pc(pc)
);
// Register file
regfile u_regfile(
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),

    .i_raddr1(reg_addr1),
    .o_data1(reg_data1),
    .i_raddr2(reg_addr2),
    .o_data2(reg_data2),

    .i_wen(reg_wen_r),
    .i_waddr(reg_waddr_r),
    .i_wdata(reg_wdata_r),

    .i_fraddr1(reg_faddr1),
    .o_fdata1(reg_fdata1),
    .i_fraddr2(reg_faddr2),
    .o_fdata2(reg_fdata2),

    .i_fwen(reg_fwen_r),
    .i_fwaddr(reg_fwaddr_r),
    .i_fwdata(reg_fwdata_r)
);
// ALU
alu u_alu(
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),

    .i_op(alu_op),
    .i_data1(alu_in1),
    .i_data2(alu_in2),

    .o_data(alu_result),
    .o_invalid(alu_invalid)
);

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
// ---- Add your own wire data assignments here if needed ---- //
assign o_addr         = MEM_addr_r;
assign o_wdata        = MEM_wdata_r;
assign o_we           = MEM_we_r;
assign o_status       = status_r;
assign o_status_valid = (state_r == S_END) || (state_r == S_NPC);

// ---------------------------------------------------------------------------
// Finite State Machine & o_status logic
// ---------------------------------------------------------------------------

always @(*) begin
    // Default
    state_w  = state_r;
    status_w = status_r;

    case(state_r)
        // ---------------------- RESET ----------------------
        S_IDLE: state_w = S_IF;
        // ---------------------- FETCH ----------------------
        S_IF: begin
            if (MEM_invalid) begin
                state_w  = S_END;
                status_w = `INVALID_TYPE;
            end
            else if (MEM_cnt_r == 2)
                state_w = S_ID;
        end
        // ---------------------- DECODE ----------------------
        S_ID: state_w = S_EX;

        // ---------------------- EXECUTE ----------------------
        S_EX: begin
            if (MEM_invalid || alu_invalid) begin
                state_w  = S_END;
                status_w = `INVALID_TYPE;
            end
            else if (op_r == EOF) begin
                state_w  = S_END;
                status_w = `EOF_TYPE;
            end
            else if (op_r == LW || op_r == FLW) begin
                if (MEM_cnt_r == 2) state_w = S_WB;
                else                state_w = state_r;
            end
            else state_w = S_WB;
        end
        // ---------------------- WRITEBACK ----------------------
        S_WB: begin
            state_w = S_NPC;
            case(op_r)
                SUB, SLT, OP_SRL, FSUB, FMUL, FCVT, FCLASS: status_w = `R_TYPE;
                ADDI, LW, JALR, FLW:                     status_w = `I_TYPE;
                SW, FSW:                                 status_w = `S_TYPE;
                BEQ, BLT:                                status_w = `B_TYPE;
                AUIPC:                                   status_w = `U_TYPE;
            endcase
        end
        // ---------------------- NEXT PC ----------------------
        S_NPC: state_w = S_IF;
        // ---------------------- TERMINATE ----------------------
        S_END: begin
            state_w  = state_r;
            status_w = status_r;
        end
    endcase
end

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------

// Memory control (instruction fetch + load/store)
always @(*) begin
    // Default assignments
    MEM_addr_w  = MEM_addr_r;
    MEM_we_w    = 1'b0;
    MEM_cnt_w   = MEM_cnt_r;
    MEM_wdata_w = MEM_wdata_r;
    MEM_invalid = 1'b0;

    case (state_r)
        // ---------------------- INSTRUCTION FETCH ----------------------
        S_IF: begin
            case (MEM_cnt_r)
                2'd0: begin
                    MEM_addr_w = pc;
                    MEM_we_w   = 1'b0;          // read
                    MEM_cnt_w  = MEM_cnt_r + 1; // issue read
                end
                2'd1: begin
                    MEM_cnt_w  = MEM_cnt_r + 1; // wait one cycle
                end
                2'd2: begin
                    // i_rdata is now valid, store it into register and change next_state
                    MEM_cnt_w = 3'd0;           // reset for next fetch
                end
            endcase
        end

        // ---------------------- LOAD / STORE ----------------------
        S_EX: begin
            case (op_r)
                LW, FLW: begin
                    case (MEM_cnt_r)
                        2'd0: begin
                            MEM_addr_w = alu_result; // effective address
                            MEM_we_w   = 1'b0;       // read
                            MEM_cnt_w  = MEM_cnt_r + 1;
                        end
                        2'd1: begin
                            MEM_cnt_w  = MEM_cnt_r + 1; // wait
                        end
                        2'd2: begin
                            MEM_cnt_w = 3'd0;
                            // data now valid -> captured at WB
                        end
                    endcase
                end
                SW, FSW: begin
                    MEM_we_w    = 1'b1;
                    MEM_addr_w  = alu_result;
                    MEM_wdata_w = (op_r == SW) ? reg_data2 : reg_fdata2;
                    MEM_cnt_w   = MEM_cnt_r;
                end
            endcase
        end
    endcase

    // Detect invalid memory address
    if (state_r == S_IF) begin
        // IF 階段：PC 只能取指令區 (0–4095)
        if (MEM_addr_w > 32'd4095)
            MEM_invalid = 1'b1;  // invalid: PC fetches from data area
    end 
    else if (state_r == S_EX && (op_r == LW || op_r == FLW)) begin
        // Load 指令：只能從 data 區讀資料
        if (MEM_addr_w < 32'd4096 || MEM_addr_w > 32'd8191)
            MEM_invalid = 1'b1;  // invalid: load outside data region
    end
    else if (state_r == S_EX && (op_r == SW || op_r == FSW)) begin
        // Store 指令：可以寫到任何位址 (包括 instruction 區)
        MEM_invalid = 1'b0;
    end
end

// Instruction Fetch and Decode
always @(*) begin
    // Default
    inst_w = inst_r;
    op_w = op_r;
    optype_w = optype_r;
    r2_w = r2_r;
    r1_w = r1_r;
    rd_w = rd_r;
    f2_w = f2_r;
    f1_w = f1_r;
    fd_w = fd_r;
    imm_w= imm_r;

    // Parse inst code
    opcode = inst_r[6:0];
    funct3 = inst_r[14:12];
    funct7 = inst_r[31:25];

    // IF 
    if (state_r == S_IF && MEM_cnt_r == 2) begin
        inst_w = i_rdata;
    end
    // ID
    else if (state_r == S_ID) begin
        casez ({funct7, funct3, opcode})
            // ---------- ALU ----------
            {`FUNCT7_SUB, `FUNCT3_SUB, `OP_SUB}: begin
                // R type
                op_w = SUB;     optype_w = TYPE_ALU;
                r2_w = inst_r[24:20];  r1_w = inst_r[19:15];  rd_w = inst_r[11:7];
            end
            {7'b???????, `FUNCT3_ADDI, `OP_ADDI}: begin
                // I type
                op_w = ADDI;    optype_w = TYPE_ALU;
                r1_w = inst_r[19:15];  rd_w = inst_r[11:7];
                imm_w = {{20{inst_r[31]}}, inst_r[31:20]}; // sign-extend imm12
            end
            {`FUNCT7_SLT, `FUNCT3_SLT, `OP_SLT}: begin
                // R type
                op_w = SLT;     optype_w = TYPE_ALU;
                r2_w = inst_r[24:20];  r1_w = inst_r[19:15];  rd_w = inst_r[11:7];
            end 
            {`FUNCT7_SRL, `FUNCT3_SRL, `OP_SRL}: begin
                // R type
                op_w = OP_SRL;     optype_w = TYPE_ALU;
                r2_w = inst_r[24:20];  r1_w = inst_r[19:15];  rd_w = inst_r[11:7];
            end               
            // ---------- MEMORY ----------
            {7'b???????, `FUNCT3_LW, `OP_LW}: begin
                // I type
                op_w = LW;  optype_w = TYPE_MEM;
                r1_w = inst_r[19:15];  rd_w = inst_r[11:7];
                imm_w = {{20{inst_r[31]}}, inst_r[31:20]};                
            end
            {7'b???????, `FUNCT3_SW, `OP_SW}: begin
                // S type
                op_w = SW;  optype_w = TYPE_MEM;
                r2_w = inst_r[24:20];   r1_w = inst_r[19:15]; 
                imm_w = {{20{inst_r[31]}}, inst_r[31:25], inst_r[11:7]};   
            end
            {7'b???????, `FUNCT3_FLW, `OP_FLW}: begin
                // I type
                op_w = FLW;  optype_w = TYPE_MEM;
                r1_w = inst_r[19:15];  fd_w = inst_r[11:7];
                imm_w = {{20{inst_r[31]}}, inst_r[31:20]};                
            end            
            {7'b???????, `FUNCT3_FSW, `OP_FSW}: begin
                // S type
                op_w = FSW;  optype_w = TYPE_MEM;
                f2_w = inst_r[24:20];   r1_w = inst_r[19:15]; 
                imm_w = {{20{inst_r[31]}}, inst_r[31:25], inst_r[11:7]};         
            // ---------- BRANCH ----------             
            end     
            {7'b???????, `FUNCT3_BEQ, `OP_BEQ}: begin
                // B type
                op_w = BEQ;     optype_w = TYPE_BRANCH;
                r2_w = inst_r[24:20];   r1_w = inst_r[19:15]; 
                imm_w = {{19{inst_r[31]}}, inst_r[31], inst_r[7], inst_r[30:25], inst_r[11:8], 1'b0};
            end     
            {7'b???????, `FUNCT3_BLT, `OP_BLT}: begin
                // B type
                op_w = BLT;     optype_w = TYPE_BRANCH;
                r2_w = inst_r[24:20];   r1_w = inst_r[19:15]; 
                imm_w = {{19{inst_r[31]}}, inst_r[31], inst_r[7], inst_r[30:25], inst_r[11:8], 1'b0}; 
            end  
            // ---------- FPU ----------
            {`FUNCT7_FSUB, `FUNCT3_FSUB, `OP_FSUB}: begin
                // R type
                op_w = FSUB;     optype_w = TYPE_FPU;
                f2_w = inst_r[24:20];  f1_w = inst_r[19:15];  fd_w = inst_r[11:7];
            end
            {`FUNCT7_FMUL, `FUNCT3_FMUL, `OP_FMUL}: begin
                // R type
                op_w = FMUL;     optype_w = TYPE_FPU;
                f2_w = inst_r[24:20];  f1_w = inst_r[19:15];  fd_w = inst_r[11:7];
            end
            {`FUNCT7_FCVTWS, `FUNCT3_FCVTWS, `OP_FCVTWS}: begin
                // R type
                op_w = FCVT;     optype_w = TYPE_FPU;
                f1_w = inst_r[19:15];  rd_w = inst_r[11:7];
            end
            {`FUNCT7_FCLASS, `FUNCT3_FCLASS, `OP_FCLASS}: begin
                // R type
                op_w = FCLASS;     optype_w = TYPE_FPU;
                f1_w = inst_r[19:15];  rd_w = inst_r[11:7];
            end
            // ---------- PC control ----------
            {7'b???????, `FUNCT3_JALR, `OP_JALR}: begin
                // I type
                op_w = JALR;     optype_w = TYPE_PC;
                r1_w = inst_r[19:15];  rd_w = inst_r[11:7];
                imm_w = {{20{inst_r[31]}}, inst_r[31:20]};  
            end  
            {7'b???????, 3'b???, `OP_AUIPC}: begin
                // U type
                op_w = AUIPC;     optype_w = TYPE_PC;
                rd_w = inst_r[11:7];
                imm_w = {inst_r[31:12], 12'b0};  // 20-bit field << 12
            end  
            // ---------- EOF ----------
            {7'b???????, 3'b???, `OP_EOF}: begin
                // EOF type
                op_w = EOF;     optype_w = TYPE_EOF;
            end  
        endcase
    end
end

// ALU, regfile control, and branch pc 
always @(*) begin
    // Default
    alu_in1      = 32'b0;
    alu_in2      = 32'b0;
    alu_op       = SUB;
    reg_wen_w    = 1'b0;
    reg_waddr_w  = 5'b0;
    reg_wdata_w  = 32'b0;
    reg_fwen_w   = 1'b0;
    reg_fwaddr_w = 5'b0;
    reg_fwdata_w = 32'b0;
    branch_pc_w  = branch_pc_r;

    // Default regfile read ports
    reg_addr1  = r1_r;
    reg_addr2  = r2_r;
    reg_faddr1 = f1_r;
    reg_faddr2 = f2_r;

    if (state_r == S_EX) begin
        case (op_r)
            SUB: begin
                alu_in1     = reg_data1;    
                alu_in2     = reg_data2;
                alu_op      = SUB;
                reg_wen_w   = 1;
                reg_waddr_w = rd_r;
                reg_wdata_w = alu_result;
            end
            ADDI: begin
                alu_in1     = reg_data1;    
                alu_in2     = imm_r;
                alu_op      = ADDI;
                reg_wen_w   = 1;
                reg_waddr_w = rd_r;
                reg_wdata_w = alu_result;
            end
            LW: begin
                // Use alu result as the memory address 
                alu_in1 = reg_data1;    
                alu_in2 = imm_r;
                alu_op  = ADDI;   
                if (MEM_cnt_r == 2) begin
                    reg_wen_w   = 1;
                    reg_waddr_w = rd_r;
                    reg_wdata_w = i_rdata;                    
                end 
            end
            FLW: begin
                // Use alu result as the memory address 
                alu_in1 = reg_data1;    
                alu_in2 = imm_r;
                alu_op  = ADDI;   
                if (MEM_cnt_r == 2) begin
                    reg_fwen_w   = 1;
                    reg_fwaddr_w = fd_r;
                    reg_fwdata_w = i_rdata;                    
                end 
            end
            SW, FSW: begin
                // Use alu result as the memory address 
                alu_in1 = reg_data1;    
                alu_in2 = imm_r;
                alu_op  = ADDI;                           
            end
            BEQ: begin
                if ($signed(reg_data1)  == $signed(reg_data2)) begin
                    branch_pc_w = pc + imm_r;
                end else begin
                    branch_pc_w = pc + 4;
                end
            end
            BLT: begin
                if ($signed(reg_data1) < $signed(reg_data2)) begin
                    branch_pc_w = pc + imm_r;
                end else begin
                    branch_pc_w = pc + 4;
                end              
            end
            JALR: begin
                alu_in1     = reg_data1;    
                alu_in2     = imm_r;
                alu_op      = ADDI;    
                reg_wen_w   = 1;
                reg_waddr_w = rd_r;
                reg_wdata_w = pc + 4;     
                branch_pc_w = (alu_result & 32'hFFFFFFFE); // aligned jump target             
            end
            AUIPC: begin
                reg_wen_w   = 1;
                reg_waddr_w = rd_r;
                reg_wdata_w = pc + imm_r;                      
            end
            SLT: begin
                alu_in1     = reg_data1;    
                alu_in2     = reg_data2;
                alu_op      = SLT;
                reg_wen_w   = 1;
                reg_waddr_w = rd_r;
                reg_wdata_w = alu_result;               
            end
            OP_SRL: begin
                alu_in1     = reg_data1;    
                alu_in2     = reg_data2;
                alu_op      = OP_SRL;
                reg_wen_w   = 1;
                reg_waddr_w = rd_r;
                reg_wdata_w = alu_result;                 
            end
            FSUB: begin
                alu_in1      = reg_fdata1;    
                alu_in2      = reg_fdata2;
                alu_op       = FSUB;
                reg_fwen_w   = 1;
                reg_fwaddr_w = fd_r;
                reg_fwdata_w = alu_result;  
            end
            FMUL: begin
                alu_in1      = reg_fdata1;    
                alu_in2      = reg_fdata2;
                alu_op       = FMUL;
                reg_fwen_w   = 1;
                reg_fwaddr_w = fd_r;
                reg_fwdata_w = alu_result;                  
            end
            FCVT: begin
                alu_in1     = reg_fdata1;    
                alu_in2     = reg_fdata2;
                alu_op      = FCVT;
                reg_wen_w   = 1;
                reg_waddr_w = rd_r;
                reg_wdata_w = alu_result;                  
            end
            FCLASS: begin
                alu_in1     = reg_fdata1;    
                alu_in2     = reg_fdata2;
                alu_op      = FCLASS;
                reg_wen_w   = 1;
                reg_waddr_w = rd_r;
                reg_wdata_w = alu_result;                  
            end
        endcase
    end
end

// Next PC generation
always @(*) begin
    next_pc = pc;
    if (state_r == S_NPC) begin
        if (op_r == BEQ || op_r == BLT || op_r == JALR) begin
            next_pc = branch_pc_r;
        end else begin
            next_pc = pc + 4;
        end
    end
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state_r      <= S_IDLE;
        status_r     <= 3'd0;
        MEM_addr_r   <= 32'd0;
        MEM_wdata_r  <= 32'd0;
        MEM_we_r     <= 1'b0;
        MEM_cnt_r    <= 2'd0;
        inst_r       <= 32'd0;
        op_r         <= SUB;
        optype_r     <= 3'd0;
        r1_r         <= 5'd0;
        r2_r         <= 5'd0;
        rd_r         <= 5'd0;
        f1_r         <= 5'd0;
        f2_r         <= 5'd0;
        fd_r         <= 5'd0;
        imm_r        <= 32'd0;
        reg_wen_r    <= 1'b0;
        reg_fwen_r   <= 1'b0;
        reg_waddr_r  <= 5'd0;
        reg_wdata_r  <= 32'd0;
        reg_fwaddr_r <= 5'd0;
        reg_fwdata_r <= 32'd0;
        branch_pc_r  <= 32'd0;
    end
    else begin
        state_r      <= state_w;
        status_r     <= status_w;
        MEM_addr_r   <= MEM_addr_w;
        MEM_wdata_r  <= MEM_wdata_w;
        MEM_we_r     <= MEM_we_w;
        MEM_cnt_r    <= MEM_cnt_w;
        inst_r       <= inst_w;
        op_r         <= op_w;
        optype_r     <= optype_w;
        r1_r         <= r1_w;
        r2_r         <= r2_w;
        rd_r         <= rd_w;
        f1_r         <= f1_w;
        f2_r         <= f2_w;
        fd_r         <= fd_w;
        imm_r        <= imm_w;
        reg_wen_r    <= reg_wen_w;
        reg_fwen_r   <= reg_fwen_w;
        reg_waddr_r  <= reg_waddr_w;
        reg_wdata_r  <= reg_wdata_w;
        reg_fwaddr_r <= reg_fwaddr_w;
        reg_fwdata_r <= reg_fwdata_w;
        branch_pc_r  <= branch_pc_w;  
    end
end

endmodule