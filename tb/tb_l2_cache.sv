`timescale 1ns/1ps
// L2 cache testbench
// L2 geometry (defaults): 4096B, 4-way, 64B blocks
//   16 sets, INDEX_BITS=4, OFFSET_BITS=6, TAG_SIZE=20
//   PA = {tag[19:0], index[3:0], offset[5:0]}
module tb_l2_cache;

    // ── Parameters ─────────────────────────────────────────────────────────
    localparam PA_WIDTH    = 30;
    localparam BLOCK_SIZE  = 64;
    localparam DATA_WIDTH  = 64;
    localparam L2_WAYS     = 4;
    localparam NUM_MSHRS   = 4;
    localparam L2_SETS     = 16;
    localparam INDEX_BITS  = 4;
    localparam OFFSET_BITS = 6;
    localparam TAG_SIZE    = 20;

    localparam [1:0] MS_IDLE       = 2'b00;
    localparam [1:0] MS_UNRESOLVED = 2'b01;
    localparam [1:0] MS_WAIT_MEM   = 2'b10;
    localparam [1:0] MS_RESOLVED   = 2'b11;

    // ── Test addresses ──────────────────────────────────────────────────────
    // PA = {tag[19:0], index[3:0], offset[5:0]}

    // Set 0 (index=4'b0000)
    localparam [PA_WIDTH-1:0] PA_S0T1 = {20'h00001, 4'b0000, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T2 = {20'h00002, 4'b0000, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T3 = {20'h00003, 4'b0000, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T4 = {20'h00004, 4'b0000, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T5 = {20'h00005, 4'b0000, 6'h00};

    // Set 1 (index=4'b0001)
    localparam [PA_WIDTH-1:0] PA_S1T1 = {20'h00010, 4'b0001, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S1T2 = {20'h00020, 4'b0001, 6'h00};

    // Set 2 (index=4'b0010) — for MSHR tests
    localparam [PA_WIDTH-1:0] PA_S2T1 = {20'h00100, 4'b0010, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S2T2 = {20'h00200, 4'b0010, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S2T3 = {20'h00300, 4'b0010, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S2T4 = {20'h00400, 4'b0010, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S2T5 = {20'h00500, 4'b0010, 6'h00};

    // 512-bit test blocks
    localparam [BLOCK_SIZE*8-1:0] BLOCK_1 = {8{64'hAAAA_AAAA_AAAA_AAAA}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_2 = {8{64'hBBBB_BBBB_BBBB_BBBB}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_3 = {8{64'hCCCC_CCCC_CCCC_CCCC}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_4 = {8{64'hDDDD_DDDD_DDDD_DDDD}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_5 = {8{64'hEEEE_EEEE_EEEE_EEEE}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_6 = {8{64'hFFFF_FFFF_FFFF_FFFF}};

    // ── DUT signals ─────────────────────────────────────────────────────────
    logic                        clk;
    logic                        rst_n;

    // L1 -> L2: writeback
    logic                        l1_wb_valid;
    logic [PA_WIDTH-1:0]         l1_wb_paddr;
    logic [BLOCK_SIZE*8-1:0]     l1_wb_data;
    wire                         l1_wb_ack;

    // L1 -> L2: miss request
    logic                        l1_req_valid;
    logic [PA_WIDTH-1:0]         l1_req_paddr;

    // L2 -> L1: data return
    wire                         l1_data_valid;
    wire  [PA_WIDTH-1:0]         l1_data_paddr;
    wire  [BLOCK_SIZE*8-1:0]     l1_data;

    // L2 -> Memory
    wire                         mem_req_valid;
    wire                         mem_req_is_write;
    wire  [PA_WIDTH-1:0]         mem_req_addr;
    wire  [BLOCK_SIZE*8-1:0]     mem_req_wdata;
    logic                        mem_req_ready;

    // Memory -> L2
    logic                        mem_resp_valid;
    logic [PA_WIDTH-1:0]         mem_resp_paddr;
    logic [BLOCK_SIZE*8-1:0]     mem_resp_rdata;

    // ── DUT ─────────────────────────────────────────────────────────────────
    l2_cache dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .l1_wb_valid     (l1_wb_valid),
        .l1_wb_paddr     (l1_wb_paddr),
        .l1_wb_data      (l1_wb_data),
        .l1_wb_ack       (l1_wb_ack),
        .l1_req_valid    (l1_req_valid),
        .l1_req_paddr    (l1_req_paddr),
        .l1_data_valid   (l1_data_valid),
        .l1_data_paddr   (l1_data_paddr),
        .l1_data         (l1_data),
        .mem_req_valid   (mem_req_valid),
        .mem_req_is_write(mem_req_is_write),
        .mem_req_addr    (mem_req_addr),
        .mem_req_wdata   (mem_req_wdata),
        .mem_req_ready   (mem_req_ready),
        .mem_resp_valid  (mem_resp_valid),
        .mem_resp_paddr  (mem_resp_paddr),
        .mem_resp_rdata  (mem_resp_rdata)
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

    task chk_wide;
        input [255:0]           name;
        input [BLOCK_SIZE*8-1:0] got;
        input [BLOCK_SIZE*8-1:0] exp;
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  @%0t", name, $time);
            $display("         got=%0h", got);
            $display("         exp=%0h", exp);
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

    task chk_int;
        input [255:0] name;
        input [31:0]  got;
        input [31:0]  exp;
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%0d  exp=%0d  @%0t", name, got, exp, $time);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    // ── Helper tasks ─────────────────────────────────────────────────────────

    task idle_inputs;
    begin
        l1_wb_valid    = 0;
        l1_wb_paddr    = 0;
        l1_wb_data     = 0;
        l1_req_valid   = 0;
        l1_req_paddr   = 0;
        mem_req_ready  = 0;
        mem_resp_valid = 0;
        mem_resp_paddr = 0;
        mem_resp_rdata = 0;
    end
    endtask

    // Drive a writeback for one cycle, wait for ack
    task do_writeback;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] data;
    begin
        @(negedge clk);
        l1_wb_valid = 1; l1_wb_paddr = paddr; l1_wb_data = data;
        @(negedge clk);
        l1_wb_valid = 0; l1_wb_paddr = 0; l1_wb_data = 0;
    end
    endtask

    // Drive an L1 miss request for one cycle
    task do_l1_req;
        input [PA_WIDTH-1:0] paddr;
    begin
        @(negedge clk);
        l1_req_valid = 1; l1_req_paddr = paddr;
        @(negedge clk);
        l1_req_valid = 0; l1_req_paddr = 0;
    end
    endtask

    // Drive memory response for one cycle
    task do_mem_resp;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] data;
    begin
        @(negedge clk);
        mem_resp_valid = 1; mem_resp_paddr = paddr; mem_resp_rdata = data;
        @(negedge clk);
        mem_resp_valid = 0; mem_resp_paddr = 0; mem_resp_rdata = 0;
    end
    endtask

    // Accept one memory request
    task do_mem_accept;
    begin
        @(negedge clk);
        mem_req_ready = 1;
        @(negedge clk);
        mem_req_ready = 0;
    end
    endtask

    // Full miss flow: L1 request → mem accept → mem respond → install
    task full_miss_flow;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] data;
    begin
        do_l1_req(paddr);          // allocate MSHR
        do_mem_accept();           // memory accepts read → WAIT_MEM
        do_mem_resp(paddr, data);  // memory responds → RESOLVED
        @(negedge clk);            // install cycle
        @(negedge clk);            // settle
    end
    endtask

    // ══════════════════════════════════════════════════════════════════════════
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        idle_inputs();
        rst_n = 0;

        // ─────────────────────────────────────────────────────────────────────
        // T1: RESET
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T1: Reset ===");
        repeat(2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        chk_state("T1 mshr[0]==IDLE",        dut.mshr_state[0], MS_IDLE);
        chk_state("T1 mshr[1]==IDLE",        dut.mshr_state[1], MS_IDLE);
        chk_state("T1 mshr[2]==IDLE",        dut.mshr_state[2], MS_IDLE);
        chk_state("T1 mshr[3]==IDLE",        dut.mshr_state[3], MS_IDLE);
        chk_bit  ("T1 wb_empty==1",          dut.wb_empty,      1'b1);
        chk_bit  ("T1 l1_wb_ack==0",         l1_wb_ack,         1'b0);
        chk_bit  ("T1 l1_data_valid==0",     l1_data_valid,     1'b0);
        chk_bit  ("T1 mem_req_valid==0",     mem_req_valid,     1'b0);
        chk_bit  ("T1 set_valids[0]==0",     dut.set_valids[0], 4'b0000);

        // ─────────────────────────────────────────────────────────────────────
        // T2: L1 writeback into empty cache (miss path → install dirty)
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T2: Writeback miss - install into empty set ===");
        do_writeback(PA_S0T1, BLOCK_1);
        // After posedge: wb miss, installs into way 0, acks
        chk_bit  ("T2 l1_wb_ack==1",             l1_wb_ack,                1'b1);
        chk_bit  ("T2 set_valids[0][0]==1",       dut.set_valids[0][0],     1'b1);
        chk_bit  ("T2 set_dirty[0][0]==1",        dut.set_dirty[0][0],      1'b1);
        chk_wide ("T2 set_contents[0][0]==BLOCK_1", dut.set_contents[0][0], BLOCK_1);

        // ─────────────────────────────────────────────────────────────────────
        // T3: Writeback same address (hit path → overwrite)
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T3: Writeback hit - overwrite data ===");
        do_writeback(PA_S0T1, BLOCK_2);
        chk_bit  ("T3 l1_wb_ack==1",             l1_wb_ack,                1'b1);
        chk_bit  ("T3 set_dirty[0][0]==1",        dut.set_dirty[0][0],      1'b1);
        chk_wide ("T3 data updated to BLOCK_2",   dut.set_contents[0][0],   BLOCK_2);

        // ─────────────────────────────────────────────────────────────────────
        // T4: L1 miss request — L2 hit (returns data immediately)
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T4: L1 request hit ===");
        do_l1_req(PA_S0T1);
        chk_bit  ("T4 l1_data_valid==1",      l1_data_valid,  1'b1);
        chk_val  ("T4 l1_data_paddr correct",  l1_data_paddr,  PA_S0T1);
        chk_wide ("T4 l1_data==BLOCK_2",       l1_data,        BLOCK_2);
        // No MSHR should be allocated
        chk_state("T4 mshr[0] still IDLE",     dut.mshr_state[0], MS_IDLE);

        // ─────────────────────────────────────────────────────────────────────
        // T5: L1 miss request — L2 miss → MSHR allocation
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T5: L1 request miss - MSHR allocation ===");
        do_l1_req(PA_S1T1);
        // Should allocate MSHR
        chk_state("T5 mshr[0]==UNRESOLVED",    dut.mshr_state[0], MS_UNRESOLVED);
        chk_val  ("T5 mshr_paddr[0]",          dut.mshr_paddr[0], PA_S1T1);
        // Combinational: mem_req should fire for read
        chk_bit  ("T5 mem_req_valid==1",       mem_req_valid,     1'b1);
        chk_bit  ("T5 mem_req_is_write==0",    mem_req_is_write,  1'b0);
        chk_val  ("T5 mem_req_addr==PA_S1T1",  mem_req_addr,      PA_S1T1);

        // ─────────────────────────────────────────────────────────────────────
        // T6: Memory accepts read → MSHR to WAIT_MEM
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T6: Memory accepts read ===");
        do_mem_accept();
        chk_state("T6 mshr[0]==WAIT_MEM",      dut.mshr_state[0], MS_WAIT_MEM);

        // ─────────────────────────────────────────────────────────────────────
        // T7: Memory responds → RESOLVED → installed → returned to L1
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T7: Memory responds - install and return to L1 ===");
        do_mem_resp(PA_S1T1, BLOCK_3);
        // After mem_resp: MSHR should be RESOLVED
        chk_state("T7 mshr[0]==RESOLVED",      dut.mshr_state[0], MS_RESOLVED);

        // Next cycle: install loop picks it up
        @(negedge clk);
        // l1_data_valid is a one-cycle pulse, check right after install posedge
        chk_bit  ("T7 l1_data_valid==1",       l1_data_valid,  1'b1);
        chk_val  ("T7 l1_data_paddr",          l1_data_paddr,  PA_S1T1);
        chk_wide ("T7 l1_data==BLOCK_3",       l1_data,        BLOCK_3);
        chk_state("T7 mshr[0]==IDLE after install", dut.mshr_state[0], MS_IDLE);
        // Check installed in cache
        chk_bit  ("T7 set_valids[1][0]==1",    dut.set_valids[1][0], 1'b1);
        chk_bit  ("T7 set_dirty[1][0]==0",     dut.set_dirty[1][0],  1'b0); // clean fill
        chk_wide ("T7 contents correct",       dut.set_contents[1][0], BLOCK_3);
        @(negedge clk); // settle

        // ─────────────────────────────────────────────────────────────────────
        // T8: Fill all 4 ways of set 2 via writebacks
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T8: Fill all 4 ways via writeback ===");
        do_writeback(PA_S2T1, BLOCK_1);
        chk_bit("T8 wb ack way0", l1_wb_ack, 1'b1);
        do_writeback(PA_S2T2, BLOCK_2);
        chk_bit("T8 wb ack way1", l1_wb_ack, 1'b1);
        do_writeback(PA_S2T3, BLOCK_3);
        chk_bit("T8 wb ack way2", l1_wb_ack, 1'b1);
        do_writeback(PA_S2T4, BLOCK_4);
        chk_bit("T8 wb ack way3", l1_wb_ack, 1'b1);
        // All 4 ways should be valid and dirty
        chk_bit("T8 set_valids[2]==1111", dut.set_valids[2], 4'b1111);
        chk_bit("T8 set_dirty[2][0]==1",  dut.set_dirty[2][0], 1'b1);
        chk_bit("T8 set_dirty[2][1]==1",  dut.set_dirty[2][1], 1'b1);
        chk_bit("T8 set_dirty[2][2]==1",  dut.set_dirty[2][2], 1'b1);
        chk_bit("T8 set_dirty[2][3]==1",  dut.set_dirty[2][3], 1'b1);
        chk_wide("T8 way0 data", dut.set_contents[2][0], BLOCK_1);
        chk_wide("T8 way1 data", dut.set_contents[2][1], BLOCK_2);
        chk_wide("T8 way2 data", dut.set_contents[2][2], BLOCK_3);
        chk_wide("T8 way3 data", dut.set_contents[2][3], BLOCK_4);

        // ─────────────────────────────────────────────────────────────────────
        // T9: 5th writeback to same set — LRU eviction, dirty victim → wb FIFO
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T9: LRU eviction on writeback - dirty victim to FIFO ===");
        // LRU victim should be way 0 (first installed, least recently touched)
        do_writeback(PA_S2T5, BLOCK_5);
        chk_bit  ("T9 l1_wb_ack==1",          l1_wb_ack,     1'b1);
        // wb FIFO should have the evicted dirty victim
        chk_bit  ("T9 wb_empty==0",           dut.wb_empty,  1'b0);
        // New block should be installed (replacing LRU victim)
        chk_wide ("T9 new block installed",   dut.set_contents[2][0], BLOCK_5);

        // ─────────────────────────────────────────────────────────────────────
        // T10: WB FIFO drain — memory write
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T10: WB FIFO drain via memory write ===");
        // wb FIFO has dirty victim — should drive mem_req for write
        chk_bit  ("T10 mem_req_valid==1",      mem_req_valid,     1'b1);
        chk_bit  ("T10 mem_req_is_write==1",   mem_req_is_write,  1'b1);
        // Accept the write
        do_mem_accept();
        @(negedge clk);
        chk_bit  ("T10 wb_empty after drain",  dut.wb_empty,      1'b1);

        // ─────────────────────────────────────────────────────────────────────
        // T11: Duplicate MSHR suppression
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T11: Duplicate MSHR suppression ===");
        // Request an address not in L2
        @(negedge clk);
        l1_req_valid = 1; l1_req_paddr = PA_S1T2;
        @(negedge clk);
        l1_req_valid = 0; l1_req_paddr = 0;
        // MSHR[0] should be allocated
        chk_state("T11 mshr[0]==UNRESOLVED",   dut.mshr_state[0], MS_UNRESOLVED);
        chk_val  ("T11 mshr_paddr[0]",         dut.mshr_paddr[0], PA_S1T2);

        // Request same address again
        @(negedge clk);
        l1_req_valid = 1; l1_req_paddr = PA_S1T2;
        @(negedge clk);
        l1_req_valid = 0; l1_req_paddr = 0;
        // Should NOT allocate a second MSHR
        chk_state("T11 mshr[1] still IDLE",    dut.mshr_state[1], MS_IDLE);
        chk_state("T11 mshr[2] still IDLE",    dut.mshr_state[2], MS_IDLE);
        chk_state("T11 mshr[3] still IDLE",    dut.mshr_state[3], MS_IDLE);

        // Clean up: accept + respond to free MSHR
        do_mem_accept();
        do_mem_resp(PA_S1T2, BLOCK_6);
        @(negedge clk); @(negedge clk); // install

        // ─────────────────────────────────────────────────────────────────────
        // T12: MSHR full — additional request ignored
        // ─────────────────────────────────────────────────────────────────────
        $display("\n=== T12: MSHR full - request dropped ===");
        // Use set 3 addresses to avoid hitting existing cache lines
        // Allocate all 4 MSHRs
        @(negedge clk);
        l1_req_valid = 1; l1_req_paddr = {20'hA0001, 4'b0011, 6'h00};
        @(negedge clk);
        l1_req_valid = 0;
        @(negedge clk);
        l1_req_valid = 1; l1_req_paddr = {20'hA0002, 4'b0100, 6'h00};
        @(negedge clk);
        l1_req_valid = 0;
        @(negedge clk);
        l1_req_valid = 1; l1_req_paddr = {20'hA0003, 4'b0101, 6'h00};
        @(negedge clk);
        l1_req_valid = 0;
        @(negedge clk);
        l1_req_valid = 1; l1_req_paddr = {20'hA0004, 4'b0110, 6'h00};
        @(negedge clk);
        l1_req_valid = 0;

        @(negedge clk);
        // All 4 should be allocated
        chk_state("T12 mshr[0]!=IDLE", dut.mshr_state[0], MS_UNRESOLVED);
        chk_state("T12 mshr[1]!=IDLE", dut.mshr_state[1], MS_UNRESOLVED);
        chk_state("T12 mshr[2]!=IDLE", dut.mshr_state[2], MS_UNRESOLVED);
        chk_state("T12 mshr[3]!=IDLE", dut.mshr_state[3], MS_UNRESOLVED);

        // 5th request — should be dropped (no l1_data_valid, no new MSHR)
        @(negedge clk);
        l1_req_valid = 1; l1_req_paddr = {20'hA0005, 4'b0111, 6'h00};
        @(negedge clk);
        l1_req_valid = 0;
        @(negedge clk);
        chk_bit("T12 l1_data_valid==0 (dropped)", l1_data_valid, 1'b0);
        // All 4 MSHRs still UNRESOLVED (5th didn't overwrite)
        chk_state("T12 mshr[0] unchanged", dut.mshr_state[0], MS_UNRESOLVED);
        chk_state("T12 mshr[1] unchanged", dut.mshr_state[1], MS_UNRESOLVED);
        chk_state("T12 mshr[2] unchanged", dut.mshr_state[2], MS_UNRESOLVED);
        chk_state("T12 mshr[3] unchanged", dut.mshr_state[3], MS_UNRESOLVED);

        // ─────────────────────────────────────────────────────────────────────
        // Summary
        // ─────────────────────────────────────────────────────────────────────
        $display("\n══════════════════════════════════════════════════════");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        $display("══════════════════════════════════════════════════════\n");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("TIMEOUT at %0t", $time);
        $finish;
    end

endmodule
