`timescale 1ns/1ps
// Comprehensive L1 cache testbench
// Address layout (corrected from original TB):
//   PA[29:8] = tag (22b)  PA[7:6] = index (2b)  PA[5:0] = offset (6b)
//   VA[7:6]  = index      VA[5:3] = word_offset  VA[2:0] = byte_offset
module tb_l1_cache_v2;

    // ── Parameters ─────────────────────────────────────────────────────────
    localparam PA_WIDTH    = 30;
    localparam VA_WIDTH    = 48;
    localparam BLOCK_SIZE  = 64;
    localparam DATA_WIDTH  = 64;
    localparam NUM_MSHRS   = 2;
    localparam L1_SETS     = 4;
    localparam INDEX_BITS  = 2;
    localparam OFFSET_BITS = 6;
    localparam TAG_SIZE    = 22;
    localparam WORD_BITS   = 3;   // 8 words per block

    localparam [1:0] MS_IDLE       = 2'b00;
    localparam [1:0] MS_UNRESOLVED = 2'b01;
    localparam [1:0] MS_RESOLVED   = 2'b10;

    // ── Test addresses ──────────────────────────────────────────────────────
    // PA = {tag[21:0], index[1:0], offset[5:0]}
    // VA = {... , index[7:6], word_offset[5:3], byte_offset[2:0]}

    // Set 0 (index=2'b00)
    localparam [PA_WIDTH-1:0] PA_S0T1 = {22'h000001, 2'b00, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T2 = {22'h000002, 2'b00, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T3 = {22'h000003, 2'b00, 6'h00};

    // Set 1 (index=2'b01)
    localparam [PA_WIDTH-1:0] PA_S1T1 = {22'h000004, 2'b01, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S1T2 = {22'h000005, 2'b01, 6'h00};

    // Set 2 (index=2'b10)
    localparam [PA_WIDTH-1:0] PA_S2T1 = {22'h000010, 2'b10, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S2T2 = {22'h000020, 2'b10, 6'h00};

    // Set 3 (index=2'b11)
    localparam [PA_WIDTH-1:0] PA_S3T1 = {22'h000011, 2'b11, 6'h00};

    // Virtual addresses — only bits [7:0] matter; upper bits are zero
    // VA[7:6]=index, VA[5:3]=word_offset
    localparam [VA_WIDTH-1:0] VA_S0W0 = 48'h000000000000; // set0, word0
    localparam [VA_WIDTH-1:0] VA_S0W5 = 48'h000000000028; // set0, word5 (5<<3=0x28)
    localparam [VA_WIDTH-1:0] VA_S0W7 = 48'h000000000038; // set0, word7 (7<<3=0x38)
    localparam [VA_WIDTH-1:0] VA_S1W0 = 48'h000000000040; // set1, word0
    localparam [VA_WIDTH-1:0] VA_S1W2 = 48'h000000000050; // set1, word2 (2<<3=0x10, +0x40)
    localparam [VA_WIDTH-1:0] VA_S2W0 = 48'h000000000080; // set2, word0
    localparam [VA_WIDTH-1:0] VA_S3W0 = 48'h0000000000C0; // set3, word0

    // 512-bit test blocks (each word of the block has the same pattern)
    localparam [BLOCK_SIZE*8-1:0] BLOCK_1 = {8{64'hAAAA_AAAA_AAAA_AAAA}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_2 = {8{64'hBBBB_BBBB_BBBB_BBBB}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_3 = {8{64'hCCCC_CCCC_CCCC_CCCC}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_ZERO = 512'h0;

    // ── DUT signals ─────────────────────────────────────────────────────────
    logic                     clk;
    logic                     rst_n;
    logic                     start_tag;
    logic [PA_WIDTH-1:0]      tlb_paddr;
    logic                     start_index;
    logic [VA_WIDTH-1:0]      trace_vaddr;
    logic                     is_write;
    logic [DATA_WIDTH-1:0]    wdata;
    logic                     l2_wb_ack;
    logic                     l2_data_valid;
    logic [PA_WIDTH-1:0]      l2_data_paddr;
    logic [BLOCK_SIZE*8-1:0]  l2_data;

    wire                      l1_stall_out_to_lsq;
    wire                      l2_wb_valid;
    wire [PA_WIDTH-1:0]       l2_wb_paddr;
    wire [BLOCK_SIZE*8-1:0]   l2_wb_data;
    wire                      l2_req_valid;
    wire [PA_WIDTH-1:0]       l2_req_paddr;

    // ── DUT ─────────────────────────────────────────────────────────────────
    l1_cache dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .start_tag          (start_tag),
        .tlb_paddr          (tlb_paddr),
        .start_index        (start_index),
        .trace_vaddr        (trace_vaddr),
        .is_write           (is_write),
        .wdata              (wdata),
        .l1_stall_out_to_lsq(l1_stall_out_to_lsq),
        .l2_wb_valid        (l2_wb_valid),
        .l2_wb_paddr        (l2_wb_paddr),
        .l2_wb_data         (l2_wb_data),
        .l2_wb_ack          (l2_wb_ack),
        .l2_req_valid       (l2_req_valid),
        .l2_req_paddr       (l2_req_paddr),
        .l2_data_valid      (l2_data_valid),
        .l2_data_paddr      (l2_data_paddr),
        .l2_data            (l2_data)
    );

    // ── Clock: 10 ns period ──────────────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Scoreboard ──────────────────────────────────────────────────────────
    integer pass_cnt;
    integer fail_cnt;

    task chk_bit;
        input [255:0]  name;
        input          got;
        input          exp;
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%b  exp=%b  @%0t", name, got, exp, $time);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task chk_val;
        input [255:0]        name;
        input [PA_WIDTH-1:0] got;
        input [PA_WIDTH-1:0] exp;
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%0h  exp=%0h  @%0t", name, got, exp, $time);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task chk_64;
        input [255:0]         name;
        input [63:0]          got;
        input [63:0]          exp;
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%0h  exp=%0h  @%0t", name, got, exp, $time);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task chk_wide;
        input [255:0]           name;
        input [BLOCK_SIZE*8-1:0] got;
        input [BLOCK_SIZE*8-1:0] exp;
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%0h  exp=%0h  @%0t", name, got, exp, $time);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task chk_state;
        input [255:0] name;
        input [1:0]   got;
        input [1:0]   exp;
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%b  exp=%b  @%0t", name, got, exp, $time);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    // ── Helper tasks ─────────────────────────────────────────────────────────

    task idle_inputs;
    begin
        start_index   = 0;
        start_tag     = 0;
        is_write      = 0;
        wdata         = 0;
        trace_vaddr   = 0;
        tlb_paddr     = 0;
        l2_wb_ack     = 0;
        l2_data_valid = 0;
        l2_data_paddr = 0;
        l2_data       = 0;
    end
    endtask

    // Drive one 2-cycle LSQ→TLB request.
    //   Negedge N:   assert start_index (latched on posedge N+1 → state 0→1)
    //   Negedge N+1: assert start_tag + paddr (tag check on posedge N+2 → state 1→0)
    //   Negedge N+2: deassert — back to idle inputs
    task send_req;
        input [VA_WIDTH-1:0]   vaddr;
        input [PA_WIDTH-1:0]   paddr;
        input                  wr;
        input [DATA_WIDTH-1:0] data;
    begin
        @(negedge clk);
        start_index = 1; trace_vaddr = vaddr; is_write = wr; wdata = data;
        @(negedge clk);
        start_index = 0;
        start_tag   = 1; tlb_paddr = paddr;
        @(negedge clk);
        start_tag = 0; tlb_paddr = 0;
    end
    endtask

    // Simulate L2 returning a block: hold valid for one cycle
    task l2_respond;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] block;
    begin
        @(negedge clk);
        l2_data_valid = 1; l2_data_paddr = paddr; l2_data = block;
        @(negedge clk);
        l2_data_valid = 0; l2_data_paddr = 0; l2_data = 0;
    end
    endtask

    // Miss + L2 response + install drain (2 idle cycles after install)
    task full_miss;
        input [VA_WIDTH-1:0]     vaddr;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] block;
    begin
        send_req(vaddr, paddr, 0, 0);
        l2_respond(paddr, block);
        @(negedge clk); @(negedge clk);
    end
    endtask

    // ══════════════════════════════════════════════════════════════════════════
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        idle_inputs();
        rst_n = 0;

        // ─────────────────────────────────────────────────────────────────────
        // T1: RESET — verify all state is cleared
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T1: Reset ===");
        repeat(2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        chk_state("T1 mshr[0]==IDLE",       dut.mshr_state[0], MS_IDLE);
        chk_state("T1 mshr[1]==IDLE",       dut.mshr_state[1], MS_IDLE);
        chk_bit  ("T1 wb_empty==1",         dut.wb_empty,       1'b1);
        chk_bit  ("T1 l2_req_valid==0",     l2_req_valid,       1'b0);
        chk_bit  ("T1 stall==0",            l1_stall_out_to_lsq, 1'b0);
        chk_bit  ("T1 set_valids[0][0]==0", dut.set_valids[0][0], 1'b0);
        chk_bit  ("T1 set_valids[1][0]==0", dut.set_valids[1][0], 1'b0);
        chk_bit  ("T1 set_valids[2][0]==0", dut.set_valids[2][0], 1'b0);
        chk_bit  ("T1 set_valids[3][0]==0", dut.set_valids[3][0], 1'b0);

        // ─────────────────────────────────────────────────────────────────────
        // T2: Load miss — MSHR[0] allocated, l2_req fires, stall correct timing
        //   Cycle by cycle:
        //   negedge 0: assert start_index      (LSQ model)
        //   posedge 1: state 0→1, curr_index latched
        //   negedge 1: check stall==1 (state!=0)
        //   posedge 2: miss detected, MSHR[0] allocated, state→0
        //   negedge 2: check MSHR state, l2_req_valid, stall drops
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T2: Load miss -> MSHR allocation, stall timing ===");
        @(negedge clk);
        start_index = 1; trace_vaddr = VA_S0W0; is_write = 0; wdata = 0;
        @(negedge clk);        // posedge latched start_index → state=1
        start_index = 0;
        chk_bit("T2 stall==1 in state1",   l1_stall_out_to_lsq, 1'b1);
        chk_bit("T2 l2_req_valid==0 yet",  l2_req_valid,        1'b0); // MSHR not yet allocated
        start_tag = 1; tlb_paddr = PA_S0T1;
        @(negedge clk);        // posedge: miss→MSHR[0] UNRESOLVED, state→0
        start_tag = 0; tlb_paddr = 0;
        @(negedge clk);
        chk_state("T2 mshr[0]==UNRESOLVED",         dut.mshr_state[0], MS_UNRESOLVED);
        chk_val  ("T2 mshr_paddr[0]==PA_S0T1",      dut.mshr_paddr[0], PA_S0T1);
        chk_bit  ("T2 mshr_is_write[0]==0",         dut.mshr_is_write[0], 1'b0);
        chk_bit  ("T2 l2_req_valid==1",             l2_req_valid,      1'b1);
        chk_val  ("T2 l2_req_paddr==PA_S0T1",       l2_req_paddr,      PA_S0T1);
        chk_bit  ("T2 stall==0 in state0 (1 MSHR)", l1_stall_out_to_lsq, 1'b0);
        chk_bit  ("T2 wb_valid==0 on miss",         l2_wb_valid,       1'b0);

        // ─────────────────────────────────────────────────────────────────────
        // T3: L2 responds → MSHR goes RESOLVED, l2_req drops immediately
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T3: L2 data return -> RESOLVED ===");
        l2_respond(PA_S0T1, BLOCK_1);
        // After l2_respond: posedge captured l2_data_valid → mshr[0]=RESOLVED
        chk_state("T3 mshr[0]==RESOLVED",  dut.mshr_state[0], MS_RESOLVED);
        chk_bit  ("T3 l2_req_valid==0",    l2_req_valid,      1'b0); // no UNRESOLVED MSHRs left

        // ─────────────────────────────────────────────────────────────────────
        // T4: State-0 install loop installs the resolved block into the cache
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T4: Cache line install ===");
        @(negedge clk); // posedge: install loop fires
        @(negedge clk);
        chk_state("T4 mshr[0]==IDLE",              dut.mshr_state[0], MS_IDLE);
        chk_bit  ("T4 set_valids[0][0]==1",        dut.set_valids[0][0], 1'b1);
        chk_bit  ("T4 set_dirty[0][0]==0",         dut.set_dirty[0][0], 1'b0);  // load miss → clean
        chk_wide ("T4 set_contents[0][0]==BLOCK_1", dut.set_contents[0][0], BLOCK_1);
        chk_bit  ("T4 stall==0 after install",     l1_stall_out_to_lsq, 1'b0);
        chk_bit  ("T4 wb_valid==0 (no eviction)",  l2_wb_valid,       1'b0);

        // ─────────────────────────────────────────────────────────────────────
        // T5: Load hit — same address hits way 0, no MSHR allocated
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T5: Load hit ===");
        send_req(VA_S0W0, PA_S0T1, 0, 0);
        @(negedge clk);
        chk_state("T5 mshr[0] stays IDLE on hit",  dut.mshr_state[0], MS_IDLE);
        chk_bit  ("T5 l2_req_valid==0 on hit",     l2_req_valid,      1'b0);
        chk_bit  ("T5 stall==0 after hit",         l1_stall_out_to_lsq, 1'b0);
        chk_bit  ("T5 set_dirty[0][0] still 0",    dut.set_dirty[0][0], 1'b0); // read → no dirty
        // LRU after hit on way 0: ~hit_way[0] = ~0 = 1 (evict way 1 next)
        chk_bit  ("T5 lru[0]==1 after hit on way0", dut.lru[0], 1'b1);

        // ─────────────────────────────────────────────────────────────────────
        // T6: Store hit — word offset selectivity
        //     Write 64'hDEAD_CAFE at word 5, verify only word 5 changes
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T6: Store hit - word offset correctness ===");
        send_req(VA_S0W5, PA_S0T1, 1, 64'hDEAD_CAFE_1234_5678);
        @(negedge clk);
        chk_bit("T6 set_dirty[0][0]==1",                   dut.set_dirty[0][0], 1'b1);
        chk_64 ("T6 word5 written",                        dut.set_contents[0][0][5*64 +: 64],
                                                            64'hDEAD_CAFE_1234_5678);
        chk_64 ("T6 word0 unchanged",                      dut.set_contents[0][0][0*64 +: 64],
                                                            64'hAAAA_AAAA_AAAA_AAAA);
        chk_64 ("T6 word4 unchanged",                      dut.set_contents[0][0][4*64 +: 64],
                                                            64'hAAAA_AAAA_AAAA_AAAA);
        chk_64 ("T6 word7 unchanged",                      dut.set_contents[0][0][7*64 +: 64],
                                                            64'hAAAA_AAAA_AAAA_AAAA);
        // A second store to a different word in the same line
        send_req(VA_S0W7, PA_S0T1, 1, 64'hBEEF_BEEF_BEEF_BEEF);
        @(negedge clk);
        chk_64 ("T6b word7 written",                       dut.set_contents[0][0][7*64 +: 64],
                                                            64'hBEEF_BEEF_BEEF_BEEF);
        chk_64 ("T6b word5 from prev store still intact",  dut.set_contents[0][0][5*64 +: 64],
                                                            64'hDEAD_CAFE_1234_5678);

        // ─────────────────────────────────────────────────────────────────────
        // T7: Fill second way of set 0 (cold), no writeback expected
        //     Way 0 = PA_S0T1 (dirty). Way 1 is cold → install without evicting.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T7: Fill second way - no spurious writeback ===");
        send_req(VA_S0W0, PA_S0T2, 0, 0);  // miss, different tag same set
        @(negedge clk);
        l2_respond(PA_S0T2, BLOCK_2);
        @(negedge clk); @(negedge clk);
        chk_bit ("T7 set_valids[0][1]==1",         dut.set_valids[0][1], 1'b1);
        chk_wide("T7 way1 holds BLOCK_2",          dut.set_contents[0][1], BLOCK_2);
        chk_bit ("T7 no wb on clean way eviction",  l2_wb_valid, 1'b0);
        chk_bit ("T7 set_dirty[0][1]==0 (load)",   dut.set_dirty[0][1], 1'b0);
        // After installing into way 1: evict_way_l=1, lru[0] = ~1 = 0 (evict way 0 next)
        chk_bit ("T7 lru[0]==0 after way1 install", dut.lru[0], 1'b0);

        // ─────────────────────────────────────────────────────────────────────
        // T8: Third miss into set 0 — both ways full, LRU evicts way 0 (dirty)
        //     Expect: writeback of PA_S0T1, way 0 replaced with PA_S0T3
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T8: LRU eviction + dirty writeback ===");
        send_req(VA_S0W0, PA_S0T3, 0, 0);
        @(negedge clk);
        l2_respond(PA_S0T3, BLOCK_3);
        @(negedge clk); @(negedge clk);

        chk_bit ("T8 l2_wb_valid==1",           l2_wb_valid,  1'b1);
        chk_val ("T8 l2_wb_paddr==PA_S0T1",     l2_wb_paddr,  PA_S0T1);
        // Expected: BLOCK_1 with word5=DEAD_CAFE (T6) and word7=BEEF_BEEF (T6b)
        chk_wide("T8 l2_wb_data is dirty line", l2_wb_data,
                 {64'hBEEF_BEEF_BEEF_BEEF,      // word7 [511:448]
                  64'hAAAA_AAAA_AAAA_AAAA,      // word6 [447:384]
                  64'hDEAD_CAFE_1234_5678,      // word5 [383:320]
                  64'hAAAA_AAAA_AAAA_AAAA,      // word4 [319:256]
                  64'hAAAA_AAAA_AAAA_AAAA,      // word3 [255:192]
                  64'hAAAA_AAAA_AAAA_AAAA,      // word2 [191:128]
                  64'hAAAA_AAAA_AAAA_AAAA,      // word1 [127:64]
                  64'hAAAA_AAAA_AAAA_AAAA});    // word0 [63:0]
        // way 0 now holds PA_S0T3
        chk_wide("T8 way0 now has BLOCK_3",     dut.set_contents[0][0], BLOCK_3);
        // lru after install into way 0: ~0 = 1 (evict way 1 next)
        chk_bit ("T8 lru[0]==1 after way0 install", dut.lru[0], 1'b1);

        // Ack the writeback
        @(negedge clk);
        l2_wb_ack = 1;
        @(negedge clk);
        l2_wb_ack = 0;
        @(negedge clk);
        chk_bit("T8 wb_valid cleared after ack", l2_wb_valid, 1'b0);

        // ─────────────────────────────────────────────────────────────────────
        // T9: LRU update on hit — hit on way 1 flips lru
        //     Set 0: way0=PA_S0T3, way1=PA_S0T2. lru=1 (evict way1 next).
        //     Hit on way1 → lru must flip to 0 (evict way0 next).
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T9: LRU update on hit ===");
        chk_bit("T9 lru[0]==1 before hit",           dut.lru[0], 1'b1);
        send_req(VA_S0W0, PA_S0T2, 0, 0);   // hit on way 1
        @(negedge clk);
        chk_bit("T9 lru[0]==0 after hit on way1",    dut.lru[0], 1'b0);
        // hit on way 0 → lru = ~0 = 1
        send_req(VA_S0W0, PA_S0T3, 0, 0);   // hit on way 0
        @(negedge clk);
        chk_bit("T9 lru[0]==1 after hit on way0",    dut.lru[0], 1'b1);

        // ─────────────────────────────────────────────────────────────────────
        // T10: Store miss — MSHR records is_write=1, installed line marked dirty
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T10: Store miss -> MSHR is_write, dirty install ===");
        // Set 2 is cold
        send_req(VA_S2W0, PA_S2T1, 1, 64'hDEAD_BEEF_DEAD_BEEF);
        @(negedge clk);
        chk_state("T10 mshr[0]==UNRESOLVED",         dut.mshr_state[0], MS_UNRESOLVED);
        chk_bit  ("T10 mshr_is_write[0]==1",         dut.mshr_is_write[0], 1'b1);
        // L2 returns block → install with dirty flag
        l2_respond(PA_S2T1, BLOCK_ZERO);
        @(negedge clk); @(negedge clk);
        chk_bit  ("T10 set_valids[2][0]==1",         dut.set_valids[2][0], 1'b1);
        chk_bit  ("T10 set_dirty[2][0]==1 (store)",  dut.set_dirty[2][0], 1'b1);

        // ─────────────────────────────────────────────────────────────────────
        // T11: Dual MSHR outstanding — arbitration (lowest-index wins)
        //      Miss PA_S1T1 → MSHR[0]. Without L2 responding, miss PA_S1T2 → MSHR[1].
        //      l2_req_paddr must show MSHR[0] first. After MSHR[0] resolved,
        //      l2_req_paddr switches to MSHR[1].
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T11: Dual MSHR arbitration ===");
        // Miss 1 (set 1, both ways cold)
        @(negedge clk);
        start_index = 1; trace_vaddr = VA_S1W0; is_write = 0; wdata = 0;
        @(negedge clk);
        start_index = 0; start_tag = 1; tlb_paddr = PA_S1T1;
        @(negedge clk);
        start_tag = 0; tlb_paddr = 0;
        // Miss 2 immediately (MSHR[0] occupied, MSHR[1] free, no stall)
        @(negedge clk);
        start_index = 1; trace_vaddr = VA_S1W2; is_write = 0; wdata = 0;
        @(negedge clk);
        start_index = 0; start_tag = 1; tlb_paddr = PA_S1T2;
        @(negedge clk);
        start_tag = 0; tlb_paddr = 0;
        @(negedge clk);

        chk_state("T11 mshr[0]==UNRESOLVED",                     dut.mshr_state[0], MS_UNRESOLVED);
        chk_state("T11 mshr[1]==UNRESOLVED",                     dut.mshr_state[1], MS_UNRESOLVED);
        chk_bit  ("T11 l2_req_valid==1",                         l2_req_valid,      1'b1);
        chk_val  ("T11 l2_req_paddr==PA_S1T1 (mshr[0] wins)",   l2_req_paddr,      PA_S1T1);
        chk_bit  ("T11 stall==1 (both MSHRs occupied)",          l1_stall_out_to_lsq, 1'b1);

        // L2 responds to MSHR[0] → MSHR[1] becomes the advertised request
        l2_respond(PA_S1T1, BLOCK_1);
        chk_state("T11 mshr[0]==RESOLVED",                       dut.mshr_state[0], MS_RESOLVED);
        chk_state("T11 mshr[1] still UNRESOLVED",                dut.mshr_state[1], MS_UNRESOLVED);
        chk_val  ("T11 l2_req_paddr switches to PA_S1T2",        l2_req_paddr,      PA_S1T2);
        // RESOLVED != IDLE, so mshr_full is still true until install drains
        chk_bit  ("T11 stall==1 (RESOLVED still occupies slot)", l1_stall_out_to_lsq, 1'b1);

        // L2 responds to MSHR[1], drain
        l2_respond(PA_S1T2, BLOCK_2);
        @(negedge clk); @(negedge clk); @(negedge clk);
        chk_state("T11 mshr[0]==IDLE after drain", dut.mshr_state[0], MS_IDLE);
        chk_state("T11 mshr[1]==IDLE after drain", dut.mshr_state[1], MS_IDLE);
        chk_bit  ("T11 stall==0 after drain",      l1_stall_out_to_lsq, 1'b0);
        chk_bit  ("T11 l2_req_valid==0 after drain", l2_req_valid,      1'b0);

        // ─────────────────────────────────────────────────────────────────────
        // T12: MSHR full stall — third miss blocked, stall auto-clears when
        //      an MSHR frees up (even without a new LSQ request)
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T12: MSHR full stall + auto-clear ===");
        // Miss 1 into set 2 way 1 (way 0 has PA_S2T1 from T10)
        send_req(VA_S2W0, PA_S2T2, 0, 0);
        // Miss 2 into set 3 (cold)
        @(negedge clk);
        start_index = 1; trace_vaddr = VA_S3W0; is_write = 0; wdata = 0;
        @(negedge clk);
        start_index = 0; start_tag = 1; tlb_paddr = PA_S3T1;
        @(negedge clk);
        start_tag = 0; tlb_paddr = 0;
        @(negedge clk);

        chk_bit("T12 stall==1 (both MSHRs full)", l1_stall_out_to_lsq, 1'b1);

        // L2 responds to whichever MSHR has PA_S2T2 or PA_S3T1 (lowest index = 0 = PA_S2T2)
        l2_respond(PA_S2T2, BLOCK_2);
        @(negedge clk); @(negedge clk);
        // One MSHR freed after install, stall must drop
        chk_bit("T12 stall==0 after one MSHR freed", l1_stall_out_to_lsq, 1'b0);

        // Drain the second
        l2_respond(PA_S3T1, BLOCK_1);
        @(negedge clk); @(negedge clk);
        chk_bit("T12 stall==0 fully drained", l1_stall_out_to_lsq, 1'b0);
        chk_bit("T12 l2_req_valid==0",        l2_req_valid,        1'b0);

        // ─────────────────────────────────────────────────────────────────────
        // T13: Stall in state1 — no new start_index accepted while waiting
        //      for TLB. Verified by timing: stall is asserted on the negedge
        //      immediately after start_index is latched (before tag arrives).
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T13: Stall asserted in state1 (TLB wait) ===");
        // Issue a hit request (PA_S1T1 installed in T11) and sample stall mid-flight
        @(negedge clk);
        start_index = 1; trace_vaddr = VA_S1W0; is_write = 0; wdata = 0;
        @(negedge clk);
        // FSM is now in state 1 — stall must be high before tag arrives
        start_index = 0;
        chk_bit("T13 stall==1 during TLB wait (state1)", l1_stall_out_to_lsq, 1'b1);
        chk_bit("T13 l2_req_valid==0 (not a miss yet)",  l2_req_valid,        1'b0);
        // Now provide tag — it's a hit, state returns to 0
        start_tag = 1; tlb_paddr = PA_S1T1;
        @(negedge clk);
        start_tag = 0; tlb_paddr = 0;
        @(negedge clk);
        chk_bit("T13 stall==0 after hit resolves state1", l1_stall_out_to_lsq, 1'b0);

        // ─────────────────────────────────────────────────────────────────────
        // T14: Address decomposition — index and tag are correct
        //      PA_S2T1 has index=2. Verify the cache installed it into set 2
        //      and the stored tag matches the top 22 bits of PA_S2T1.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T14: Address decomposition correctness ===");
        // PA_S2T1 was installed in T10 into set 2, way 0
        chk_bit("T14 set_valids[2][0]==1 (correct set)", dut.set_valids[2][0], 1'b1);
        chk_bit("T14 set_valids[0][0] is NOT PA_S2T1",   dut.set_valids[0][0], 1'b1); // already checked set0 in earlier tests
        // Tag stored should be PA_S2T1[29:8] = top 22 bits
        if (dut.tags[2][0] === PA_S2T1[PA_WIDTH-1 -: TAG_SIZE]) begin
            $display("  PASS  T14 tags[2][0] correct: %0h", dut.tags[2][0]);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  T14 tags[2][0]=%0h  exp=%0h", dut.tags[2][0], PA_S2T1[PA_WIDTH-1 -: TAG_SIZE]);
            fail_cnt = fail_cnt + 1;
        end
        // Writeback address reconstruction: PA_S0T1 wb happened in T8.
        // We already checked l2_wb_paddr==PA_S0T1 there, which validates
        // the {tag, index, 6'b0} reconstruction with 6 offset bits.

        // ─────────────────────────────────────────────────────────────────────
        // T15: Writeback guard — l2_wb_valid stays asserted until ack
        //      Trigger a dirty eviction and hold off l2_wb_ack for several
        //      cycles. wb_valid must remain 1 throughout.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T15: Writeback persistence until ack ===");
        // Set 3 has PA_S3T1 in way 0 (clean, from T12). Way 1 is invalid.
        // First fill way 1 so both ways are occupied.
        full_miss(VA_S3W0, {22'h0000FE, 2'b11, 6'h00}, BLOCK_2); // way 1 of set 3
        // Now make way 0 (PA_S3T1) dirty with a store hit.
        send_req(VA_S3W0, PA_S3T1, 1, 64'hF00D_F00D_F00D_F00D);
        @(negedge clk);
        chk_bit("T15 set_dirty[3][0]==1", dut.set_dirty[3][0], 1'b1);
        // After store hit on way 0: lru[3]=~0=1 (evict way 1 next, which is clean).
        // Hit way 1 to flip LRU so dirty way 0 becomes the victim.
        send_req(VA_S3W0, {22'h0000FE, 2'b11, 6'h00}, 0, 0); // hit on way 1
        @(negedge clk);
        chk_bit("T15 lru[3]==0 (evict way0 next)", dut.lru[3], 1'b0);
        // Miss a 3rd tag into set 3 — both ways valid, LRU evicts dirty way 0.
        @(negedge clk);
        start_index = 1; trace_vaddr = VA_S3W0; is_write = 0; wdata = 0;
        @(negedge clk);
        start_index = 0; start_tag = 1; tlb_paddr = {22'h0000FF, 2'b11, 6'h00};
        @(negedge clk);
        start_tag = 0; tlb_paddr = 0;
        l2_respond({22'h0000FF, 2'b11, 6'h00}, BLOCK_1);
        @(negedge clk); @(negedge clk);
        chk_bit("T15 wb_valid==1 after dirty evict",        l2_wb_valid, 1'b1);
        // Hold off ack for 3 cycles — wb_valid must persist
        @(negedge clk);
        chk_bit("T15 wb_valid still 1 (cycle+1, no ack)",  l2_wb_valid, 1'b1);
        @(negedge clk);
        chk_bit("T15 wb_valid still 1 (cycle+2, no ack)",  l2_wb_valid, 1'b1);
        @(negedge clk);
        chk_bit("T15 wb_valid still 1 (cycle+3, no ack)",  l2_wb_valid, 1'b1);
        // Now ack
        l2_wb_ack = 1;
        @(negedge clk);
        l2_wb_ack = 0;
        @(negedge clk);
        chk_bit("T15 wb_valid==0 after ack",                l2_wb_valid, 1'b0);

        // ─────────────────────────────────────────────────────────────────────
        // T16: l2_data_valid with wrong address — no MSHR should match
        //      Spurious L2 responses must not corrupt MSHR state.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T16: Spurious L2 response (wrong address) ===");
        // All MSHRs currently IDLE. Drive l2_data_valid with a garbage address.
        @(negedge clk);
        l2_data_valid = 1; l2_data_paddr = 30'h3FFFFFFF; l2_data = BLOCK_3;
        @(negedge clk);
        l2_data_valid = 0; l2_data_paddr = 0; l2_data = 0;
        @(negedge clk);
        chk_state("T16 mshr[0] still IDLE after spurious resp", dut.mshr_state[0], MS_IDLE);
        chk_state("T16 mshr[1] still IDLE after spurious resp", dut.mshr_state[1], MS_IDLE);

        // ─────────────────────────────────────────────────────────────────────
        // FRESH RESET for new test suite (T17+)
        // ─────────────────────────────────────────────────────────────────────
        idle_inputs();
        rst_n = 0;
        repeat(2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // ─────────────────────────────────────────────────────────────────────
        // T17: Back-to-back hits — no unnecessary stall between consecutive hits
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T17: Back-to-back hits ===");
        full_miss(VA_S0W0, PA_S0T1, BLOCK_1);  // install set0 way0
        send_req(VA_S0W0, PA_S0T1, 0, 0);      // hit #1
        @(negedge clk);
        chk_bit("T17 stall==0 between hits", l1_stall_out_to_lsq, 1'b0);
        send_req(VA_S0W0, PA_S0T1, 0, 0);      // hit #2 immediately
        @(negedge clk);
        chk_bit  ("T17 stall==0 after 2nd hit",  l1_stall_out_to_lsq, 1'b0);
        chk_state("T17 no MSHR allocated",       dut.mshr_state[0], MS_IDLE);
        chk_state("T17 mshr[1] still IDLE",      dut.mshr_state[1], MS_IDLE);

        // ─────────────────────────────────────────────────────────────────────
        // T18: Store miss → store merge on install
        //      Store miss with specific word data, verify L2 block merged
        //      with store data at the correct word offset after install.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T18: Store miss -> store merge on install ===");
        // Store miss to set 1 (cold), word offset 2 (VA_S1W2)
        send_req(VA_S1W2, PA_S1T1, 1, 64'hCAFE_BABE_CAFE_BABE);
        @(negedge clk);
        chk_state("T18 mshr[0]==UNRESOLVED", dut.mshr_state[0], MS_UNRESOLVED);
        chk_bit  ("T18 mshr_is_write==1",    dut.mshr_is_write[0], 1'b1);
        // L2 returns BLOCK_1 (all 0xAAAA words)
        l2_respond(PA_S1T1, BLOCK_1);
        @(negedge clk); @(negedge clk);
        chk_state("T18 mshr[0]==IDLE",      dut.mshr_state[0], MS_IDLE);
        chk_64   ("T18 word2 has store data", dut.set_contents[1][0][2*64 +: 64],
                                              64'hCAFE_BABE_CAFE_BABE);
        chk_64   ("T18 word0 from L2 block",  dut.set_contents[1][0][0*64 +: 64],
                                              64'hAAAA_AAAA_AAAA_AAAA);
        chk_64   ("T18 word7 from L2 block",  dut.set_contents[1][0][7*64 +: 64],
                                              64'hAAAA_AAAA_AAAA_AAAA);
        chk_bit  ("T18 dirty==1 (store)",     dut.set_dirty[1][0], 1'b1);
        // Load hit same address — should hit, no MSHR
        send_req(VA_S1W2, PA_S1T1, 0, 0);
        @(negedge clk);
        chk_state("T18 hit, no MSHR",        dut.mshr_state[0], MS_IDLE);

        // ─────────────────────────────────────────────────────────────────────
        // T20: Clean eviction — no writeback
        //      Both ways of set 1 filled with clean data. Third miss evicts
        //      clean LRU victim → l2_wb_valid must stay 0.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T20: Clean eviction - no writeback ===");
        // Set 1 way0 = PA_S1T1 (dirty from T18). Install way1 (clean).
        full_miss(VA_S1W0, PA_S1T2, BLOCK_2);  // set1 way1 = PA_S1T2, clean
        // After install into way1: lru[1] = ~1 = 0 (evict way0 next, dirty).
        // Hit way0 to flip LRU so clean way1 becomes victim.
        send_req(VA_S1W0, PA_S1T1, 0, 0);      // hit way0
        @(negedge clk);
        chk_bit("T20 lru[1]==1 (evict way1)", dut.lru[1], 1'b1);
        // Miss new tag → evicts way1 (PA_S1T2, clean) → no writeback
        send_req(VA_S1W0, {22'h000006, 2'b01, 6'h00}, 0, 0);
        @(negedge clk);
        l2_respond({22'h000006, 2'b01, 6'h00}, BLOCK_3);
        @(negedge clk); @(negedge clk);
        chk_bit ("T20 wb_valid==0 (clean evict)", l2_wb_valid,       1'b0);
        chk_wide("T20 way1 replaced with BLOCK_3", dut.set_contents[1][1], BLOCK_3);

        // ─────────────────────────────────────────────────────────────────────
        // T19: WB queue full blocks MSHR install
        //      Fill WB queue to capacity (2), then trigger dirty eviction.
        //      Install must stall until WB has room.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T19: WB queue full blocks MSHR install ===");
        idle_inputs();
        rst_n = 0;
        repeat(2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // Fill set 0 both ways dirty
        full_miss(VA_S0W0, PA_S0T1, BLOCK_1);                                        // way0 clean
        send_req(VA_S0W0, PA_S0T1, 1, 64'hD1D1_D1D1_D1D1_D1D1); @(negedge clk);   // way0 dirty
        full_miss(VA_S0W0, PA_S0T2, BLOCK_2);                                        // way1 clean
        send_req(VA_S0W0, PA_S0T2, 1, 64'hD2D2_D2D2_D2D2_D2D2); @(negedge clk);   // way1 dirty
        // lru[0]=0 after store hit on way1. Evict way0 next.
        // Miss PA_S0T3 → evicts dirty way0 → WB entry 1
        send_req(VA_S0W0, PA_S0T3, 0, 0);
        @(negedge clk);
        l2_respond(PA_S0T3, BLOCK_3);
        @(negedge clk); @(negedge clk);
        chk_bit("T19 wb_valid==1 after 1st evict", l2_wb_valid, 1'b1);

        // set0: way0=PA_S0T3 (clean), way1=PA_S0T2 (dirty). lru=1 (evict way1).
        // Miss PA_S0T1 → evicts dirty way1 → WB entry 2 (full)
        send_req(VA_S0W0, PA_S0T1, 0, 0);
        @(negedge clk);
        l2_respond(PA_S0T1, BLOCK_1);
        @(negedge clk); @(negedge clk);
        chk_bit("T19 wb_full==1 (2 entries)", dut.wb_full, 1'b1);

        // Set up set 2 with dirty way0 (cold set, no eviction needed for install)
        full_miss(VA_S2W0, PA_S2T1, BLOCK_1);                                        // way0, no evict
        send_req(VA_S2W0, PA_S2T1, 1, 64'hE1E1_E1E1_E1E1_E1E1); @(negedge clk);   // way0 dirty
        full_miss(VA_S2W0, PA_S2T2, BLOCK_2);                                        // way1, no evict
        // lru[2]=0 (evict way0 next, which is dirty)

        // Miss new tag in set 2 → dirty eviction, but WB is full → install stalls
        send_req(VA_S2W0, {22'h000030, 2'b10, 6'h00}, 0, 0);
        @(negedge clk);
        l2_respond({22'h000030, 2'b10, 6'h00}, BLOCK_3);
        @(negedge clk); @(negedge clk);
        // MSHR should be RESOLVED but NOT installed (WB full, dirty victim)
        chk_state("T19 mshr RESOLVED (blocked by wb_full)", dut.mshr_state[0], MS_RESOLVED);
        chk_bit  ("T19 wb_full still 1",                     dut.wb_full,       1'b1);
        // Another cycle — still blocked
        @(negedge clk);
        chk_state("T19 mshr still RESOLVED",                 dut.mshr_state[0], MS_RESOLVED);

        // Ack one WB entry → install should proceed
        l2_wb_ack = 1;
        @(negedge clk);
        l2_wb_ack = 0;
        @(negedge clk); @(negedge clk);
        chk_state("T19 mshr IDLE after ack unblocks install", dut.mshr_state[0], MS_IDLE);
        chk_bit  ("T19 set2 way0 replaced",                   dut.set_valids[2][0], 1'b1);
        // The dirty eviction should now be in the WB queue
        chk_bit  ("T19 wb_valid==1 (evicted line queued)",    l2_wb_valid,       1'b1);
        // Drain remaining WB
        l2_wb_ack = 1;
        repeat(3) @(negedge clk);
        l2_wb_ack = 0;
        @(negedge clk);

        // ─────────────────────────────────────────────────────────────────────
        // T21: Simultaneous WB push + pop
        //      Dirty eviction (push) happens on the same posedge as l2_wb_ack
        //      (pop). wb_count should remain stable.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T21: Simultaneous WB push + pop ===");
        idle_inputs();
        rst_n = 0;
        repeat(2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // Fill set 0 both ways dirty
        full_miss(VA_S0W0, PA_S0T1, BLOCK_1);
        send_req(VA_S0W0, PA_S0T1, 1, 64'hAA00_AA00_AA00_AA00); @(negedge clk);
        full_miss(VA_S0W0, PA_S0T2, BLOCK_2);
        send_req(VA_S0W0, PA_S0T2, 1, 64'hBB00_BB00_BB00_BB00); @(negedge clk);
        // lru[0]=0 (evict way0). Miss → evict dirty way0 → WB=1
        send_req(VA_S0W0, PA_S0T3, 0, 0);
        @(negedge clk);
        l2_respond(PA_S0T3, BLOCK_3);
        @(negedge clk); @(negedge clk);
        chk_bit("T21 wb_count==1 before push+pop", (dut.wb_count == 2'd1), 1'b1);

        // set0: way0=PA_S0T3(clean), way1=PA_S0T2(dirty). lru=1 (evict way1).
        // Miss PA_S0T1 → MSHR. L2 respond → RESOLVED.
        // Time the l2_wb_ack to coincide with the install posedge.
        send_req(VA_S0W0, PA_S0T1, 0, 0);
        @(negedge clk);
        // L2 respond: first negedge asserts l2_data_valid
        l2_data_valid = 1; l2_data_paddr = PA_S0T1; l2_data = BLOCK_1;
        @(negedge clk);
        // posedge just happened: MSHR → RESOLVED.
        // Now set ack AND clear l2_data — next posedge will do install + pop
        l2_data_valid = 0; l2_data_paddr = 0; l2_data = 0;
        l2_wb_ack = 1;
        @(negedge clk);
        // posedge: install loop (push dirty way1) + wb_pop (ack). Push+pop same cycle.
        l2_wb_ack = 0;
        @(negedge clk);
        // wb_count should still be 1: one popped, one pushed
        chk_bit("T21 wb_count==1 after push+pop", (dut.wb_count == 2'd1), 1'b1);
        chk_state("T21 mshr IDLE (install succeeded)", dut.mshr_state[0], MS_IDLE);
        // Drain WB
        l2_wb_ack = 1; @(negedge clk); l2_wb_ack = 0; @(negedge clk);

        // ─────────────────────────────────────────────────────────────────────
        // T22: L2 response during state 1 (tag wait)
        //      An outstanding MSHR receives L2 data while L1 is in state 1
        //      processing a different request. The L2 scan runs outside the
        //      case statement, so it should still transition to RESOLVED.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T22: L2 response during state 1 ===");
        idle_inputs();
        rst_n = 0;
        repeat(2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // Miss set 0 → MSHR[0] UNRESOLVED
        send_req(VA_S0W0, PA_S0T1, 0, 0);
        @(negedge clk);
        chk_state("T22 mshr[0]==UNRESOLVED", dut.mshr_state[0], MS_UNRESOLVED);

        // Install set 1 way0 (for a hit target)
        full_miss(VA_S1W0, PA_S1T1, BLOCK_2);

        // Start a new request (hit on set 1) — L1 enters state 1
        @(negedge clk);
        start_index = 1; trace_vaddr = VA_S1W0; is_write = 0; wdata = 0;
        @(negedge clk);
        // L1 now in state 1 (waiting for tag)
        start_index = 0;
        chk_bit("T22 state==1", (dut.state == 3'd1), 1'b1);

        // While in state 1, pulse L2 data for MSHR[0]
        l2_data_valid = 1; l2_data_paddr = PA_S0T1; l2_data = BLOCK_1;
        // Also provide tag for the current request (hit)
        start_tag = 1; tlb_paddr = PA_S1T1;
        @(negedge clk);
        // posedge just happened: state 1→0 (hit), L2 scan matches MSHR[0] → RESOLVED
        // Check NOW before the next posedge runs the install loop
        chk_state("T22 mshr[0]==RESOLVED despite state1", dut.mshr_state[0], MS_RESOLVED);
        chk_bit  ("T22 state back to 0",                   (dut.state == 3'd0), 1'b1);
        start_tag = 0; tlb_paddr = 0;
        l2_data_valid = 0; l2_data_paddr = 0; l2_data = 0;
        // Let install drain
        @(negedge clk); @(negedge clk);
        chk_state("T22 mshr[0]==IDLE after install",       dut.mshr_state[0], MS_IDLE);
        chk_bit  ("T22 set0 way0 installed",               dut.set_valids[0][0], 1'b1);

        // ─────────────────────────────────────────────────────────────────────
        // T23: Duplicate MSHR addresses (no deduplication)
        //      Miss the same address twice → both MSHRs get the same paddr.
        //      L2 responds once → both MSHRs match and become RESOLVED.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T23: Duplicate MSHR addresses ===");
        idle_inputs();
        rst_n = 0;
        repeat(2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // Miss #1 to PA_S0T1
        send_req(VA_S0W0, PA_S0T1, 0, 0);
        @(negedge clk);
        chk_state("T23 mshr[0]==UNRESOLVED", dut.mshr_state[0], MS_UNRESOLVED);
        // Miss #2 to same PA (different VA word offset to distinguish)
        send_req(VA_S0W5, PA_S0T1, 0, 0);
        @(negedge clk);
        chk_state("T23 mshr[1]==UNRESOLVED (dup addr)", dut.mshr_state[1], MS_UNRESOLVED);
        chk_val  ("T23 mshr[0].paddr==PA_S0T1",         dut.mshr_paddr[0], PA_S0T1);
        chk_val  ("T23 mshr[1].paddr==PA_S0T1",         dut.mshr_paddr[1], PA_S0T1);

        // L2 responds once — both MSHRs should match
        l2_respond(PA_S0T1, BLOCK_1);
        chk_state("T23 mshr[0]==RESOLVED", dut.mshr_state[0], MS_RESOLVED);
        chk_state("T23 mshr[1]==RESOLVED", dut.mshr_state[1], MS_RESOLVED);
        // Let both install (one per cycle)
        repeat(4) @(negedge clk);
        chk_state("T23 mshr[0]==IDLE after drain", dut.mshr_state[0], MS_IDLE);
        chk_state("T23 mshr[1]==IDLE after drain", dut.mshr_state[1], MS_IDLE);

        // ─────────────────────────────────────────────────────────────────────
        // T24: Word offset 0 and 7 boundary test
        //      Store at the lowest (word 0) and highest (word 7) positions
        //      of a cache line. Verify both writes land correctly and don't
        //      corrupt each other.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T24: Word offset 0 and 7 boundary ===");
        idle_inputs();
        rst_n = 0;
        repeat(2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // Install clean block into set 0 way 0
        full_miss(VA_S0W0, PA_S0T1, BLOCK_ZERO);
        // Store to word 0 (bits [63:0])
        send_req(VA_S0W0, PA_S0T1, 1, 64'h0000_0000_DEAD_0000);
        @(negedge clk);
        chk_64("T24 word0 written",    dut.set_contents[0][0][0*64 +: 64], 64'h0000_0000_DEAD_0000);
        chk_64("T24 word1 still zero", dut.set_contents[0][0][1*64 +: 64], 64'h0);
        // Store to word 7 (bits [511:448])
        send_req(VA_S0W7, PA_S0T1, 1, 64'hBEEF_0000_0000_BEEF);
        @(negedge clk);
        chk_64("T24 word7 written",    dut.set_contents[0][0][7*64 +: 64], 64'hBEEF_0000_0000_BEEF);
        chk_64("T24 word6 still zero", dut.set_contents[0][0][6*64 +: 64], 64'h0);
        chk_64("T24 word0 preserved",  dut.set_contents[0][0][0*64 +: 64], 64'h0000_0000_DEAD_0000);
        chk_bit("T24 dirty==1",        dut.set_dirty[0][0], 1'b1);

        // ─────────────────────────────────────────────────────────────────────
        // RESULTS
        // ─────────────────────────────────────────────────────────────────────
        $display("\n==========================================");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("  ALL TESTS PASSED");
        else               $display("  *** FAILURES DETECTED ***");
        $display("==========================================\n");
        $finish;
    end

endmodule
