`timescale 1ns/1ps

module tb_tlb_lru;

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

    // ── Counters ──────────────────────────────────────────────────────────
    integer pass_cnt;
    integer fail_cnt;

    // ── Precomputed address tables ─────────────────────────────────────────
    // 20 unique VPNs and PPNs so we can fill beyond the 16-way capacity.
    // Stored as plain regs to avoid Icarus issues with function+bit-select
    // inside task argument lists.
    reg [47:0] VA [0:19];
    reg [29:0] PA [0:19];

    integer gi;
    initial begin
        for (gi = 0; gi < 20; gi = gi + 1) begin
            VA[gi] = {20'hBEEF0, gi[15:0], 12'h000};
            PA[gi] = {14'h3AAA,  gi[9:0],   6'h00};
        end
    end

    // ── Check helpers ─────────────────────────────────────────────────────
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

    task check_is_lru;
        input [63:0]  line_num;
        input [255:0] name;
        input [3:0]   way;
    begin
        if (dut.lrumat[way] === 16'h0000) begin
            $display("  PASS  %s  (way %0d is LRU)", name, way);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  way %0d lrumat=%b  expected all-zeros",
                     name, way, dut.lrumat[way]);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task check_is_mru;
        input [63:0]  line_num;
        input [255:0] name;
        input [3:0]   way;
        // lrumat[way][way] is always 0 (diagonal) so mask it out.
        // All other bits must be 1 to confirm MRU status.
        reg [15:0] mask;
        reg [15:0] expected;
    begin
        mask     = ~(16'h1 << way);
        expected = mask;
        if ((dut.lrumat[way] & mask) === expected) begin
            $display("  PASS  %s  (way %0d is MRU)", name, way);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  way %0d lrumat=%b  expected all-ones except diagonal",
                     name, way, dut.lrumat[way]);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    // ── Stimulus helpers ──────────────────────────────────────────────────
    task idle_inputs;
    begin
        is_tlb_fill = 0;
        vaddr       = 0;
        paddr       = 0;
        start       = 0;
    end
    endtask

    task do_reset;
    begin
        idle_inputs();
        rst_n = 0;
        @(negedge clk); @(negedge clk);
        rst_n = 1;
        @(negedge clk);
    end
    endtask

    // Fill one entry; advance to negedge after op completes.
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

    // Lookup; sample outputs on posedge+#1, then deassert start.
    // Checks must follow immediately with NO extra @(negedge clk).
    task tlb_lookup;
        input [47:0] va;
    begin
        @(negedge clk);
        is_tlb_fill = 0;
        vaddr       = va;
        start       = 1;
        @(posedge clk); #1;
        @(negedge clk);
        start = 0;
        vaddr = 0;
    end
    endtask

    // Fill slots first..last inclusive, no lookups in between.
    task fill_range;
        input integer first;
        input integer last;
        integer i;
    begin
        for (i = first; i <= last; i = i + 1)
            tlb_fill(VA[i], PA[i]);
        @(negedge clk);
    end
    endtask

    // ═════════════════════════════════════════════════════════════════════
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;

        // ─────────────────────────────────────────────────────────────────
        // L1: After reset, lrumat is all-zero
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L1: Reset clears lrumat ===");
        do_reset();

        check_bit(0, "L1 lrumat[0]==0  after reset",  (dut.lrumat[0]  === 16'h0), 1'b1);
        check_bit(0, "L1 lrumat[7]==0  after reset",  (dut.lrumat[7]  === 16'h0), 1'b1);
        check_bit(0, "L1 lrumat[15]==0 after reset",  (dut.lrumat[15] === 16'h0), 1'b1);

        // ─────────────────────────────────────────────────────────────────
        // L2: First fill sets that way as MRU (row all-ones)
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L2: First fill makes way 0 MRU ===");
        do_reset();
        tlb_fill(VA[0], PA[0]);
        @(negedge clk);

        check_is_mru(0, "L2 way 0 is MRU after first fill", 4'd0);

        // ─────────────────────────────────────────────────────────────────
        // L3: Sequential fills 0..3 -> way 0 is LRU, way 3 is MRU
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L3: Sequential fills 0..3, way 0 LRU way 3 MRU ===");
        do_reset();
        fill_range(0, 3);

        // After filling 4 ways, empty way 4 has an all-zero row -> LRU.
        // Way 0 (filled first) has bits 4-15 still set from being
        // accessed first, so it is NOT the LRU in a partial fill.
        check_is_lru(0, "L3 way 4 is LRU after fills 0-3", 4'd4);
        check_is_mru(0, "L3 way 3 is MRU after fills 0-3", 4'd3);

        // ─────────────────────────────────────────────────────────────────
        // L4: Lookup hit promotes way to MRU
        //     Fill 0..3, lookup way 0 -> way 0 MRU, way 1 LRU
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L4: Lookup hit promotes accessed way to MRU ===");
        do_reset();
        fill_range(0, 3);

        begin : l4_block
            reg [29:0] exp_pa;
            tlb_lookup(VA[0]);
            exp_pa = {PA[0][29:6], VA[0][5:0]};
            check_bit(0, "L4 hit on way 0",  valid,          1'b1);
            check_bit(0, "L4 no panic",       panic_tlb_miss, 1'b0);
            check_vec(0, "L4 paddr correct",  result_paddr,   exp_pa);
            @(negedge clk);
            check_is_mru(0, "L4 way 0 promoted to MRU after lookup", 4'd0);
            // After filling 0-3 and re-accessing way 0, the empty way 4
            // still has an all-zero row so it remains the LRU victim.
            check_is_lru(0, "L4 way 4 is LRU (first empty slot)",    4'd4);
        end

        // ─────────────────────────────────────────────────────────────────
        // L5: Fill all 16 ways, way 0 (filled first) is LRU
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L5: Fill all 16 ways, way 0 is LRU ===");
        do_reset();
        fill_range(0, 15);

        check_is_lru(0, "L5 way 0  is LRU after filling all 16", 4'd0);
        check_is_mru(0, "L5 way 15 is MRU after filling all 16", 4'd15);

        // ─────────────────────────────────────────────────────────────────
        // L6: Fill all 16 in reverse order 15..0, way 15 is LRU
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L6: Fill all 16 in reverse order, way 15 is LRU ===");
        do_reset();
        begin : l6_reverse
            integer i;
            for (i = 15; i >= 0; i = i - 1)
                tlb_fill(VA[i], PA[i]);
            @(negedge clk);
        end

        // Ways are always allocated in scan order (0,1,2...) regardless of
        // VPN order. Filling VPNs 15..0 still fills physical ways 0..15 in
        // that order, so way 0 (accessed first) is LRU and way 15 is MRU.
        check_is_lru(0, "L6 way 0  is LRU after reverse fill", 4'd0);
        check_is_mru(0, "L6 way 15 is MRU after reverse fill", 4'd15);

        // ─────────────────────────────────────────────────────────────────
        // L7: 17th fill evicts LRU (way 0), new entry takes its slot,
        //     way 1 becomes the new LRU
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L7: 17th fill evicts way 0 (LRU), way 1 becomes LRU ===");
        do_reset();
        fill_range(0, 15);

        tlb_fill(VA[16], PA[16]);
        @(negedge clk);

        tlb_lookup(VA[16]);
        check_bit(0, "L7 new entry (slot 16) hits", valid,          1'b1);
        check_bit(0, "L7 new entry no panic",        panic_tlb_miss, 1'b0);

        tlb_lookup(VA[0]);
        check_bit(0, "L7 evicted entry (slot 0) misses", panic_tlb_miss, 1'b1);

        @(negedge clk);
        check_is_lru(0, "L7 way 1 is new LRU after eviction", 4'd1);

        // ─────────────────────────────────────────────────────────────────
        // L8: Re-access way 0 after full fill shifts LRU to way 1
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L8: Re-access way 0 shifts LRU to way 1 ===");
        do_reset();
        fill_range(0, 15);
        check_is_lru(0, "L8 way 0 is LRU before re-access", 4'd0);

        tlb_lookup(VA[0]);
        check_bit(0, "L8 way 0 hit",  valid,          1'b1);
        check_bit(0, "L8 no panic",   panic_tlb_miss, 1'b0);
        @(negedge clk);
        check_is_lru(0, "L8 way 1 is LRU after re-accessing way 0", 4'd1);
        check_is_mru(0, "L8 way 0 is MRU after re-access",           4'd0);

        // ─────────────────────────────────────────────────────────────────
        // L9: Two re-accesses — fill 0..15, lookup 0 then 1
        //     LRU advances to way 2
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L9: Two re-accesses shift LRU to way 2 ===");
        do_reset();
        fill_range(0, 15);

        tlb_lookup(VA[0]);
        check_bit(0, "L9 way 0 hit", valid, 1'b1);
        tlb_lookup(VA[1]);
        check_bit(0, "L9 way 1 hit", valid, 1'b1);
        @(negedge clk);
        check_is_lru(0, "L9 way 2 is LRU after re-accessing ways 0 and 1", 4'd2);

        // ─────────────────────────────────────────────────────────────────
        // L10: Evict chain — three consecutive evictions
        //      Fill 0..15, evict with slots 16, 17, 18.
        //      Victims in order: way 0, way 1, way 2.
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L10: Evict chain, three consecutive evictions ===");
        do_reset();
        fill_range(0, 15);

        // Eviction 1: victim = way 0
        tlb_fill(VA[16], PA[16]);
        @(negedge clk);
        tlb_lookup(VA[0]);
        check_bit(0, "L10 eviction 1: slot 0 misses",  panic_tlb_miss, 1'b1);
        tlb_lookup(VA[16]);
        check_bit(0, "L10 eviction 1: slot 16 hits",   valid,          1'b1);
        @(negedge clk);
        check_is_lru(0, "L10 way 1 is LRU after first eviction", 4'd1);

        // Eviction 2: victim = way 1
        tlb_fill(VA[17], PA[17]);
        @(negedge clk);
        tlb_lookup(VA[1]);
        check_bit(0, "L10 eviction 2: slot 1 misses",  panic_tlb_miss, 1'b1);
        tlb_lookup(VA[17]);
        check_bit(0, "L10 eviction 2: slot 17 hits",   valid,          1'b1);
        @(negedge clk);
        check_is_lru(0, "L10 way 2 is LRU after second eviction", 4'd2);

        // Eviction 3: victim = way 2
        tlb_fill(VA[18], PA[18]);
        @(negedge clk);
        tlb_lookup(VA[2]);
        check_bit(0, "L10 eviction 3: slot 2 misses",  panic_tlb_miss, 1'b1);
        tlb_lookup(VA[18]);
        check_bit(0, "L10 eviction 3: slot 18 hits",   valid,          1'b1);
        @(negedge clk);
        check_is_lru(0, "L10 way 3 is LRU after third eviction", 4'd3);

        // ─────────────────────────────────────────────────────────────────
        // L11: Non-evicted entries survive eviction unchanged
        //      Fill 0..15, evict way 0 (fill slot 16).
        //      Ways 1..15 all hit with correct paddrs.
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L11: Non-evicted entries survive eviction ===");
        do_reset();
        fill_range(0, 15);
        tlb_fill(VA[16], PA[16]);
        @(negedge clk);

        begin : l11_survivors
            integer i;
            reg [29:0] exp_pa;
            for (i = 1; i <= 15; i = i + 1) begin
                tlb_lookup(VA[i]);
                exp_pa = {PA[i][29:6], VA[i][5:0]};
                check_bit(i, "L11 survivor hit",          valid,          1'b1);
                check_bit(i, "L11 survivor no panic",      panic_tlb_miss, 1'b0);
                check_vec(i, "L11 survivor paddr correct", result_paddr,   exp_pa);
            end
        end

        // ─────────────────────────────────────────────────────────────────
        // L12: Fill into full TLB makes the reused slot MRU
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L12: Fill into full TLB promotes new entry to MRU ===");
        do_reset();
        fill_range(0, 15);
        tlb_fill(VA[16], PA[16]);
        @(negedge clk);
        // Way 0 was evicted and reused for slot 16, should now be MRU
        check_is_mru(0, "L12 reused way 0 is MRU after 17th fill", 4'd0);

        // ─────────────────────────────────────────────────────────────────
        // L13: Miss lookup does NOT update lrumat
        //      Fill 0..3, snapshot lrumat, do a miss, verify unchanged.
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L13: Miss lookup does not update lrumat ===");
        do_reset();
        fill_range(0, 3);

        begin : l13_miss
            reg [15:0] snap0, snap1, snap2, snap3;
            @(negedge clk);
            snap0 = dut.lrumat[0];
            snap1 = dut.lrumat[1];
            snap2 = dut.lrumat[2];
            snap3 = dut.lrumat[3];

            tlb_lookup(VA[15]);   // slot 15 not filled -> miss
            check_bit(0, "L13 panic on miss", panic_tlb_miss, 1'b1);
            @(negedge clk);

            check_bit(0, "L13 lrumat[0] unchanged after miss",
                      (dut.lrumat[0] === snap0), 1'b1);
            check_bit(0, "L13 lrumat[1] unchanged after miss",
                      (dut.lrumat[1] === snap1), 1'b1);
            check_bit(0, "L13 lrumat[2] unchanged after miss",
                      (dut.lrumat[2] === snap2), 1'b1);
            check_bit(0, "L13 lrumat[3] unchanged after miss",
                      (dut.lrumat[3] === snap3), 1'b1);
        end

        // ─────────────────────────────────────────────────────────────────
        // L14: Reset after LRU activity clears entire matrix
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== L14: Reset after LRU activity clears matrix ===");
        fill_range(0, 15);
        tlb_fill(VA[16], PA[16]);
        @(negedge clk);
        do_reset();

        begin : l14_reset
            integer i;
            for (i = 0; i < 16; i = i + 1)
                check_bit(i, "L14 lrumat row cleared after reset",
                          (dut.lrumat[i] === 16'h0), 1'b1);
        end

        // ─────────────────────────────────────────────────────────────────
        $display("\n==========================================");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        $display("==========================================\n");
        $finish;
    end

endmodule