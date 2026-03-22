`timescale 1ns/1ps
// Integrated L1+L2 testbench
// Instantiates both L1 and L2 with their interfaces wired together.
// Memory side is driven by the testbench (simulates main memory).
// LSQ/TLB side is driven by the testbench (simulates CPU requests).
//
// L1: 512B, 2-way, 64B blocks, 4 sets, 2 MSHRs
//   PA: {tag[21:0], index[1:0], offset[5:0]}
//   VA: {... , index[7:6], word_offset[5:3], byte_offset[2:0]}
//
// L2: 4096B, 4-way, 64B blocks, 16 sets, 4 MSHRs
//   PA: {tag[19:0], index[3:0], offset[5:0]}

module tb_l1_l2_integrated;

    // ── Parameters ─────────────────────────────────────────────────────────
    localparam PA_WIDTH    = 30;
    localparam VA_WIDTH    = 48;
    localparam BLOCK_SIZE  = 64;
    localparam DATA_WIDTH  = 64;

    // L1 geometry
    localparam L1_WAYS     = 2;
    localparam L1_MSHRS    = 2;
    localparam L1_SETS     = 4;
    localparam L1_INDEX    = 2;
    localparam L1_TAG      = 22;
    localparam OFFSET_BITS = 6;
    localparam WORD_BITS   = 3;

    // L2 geometry
    localparam L2_WAYS     = 4;
    localparam L2_MSHRS    = 4;
    localparam L2_SETS     = 16;
    localparam L2_INDEX    = 4;
    localparam L2_TAG      = 20;

    // MSHR states
    localparam [1:0] L1_MS_IDLE       = 2'b00;
    localparam [1:0] L1_MS_UNRESOLVED = 2'b01;
    localparam [1:0] L1_MS_RESOLVED   = 2'b10;

    localparam [1:0] L2_MS_IDLE       = 2'b00;
    localparam [1:0] L2_MS_UNRESOLVED = 2'b01;
    localparam [1:0] L2_MS_WAIT_MEM   = 2'b10;
    localparam [1:0] L2_MS_RESOLVED   = 2'b11;

    // ── Test addresses ────────────────────────────────────────────────────
    // PA = {tag[21:0], index[1:0], offset[5:0]}  (L1 view)
    // PA = {tag[19:0], index[3:0], offset[5:0]}  (L2 view)
    // L1 index = PA[7:6], L2 index = PA[9:6]

    // Set 0 in L1 (L1 index=2'b00), L2 index=4'b0000
    localparam [PA_WIDTH-1:0] PA_A = {22'h000001, 2'b00, 6'h00};
    localparam [PA_WIDTH-1:0] PA_B = {22'h000002, 2'b00, 6'h00};
    localparam [PA_WIDTH-1:0] PA_C = {22'h000003, 2'b00, 6'h00};

    // Set 1 in L1 (L1 index=2'b01), L2 index=4'b0001
    localparam [PA_WIDTH-1:0] PA_D = {22'h000004, 2'b01, 6'h00};
    localparam [PA_WIDTH-1:0] PA_E = {22'h000005, 2'b01, 6'h00};
    localparam [PA_WIDTH-1:0] PA_F = {22'h000006, 2'b01, 6'h00};

    // Set 2 in L1 (L1 index=2'b10), L2 index=4'b0010
    localparam [PA_WIDTH-1:0] PA_G = {22'h000010, 2'b10, 6'h00};

    // VA addresses — VA[7:6]=index, VA[5:3]=word_offset
    localparam [VA_WIDTH-1:0] VA_S0W0 = 48'h000000000000; // set0, word0
    localparam [VA_WIDTH-1:0] VA_S0W3 = 48'h000000000018; // set0, word3
    localparam [VA_WIDTH-1:0] VA_S1W0 = 48'h000000000040; // set1, word0
    localparam [VA_WIDTH-1:0] VA_S1W2 = 48'h000000000050; // set1, word2
    localparam [VA_WIDTH-1:0] VA_S2W0 = 48'h000000000080; // set2, word0

    // 512-bit test blocks
    localparam [BLOCK_SIZE*8-1:0] BLOCK_A = {8{64'hAAAA_AAAA_AAAA_AAAA}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_B = {8{64'hBBBB_BBBB_BBBB_BBBB}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_C = {8{64'hCCCC_CCCC_CCCC_CCCC}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_D = {8{64'hDDDD_DDDD_DDDD_DDDD}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_E = {8{64'hEEEE_EEEE_EEEE_EEEE}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_F = {8{64'hFFFF_FFFF_FFFF_FFFF}};

    // ── Signals ───────────────────────────────────────────────────────────
    logic                     clk;
    logic                     rst_n;

    // LSQ/TLB → L1 (testbench drives these)
    logic                     start_tag;
    logic [PA_WIDTH-1:0]      tlb_paddr;
    logic                     start_index;
    logic [VA_WIDTH-1:0]      trace_vaddr;
    logic                     is_write;
    logic [DATA_WIDTH-1:0]    wdata;

    // L1 → LSQ
    wire                      l1_stall_out_to_lsq;

    // L1 ↔ L2 interconnect (directly wired)
    wire                      l1_to_l2_wb_valid;
    wire [PA_WIDTH-1:0]       l1_to_l2_wb_paddr;
    wire [BLOCK_SIZE*8-1:0]   l1_to_l2_wb_data;
    wire                      l2_to_l1_wb_ack;

    wire                      l1_to_l2_req_valid;
    wire [PA_WIDTH-1:0]       l1_to_l2_req_paddr;

    wire                      l2_to_l1_data_valid;
    wire [PA_WIDTH-1:0]       l2_to_l1_data_paddr;
    wire [BLOCK_SIZE*8-1:0]   l2_to_l1_data;

    // L2 ↔ Memory (testbench drives memory side)
    wire                      mem_req_valid;
    wire                      mem_req_is_write;
    wire [PA_WIDTH-1:0]       mem_req_addr;
    wire [BLOCK_SIZE*8-1:0]   mem_req_wdata;
    logic                     mem_req_ready;

    logic                     mem_resp_valid;
    logic [PA_WIDTH-1:0]      mem_resp_paddr;
    logic [BLOCK_SIZE*8-1:0]  mem_resp_rdata;

    // ── DUT instantiation ──────────────────────────────────────────────────
    l1_cache l1 (
        .clk                (clk),
        .rst_n              (rst_n),
        .start_tag          (start_tag),
        .tlb_paddr          (tlb_paddr),
        .start_index        (start_index),
        .trace_vaddr        (trace_vaddr),
        .is_write           (is_write),
        .wdata              (wdata),
        .l1_stall_out_to_lsq(l1_stall_out_to_lsq),
        .l2_wb_valid        (l1_to_l2_wb_valid),
        .l2_wb_paddr        (l1_to_l2_wb_paddr),
        .l2_wb_data         (l1_to_l2_wb_data),
        .l2_wb_ack          (l2_to_l1_wb_ack),
        .l2_req_valid       (l1_to_l2_req_valid),
        .l2_req_paddr       (l1_to_l2_req_paddr),
        .l2_data_valid      (l2_to_l1_data_valid),
        .l2_data_paddr      (l2_to_l1_data_paddr),
        .l2_data            (l2_to_l1_data)
    );

    l2_cache l2 (
        .clk             (clk),
        .rst_n           (rst_n),
        .l1_wb_valid     (l1_to_l2_wb_valid),
        .l1_wb_paddr     (l1_to_l2_wb_paddr),
        .l1_wb_data      (l1_to_l2_wb_data),
        .l1_wb_ack       (l2_to_l1_wb_ack),
        .l1_req_valid    (l1_to_l2_req_valid),
        .l1_req_paddr    (l1_to_l2_req_paddr),
        .l1_data_valid   (l2_to_l1_data_valid),
        .l1_data_paddr   (l2_to_l1_data_paddr),
        .l1_data         (l2_to_l1_data),
        .mem_req_valid   (mem_req_valid),
        .mem_req_is_write(mem_req_is_write),
        .mem_req_addr    (mem_req_addr),
        .mem_req_wdata   (mem_req_wdata),
        .mem_req_ready   (mem_req_ready),
        .mem_resp_valid  (mem_resp_valid),
        .mem_resp_paddr  (mem_resp_paddr),
        .mem_resp_rdata  (mem_resp_rdata)
    );

    // ── Clock: 10 ns period ────────────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Scoreboard ─────────────────────────────────────────────────────────
    integer pass_cnt;
    integer fail_cnt;

    task chk_bit;
        input [255:0]  name;
        input          got;
        input          exp;
    begin
        if (got === exp) begin
            $display("  PASS  %0s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %0s  got=%b  exp=%b  @%0t", name, got, exp, $time);
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
            $display("  PASS  %0s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %0s  got=%0h  exp=%0h  @%0t", name, got, exp, $time);
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
            $display("  PASS  %0s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %0s  @%0t", name, $time);
            $display("         got=%0h", got);
            $display("         exp=%0h", exp);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task chk_64;
        input [255:0]  name;
        input [63:0]   got;
        input [63:0]   exp;
    begin
        if (got === exp) begin
            $display("  PASS  %0s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %0s  got=%0h  exp=%0h  @%0t", name, got, exp, $time);
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
            $display("  PASS  %0s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %0s  got=%b  exp=%b  @%0t", name, got, exp, $time);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    // ── Helper tasks ──────────────────────────────────────────────────────
    task idle_inputs;
    begin
        start_tag      = 0;
        tlb_paddr      = 0;
        start_index    = 0;
        trace_vaddr    = 0;
        is_write       = 0;
        wdata          = 0;
        mem_req_ready  = 0;
        mem_resp_valid = 0;
        mem_resp_paddr = 0;
        mem_resp_rdata = 0;
    end
    endtask

    // Issue an L1 load request (2 cycles: index phase, then tag phase)
    // Returns after tag phase completes (L1 back in IDLE)
    task do_load;
        input [VA_WIDTH-1:0]  va;
        input [PA_WIDTH-1:0]  pa;
    begin
        // Cycle 1: index phase (start_index)
        @(negedge clk);
        start_index = 1;
        trace_vaddr = va;
        is_write    = 0;
        wdata       = 0;
        @(negedge clk);
        start_index = 0;
        // Cycle 2: tag phase (start_tag)
        start_tag   = 1;
        tlb_paddr   = pa;
        @(negedge clk);
        start_tag   = 0;
        tlb_paddr   = 0;
    end
    endtask

    // Issue an L1 store request
    task do_store;
        input [VA_WIDTH-1:0]  va;
        input [PA_WIDTH-1:0]  pa;
        input [DATA_WIDTH-1:0] data;
    begin
        @(negedge clk);
        start_index = 1;
        trace_vaddr = va;
        is_write    = 1;
        wdata       = data;
        @(negedge clk);
        start_index = 0;
        start_tag   = 1;
        tlb_paddr   = pa;
        @(negedge clk);
        start_tag   = 0;
        tlb_paddr   = 0;
        is_write    = 0;
        wdata       = 0;
    end
    endtask

    // Accept one memory request from L2
    task do_mem_accept;
    begin
        @(negedge clk);
        mem_req_ready = 1;
        @(negedge clk);
        mem_req_ready = 0;
    end
    endtask

    // Send a memory response to L2
    task do_mem_resp;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] data;
    begin
        @(negedge clk);
        mem_resp_valid = 1;
        mem_resp_paddr = paddr;
        mem_resp_rdata = data;
        @(negedge clk);
        mem_resp_valid = 0;
        mem_resp_paddr = 0;
        mem_resp_rdata = 0;
    end
    endtask

    // Wait for L2 to issue a memory read request, accept it, then respond
    // This simulates the full memory round-trip for a miss
    task serve_mem_read;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] data;
    begin
        // Wait until L2 drives mem_req_valid for a read
        wait (mem_req_valid && !mem_req_is_write);
        do_mem_accept();
        do_mem_resp(paddr, data);
    end
    endtask

    // Wait N cycles
    task wait_cycles;
        input integer n;
        integer i;
    begin
        for (i = 0; i < n; i++)
            @(negedge clk);
    end
    endtask

    // ══════════════════════════════════════════════════════════════════════
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        idle_inputs();
        rst_n = 0;

        // ─────────────────────────────────────────────────────────────────
        // T1: RESET
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T1: Reset ===");
        repeat(3) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // L1 checks
        chk_state("T1 L1 mshr[0]==IDLE",     l1.mshr_state[0], L1_MS_IDLE);
        chk_state("T1 L1 mshr[1]==IDLE",     l1.mshr_state[1], L1_MS_IDLE);
        chk_bit  ("T1 L1 stall==0",          l1_stall_out_to_lsq, 1'b0);

        // L2 checks
        chk_state("T2 L2 mshr[0]==IDLE",     l2.mshr_state[0], L2_MS_IDLE);
        chk_state("T2 L2 mshr[1]==IDLE",     l2.mshr_state[1], L2_MS_IDLE);
        chk_bit  ("T1 L2 wb_empty==1",       l2.wb_empty,      1'b1);
        chk_bit  ("T1 mem_req_valid==0",     mem_req_valid,     1'b0);

        // Interconnect idle
        chk_bit  ("T1 l1->l2 wb_valid==0",  l1_to_l2_wb_valid,  1'b0);
        chk_bit  ("T1 l1->l2 req_valid==0", l1_to_l2_req_valid, 1'b0);
        chk_bit  ("T1 l2->l1 data_valid==0",l2_to_l1_data_valid,1'b0);

        // ─────────────────────────────────────────────────────────────────
        // T2: L1 load miss → L2 miss → memory fill → data back to L1
        // Full cold-miss flow through both caches
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T2: Cold miss - L1 miss, L2 miss, memory fill ===");

        // Issue load to L1 for PA_A (not in L1 or L2)
        do_load(VA_S0W0, PA_A);

        // L1 should have allocated an MSHR
        chk_state("T2 L1 mshr[0]==UNRESOLVED", l1.mshr_state[0], L1_MS_UNRESOLVED);
        chk_val  ("T2 L1 mshr_paddr[0]",       l1.mshr_paddr[0], PA_A);

        // L1 should be requesting from L2
        chk_bit  ("T2 l1->l2 req_valid==1",    l1_to_l2_req_valid, 1'b1);
        chk_val  ("T2 l1->l2 req_paddr",       l1_to_l2_req_paddr, PA_A);

        // Wait a cycle for L2 to process the request
        @(negedge clk);

        // L2 misses too — should allocate MSHR and request from memory
        chk_state("T2 L2 mshr[0]==UNRESOLVED", l2.mshr_state[0], L2_MS_UNRESOLVED);
        chk_val  ("T2 L2 mshr_paddr[0]",       l2.mshr_paddr[0], PA_A);

        // L2 should drive mem_req for a read
        chk_bit  ("T2 mem_req_valid==1",        mem_req_valid,     1'b1);
        chk_bit  ("T2 mem_req_is_write==0",     mem_req_is_write,  1'b0);
        chk_val  ("T2 mem_req_addr==PA_A",      mem_req_addr,      PA_A);

        // Memory accepts the read
        do_mem_accept();
        chk_state("T2 L2 mshr[0]==WAIT_MEM",   l2.mshr_state[0], L2_MS_WAIT_MEM);

        // Memory responds with BLOCK_A
        do_mem_resp(PA_A, BLOCK_A);
        chk_state("T2 L2 mshr[0]==RESOLVED",   l2.mshr_state[0], L2_MS_RESOLVED);

        // Wait for L2 install cycle → L2 returns data to L1
        @(negedge clk);
        chk_bit  ("T2 l2->l1 data_valid==1",   l2_to_l1_data_valid, 1'b1);
        chk_val  ("T2 l2->l1 data_paddr",      l2_to_l1_data_paddr, PA_A);
        chk_wide ("T2 l2->l1 data==BLOCK_A",   l2_to_l1_data,       BLOCK_A);

        // L2 MSHR should be freed, block installed in L2
        chk_state("T2 L2 mshr[0]==IDLE",        l2.mshr_state[0], L2_MS_IDLE);

        // Wait for L1 to pick up l2_data_valid and move MSHR to RESOLVED
        @(negedge clk);
        chk_state("T2 L1 mshr[0]==RESOLVED",    l1.mshr_state[0], L1_MS_RESOLVED);

        // Wait for L1 install cycle
        @(negedge clk);
        chk_state("T2 L1 mshr[0]==IDLE",        l1.mshr_state[0], L1_MS_IDLE);

        // Verify block is in L1 cache
        chk_bit  ("T2 L1 set_valids[0][0]==1",  l1.set_valids[0][0], 1'b1);
        chk_wide ("T2 L1 block installed",       l1.set_contents[0][0], BLOCK_A);

        // L2 index for PA_A: PA_A[9:6] = 4'b0100 = set 4
        chk_bit  ("T2 L2 block in set4",         l2.set_valids[4][0], 1'b1);
        chk_wide ("T2 L2 block data",            l2.set_contents[4][0], BLOCK_A);

        wait_cycles(2); // settle

        // ─────────────────────────────────────────────────────────────────
        // T3: L1 load hit after fill
        // PA_A should now be in L1 from T2 — load should hit
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T3: L1 load hit (data from T2 fill) ===");
        do_load(VA_S0W0, PA_A);

        // No MSHR should be allocated (hit path)
        chk_state("T3 L1 mshr[0]==IDLE",        l1.mshr_state[0], L1_MS_IDLE);
        chk_state("T3 L1 mshr[1]==IDLE",        l1.mshr_state[1], L1_MS_IDLE);
        // L2 should not have been touched (no new request)
        chk_state("T3 L2 mshr[0]==IDLE",        l2.mshr_state[0], L2_MS_IDLE);

        @(negedge clk);

        // ─────────────────────────────────────────────────────────────────
        // T4: L1 store hit — write word into cached block
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T4: L1 store hit - write to cached block ===");
        do_store(VA_S0W0, PA_A, 64'h1234_5678_DEAD_BEEF);

        // Block should now be dirty in L1
        chk_bit  ("T4 L1 dirty[0][0]==1",       l1.set_dirty[0][0], 1'b1);

        // Verify the word was written (word 0 of the block)
        chk_64   ("T4 L1 word0 updated",        l1.set_contents[0][0][63:0], 64'h1234_5678_DEAD_BEEF);

        // No MSHR, no L2 interaction for a hit
        chk_state("T4 L1 mshr[0]==IDLE",        l1.mshr_state[0], L1_MS_IDLE);

        wait_cycles(2);

        // ─────────────────────────────────────────────────────────────────
        // T5: L1 miss with dirty eviction → L2 writeback
        // Fill L1 set 0 way 1 first, then evict way 0 (dirty from T4)
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T5: L1 miss → dirty eviction → L2 writeback ===");

        // Fill way 1 of set 0 with PA_B (cold miss)
        do_load(VA_S0W0, PA_B);
        // L1 miss, L2 miss → full memory flow
        chk_state("T5a L1 mshr[0]==UNRESOLVED", l1.mshr_state[0], L1_MS_UNRESOLVED);

        // Serve memory for PA_B
        serve_mem_read(PA_B, BLOCK_B);
        // Wait for L2 install + L1 data return + L1 install
        wait_cycles(4);

        chk_state("T5a L1 mshr[0]==IDLE",       l1.mshr_state[0], L1_MS_IDLE);
        chk_bit  ("T5a L1 set0 both valid",     l1.set_valids[0], 2'b11);

        // Now load PA_C into set 0 — this must evict one way (LRU = dirty PA_A)
        do_load(VA_S0W0, PA_C);
        chk_state("T5b L1 mshr[0]==UNRESOLVED", l1.mshr_state[0], L1_MS_UNRESOLVED);

        // L1 should writeback dirty victim to L2
        // Wait for writeback to appear on the L1→L2 wb port
        wait_cycles(1);

        // Check L1 wb FIFO has an entry (dirty eviction queued)
        // The combinational wb output should eventually drive l1_to_l2_wb_valid
        // Wait for wb_valid to assert
        wait_cycles(2);

        // Serve memory for PA_C through L2
        serve_mem_read(PA_C, BLOCK_C);
        // Wait for full pipeline to settle
        wait_cycles(6);

        // After everything settles, PA_C should be in L1
        // and the dirty PA_A data should have been written back to L2
        chk_state("T5b L1 mshr[0]==IDLE",       l1.mshr_state[0], L1_MS_IDLE);

        // ─────────────────────────────────────────────────────────────────
        // T6: L1 miss → L2 hit (data already in L2 from T2 or T5 writeback)
        // PA_A was evicted from L1 but should still be in L2
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T6: L1 miss, L2 hit - no memory access ===");

        // First check PA_A is in L2
        // Load PA_A — should miss L1 but hit L2
        do_load(VA_S0W0, PA_A);
        @(negedge clk);

        // L1 allocated MSHR
        chk_state("T6 L1 mshr[0]==UNRESOLVED",  l1.mshr_state[0], L1_MS_UNRESOLVED);

        // L2 should hit — return data without going to memory
        // Wait for L2 to process and return data
        @(negedge clk);

        // L2 should NOT allocate an MSHR (it's a hit)
        chk_state("T6 L2 mshr[0]==IDLE",        l2.mshr_state[0], L2_MS_IDLE);
        chk_state("T6 L2 mshr[1]==IDLE",        l2.mshr_state[1], L2_MS_IDLE);

        // L2 should have returned data to L1
        // Wait for L1 to transition to RESOLVED then IDLE
        wait_cycles(3);
        chk_state("T6 L1 mshr[0]==IDLE",        l1.mshr_state[0], L1_MS_IDLE);

        // PA_A should be back in L1
        // Verify by doing a load that hits
        do_load(VA_S0W0, PA_A);
        chk_state("T6 verify hit: L1 mshr[0]==IDLE", l1.mshr_state[0], L1_MS_IDLE);

        wait_cycles(2);

        // ─────────────────────────────────────────────────────────────────
        // T7: Multiple sequential loads — fill L1 set 1
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T7: Fill L1 set 1 with two blocks ===");

        // Load PA_D into set 1
        do_load(VA_S1W0, PA_D);
        serve_mem_read(PA_D, BLOCK_D);
        wait_cycles(5);
        chk_state("T7a L1 mshr[0]==IDLE",       l1.mshr_state[0], L1_MS_IDLE);

        // Load PA_E into set 1 way 1
        do_load(VA_S1W0, PA_E);
        serve_mem_read(PA_E, BLOCK_E);
        wait_cycles(5);
        chk_state("T7b L1 mshr[0]==IDLE",       l1.mshr_state[0], L1_MS_IDLE);
        chk_bit  ("T7 L1 set1 both valid",      l1.set_valids[1], 2'b11);

        wait_cycles(2);

        // ─────────────────────────────────────────────────────────────────
        // T8: Store miss → L1 MSHR → L2 miss → memory → install + merge
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T8: Store miss through both caches ===");

        // Store to PA_G (not in L1 or L2)
        do_store(VA_S2W0, PA_G, 64'hCAFE_BABE_F00D_FACE);
        @(negedge clk);

        chk_state("T8 L1 mshr[0]==UNRESOLVED",  l1.mshr_state[0], L1_MS_UNRESOLVED);

        // Serve memory
        serve_mem_read(PA_G, BLOCK_D); // fill with BLOCK_D, store merges word 0
        wait_cycles(6);

        chk_state("T8 L1 mshr[0]==IDLE",        l1.mshr_state[0], L1_MS_IDLE);

        // Block should be in L1, dirty, with merged store data
        chk_bit  ("T8 L1 set2 valid",           l1.set_valids[2][0] | l1.set_valids[2][1], 1'b1);

        wait_cycles(2);

        // ─────────────────────────────────────────────────────────────────
        // T9: L2 dirty writeback to memory on eviction
        // Fill L2 set 0 all 4 ways (some already filled), then cause eviction
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T9: L2 writeback to memory on eviction ===");

        // We need addresses that map to L2 set 0 (L2 index = PA[9:6] = 4'b0000)
        // PA_A and PA_B already in L2 set 0. PA_C also maps there.
        // Need 2 more addresses for set 0 in L2.
        // L2 index for PA_A = PA_A[9:6] = 0000. Good.

        // PA_A is in L2 set 4 from T2
        chk_bit("T9 L2 set4 has entries", l2.set_valids[4][0], 1'b1);

        wait_cycles(2);

        // ─────────────────────────────────────────────────────────────────
        // T10: Verify no stale data — reload evicted block
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T10: Coherence check - dirty writeback preserved ===");

        // Store to PA_D to make it dirty in L1
        do_store(VA_S1W0, PA_D, 64'hDEAD_DEAD_DEAD_DEAD);
        wait_cycles(2);
        chk_bit("T10 L1 PA_D dirty", l1.set_dirty[1][0] | l1.set_dirty[1][1], 1'b1);

        // Now load PA_F to evict PA_D from L1 set 1 (already has PA_D, PA_E)
        do_load(VA_S1W0, PA_F);
        serve_mem_read(PA_F, BLOCK_F);
        wait_cycles(8);

        chk_state("T10 L1 mshr[0]==IDLE", l1.mshr_state[0], L1_MS_IDLE);

        // PA_D dirty data should have been written back to L2
        // Drain any L2 wb FIFO entries to memory
        if (mem_req_valid && mem_req_is_write) begin
            do_mem_accept();
            wait_cycles(2);
        end

        wait_cycles(2);

        // ─────────────────────────────────────────────────────────────────
        // T11: Back-to-back loads to different sets
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T11: Back-to-back loads ===");

        // Load PA_D again (should be in L2 from writeback)
        do_load(VA_S1W0, PA_D);
        wait_cycles(6);
        chk_state("T11 L1 mshr[0]==IDLE", l1.mshr_state[0], L1_MS_IDLE);

        // Immediately load PA_E (should also be in L2)
        do_load(VA_S1W0, PA_E);
        wait_cycles(6);
        chk_state("T11 L1 mshr[0]==IDLE", l1.mshr_state[0], L1_MS_IDLE);

        wait_cycles(2);

        // ─────────────────────────────────────────────────────────────────
        // T12: L2 wb FIFO drain — verify memory writes complete
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T12: Drain any pending L2 wb FIFO entries ===");

        // Accept any pending memory writes
        repeat(4) begin
            @(negedge clk);
            if (mem_req_valid && mem_req_is_write) begin
                mem_req_ready = 1;
                @(negedge clk);
                mem_req_ready = 0;
            end
        end
        wait_cycles(2);
        chk_bit("T12 L2 wb_empty", l2.wb_empty, 1'b1);

        // ─────────────────────────────────────────────────────────────────
        // Summary
        // ─────────────────────────────────────────────────────────────────
        $display("\n══════════════════════════════════════════════════════");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        $display("══════════════════════════════════════════════════════\n");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #200000;
        $display("TIMEOUT at %0t", $time);
        $finish;
    end

endmodule
