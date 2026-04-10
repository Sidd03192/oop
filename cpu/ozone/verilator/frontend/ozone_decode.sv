// Decode/crack stage: interpret fetched instruction bits, extract architectural
// source/destination fields, immediates, and emit one or more backend uops.
module ozone_decode
(
    input logic clk,
    input logic rst,
    input logic [31:0] insn_bits,
    input logic insn_ready,

    output logic decoder_ready,
);

    logic [2:0] decoder_state;

    typedef struct packed {
        logic [31:0] imm;
        logic [5:0]  reg_n;
        logic [5:0]  reg_m;
        logic [5:0]  reg_d;
        logic [5:0]  reg_t;
        logic [10:0] opcode;
        logic [1:0]  shift_type;
        logic [3:0]  cond_code;
        logic [1:0]  hw_val;
    } ins_packet_t;

    ins_packet_t packet;

    always_comb begin
        decoder_ready = 1;
    end

    always_ff @(posedge clk) begin
        if (rst) begin

        end else begin
            // 32 -> ZERO REGISTER
            // 31 -> STACK POINTER.
            // TODO: Determine this, also make sure this is a valid instruction.
            logic [3:0] ins_format;
            
            case (ins_format)
                0: begin
                    // M-format.
                    packet.opcode <= insn_bits[31:21];

                    // sign extend from 9 bits to 32.
                    packet.imm <= {{23{insn_bits[20]}}, insn_bits[20:12]};

                    packet.reg_n <= insn_bits[9:5] == '1 ? 6'(31) : insn_bits[9:5];
                    packet.reg_t <= insn_bits[4:0] == '1  ? 6'(32) : insn_bits[4:0];
                end

                1: begin
                    // I1-format

                    packet.opcode <= insn_bits[31:23];
                    packet.hw_val <= insn_bits[22:21];
                    packet.imm <= {16'b0, insn_bits[20:5]};
                    packet.reg_d <= insn_bits[4:0] == '1 ? 6'(32) : insn_bits[4:0];
                end

                2: begin
                    // I2-format

                    packet.opcode <= insn_bits[31:24];
                    packet.imm <= {{13{insn_bits[23]}}, insn_bits[23:5]};
                    packet.reg_d <= insn_bits[4:0] == '1 ? 6'(32) : insn_bits[4:0];
                end

                3: begin
                    // RR-format

                    packet.opcode <= insn_bits[31:24];
                    packet.shift_type <= insn_bits[23:22];
                    packet.reg_m <= insn_bits[20:16] == '1 ? 6'(32) insn_bits[20:16];
                    packet.imm <= insn_bits[15:10];
                    packet.reg_n <= insn_bits[9:5] == '1 ? 6'(32) : insn_bits[9:5];
                    packet.reg_d <= insn_bits[4:0] == '1 ? 6'(32) : insn_bits[4:0];
                end

                4: begin
                    // RI-format

                    packet.opcode <= insn_bits[31:23];
                    packet.imm <= insn_bits[21:10];
                    packet.reg_n <= insn_bits[9:5] == '1 ? 6'(32) : insn_bits[9:5];
                    packet.reg_d <= insn_bits[4:0] == '1 ? 6'(32) : insn_bits[4:0];
                end

                5: begin
                    // B1-format

                    packet.opcode <= insn_bits[31:26];
                    packet.imm <= {{6{insn_bits[25]}}, insn_bits[25:0]};
                end

                6: begin
                    // B2-format

                    packet.opcode <= insn_bits[31:24];
                    packet.imm <= {{13{insn_bits[23]}}, insn_bits[23:5]};
                    packet.cond_code <= insn_bits[3:0];
                end

                7: begin
                    // B3-format
                    packet.opcode <= insn_bits[31:21];
                    packet.reg_n <= insn_bits[9:5] == '1 ? '(32) : insn_bits[9:5];

                end

                8: begin
                    // S-format

                    packet.opcode <= insn_bits[31:21];

                    // TODO: This.
                end

                default: begin end
            endcase
        end
    end

endmodule
