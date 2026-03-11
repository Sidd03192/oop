`timescale 1ns/1ps

module tb_tlb;

    // ── Address layout ────────────────────────────────────────────────────
    // vaddr[47:12] = VPN (36 bits)   vaddr[5:0] = block offset
    // paddr[29:6]  = PPN (24 bits)   paddr[5:0] = block offset
    // ways[i] = {valid(1), PPN(24), VPN(36)} = 61 bits
    // hit when ways[i][60]==1 && ways[i][35:0] == vaddr[47:12]
    // result  = {ways[hit][59:36], vaddr[5:0]}

    // ── Test virtual addresses (distinct VPNs in [47:12]) ─────────────────
    localparam [47:0] VADDR_A     = {36'hA_BCDE_F000, 12'h000};
    localparam [47:0] VADDR_B     = {36'h1_2345_6789, 12'h000};
    localparam [47:0] VADDR_C     = {36'hC_CCCC_CCCC, 12'h000};
    localparam [47:0] VADDR_D     = {36'hD_DDDD_DDDD, 12'h000};
    localparam [47:0] VADDR_E     = {36'hE_EEEE_EEEE, 12'h000};
    localparam [47:0] VADDR_F     = {36'hF_FFFF_FFFF, 12'h000};
    // Same VPN as A, offset = 0x2A
    localparam [47:0] VADDR_A_OFF = {36'hA_BCDE_F000, 6'h00, 6'h2A};

    // ── Test physical addresses ───────────────────────────────────────────
    localparam [29:0] PADDR_A = {24'hAABBCC, 6'h00};
    localparam [29:0] PADDR_B = {24'h112233, 6'h00};
    localparam [29:0] PADDR_C = {24'hC0FFEE, 6'h00};
    localparam [29:0] PADDR_D = {24'hDEADBE, 6'h00};
    localparam [29:0] PADDR_E = {24'hE1E1E1, 6'h00};
    localparam [29:0] PADDR_F = {24'hF2F2F2, 6'h00};

    // ── DUT signals ───────────────────────────────────────────────────────
    reg         clk;
    reg         rst_n;
    reg         is_tlb_fill;
    reg  [47:0] vaddr;
    reg  [29:0] paddr;
    reg         start;

    wire        ready;
    wire        valid;
    wire [29:0] result_paddr;
    wire        panic_tlb_miss;

    // ── DUT ───────────────────────────────────────────────────────────────
    tlb dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .is_tlb_fill    (is_tlb_fill),
        .vaddr          (vaddr),
        .paddr          (paddr),
        .start          (start),
        .ready          (ready),
        .valid          (valid),
        .result_paddr   (result_paddr),
        .panic_tlb_miss (panic_tlb_miss)
    );

    // ── Clock ─────────────────────────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Pass/fail counters ────────────────────────────────────────────────
    integer pass_cnt;
    integer fail_cnt;

    task check_bit;
        input [63:0]  line_num;
        input [255:0] name;
        input         got;
        input         expected;
    begin
        if (got === expected) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%b  expected=%b", name, got, expected);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task check_vec;
        input [63:0]  line_num;
        input [255:0] name;
        input [29:0]  got;
        input [29:0]  expected;
    begin
        if (got === expected) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%h  expected=%h", name, got, expected);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    // ── Idle all inputs ───────────────────────────────────────────────────
    task idle_inputs;
    begin
        is_tlb_fill = 0;
        vaddr       = 0;
        paddr       = 0;
        start       = 0;
    end
    endtask

    // ── Fill one TLB entry ────────────────────────────────────────────────
    // Advances to negedge after operation completes, safe to check
    // internal state (ways, lrumat) immediately after this returns.
    task tlb_fill;
        input [47:0] va;
        input [29:0] pa;
    begin
        @(negedge clk);
        is_tlb_fill = 1;
        vaddr       = va;
        paddr       = pa;
        start       = 1;
        @(negedge clk);
        start       = 0;
        is_tlb_fill = 0;
        vaddr       = 0;
        paddr       = 0;
    end
    endtask

    // ── Perform a TLB lookup ──────────────────────────────────────────────
    // Samples outputs on posedge (while start still high, valid/panic live)
    // then deasserts start. Checks should run immediately after this returns
    // with NO extra @(negedge clk) in the caller.
    task tlb_lookup;
        input [47:0] va;
    begin
        @(negedge clk);
        is_tlb_fill = 0;
        vaddr       = va;
        start       = 1;
        @(posedge clk); #1;   // outputs (valid, panic, result_paddr) are live here
        @(negedge clk);
        start       = 0;
        vaddr       = 0;
    end
    endtask

    // ── Fill all 16 ways with unique entries ──────────────────────────────
    task fill_all_16;
        integer i;
    begin
        for (i = 0; i < 16; i = i + 1) begin
            @(negedge clk);
            is_tlb_fill = 1;
            vaddr       = {32'hDEAD0000 | i[15:0], 16'h0};
            paddr       = {18'h3CAFE0   | i[5:0],   6'h0};
            start       = 1;
            @(negedge clk);
            start       = 0;
            is_tlb_fill = 0;
        end
        @(negedge clk);
    end
    endtask

    // ═════════════════════════════════════════════════════════════════════
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        idle_inputs();
        rst_n = 0;

        // ─────────────────────────────────────────────────────────────────
        // T1: RESET – verify all outputs and internal state cleared
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T1: Reset ===");
        @(negedge clk);
        @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        check_bit(0, "T1 ready==1 after reset",          ready,            1'b1);
        check_bit(0, "T1 valid==0 after reset",          valid,            1'b0);
        check_bit(0, "T1 panic_tlb_miss==0 after reset", panic_tlb_miss,   1'b0);
        check_bit(0, "T1 ways[0]  valid bit clear",      dut.ways[0][60],  1'b0);
        check_bit(0, "T1 ways[15] valid bit clear",      dut.ways[15][60], 1'b0);

        // ─────────────────────────────────────────────────────────────────
        // T2: FILL – fill does not assert valid or panic
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T2: Fill does not assert valid ===");
        tlb_fill(VADDR_A, PADDR_A);
        @(negedge clk);

        check_bit(0, "T2 ready==1 after fill",                      ready,           1'b1);
        check_bit(0, "T2 valid==0 after fill (no translation out)",  valid,           1'b0);
        check_bit(0, "T2 panic==0 after fill",                      panic_tlb_miss,  1'b0);
        check_bit(0, "T2 ways[0] valid bit set",                    dut.ways[0][60], 1'b1);

        // ─────────────────────────────────────────────────────────────────
        // T3: LOOKUP HIT – translate VADDR_A, check PPN and offset
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T3: Lookup hit ===");
        tlb_lookup(VADDR_A);
        // no extra @(negedge clk) — task already sampled on posedge
        check_bit(0, "T3 valid==1 on hit",      valid,          1'b1);
        check_bit(0, "T3 panic==0 on hit",      panic_tlb_miss, 1'b0);
        check_vec(0, "T3 result_paddr correct",
                  result_paddr, {PADDR_A[29:6], VADDR_A[5:0]});

        // ─────────────────────────────────────────────────────────────────
        // T4: LOOKUP MISS – VPN not present, panic asserts
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T4: Lookup miss ===");
        tlb_lookup(VADDR_B);   // VADDR_B never filled
        check_bit(0, "T4 valid==1 (lookup completed)", valid,          1'b1);
        check_bit(0, "T4 panic==1 on miss",            panic_tlb_miss, 1'b1);

        // ─────────────────────────────────────────────────────────────────
        // T5: READY handshake – deasserts while start is high
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T5: Ready deasserts during start ===");
        @(negedge clk);
        is_tlb_fill = 0;
        vaddr       = VADDR_A;
        start       = 1;
        @(posedge clk); #1;
        check_bit(0, "T5 ready==0 while start is asserted", ready, 1'b0);
        @(negedge clk);
        start = 0;
        vaddr = 0;
        @(negedge clk);
        check_bit(0, "T5 ready==1 after start deasserts", ready, 1'b1);

        // ─────────────────────────────────────────────────────────────────
        // T6: OUTPUTS CLEAR ON IDLE
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T6: Outputs clear when idle ===");
        tlb_lookup(VADDR_F);   // unfilled -> sets panic
        check_bit(0, "T6 panic set before idle check", panic_tlb_miss, 1'b1);
        idle_inputs();
        @(negedge clk); @(negedge clk);
        check_bit(0, "T6 valid==0 when idle", valid, 1'b0);
        check_bit(0, "T6 ready==1 when idle", ready, 1'b1);

        // ─────────────────────────────────────────────────────────────────
        // T7: BLOCK OFFSET PASSTHROUGH
        // Same VPN as A, vaddr[5:0]=0x2A -> offset forwarded into paddr
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T7: Block offset passthrough ===");
        tlb_lookup(VADDR_A_OFF);
        check_bit(0, "T7 valid==1",  valid,          1'b1);
        check_bit(0, "T7 no panic",  panic_tlb_miss, 1'b0);
        check_vec(0, "T7 PPN from PADDR_A with offset 0x2A",
                  result_paddr, {PADDR_A[29:6], 6'h2A});

        // ─────────────────────────────────────────────────────────────────
        // T8: MULTIPLE ENTRIES – fill B/C/D, all hit independently,
        //     original entry A survives
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T8: Multiple independent entries ===");
        tlb_fill(VADDR_B, PADDR_B);
        tlb_fill(VADDR_C, PADDR_C);
        tlb_fill(VADDR_D, PADDR_D);
        @(negedge clk);

        tlb_lookup(VADDR_B);
        check_bit(0, "T8 VADDR_B hit",      valid,          1'b1);
        check_bit(0, "T8 VADDR_B no panic", panic_tlb_miss, 1'b0);
        check_vec(0, "T8 VADDR_B paddr",
                  result_paddr, {PADDR_B[29:6], VADDR_B[5:0]});

        tlb_lookup(VADDR_C);
        check_bit(0, "T8 VADDR_C hit",  valid, 1'b1);
        check_vec(0, "T8 VADDR_C paddr",
                  result_paddr, {PADDR_C[29:6], VADDR_C[5:0]});

        tlb_lookup(VADDR_D);
        check_bit(0, "T8 VADDR_D hit",  valid, 1'b1);
        check_vec(0, "T8 VADDR_D paddr",
                  result_paddr, {PADDR_D[29:6], VADDR_D[5:0]});

        tlb_lookup(VADDR_A);
        check_bit(0, "T8 VADDR_A still hits after more fills", valid, 1'b1);
        check_vec(0, "T8 VADDR_A paddr unchanged",
                  result_paddr, {PADDR_A[29:6], VADDR_A[5:0]});

        // ─────────────────────────────────────────────────────────────────
        // T9: CAPACITY – fill all 16 ways, both ends should hit
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T9: Fill all 16 ways (capacity) ===");
        @(negedge clk);
        rst_n = 0;
        @(negedge clk); @(negedge clk);
        rst_n = 1;
        @(negedge clk);
        fill_all_16();

        begin : t9_check
            reg [47:0] va0, va15;
            va0  = {32'hDEAD0000 | 16'h0, 16'h0};
            va15 = {32'hDEAD0000 | 16'hF, 16'h0};

            tlb_lookup(va0);
            check_bit(0, "T9 slot 0 hits after filling 16",  valid,          1'b1);
            check_bit(0, "T9 slot 0 no panic",               panic_tlb_miss, 1'b0);

            tlb_lookup(va15);
            check_bit(0, "T9 slot 15 hits after filling 16", valid,          1'b1);
            check_bit(0, "T9 slot 15 no panic",              panic_tlb_miss, 1'b0);
        end

        // ─────────────────────────────────────────────────────────────────
        // T10: LRU EVICTION – 17th unique fill evicts least-recently-used
        // Reset first for a clean LRU state, fill all 16 without any
        // lookups so slot 0 (filled first, never re-accessed) is the LRU.
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T10: LRU eviction on 17th fill ===");
        @(negedge clk);
        rst_n = 0;
        @(negedge clk); @(negedge clk);
        rst_n = 1;
        @(negedge clk);
        fill_all_16();   // fills slots 0-15, no lookups so slot 0 is LRU

        begin : t10_evict
            reg [47:0] va_lru, va_new;
            reg [29:0] pa_new;
            va_lru = {32'hDEAD0000 | 16'h0, 16'h0};   // slot 0 VPN — LRU victim
            va_new = 48'hBEEF_CAFE_0000;               // brand new VPN
            pa_new = 30'h3FFF_FF00;

            // 17th fill — should evict slot 0 (LRU)
            tlb_fill(va_new, pa_new);
            @(negedge clk);

            // New entry must hit
            tlb_lookup(va_new);
            check_bit(0, "T10 new entry hits after eviction", valid,          1'b1);
            check_bit(0, "T10 new entry no panic",            panic_tlb_miss, 1'b0);

            // Evicted LRU entry must now miss
            tlb_lookup(va_lru);
            check_bit(0, "T10 LRU entry now misses",          panic_tlb_miss, 1'b1);
        end

        // ─────────────────────────────────────────────────────────────────
        // T11: RESET CLEARS ALL ENTRIES
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T11: Reset clears all entries ===");
        @(negedge clk);
        rst_n = 0;
        @(negedge clk); @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        check_bit(0, "T11 ways[0]  invalid after reset", dut.ways[0][60],  1'b0);
        check_bit(0, "T11 ways[7]  invalid after reset", dut.ways[7][60],  1'b0);
        check_bit(0, "T11 ways[15] invalid after reset", dut.ways[15][60], 1'b0);
        check_bit(0, "T11 ready==1 after reset",         ready,            1'b1);
        check_bit(0, "T11 valid==0 after reset",         valid,            1'b0);

        tlb_fill(VADDR_A, PADDR_A);
        @(negedge clk);
        rst_n = 0;
        @(negedge clk); @(negedge clk);
        rst_n = 1;
        @(negedge clk);
        tlb_lookup(VADDR_A);
        check_bit(0, "T11 filled entry misses after reset", panic_tlb_miss, 1'b1);

        // ─────────────────────────────────────────────────────────────────
        // T12: BACK-TO-BACK – fill then lookup with no idle gap
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T12: Fill immediately followed by lookup ===");
        tlb_fill(VADDR_E, PADDR_E);
        tlb_lookup(VADDR_E);
        check_bit(0, "T12 hit immediately after fill", valid,          1'b1);
        check_bit(0, "T12 no panic",                   panic_tlb_miss, 1'b0);
        check_vec(0, "T12 correct paddr",
                  result_paddr, {PADDR_E[29:6], VADDR_E[5:0]});

        // ─────────────────────────────────────────────────────────────────
        $display("\n==========================================");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        $display("==========================================\n");
        $finish;
    end

endmodule