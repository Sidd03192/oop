// Decode/crack stage: interpret fetched instruction bits, extract architectural
// source/destination fields, immediates, and emit one or more backend uops.
module ozone_decode
(
    input logic clk,
    input logic rst,
    input logic [31:0] the_insn_bits,
    input logic insn_ready,

    output logic decoder_ready
);

    logic [31:0] insn_bits;
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
    logic [3:0]  comb_ins_format;
    logic        comb_ins_valid;

    always_comb begin
        decoder_ready = 1;
    end

    // Combinational: derive instruction format and validity from raw bits.
    // All supported instructions are 64-bit (sf=1). Encodings follow AArch64.
    always_comb begin
        comb_ins_format = 4'hF;
        comb_ins_valid  = 1'b0;

        // Format 0 (M): unscaled load/store (LDUR/STUR, integer and FP).
        // bits[29:27]=111, bits[25:24]=00, bit[21]=0, bits[11:10]=00 (offset encoding).
        if (insn_bits[29:27] == 3'b111  &&
            insn_bits[25:24] == 2'b00   &&
            insn_bits[21]    == 1'b0    &&
            insn_bits[11:10] == 2'b00)
        begin
            comb_ins_format = 4'd0;
            // Must be 64-bit size (bits[31:30]=11) and opc=store(00) or load(01).
            comb_ins_valid = (insn_bits[31:30] == 2'b11) &&
                        (insn_bits[23:22] inside {2'b00, 2'b01});
        end

        // Format 7 (B3): branch register (BR, BLR, RET).
        // bits[31:25]=1101011; opc: 0000=BR, 0001=BLR, 0010=RET.
        // Remaining fixed fields must be zero (op2=11111, op3/op4=0).
        else if (insn_bits[31:25] == 7'b1101011               &&
                 insn_bits[24:21] inside {4'b0000, 4'b0001, 4'b0010} &&
                 insn_bits[20:16] == 5'b11111                 &&
                 insn_bits[15:10] == 6'b000000                &&
                 insn_bits[4:0]   == 5'b00000)
        begin
            comb_ins_format = 4'd7;
            comb_ins_valid  = 1'b1;
        end

        // Format 8 (S): system / exception / ADRP.
        //   SVC:          bits[31:21]=11010100000, bits[4:0]=00001
        //   ERET:         bits[31:21]=11010110100
        //   MRS/MSR/NOP:  bits[31:22]=1101010100
        //   ADRP:         bit[31]=1, bits[28:24]=10000
        else if ((insn_bits[31:21] == 11'b11010100000 && insn_bits[4:0] == 5'b00001) ||
                 (insn_bits[31:21] == 11'b11010110100)                                ||
                 (insn_bits[31:22] == 10'b1101010100)                                 ||
                 (insn_bits[31]    == 1'b1 && insn_bits[28:24] == 5'b10000))
        begin
            comb_ins_format = 4'd8;
            comb_ins_valid  = 1'b1;
        end

        // Format 6 (B2): conditional branch (B.cond).
        // bits[31:24]=01010100; bit[4] must be 0 (reserved).
        else if (insn_bits[31:24] == 8'b01010100 && insn_bits[4] == 1'b0) begin
            comb_ins_format = 4'd6;
            comb_ins_valid  = 1'b1;
        end

        // Format 5 (B1): unconditional branch (B / BL).
        // bits[30:26]=00101; bit[31] distinguishes B(0) from BL(1).
        else if (insn_bits[30:26] == 5'b00101) begin
            comb_ins_format = 4'd5;
            comb_ins_valid  = 1'b1;
        end

        // Format 2 (I2): compare-and-branch (CBZ / CBNZ), 64-bit.
        // bit[31]=1 (sf), bits[30:25]=011010; bit[24] selects CBZ(0)/CBNZ(1).
        else if (insn_bits[31] == 1'b1 && insn_bits[30:25] == 6'b011010) begin
            comb_ins_format = 4'd2;
            comb_ins_valid  = 1'b1;
        end

        // Format 1 (I1): move-wide immediate (MOVZ / MOVK), 64-bit.
        // bits[28:23]=100101, bit[31]=1; opc bits[30:29]: MOVZ=10, MOVK=11.
        else if (insn_bits[28:23] == 6'b100101 && insn_bits[31] == 1'b1) begin
            comb_ins_format = 4'd1;
            comb_ins_valid  = insn_bits[30:29] inside {2'b10, 2'b11};
        end

        // Format 4 (RI): add/sub immediate, or bitfield (UBFM / SBFM), 64-bit.
        //   Add/sub imm: bits[28:24]=10001, bit[31]=1.
        //   Bitfield:    bits[28:23]=100110, bit[31]=1, bit[22]=1 (N required for 64-bit).
        else if ((insn_bits[31] == 1'b1 && insn_bits[28:24] == 5'b10001) ||
                 (insn_bits[31] == 1'b1 && insn_bits[28:23] == 6'b100110 &&
                  insn_bits[22] == 1'b1))
        begin
            comb_ins_format = 4'd4;
            comb_ins_valid  = 1'b1;
        end

        // Format 3 (RR): shifted-register ALU and shift-by-register, 64-bit.
        //   Arithmetic shifted (ADD/ADDS/SUB/SUBS): bits[28:24]=01011, bit[21]=0.
        //   Logical shifted (AND/ANDS/ORR/ORN/EOR): bits[28:24]=01010.
        //   Shift-by-register (LSLV/LSRV/ASRV):    bits[31:21]=10011010110.
        else if ((insn_bits[31] == 1'b1 && insn_bits[28:24] == 5'b01011 && insn_bits[21] == 1'b0) ||
                 (insn_bits[31] == 1'b1 && insn_bits[28:24] == 5'b01010)                           ||
                 (insn_bits[31:21] == 11'b10011010110))
        begin
            comb_ins_format = 4'd3;
            comb_ins_valid  = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            decoder_state <= 0;
        end else begin
            case (decoder_state)
                // 32 -> ZERO REGISTER
                // 31 -> STACK POINTER.
                0: begin
                    if (decoder_ready && insn_ready) begin
                        insn_bits     <= the_insn_bits;
                        decoder_state <= 1;
                    end
                end

                1: begin
                    // Crack instruction fields into packet.
                    case (comb_ins_format)
                        0: begin
                            // M-format.
                            packet.opcode <= insn_bits[31:21];
                            packet.imm    <= {{23{insn_bits[20]}}, insn_bits[20:12]};
                            packet.reg_n  <= insn_bits[9:5] == '1 ? 6'(31) : insn_bits[9:5];
                            packet.reg_t  <= insn_bits[4:0] == '1 ? 6'(32) : insn_bits[4:0];
                        end
                        1: begin
                            // I1-format
                            packet.opcode <= insn_bits[31:23];
                            packet.hw_val <= insn_bits[22:21];
                            packet.imm    <= {16'b0, insn_bits[20:5]};
                            packet.reg_d  <= insn_bits[4:0] == '1 ? 6'(32) : insn_bits[4:0];
                        end
                        2: begin
                            // I2-format
                            packet.opcode <= insn_bits[31:24];
                            packet.imm    <= {{13{insn_bits[23]}}, insn_bits[23:5]};
                            packet.reg_d  <= insn_bits[4:0] == '1 ? 6'(32) : insn_bits[4:0];
                        end
                        3: begin
                            // RR-format
                            packet.opcode      <= insn_bits[31:24];
                            packet.shift_type  <= insn_bits[23:22];
                            packet.reg_m       <= insn_bits[20:16] == '1 ? 6'(32) : insn_bits[20:16];
                            packet.imm         <= {26'b0, insn_bits[15:10]};
                            packet.reg_n       <= insn_bits[9:5]  == '1 ? 6'(32) : insn_bits[9:5];
                            packet.reg_d       <= insn_bits[4:0]  == '1 ? 6'(32) : insn_bits[4:0];
                        end
                        4: begin
                            // RI-format
                            packet.opcode <= insn_bits[31:23];
                            packet.imm    <= {20'b0, insn_bits[21:10]};
                            packet.reg_n  <= insn_bits[9:5] == '1 ? 6'(32) : insn_bits[9:5];
                            packet.reg_d  <= insn_bits[4:0] == '1 ? 6'(32) : insn_bits[4:0];
                        end
                        5: begin
                            // B1-format
                            packet.opcode <= insn_bits[31:26];
                            packet.imm    <= {{6{insn_bits[25]}}, insn_bits[25:0]};
                        end
                        6: begin
                            // B2-format
                            packet.opcode    <= insn_bits[31:24];
                            packet.imm       <= {{13{insn_bits[23]}}, insn_bits[23:5]};
                            packet.cond_code <= insn_bits[3:0];
                        end
                        7: begin
                            // B3-format
                            packet.opcode <= insn_bits[31:21];
                            packet.reg_n  <= insn_bits[9:5] == '1 ? 6'(32) : insn_bits[9:5];
                        end
                        8: begin
                            // S-format
                            packet.opcode <= insn_bits[31:21];
                            packet.reg_d  <= insn_bits[4:0];
                            packet.imm    <= {{13{insn_bits[23]}}, insn_bits[23:5]};
                        end
                        default: begin end
                    endcase

                    // Print decoded fields for simulation/debug.
                    if (!comb_ins_valid) begin
                        $display("[DECODE] 0x%08X -> INVALID (format=0x%X)",
                                 insn_bits, comb_ins_format);
                    end else begin
                        case (comb_ins_format)
                            4'd0: $display("[DECODE] M-format  | opcode=%b  imm=%0d  Rn=%0d  Rt=%0d  FP=%0b",
                                           insn_bits[31:21],
                                           $signed({{23{insn_bits[20]}}, insn_bits[20:12]}),
                                           insn_bits[9:5], insn_bits[4:0],
                                           insn_bits[26]);
                            4'd1: $display("[DECODE] I1-format | opcode=%b  hw=%0d  imm16=0x%04X  Rd=%0d",
                                           insn_bits[31:23], insn_bits[22:21],
                                           insn_bits[20:5], insn_bits[4:0]);
                            4'd2: $display("[DECODE] I2-format | opcode=%b  imm=%0d  Rt=%0d",
                                           insn_bits[31:24],
                                           $signed({{13{insn_bits[23]}}, insn_bits[23:5]}),
                                           insn_bits[4:0]);
                            4'd3: $display("[DECODE] RR-format | opcode=%b  shift=%0d  N=%0b  Rm=%0d  imm6=%0d  Rn=%0d  Rd=%0d",
                                           insn_bits[31:24], insn_bits[23:22], insn_bits[21],
                                           insn_bits[20:16], insn_bits[15:10],
                                           insn_bits[9:5], insn_bits[4:0]);
                            4'd4: $display("[DECODE] RI-format | opcode=%b  imm=0x%03X  Rn=%0d  Rd=%0d",
                                           insn_bits[31:23], insn_bits[21:10],
                                           insn_bits[9:5], insn_bits[4:0]);
                            4'd5: $display("[DECODE] B1-format | opcode=%b  imm26=%0d",
                                           insn_bits[31:26],
                                           $signed({{6{insn_bits[25]}}, insn_bits[25:0]}));
                            4'd6: $display("[DECODE] B2-format | opcode=%b  imm19=%0d  cond=0x%X",
                                           insn_bits[31:24],
                                           $signed({{13{insn_bits[23]}}, insn_bits[23:5]}),
                                           insn_bits[3:0]);
                            4'd7: $display("[DECODE] B3-format | opcode=%b  Rn=%0d",
                                           insn_bits[31:21], insn_bits[9:5]);
                            4'd8: $display("[DECODE] S-format  | opcode=%b",
                                           insn_bits[31:21]);
                            default: ;
                        endcase
                    end

                    decoder_state <= 0;
                end

                default: decoder_state <= 0;
            endcase
        end
    end

endmodule
