typedef enum logic [3:0] {
    UOP_AGU        = 4'd0,
    UOP_RD         = 4'd1,
    UOP_WR         = 4'd2,
    UOP_AND        = 4'd3,
    UOP_OR         = 4'd4,
    UOP_ADD        = 4'd5,
    UOP_XOR        = 4'd7,
    UOP_LSL        = 4'd8,
    UOP_LSR        = 4'd9,
    UOP_ASR        = 4'd10,
    UOP_COND_CHECK = 4'd11,
    UOP_NAN_CHECK  = 4'd12,
    UOP_FADD       = 4'd13,
    UOP_FMUL       = 4'd14
} uop_type_e;

typedef struct packed {
    uop_type_e uop_type;
    logic [5:0] a, b, c; // registers. a is destination or load/store target.
    // b is the first operand when applicable,
    // c is the second operand when applicable.
    logic neg_c_or_imm;
    logic imm_opnd; // specifies whether the second operand is an immediate or from a register in cases where it is otherwise ambiguous.
    logic [47:0] pc;
    logic [63:0] imm_bits; // specifies the bits of the second operand.
    logic fp_bit; // specifies whether the operation deals with floating point registers, but is not specifically a floating point operation. e.g., load, store.
    logic set_flags;
    logic check_target;
} uop_t;
