typedef enum logic [3:0] {
    UOP_AGU        = 4'd0,
    UOP_RD         = 4'd1,
    UOP_WR         = 4'd2,
    UOP_AND        = 4'd3,
    UOP_OR         = 4'd4,
    UOP_ADD        = 4'd5,
    UOP_SHIFT      = 4'd6,
    UOP_XOR        = 4'd7,
    UOP_LSL        = 4'd8,
    UOP_LSR        = 4'd9,
    UOP_ASR        = 4'd10,
    UOP_COND_CHECK = 4'd11,
    UOP_NAN_CHECK  = 4'd12,
    UOP_FADD       = 4'd13,
    UOP_FMUL       = 4'd14
} uop_type_e;

