// Decode/crack stage: interpret fetched instruction bits, extract architectural
// source/destination fields, immediates, and emit one or more backend uops.


// TODO: HANDLE FLOATING POINT STUFF. URGENT. URGENT. URGENT.
module ozone_decode
(
    input logic clk,
    input logic rst,
    input logic [31:0] the_insn_bits,
    input logic [47:0] the_insn_pc,
    input logic insn_ready,


    input logic ready_for_uop,

    output logic decoder_ready,
    output uop_t uop_out[2],
    output logic uop_valid,
);

    logic [31:0] insn_bits;
    logic [47:0] insn_pc;
    logic [2:0] decoder_state;

    typedef struct packed {
        logic [63:0] imm;
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
        decoder_ready = decoder_state == 0;
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
            uop_valid <= 1'b0;
            uop_out   <= '0;
        end else begin
            case (decoder_state)
                // 32 -> ZERO REGISTER
                // 31 -> STACK POINTER.
                0: begin
                    if (decoder_ready && insn_ready) begin
                        insn_bits <= the_insn_bits;
                        insn_pc <= the_insn_pc;
                        decoder_state <= 1;
                    end
                end

                1: begin
                    // Crack instruction fields into packet.
                    case (comb_ins_format)
                        0: begin
                            // M-format.
                            packet.opcode <= insn_bits[31:21];
                            packet.imm    <= {{55{insn_bits[20]}}, insn_bits[20:12]};
                            packet.reg_n  <= insn_bits[9:5] == '1 ? 6'(31) : {1'b0, insn_bits[9:5]};
                            packet.reg_t  <= insn_bits[4:0] == '1 ? 6'(32) : {1'b0, insn_bits[4:0]};
                        end
                        1: begin
                            // I1-format
                            packet.opcode <= {2'b0, insn_bits[31:23]};
                            packet.hw_val <= insn_bits[22:21];
                            packet.imm    <= {48'b0, insn_bits[20:5]};
                            packet.reg_d  <= insn_bits[4:0] == '1 ? 6'(32) : {1'b0, insn_bits[4:0]};
                        end
                        3: begin
                            // RR-format
                            packet.opcode      <= {3'b0, insn_bits[31:24]};
                            packet.shift_type  <= insn_bits[23:22];
                            packet.reg_m       <= insn_bits[20:16] == '1 ? 6'(32) : {1'b0, insn_bits[20:16]};
                            packet.imm         <= {26'b0, insn_bits[15:10]};
                            packet.reg_n       <= insn_bits[9:5]  == '1 ? 6'(32) : {1'b0, insn_bits[9:5]};
                            packet.reg_d       <= insn_bits[4:0]  == '1 ? 6'(32) : {1'b0, insn_bits[4:0]};
                        end
                        4: begin
                            // RI-format
                            packet.opcode <= {2'b0, insn_bits[31:23]};
                            packet.imm    <= {52'b0, insn_bits[21:10]};
                            packet.reg_n  <= insn_bits[9:5] == '1 ? 6'(32) : {1'b0, insn_bits[9:5]};
                            packet.reg_d  <= insn_bits[4:0] == '1 ? 6'(32) : {1'b0, insn_bits[4:0]};
                        end
                        5: begin
                            // B1-format
                            packet.opcode <= {5'b0, insn_bits[31:26]};
                            packet.imm    <= {{38{insn_bits[25]}}, insn_bits[25:0], 2'b0};
                        end
                        6: begin
                            // B2-format
                            packet.opcode    <= {3'b0, insn_bits[31:24]};
                            packet.imm       <= {{45{insn_bits[23]}}, insn_bits[23:5]};
                            packet.cond_code <= insn_bits[3:0];
                        end
                        7: begin
                            // B3-format
                            packet.opcode <= insn_bits[31:21];
                            packet.reg_n  <= insn_bits[9:5] == '1 ? 6'(32) : {1'b0, insn_bits[9:5]};
                        end
                        8: begin
                            // S-format
                            packet.opcode <= insn_bits[31:21];
                            packet.reg_d  <= {1'b0, insn_bits[4:0]};
                            packet.imm    <= {{31{insn_bits[23]}}, insn_bits[23:5], insn_bits[30:29], 12'b0};
                        end
                        default: begin end
                    endcase

                    // // Print decoded fields for simulation/debug.
                    // if (!comb_ins_valid) begin
                    //     $display("[DECODE] 0x%08X -> INVALID (format=0x%X)",
                    //              insn_bits, comb_ins_format);
                    // end else begin
                    //     case (comb_ins_format)
                    //         4'd0: $display("[DECODE] M-format  | opcode=%b  imm=%0d  Rn=%0d  Rt=%0d  FP=%0b",
                    //                        insn_bits[31:21],
                    //                        $signed({{23{insn_bits[20]}}, insn_bits[20:12]}),
                    //                        insn_bits[9:5], insn_bits[4:0],
                    //                        insn_bits[26]);
                    //         4'd1: $display("[DECODE] I1-format | opcode=%b  hw=%0d  imm16=0x%04X  Rd=%0d",
                    //                        insn_bits[31:23], insn_bits[22:21],
                    //                        insn_bits[20:5], insn_bits[4:0]);
                    //         4'd2: $display("[DECODE] I2-format | opcode=%b  imm=%0d  Rt=%0d",
                    //                        insn_bits[31:24],
                    //                        $signed({{13{insn_bits[23]}}, insn_bits[23:5]}),
                    //                        insn_bits[4:0]);
                    //         4'd3: $display("[DECODE] RR-format | opcode=%b  shift=%0d  N=%0b  Rm=%0d  imm6=%0d  Rn=%0d  Rd=%0d",
                    //                        insn_bits[31:24], insn_bits[23:22], insn_bits[21],
                    //                        insn_bits[20:16], insn_bits[15:10],
                    //                        insn_bits[9:5], insn_bits[4:0]);
                    //         4'd4: $display("[DECODE] RI-format | opcode=%b  imm=0x%03X  Rn=%0d  Rd=%0d",
                    //                        insn_bits[31:23], insn_bits[21:10],
                    //                        insn_bits[9:5], insn_bits[4:0]);
                    //         4'd5: $display("[DECODE] B1-format | opcode=%b  imm26=%0d",
                    //                        insn_bits[31:26],
                    //                        $signed({{6{insn_bits[25]}}, insn_bits[25:0]}));
                    //         4'd6: $display("[DECODE] B2-format | opcode=%b  imm19=%0d  cond=0x%X",
                    //                        insn_bits[31:24],
                    //                        $signed({{13{insn_bits[23]}}, insn_bits[23:5]}),
                    //                        insn_bits[3:0]);
                    //         4'd7: $display("[DECODE] B3-format | opcode=%b  Rn=%0d",
                    //                        insn_bits[31:21], insn_bits[9:5]);
                    //         4'd8: $display("[DECODE] S-format  | opcode=%b",
                    //                        insn_bits[31:21]);
                    //         default: ;
                    //     endcase
                    // end

                    decoder_state <= 2;
                end

                // Micro-op generation: fill uop_t fields from decoded packet.
                2: begin
                    uop_valid <= 1'b1;
                    uop_out[0].pc <= insn_pc;
                    uop_out[1].pc <= insn_pc;

                    case (comb_ins_format)
                        4'd0: begin  // M: load/store
                            uop_out[0].uop_type <= UOP_AGU;
                            uop_out[0].a        <= 6'd32;
                            uop_out[0].b        <= packet.reg_n;
                            uop_out[0].imm_opnd <= 1'b1;
                            uop_out[0].imm_bits <= {{32{packet.imm[31]}}, packet.imm};

                            uop_out[1].uop_type <= packet.opcode[1] ? UOP_RD : UOP_WR;
                            uop_out[1].a        <= packet.reg_t;
                            uop_out[1].fp_bit   <= packet.opcode[5];
                        end

                        4'd1: begin  // I1: MOVZ / MOVK
                            // MOVZ: OR(zero, shifted_imm); MOVK: OR(AND(Rd, <mask>), shifted_imm).
                            // packet.opcode[6] == insn_bits[29] == opc[0]: 0=MOVZ, 1=MOVK.

                            if (packet.opcode[6] == 0) begin
                                uop_out[0].uop_type <= UOP_OR;
                                uop_out[0].a        <= packet.reg_d;
                                uop_out[0].b        <= 6'd32;
                                uop_out[0].imm_opnd <= 1'b1;
                                uop_out[0].imm_bits <= 64'(packet.imm) << {packet.hw_val, 4'b0};
                            end else begin
                                logic [63:0] mask;

                                case (packet.hw_val)
                                    0: mask = 64'hFFFF;
                                    1: mask = 64'hFFFF0000;
                                    2: mask = 64'hFFFF00000000;
                                    3: mask = 64'hFFFF000000000000;
                                endcase

                                uop_out[0].uop_type <= UOP_AND;
                                uop_out[0].a        <= 6'd32;
                                uop_out[0].b        <= packet.reg_d;
                                uop_out[0].imm_opnd <= 1'b1;
                                uop_out[0].imm_bits <= ~mask;

                                uop_out[1].uop_type <= UOP_OR;
                                uop_out[1].a        <= packet.reg_d;
                                uop_out[1].b        <= 6'd32;
                                uop_out[1].imm_opnd <= 1'b1;
                                uop_out[1].imm_bits <= 64'(packet.imm) << {packet.hw_val, 4'b0};
                            end
                        end

                        4'd3: begin  // RR: shifted-register ALU / shift-by-register
                            if (packet.opcode[7:4] == 4'h9) begin  // LSLV / LSRV / ASRV: shift amount from register, single uop
                                uop_out[0].a <= packet.reg_d;
                                uop_out[0].b <= packet.reg_n;
                                uop_out[0].c <= packet.reg_m;
                                case (packet.imm[3:0])
                                    4'h8: uop_out[0].uop_type <= UOP_LSL;
                                    4'h9: uop_out[0].uop_type <= UOP_LSR;
                                    4'hA: uop_out[0].uop_type <= UOP_ASR;
                                    default: uop_out[0].uop_type <= UOP_LSL;
                                endcase
                            end else begin
                                uop_out[0].a         <= 6'd32;
                                uop_out[0].b         <= packet.reg_m;
                                uop_out[0].imm_opnd <= 1;
                                uop_out[0].imm_bits <= {56'b0, packet.imm[5:0]};

                                case (packet.shift_type)
                                    0: uop_out[0].uop_type <= UOP_LSL;
                                    1: uop_out[0].uop_type <= UOP_LSR;
                                    2: uop_out[0].uop_type <= UOP_ASR;
                                endcase

                                uop_out[1].a <= packet.reg_d;
                                uop_out[1].b <= packet.reg_n;
                                uop_out[1].c <= 6'd32;
                                uop_out[1].set_flags <= 1;
                                if (packet.opcode[0]) begin  // insn_bits[24]=1 → arithmetic (01011)
                                    uop_out[1].uop_type <= UOP_ADD;  // ADDS / SUBS
                                    uop_out[1].neg_c_or_imm <= packet.opcode[6];
                                end else begin               // insn_bits[24]=0 → logical (01010)
                                    case (packet.opcode[6:5])  // opc[1:0] = insn_bits[30:29]
                                        2'b01: begin
                                            uop_out[1].uop_type <= UOP_OR;   // ORR / ORN
                                            if (insn_bits[21]) begin
                                                uop_out[1].neg_c_or_imm <= 1;
                                            end
                                        end
                                        2'b10: uop_out[1].uop_type <= UOP_XOR;  // EOR / EON
                                        2'b11: uop_out[1].uop_type <= UOP_AND;  // ANDS / BICS
                                    endcase
                                end
                            end
                        end

                        4'd4: begin  // RI: add/sub immediate or bitfield (UBFM/SBFM)
                            // TODO: Maybe change this if FP stuff ends up here.
                            if (insn_bits[28:24] != 5'b10001) begin  // UBFM / SBFM: shift operation, single uop
                                // packet.imm[11:6] = immr = insn_bits[21:16]
                                // packet.imm[5:0]  = imms = insn_bits[15:10]
                                // packet.opcode[7] = opc[1] = insn_bits[30]: 0=SBFM, 1=UBFM
                                uop_out[0].a        <= packet.reg_d;
                                uop_out[0].b        <= packet.reg_n;
                                uop_out[0].imm_opnd <= 1'b1;
                                if (!packet.opcode[7]) begin  // SBFM → ASR, shift amount = immr
                                    uop_out[0].uop_type <= UOP_ASR;
                                    uop_out[0].imm_bits <= {58'b0, packet.imm[11:6]};
                                end else if (packet.imm[5:0] == 6'd63) begin  // UBFM, imms==63 → LSR, shift amount = immr
                                    uop_out[0].uop_type <= UOP_LSR;
                                    uop_out[0].imm_bits <= {58'b0, packet.imm[11:6]};
                                end else begin  // UBFM, imms!=63 → LSL, shift amount = 63 - imms
                                    uop_out[0].uop_type <= UOP_LSL;
                                    uop_out[0].imm_bits <= {58'b0, 6'd63 - packet.imm[5:0]};
                                end
                            end else begin  // add/sub immediate: shift is on a static immediate, bake it in
                                uop_out[0].a             <= packet.reg_d;
                                uop_out[0].b             <= packet.reg_n;
                                uop_out[0].uop_type      <= UOP_ADD;  // ADD / ADDS / SUB / SUBS
                                uop_out[0].set_flags     <= packet.opcode[6];   // S-bit = insn_bits[29]
                                uop_out[0].neg_c_or_imm  <= packet.opcode[7];   // opc = insn_bits[30]: 1 → SUB
                                uop_out[0].imm_opnd      <= 1;
                                uop_out[0].imm_bits      <= insn_bits[22] ? {40'b0, packet.imm[11:0], 12'b0} : packet.imm;
                            end
                        end

                        4'd5: begin  // B1: B / BL
                            // packet.opcode[5] == insn_bits[31]: 0=B, 1=BL (writes x30).
                            uop_out[0].uop_type <= UOP_ADD;
                            uop_out[0].a        <= packet.opcode[5] ? 6'd30 : 6'd32;
                            uop_out[0].imm_opnd <= 1'b1;
                            uop_out[0].imm_bits <= {{32{packet.imm[31]}}, packet.imm};
                            uop_out[0].check_target <= 1;
                        end

                        4'd6: begin  // B2: B.cond
                            uop_out[0].uop_type <= UOP_COND_CHECK;
                            uop_out[0].imm_opnd <= 1'b1;
                            uop_out[0].imm_bits <= {{32{packet.imm[31]}}, packet.imm};
                            uop_out[0].check_cond <= 1;
                        end

                        4'd7: begin  // B3: BR / BLR / RET
                            // packet.opcode[0] == insn_bits[21]: BLR sets a=x30.
                            uop_out[0].uop_type     <= UOP_OR;
                            uop_out[0].a            <= packet.opcode[0] ? 6'd30 : 6'd32;
                            uop_out[0].b            <= packet.reg_n;
                            uop_out[0].c            <= 6'd32;
                            uop_out[0].check_target <= 1;
                            // TODO: ERET.
                        end

                        4'd8: begin  // S: system / ADRP
                            uop_out[0].uop_type <= UOP_ADD;
                            uop_out[0].a        <= packet.reg_d;
                            uop_out[0].imm_opnd <= 1'b1;
                            uop_out[0].imm_bits <= packet.imm;
                            // TODO: MSR, MRS
                        end

                        default: uop_out[0].uop_type <= UOP_ADD;
                    endcase

                    decoder_state <= 3;
                end

                3: begin
                    if (ready_for_uop) begin
                        decoder_state <= 0;
                        uop_valid     <= 1'b0;
                    end
                end

                default: decoder_state <= 0;
            endcase
        end
    end

endmodule
