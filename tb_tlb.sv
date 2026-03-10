`timescale 1ns/1ps

module tb_tlb;

    // ── Parameters ────────────────────────────────────────────────────────
    // vaddr[47:12] = VPN (36 bits), vaddr[11:0] = page offset
    // paddr[29:6]  = PPN (24 bits), paddr[5:0]  = block offset

    // ── Test addresses ────────────────────────────────────────────────────
    // Virtual addresses: distinct VPNs in vaddr[47:12]
    localparam [47:0] VADDR_A = {36'hABCDE_F0000, 12'h000};
    localparam [47:0] VADDR_B = {36'h11111_22222, 12'h100};
    localparam [47:0] VADDR_C = {36'hCCCCC_CCCCC, 12'h200};
    localparam [47:0] VADDR_D = {36'hDDDDD_DDDDD, 12'h300};

    // Physical addresses: [29:6] = PPN, [5:0] = block offset
    localparam [29:0] PADDR_A = {24'hAABBCC, 6'h00};
    localparam [29:0] PADDR_B = {24'h112233, 6'h00};
    localparam [29:0] PADDR_C = {24'hC0FFEE, 6'h00};
    localparam [29:0] PADDR_D = {24'hDEADBE, 6'h00};

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

    // ── Fill one TLB entry (one cycle pulse) ──────────────────────────────
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

    // ── Lookup one virtual address (one cycle pulse) ───────────────────────
    task tlb_lookup;
        input [47:0] va;
    begin
        @(negedge clk);
        is_tlb_fill = 0;
        vaddr       = va;
        start       = 1;
        @(negedge clk);
        start       = 0;
        vaddr       = 0;
    end
    endtask

    // ═════════════════════════════════════════════════════════════════════
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        idle_inputs();
        rst_n = 0;

        // ─────────────────────────────────────────────────────────────────
        // T1: RESET
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T1: Reset ===");
        @(negedge clk);
        @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        check_bit(0, "T1 ready==1 after reset",          ready,          1'b1);
        check_bit(0, "T1 valid==0 after reset",          valid,          1'b0);
        check_bit(0, "T1 panic_tlb_miss==0 after reset", panic_tlb_miss, 1'b0);

        // ─────────────────────────────────────────────────────────────────
        // T2: FILL – install entry A into TLB
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T2: TLB fill entry A ===");
        tlb_fill(VADDR_A, PADDR_A);
        @(negedge clk);

        // After fill, ready should return high and valid should be low
        // (fill does not produce a translated result)
        check_bit(0, "T2 ready==1 after fill",  ready, 1'b1);
        check_bit(0, "T2 valid==0 after fill",  valid, 1'b0);
        // Entry should now be present in ways[0]
        check_bit(0, "T2 ways[0] valid bit set", dut.ways[0][60], 1'b1);

        // ─────────────────────────────────────────────────────────────────
        // T3: LOOKUP HIT – translate VADDR_A
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T3: Lookup hit for VADDR_A ===");
        tlb_lookup(VADDR_A);
        @(negedge clk);

        // Expected paddr: PPN from PADDR_A concatenated with block offset
        // from VADDR_A[5:0].  VADDR_A[5:0] = 6'h00, PADDR_A[29:6] = 24'hAABBCC
        check_bit(0, "T3 valid==1 on hit",             valid,          1'b1);
        check_bit(0, "T3 panic_tlb_miss==0 on hit",    panic_tlb_miss, 1'b0);
        check_vec(0, "T3 result_paddr correct on hit",
                  result_paddr,
                  {PADDR_A[29:6], VADDR_A[5:0]});

        // ─────────────────────────────────────────────────────────────────
        // T4: LOOKUP MISS – address not yet installed
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T4: Lookup miss (VADDR_B not filled) ===");
        tlb_lookup(VADDR_B);
        @(negedge clk);

        check_bit(0, "T4 valid==1 (lookup completed)",   valid,          1'b1);
        check_bit(0, "T4 panic_tlb_miss==1 on miss",     panic_tlb_miss, 1'b1);

        // ─────────────────────────────────────────────────────────────────
        // T5: FILL then HIT – install B then translate it
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T5: Fill B then lookup hit ===");
        tlb_fill(VADDR_B, PADDR_B);
        @(negedge clk);
        tlb_lookup(VADDR_B);
        @(negedge clk);

        check_bit(0, "T5 valid==1 after fill+lookup",           valid,          1'b1);
        check_bit(0, "T5 panic_tlb_miss==0",                    panic_tlb_miss, 1'b0);
        check_vec(0, "T5 result_paddr correct for VADDR_B",
                  result_paddr,
                  {PADDR_B[29:6], VADDR_B[5:0]});

        // ─────────────────────────────────────────────────────────────────
        // T6: Block offset passthrough
        // Install VADDR_C then look up with the same VPN but different
        // block-offset bits (vaddr[5:0]) to confirm they pass through.
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T6: Block offset passthrough ===");
        tlb_fill(VADDR_C, PADDR_C);
        @(negedge clk);

        begin : t6_offset
            reg [47:0] va_with_offset;
            va_with_offset = {VADDR_C[47:6], 6'h2A};   // same VPN, offset = 0x2A
            tlb_lookup(va_with_offset);
            @(negedge clk);

            check_bit(0, "T6 valid==1",          valid,          1'b1);
            check_bit(0, "T6 no panic",          panic_tlb_miss, 1'b0);
            check_vec(0, "T6 offset 0x2A passes through",
                      result_paddr,
                      {PADDR_C[29:6], 6'h2A});
        end

        // ─────────────────────────────────────────────────────────────────
        // T7: Idle (no start) – ready high, valid low
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T7: Idle cycle ===");
        idle_inputs();
        @(negedge clk);
        @(negedge clk);

        check_bit(0, "T7 ready==1 when idle", ready, 1'b1);
        check_bit(0, "T7 valid==0 when idle", valid, 1'b0);

        // ─────────────────────────────────────────────────────────────────
        // T8: Multiple fills + independent hits
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T8: Multiple fills and independent hits ===");
        tlb_fill(VADDR_D, PADDR_D);
        @(negedge clk);

        // Hit on A (installed in T2) – should still be present
        tlb_lookup(VADDR_A);
        @(negedge clk);
        check_bit(0, "T8 VADDR_A still hits after more fills", valid,          1'b1);
        check_bit(0, "T8 VADDR_A no panic",                    panic_tlb_miss, 1'b0);
        check_vec(0, "T8 VADDR_A paddr correct",
                  result_paddr,
                  {PADDR_A[29:6], VADDR_A[5:0]});

        // Hit on D (just installed)
        tlb_lookup(VADDR_D);
        @(negedge clk);
        check_bit(0, "T8 VADDR_D hits",    valid,          1'b1);
        check_bit(0, "T8 VADDR_D no panic", panic_tlb_miss, 1'b0);
        check_vec(0, "T8 VADDR_D paddr correct",
                  result_paddr,
                  {PADDR_D[29:6], VADDR_D[5:0]});

        // ─────────────────────────────────────────────────────────────────
        // T9: Reset clears all entries
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T9: Reset clears TLB ===");
        @(negedge clk);
        rst_n = 0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // After reset every ways[i][60] should be 0
        check_bit(0, "T9 ways[0] invalid after reset", dut.ways[0][60], 1'b0);
        check_bit(0, "T9 ways[1] invalid after reset", dut.ways[1][60], 1'b0);
        check_bit(0, "T9 ways[2] invalid after reset", dut.ways[2][60], 1'b0);
        check_bit(0, "T9 ways[3] invalid after reset", dut.ways[3][60], 1'b0);

        // Lookup after reset should miss
        tlb_lookup(VADDR_A);
        @(negedge clk);
        check_bit(0, "T9 panic after reset lookup", panic_tlb_miss, 1'b1);

        // ─────────────────────────────────────────────────────────────────
        $display("\n==========================================");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        $display("==========================================\n");
        $finish;
    end

endmodule