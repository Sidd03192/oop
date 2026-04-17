/* verilator lint_off UNUSEDSIGNAL */
// Decode testbench.
//
// Each test drives one instruction word into the decoder and waits two clock
// cycles: one for the decoder to latch the bits (state 0→1) and one for the
// crack logic and $display to fire (state 1→0).
//
// Expected formats at a glance:
//   M-format  (0) : LDUR, STUR, FP-LDUR, FP-STUR
//   I1-format (1) : MOVZ, MOVK
//   RR-format (3) : ADD/ADDS/CMN/SUB/SUBS/CMP (shifted-reg), ORR/ORN/MVN/EOR/ANDS/TST, LSLV/LSRV/ASRV
//   RI-format (4) : UBFM, SBFM, LSL(imm), LSR(imm), ASR(imm)
//   B1-format (5) : B, BL
//   B2-format (6) : B.cond
//   B3-format (7) : RET
//   S-format  (8) : NOP, ERET, MRS, MSR, SVC, ADRP
//   INVALID (0xF) : FP arithmetic (FMOV/FNEG/FADD/FMUL/FSUB/FCMP) — no format defined yet

module tb_ozone_decode;

    logic        clk;
    logic        rst;
    logic [31:0] the_insn_bits;
    logic        insn_ready;
    logic        decoder_ready;

    ozone_decode dut (
        .clk          (clk),
        .rst          (rst),
        .the_insn_bits(the_insn_bits),
        .insn_ready   (insn_ready),
        .decoder_ready(decoder_ready)
    );

    // 10 ns clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------------
    // Helper: assert insn_ready for one cycle so the decoder latches
    // the word, then wait a second cycle for the crack+display pass.
    // ---------------------------------------------------------------
    task send_insn(input [31:0] bits, input string label);
        $display("\n--- %s (0x%08X) ---", label, bits);
        @(negedge clk);
        the_insn_bits = bits;
        insn_ready    = 1'b1;
        @(posedge clk);          // state 0→1: latch
        @(negedge clk);
        insn_ready    = 1'b0;
        @(posedge clk);          // state 1→0: crack + $display fires
        #1;
    endtask

    // ---------------------------------------------------------------
    // Reset
    // ---------------------------------------------------------------
    task reset_dut();
        rst       = 1'b1;
        insn_ready = 1'b0;
        the_insn_bits = '0;
        repeat(3) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    // ---------------------------------------------------------------
    // Test stimulus
    // ---------------------------------------------------------------
    initial begin
        reset_dut();

        // ── M-format (0): LDUR / STUR ───────────────────────────────
        // LDUR X1, [X2, #8]   : size=11 V=0 opc=01 imm9=8(->bit[15]) Rn=X2 Rt=X1
        //   31:24=F8  23:16=40  15:8=80  7:0=41
        send_insn(32'hF8408041, "LDUR X1, [X2, #8]");

        // STUR X1, [X2, #8]   : size=11 V=0 opc=00 imm9=8 Rn=X2 Rt=X1
        //   31:24=F8  23:16=00  15:8=80  7:0=41
        send_insn(32'hF8008041, "STUR X1, [X2, #8]");

        // LDUR D1, [X2, #8]   : size=11 V=1 opc=01 → FP=1
        //   31:24=FC  23:16=40  15:8=80  7:0=41
        send_insn(32'hFC408041, "LDUR D1, [X2, #8]  (FP)");

        // STUR D1, [X2, #8]   : size=11 V=1 opc=00 → FP=1
        //   31:24=FC  23:16=00  15:8=80  7:0=41
        send_insn(32'hFC008041, "STUR D1, [X2, #8]  (FP)");

        // ── I1-format (1): MOVZ / MOVK ──────────────────────────────
        // MOVZ X1, #1         : sf=1 opc=10 hw=0 imm16=1 Rd=X1
        send_insn(32'hD2800021, "MOVZ X1, #1");

        // MOVK X1, #1         : sf=1 opc=11 hw=0 imm16=1 Rd=X1
        send_insn(32'hF2800021, "MOVK X1, #1");

        // ── S-format (8): ADRP ──────────────────────────────────────
        // ADRP X1, page+1     : P=1 immlo=01 bits[28:24]=10000 immhi=0 Rd=X1
        send_insn(32'hB0000001, "ADRP X1, page+1");

        // ── RR-format (3): arithmetic shifted-register ───────────────
        // ADD X1, X2, X3      : sf=1 op=0 S=0 shift=LSL rm=X3 imm6=0 Rn=X2 Rd=X1
        send_insn(32'h8B030041, "ADD X1, X2, X3");

        // ADDS X1, X2, X3     : S=1
        send_insn(32'hAB030041, "ADDS X1, X2, X3");

        // CMN X2, X3          : ADDS XZR, X2, X3 (Rd=31)
        send_insn(32'hAB03005F, "CMN X2, X3  (=ADDS XZR,X2,X3)");

        // SUB X1, X2, X3      : op=1 S=0
        send_insn(32'hCB030041, "SUB X1, X2, X3");

        // SUBS X1, X2, X3     : op=1 S=1
        send_insn(32'hEB030041, "SUBS X1, X2, X3");

        // CMP X2, X3          : SUBS XZR, X2, X3 (Rd=31)
        send_insn(32'hEB03005F, "CMP X2, X3  (=SUBS XZR,X2,X3)");

        // ── RR-format (3): logical shifted-register ──────────────────
        // ORR X1, X2, X3      : opc=01 N=0
        send_insn(32'hAA030041, "ORR X1, X2, X3");

        // ORN X1, X2, X3      : opc=01 N=1 (bit[21]=1)
        send_insn(32'hAA230041, "ORN X1, X2, X3");

        // MVN X1, X3          : ORN X1, XZR, X3  (Rn=31)
        send_insn(32'hAA2303E1, "MVN X1, X3  (=ORN X1,XZR,X3)");

        // EOR X1, X2, X3      : opc=10 N=0
        send_insn(32'hCA030041, "EOR X1, X2, X3");

        // ANDS X1, X2, X3     : opc=11 N=0
        send_insn(32'hEA030041, "ANDS X1, X2, X3");

        // TST X2, X3          : ANDS XZR, X2, X3 (Rd=31)
        send_insn(32'hEA03005F, "TST X2, X3  (=ANDS XZR,X2,X3)");

        // ── RR-format (3): shift-by-register ────────────────────────
        // LSLV X1, X2, X3     : bits[31:21]=10011010110 bits[15:10]=001000
        send_insn(32'h9AC32041, "LSLV X1, X2, X3");

        // LSRV X1, X2, X3     : bits[15:10]=001001  (user wrote "RSRV")
        send_insn(32'h9AC32441, "LSRV X1, X2, X3");

        // ASRV X1, X2, X3     : bits[15:10]=001010
        send_insn(32'h9AC32841, "ASRV X1, X2, X3");

        // ── RI-format (4): bitfield ──────────────────────────────────
        // UBFM X1, X2, #2, #5 : sf=1 opc=10 N=1 immr=2 imms=5
        send_insn(32'hD3421441, "UBFM X1, X2, #2, #5");

        // SBFM X1, X2, #2, #5 : sf=1 opc=00 N=1 immr=2 imms=5
        send_insn(32'h93421441, "SBFM X1, X2, #2, #5");

        // LSL X1, X2, #3      : UBFM X1,X2,#61,#60 (immr=61 imms=60)
        send_insn(32'hD37DF041, "LSL X1, X2, #3  (=UBFM immr=61 imms=60)");

        // LSR X1, X2, #3      : UBFM X1,X2,#3,#63 (immr=3 imms=63)
        send_insn(32'hD343FC41, "LSR X1, X2, #3  (=UBFM immr=3 imms=63)");

        // ASR X1, X2, #3      : SBFM X1,X2,#3,#63
        send_insn(32'h9343FC41, "ASR X1, X2, #3  (=SBFM immr=3 imms=63)");

        // ── B1-format (5): unconditional branch ──────────────────────
        // B #+16              : bits[31:26]=000101 imm26=4
        send_insn(32'h14000004, "B #+16");

        // BL #+16             : bits[31:26]=100101 imm26=4
        send_insn(32'h94000004, "BL #+16");

        // ── B2-format (6): conditional branch ────────────────────────
        // B.EQ #+16           : bits[31:24]=01010100 imm19=4 cond=0000
        send_insn(32'h54000080, "B.EQ #+16");

        // ── B3-format (7): branch register ───────────────────────────
        // RET X30             : opc=0010 Rn=X30 fixed zeros
        send_insn(32'hD65F03C0, "RET X30");

        // ── S-format (8): system / exception ─────────────────────────
        // NOP                 : hint #0 — bits[31:22]=1101010100 fixed
        send_insn(32'hD503201F, "NOP");

        // ERET                : bits[31:21]=11010110100
        send_insn(32'hD69F03E0, "ERET");

        // MRS X1, NZCV       : L=1 op0=11 op1=011 CRn=0100 CRm=0010 op2=000 Rt=X1
        send_insn(32'hD53B4201, "MRS X1, NZCV");

        // MSR NZCV, X1       : L=0 same sysreg Rt=X1
        send_insn(32'hD51B4201, "MSR NZCV, X1");

        // SVC #0              : bits[31:21]=11010100000 imm16=0 bits[4:0]=00001
        send_insn(32'hD4000001, "SVC #0");

        // ── FP arithmetic: no format defined yet → expect INVALID ────
        // FMOV D1, D2         : bits[28:24]=11110 type=01
        send_insn(32'h1E604041, "FMOV D1, D2   (FP arith - expect INVALID)");

        // FNEG D1, D2
        send_insn(32'h1E614041, "FNEG D1, D2   (FP arith - expect INVALID)");

        // FADD D1, D2, D3     : opc=001010
        send_insn(32'h1E632841, "FADD D1, D2, D3  (FP arith - expect INVALID)");

        // FMUL D1, D2, D3     : opc=000010
        send_insn(32'h1E630841, "FMUL D1, D2, D3  (FP arith - expect INVALID)");

        // FSUB D1, D2, D3     : opc=001110
        send_insn(32'h1E633841, "FSUB D1, D2, D3  (FP arith - expect INVALID)");

        // FCMP D1, D2         : opc=001000 opc2=00000
        send_insn(32'h1E622020, "FCMP D1, D2   (FP arith - expect INVALID)");

        $display("\n=== All decode tests complete ===");
        $finish;
    end

endmodule
