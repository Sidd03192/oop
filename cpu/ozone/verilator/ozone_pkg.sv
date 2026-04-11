// Shared Ozone definitions: parameters, enums, packed structs, uop formats,
// ROB/RS/LSQ metadata types, exception codes, and common constants.
package ozone_pkg;

// -------------------------------------------------------
// Global Parameters
// -------------------------------------------------------
localparam int ROB_IDX_WIDTH = 6;   // 64-entry ROB
localparam int OPCODE_W      = 6;   // 64 possible micro-ops

// -------------------------------------------------------
// Micro-op Opcodes (for adder FU)
// -------------------------------------------------------
typedef enum logic [OPCODE_W-1:0] {
    // Arithmetic
    OP_ADD      = 6'd0,
    OP_ADDS     = 6'd1,   // ADD with flags
    OP_SUB      = 6'd2,
    OP_SUBS     = 6'd3,   // SUB with flags
    OP_CMP      = 6'd4,   // SUB with flags, no writeback
    OP_CMN      = 6'd5,   // ADD with flags, no writeback
    OP_ADRP_ADD = 6'd6,   // ADD portion of ADRP (Vj = PC & ~0xFFF, Vk = imm << 12)
    // Unconditional branches
    OP_B        = 6'd8,
    OP_BL       = 6'd9,   // branch and link (writes return addr)
    OP_BR       = 6'd10,  // branch register
    OP_BLR      = 6'd11,  // branch-link register
    OP_RET      = 6'd12,  // return (BR X30)
    // Compare-and-branch
    OP_CBZ      = 6'd16,
    OP_CBNZ     = 6'd17,
    // Conditional branch (B.cond) - checks NZCV
    OP_BCOND    = 6'd18
} adder_op_e;


typedef enum logic [3:0] {
    COND_EQ = 4'h0,   // Equal (Z==1)
    COND_NE = 4'h1,   // Not equal (Z==0)
    COND_CS = 4'h2,   // Carry set / unsigned >= (C==1)
    COND_CC = 4'h3,   // Carry clear / unsigned < (C==0)
    COND_MI = 4'h4,   // Minus / negative (N==1)
    COND_PL = 4'h5,   // Plus / positive or zero (N==0)
    COND_VS = 4'h6,   // Overflow (V==1)
    COND_VC = 4'h7,   // No overflow (V==0)
    COND_HI = 4'h8,   // Unsigned > (C==1 && Z==0)
    COND_LS = 4'h9,   // Unsigned <= (C==0 || Z==1)
    COND_GE = 4'hA,   // Signed >= (N==V)
    COND_LT = 4'hB,   // Signed < (N!=V)
    COND_GT = 4'hC,   // Signed > (Z==0 && N==V)
    COND_LE = 4'hD,   // Signed <= (Z==1 || N!=V)
    COND_AL = 4'hE,   // Always
    COND_NV = 4'hF    // Always (alternate encoding)
} cond_code_e;

typedef struct packed {
    logic [63:0]                 value;      // actual architectural state
    logic                        busy;       // if somehing will update this
    logic [ROB_IDX_WIDTH-1:0]    rob_idx;    // rob entry for why its busy (wakeup)
} reg_entry_t;


// Reservation station entry 
typedef struct packed {
    logic                       value;     // computed value (when ready)
    logic [63:0]                Vj;       // value of source 1 (when ready)
    logic [63:0]                Vk;       // value of source 2 (when ready)
    logic [ROB_IDX_WIDTH-1:0]   Qj;       // ROB tag for source 1 (0 = ready)
    logic [ROB_IDX_WIDTH-1:0]   Qk;       // ROB tag for source 2 (0 = ready)
    logic [ROB_IDX_WIDTH-1:0]   rob_tag; // which ROB entry gets the result
    logic                       valid;
    logic [OPCODE_W-1:0]        op; // FU can do multiple micro-ops
    logic [3:0]                 nzcv;      // NZCV flags for this instruction 
    logic                       updates_nzcv; // does this instruction update NZCV?
} rs_entry_t;


typedef struct packed {
    logic                       value;     // computed value (when ready)
    logic [63:0]                Vj;       // value of source 1 (when ready)
    logic [63:0]                Vk;       // value of source 2 (when ready)
    logic [ROB_IDX_WIDTH-1:0]   Qj;       // ROB tag for source 1 (0 = ready)
    logic [ROB_IDX_WIDTH-1:0]   Qk;       // ROB tag for source 2 (0 = ready)
    logic [ROB_IDX_WIDTH-1:0]   rob_tag; // which ROB entry gets the result
    logic                       valid;
    logic [OPCODE_W-1:0]        op; // FU can do multiple micro-ops
    logic                       nzcv;      // NZCV flags for this instruction 
    cond_code_e                 branch_cond; // condition code for B.cond
    logic                      branch_target; // computed target
    logic                      branch_taken;  // computed taken/not taken (true value)
    logic                      pred_taken;    // branch predictor's taken/not-taken decision
} rs_entry_add_t;


typedef struct packed {
    logic                       valid;        // result ready to broadcast
    logic [ROB_IDX_WIDTH-1:0]   rob_tag;      // which ROB entry completed
    logic [63:0]                value;        // computed result
    
    // flags (for ALU ops like ADDS, SUBS, CMP)
    logic                       update_nzcv;
    logic [3:0]                 nzcv;
    
    // branch resolution (adder)
    logic                       br_valid;     // this is a branch result
    logic                       br_taken;
    logic [63:0]                br_target;
    logic                       pred_taken;   // carried predicted taken/not-taken metadata
    
    // exceptions 
    logic                       exc;
    logic [7:0]                 exc_code;
} cdb_broadcast_t;

endpackage
