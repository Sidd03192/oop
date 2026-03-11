`timescale 1ns/1ps

// Accurate directed testbench for l2_cache.sv.
//
// Test plan:
//   T1  Reset and idle outputs
//       Confirms cache state, MSHRs, and writeback FIFO reset cleanly.
//
//   T2  Read hit returns data immediately and updates LRU
//       Preloads one line, issues an L1 read hit, and checks returned data plus
//       the matrix-LRU update for the touched way.
//
//   T3  Cold read miss allocates one MSHR and advertises a memory read
//       Verifies a miss becomes UNRESOLVED and drives mem_req outputs.
//
//   T4  Accepted read request moves the MSHR to WAIT_MEM
//       Pulses mem_req_ready and checks the oldest unresolved miss advances.
//
//   T5  Memory response capture and next-cycle install
//       Verifies mem_resp moves WAIT_MEM to RESOLVED, then installs the block,
//       returns it to L1, and frees the MSHR on the next cycle.
//
//   T6  Duplicate read-miss suppression
//       Holds the same miss request high for multiple cycles and checks only one
//       MSHR is allocated.
//
//   T7  Multiple distinct misses and issue ordering
//       Creates multiple misses, checks separate MSHRs fill, and verifies issue
//       order follows lowest-index unresolved first.
//
//   T8  Writeback hit updates the line and sets dirty
//       Checks data overwrite, dirty bit, ack pulse, and LRU update on hit.
//
//   T9  Writeback miss installs into an invalid way without using an MSHR
//       Verifies install/ack behavior and confirms MSHRs remain idle.
//
//   T10 Dirty victim on writeback miss is queued correctly
//       Forces a same-set replacement and checks the evicted dirty block enters
//       the writeback FIFO with the right address and data.
//
//   T11 WB FIFO has priority over read-miss issue
//       Confirms memory sees queued writebacks before unresolved read misses.
//
//   T12 Resolved install stalls when WB FIFO is full, then resumes
//       Verifies a dirty-victim install is blocked by full WB FIFO and completes
//       after one queued writeback drains.
//
//   T13 Back-to-back dirty evictions are preserved in FIFO order
//       Forces two consecutive resolved installs that both evict dirty lines and
//       checks the FIFO preserves both writebacks.
//
//   T14 4-way matrix LRU kicks out the expected block
//       Fills a set, touches ways in a known order, then forces a replacement and
//       checks the row-all-zero victim is evicted.
//
//   T15 Invalid way beats LRU
//       Confirms a writeback miss chooses an invalid way before evicting a valid line.
//
//   T16 Wrong-address memory response is ignored
//       Drives a response that matches no WAIT_MEM MSHR and checks state does not change.
//
//   T17 Read miss followed by writeback to the same block
//       Locks the current simple behavior: the read miss remains tracked while the
//       writeback still installs data into the cache and acks.

module tb_l2_accurate;

    localparam int PA_WIDTH    = 30;
    localparam int BLOCK_SIZE  = 64;
    localparam int DATA_WIDTH  = 64;
    localparam int NUM_MSHRS   = 4;
    localparam int L2_CAPACITY = 4096;
    localparam int L2_WAYS     = 4;
    localparam int L2_SETS     = L2_CAPACITY / (BLOCK_SIZE * L2_WAYS);
    localparam int INDEX_BITS  = $clog2(L2_SETS);
    localparam int OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam int TAG_SIZE    = PA_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam int WB_DEPTH    = NUM_MSHRS;

    localparam [1:0] MS_IDLE       = 2'b00;
    localparam [1:0] MS_UNRESOLVED = 2'b01;
    localparam [1:0] MS_WAIT_MEM   = 2'b10;
    localparam [1:0] MS_RESOLVED   = 2'b11;

    localparam [PA_WIDTH-1:0] PA_S0T0 = {20'h00010, 4'h0, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T1 = {20'h00011, 4'h0, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T2 = {20'h00012, 4'h0, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T3 = {20'h00013, 4'h0, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T4 = {20'h00014, 4'h0, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T5 = {20'h00015, 4'h0, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S1T0 = {20'h00020, 4'h1, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S1T1 = {20'h00021, 4'h1, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S1T2 = {20'h00022, 4'h1, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S2T0 = {20'h00030, 4'h2, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S2T1 = {20'h00031, 4'h2, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S3T0 = {20'h00040, 4'h3, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S3T1 = {20'h00041, 4'h3, 6'h00};

    localparam [BLOCK_SIZE*8-1:0] BLOCK_A = {8{64'hAAAA_AAAA_AAAA_AAAA}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_B = {8{64'hBBBB_BBBB_BBBB_BBBB}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_C = {8{64'hCCCC_CCCC_CCCC_CCCC}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_D = {8{64'hDDDD_DDDD_DDDD_DDDD}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_E = {8{64'hEEEE_EEEE_EEEE_EEEE}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_F = {8{64'hF0F0_F0F0_F0F0_F0F0}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_G = {8{64'h1234_5678_9ABC_DEF0}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_H = {8{64'h0BAD_F00D_0BAD_F00D}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_I = {8{64'h1111_2222_3333_4444}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_J = {8{64'h5555_6666_7777_8888}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_ZERO = '0;

    logic                     clk;
    logic                     rst_n;
    logic                     l1_wb_valid;
    logic [PA_WIDTH-1:0]      l1_wb_paddr;
    logic [BLOCK_SIZE*8-1:0]  l1_wb_data;
    logic                     l1_req_valid;
    logic [PA_WIDTH-1:0]      l1_req_paddr;
    logic                     mem_req_ready;
    logic                     mem_resp_valid;
    logic [PA_WIDTH-1:0]      mem_resp_paddr;
    logic [BLOCK_SIZE*8-1:0]  mem_resp_rdata;

    wire                      l1_wb_ack;
    wire                      l1_data_valid;
    wire [PA_WIDTH-1:0]       l1_data_paddr;
    wire [BLOCK_SIZE*8-1:0]   l1_data;
    wire                      mem_req_valid;
    wire                      mem_req_is_write;
    wire [PA_WIDTH-1:0]       mem_req_addr;
    wire [BLOCK_SIZE*8-1:0]   mem_req_wdata;

    integer pass_cnt;
    integer fail_cnt;
    integer i;
    integer j;
    integer busy_cnt;

    l2_cache dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .l1_wb_valid  (l1_wb_valid),
        .l1_wb_paddr  (l1_wb_paddr),
        .l1_wb_data   (l1_wb_data),
        .l1_wb_ack    (l1_wb_ack),
        .l1_req_valid (l1_req_valid),
        .l1_req_paddr (l1_req_paddr),
        .l1_data_valid(l1_data_valid),
        .l1_data_paddr(l1_data_paddr),
        .l1_data      (l1_data),
        .mem_req_valid(mem_req_valid),
        .mem_req_is_write(mem_req_is_write),
        .mem_req_addr (mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_req_ready(mem_req_ready),
        .mem_resp_valid(mem_resp_valid),
        .mem_resp_paddr(mem_resp_paddr),
        .mem_resp_rdata(mem_resp_rdata)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    function automatic [INDEX_BITS-1:0] addr_index(input [PA_WIDTH-1:0] paddr);
        begin
            addr_index = paddr[OFFSET_BITS +: INDEX_BITS];
        end
    endfunction

    function automatic [TAG_SIZE-1:0] addr_tag(input [PA_WIDTH-1:0] paddr);
        begin
            addr_tag = paddr[PA_WIDTH-1 -: TAG_SIZE];
        end
    endfunction

    task automatic chk_bit;
        input [255:0] name;
        input         got;
        input         exp;
        begin
            if (got === exp) begin
                $display("  PASS  %s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %s  got=%b exp=%b @%0t", name, got, exp, $time);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic chk_state;
        input [255:0] name;
        input [1:0]   got;
        input [1:0]   exp;
        begin
            if (got === exp) begin
                $display("  PASS  %s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %s  got=%b exp=%b @%0t", name, got, exp, $time);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic chk_pa;
        input [255:0]        name;
        input [PA_WIDTH-1:0] got;
        input [PA_WIDTH-1:0] exp;
        begin
            if (got === exp) begin
                $display("  PASS  %s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %s  got=%0h exp=%0h @%0t", name, got, exp, $time);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic chk_int;
        input [255:0] name;
        input integer got;
        input integer exp;
        begin
            if (got === exp) begin
                $display("  PASS  %s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %s  got=%0d exp=%0d @%0t", name, got, exp, $time);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic chk_wide;
        input [255:0]            name;
        input [BLOCK_SIZE*8-1:0] got;
        input [BLOCK_SIZE*8-1:0] exp;
        begin
            if (got === exp) begin
                $display("  PASS  %s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %s  got=%0h exp=%0h @%0t", name, got, exp, $time);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic idle_inputs;
        begin
            l1_wb_valid   = 1'b0;
            l1_wb_paddr   = '0;
            l1_wb_data    = '0;
            l1_req_valid  = 1'b0;
            l1_req_paddr  = '0;
            mem_req_ready = 1'b0;
            mem_resp_valid = 1'b0;
            mem_resp_paddr = '0;
            mem_resp_rdata = '0;
        end
    endtask

    task automatic apply_reset;
        begin
            idle_inputs();
            rst_n = 1'b0;
            repeat (2) @(negedge clk);
            rst_n = 1'b1;
            @(negedge clk);
        end
    endtask

    task automatic send_l1_req;
        input [PA_WIDTH-1:0] paddr;
        begin
            @(negedge clk);
            l1_req_valid = 1'b1;
            l1_req_paddr = paddr;
            @(negedge clk);
            l1_req_valid = 1'b0;
            l1_req_paddr = '0;
        end
    endtask

    task automatic send_l1_wb;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] block;
        begin
            @(negedge clk);
            l1_wb_valid = 1'b1;
            l1_wb_paddr = paddr;
            l1_wb_data  = block;
            @(negedge clk);
            l1_wb_valid = 1'b0;
            l1_wb_paddr = '0;
            l1_wb_data  = '0;
        end
    endtask

    task automatic accept_mem_req;
        begin
            @(negedge clk);
            mem_req_ready = 1'b1;
            @(negedge clk);
            mem_req_ready = 1'b0;
        end
    endtask

    task automatic mem_return;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] block;
        begin
            @(negedge clk);
            mem_resp_valid = 1'b1;
            mem_resp_paddr = paddr;
            mem_resp_rdata = block;
            @(negedge clk);
            mem_resp_valid = 1'b0;
            mem_resp_paddr = '0;
            mem_resp_rdata = '0;
        end
    endtask

    task automatic preload_line;
        input integer            way;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] block;
        input                    dirty;
        integer set_idx;
        begin
            @(negedge clk);
            set_idx = addr_index(paddr);
            dut.set_contents[set_idx][way] = block;
            dut.tags[set_idx][way]         = addr_tag(paddr);
            dut.set_valids[set_idx][way]   = 1'b1;
            dut.set_dirty[set_idx][way]    = dirty;
        end
    endtask

    task automatic mark_way_mru;
        input integer set_idx;
        input integer way;
        integer k;
        begin
            @(negedge clk);
            for (k = 0; k < L2_WAYS; k = k + 1) begin
                dut.lru_matrix[set_idx][way][k] = 1'b1;
                dut.lru_matrix[set_idx][k][way] = 1'b0;
            end
        end
    endtask

    task automatic clear_set;
        input integer set_idx;
        integer way;
        integer r;
        integer c;
        begin
            @(negedge clk);
            dut.set_valids[set_idx] = '0;
            dut.set_dirty[set_idx]  = '0;
            for (way = 0; way < L2_WAYS; way = way + 1) begin
                dut.set_contents[set_idx][way] = '0;
                dut.tags[set_idx][way]         = '0;
            end
            for (r = 0; r < L2_WAYS; r = r + 1)
                for (c = 0; c < L2_WAYS; c = c + 1)
                    dut.lru_matrix[set_idx][r][c] = 1'b0;
        end
    endtask

    task automatic preload_mshr;
        input integer            slot;
        input [1:0]              state;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] block;
        input                    issued;
        begin
            @(negedge clk);
            dut.mshr_state[slot]      = state;
            dut.mshr_paddr[slot]      = paddr;
            dut.mshr_block[slot]      = block;
            dut.mshr_mem_issued[slot] = issued;
        end
    endtask

    task automatic count_busy_mshrs;
        output integer count;
        integer idx;
        begin
            count = 0;
            for (idx = 0; idx < NUM_MSHRS; idx = idx + 1)
                if (dut.mshr_state[idx] != MS_IDLE)
                    count = count + 1;
        end
    endtask

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        busy_cnt = 0;
        idle_inputs();
        rst_n = 1'b1;

        // T1: Reset and idle outputs
        $display("\n=== T1: Reset and idle outputs ===");
        apply_reset();
        for (i = 0; i < NUM_MSHRS; i = i + 1)
            chk_state("T1 each MSHR reset to IDLE", dut.mshr_state[i], MS_IDLE);
        chk_bit("T1 mem_req_valid low", mem_req_valid, 1'b0);
        chk_bit("T1 l1_wb_ack low",     l1_wb_ack,     1'b0);
        chk_bit("T1 l1_data_valid low", l1_data_valid, 1'b0);
        chk_bit("T1 wb fifo empty",     dut.wb_empty,  1'b1);
        for (i = 0; i < L2_SETS; i = i + 1) begin
            chk_int("T1 set valid bits clear", dut.set_valids[i], 0);
            chk_int("T1 set dirty bits clear", dut.set_dirty[i],  0);
        end

        // T2: Read hit and LRU update
        $display("\n=== T2: Read hit returns data and updates LRU ===");
        apply_reset();
        @(negedge clk);
        dut.set_contents[0][2] = BLOCK_A;
        dut.tags[0][2]         = addr_tag(PA_S0T2);
        dut.set_valids[0][2]   = 1'b1;
        dut.set_dirty[0][2]    = 1'b0;
        send_l1_req(PA_S0T2);
        chk_bit ("T2 l1_data_valid on read hit", l1_data_valid, 1'b1);
        chk_pa  ("T2 l1_data_paddr matches",     l1_data_paddr, PA_S0T2);
        chk_wide("T2 l1_data block matches",     l1_data,       BLOCK_A);
        chk_bit ("T2 touched row marks way newer than way0", dut.lru_matrix[0][2][0], 1'b1);
        chk_bit ("T2 touched column clears way0 newer-than-hit", dut.lru_matrix[0][0][2], 1'b0);

        // T3: Cold read miss allocates one MSHR and advertises read
        $display("\n=== T3: Cold read miss allocates one MSHR ===");
        apply_reset();
        send_l1_req(PA_S1T0);
        chk_state("T3 mshr[0] becomes UNRESOLVED", dut.mshr_state[0], MS_UNRESOLVED);
        chk_pa   ("T3 mshr[0] captures address",   dut.mshr_paddr[0], PA_S1T0);
        chk_bit  ("T3 mem_req_valid asserted",     mem_req_valid,     1'b1);
        chk_bit  ("T3 mem_req is read",            mem_req_is_write,  1'b0);
        chk_pa   ("T3 mem_req_addr matches miss",  mem_req_addr,      PA_S1T0);

        // T4: Accepted read request moves to WAIT_MEM
        $display("\n=== T4: Accepted read request moves MSHR to WAIT_MEM ===");
        accept_mem_req();
        chk_state("T4 mshr[0] becomes WAIT_MEM", dut.mshr_state[0], MS_WAIT_MEM);
        chk_bit  ("T4 mshr_mem_issued set",      dut.mshr_mem_issued[0], 1'b1);
        chk_bit  ("T4 mem_req drops after issue", mem_req_valid, 1'b0);

        // T5: Response capture then next-cycle install
        $display("\n=== T5: Memory response installs on following cycle ===");
        mem_return(PA_S1T0, BLOCK_B);
        chk_state("T5 response moves MSHR to RESOLVED", dut.mshr_state[0], MS_RESOLVED);
        chk_wide ("T5 response stored in mshr_block",   dut.mshr_block[0], BLOCK_B);
        @(negedge clk);
        chk_state("T5 resolved MSHR frees after install", dut.mshr_state[0], MS_IDLE);
        chk_bit  ("T5 installed line valid",             dut.set_valids[1][0], 1'b1);
        chk_bit  ("T5 installed line clean",             dut.set_dirty[1][0],  1'b0);
        chk_wide ("T5 installed block matches",          dut.set_contents[1][0], BLOCK_B);
        chk_bit  ("T5 l1_data_valid asserted on install", l1_data_valid, 1'b1);
        chk_pa   ("T5 l1_data_paddr matches fill",        l1_data_paddr, PA_S1T0);
        chk_wide ("T5 l1_data block matches fill",         l1_data, BLOCK_B);

        // T6: Duplicate read miss suppression
        $display("\n=== T6: Duplicate read miss suppression ===");
        apply_reset();
        @(negedge clk);
        l1_req_valid = 1'b1;
        l1_req_paddr = PA_S2T0;
        repeat (3) @(negedge clk);
        l1_req_valid = 1'b0;
        l1_req_paddr = '0;
        count_busy_mshrs(busy_cnt);
        chk_int  ("T6 only one active MSHR for repeated same miss", busy_cnt, 1);
        chk_state("T6 mshr[0] unresolved", dut.mshr_state[0], MS_UNRESOLVED);
        chk_pa   ("T6 active MSHR tracks requested block", dut.mshr_paddr[0], PA_S2T0);

        // T7: Multiple distinct misses and issue ordering
        $display("\n=== T7: Multiple distinct misses and issue ordering ===");
        apply_reset();
        send_l1_req(PA_S0T0);
        send_l1_req(PA_S1T1);
        send_l1_req(PA_S2T1);
        chk_state("T7 mshr[0] unresolved", dut.mshr_state[0], MS_UNRESOLVED);
        chk_state("T7 mshr[1] unresolved", dut.mshr_state[1], MS_UNRESOLVED);
        chk_state("T7 mshr[2] unresolved", dut.mshr_state[2], MS_UNRESOLVED);
        chk_pa   ("T7 oldest unresolved miss issues first", mem_req_addr, PA_S0T0);
        accept_mem_req();
        chk_state("T7 mshr[0] advances to WAIT_MEM", dut.mshr_state[0], MS_WAIT_MEM);
        chk_pa   ("T7 second unresolved miss issues next", mem_req_addr, PA_S1T1);
        accept_mem_req();
        chk_state("T7 mshr[1] advances to WAIT_MEM", dut.mshr_state[1], MS_WAIT_MEM);
        chk_pa   ("T7 third unresolved miss issues next", mem_req_addr, PA_S2T1);

        // T8: Writeback hit updates line and sets dirty
        $display("\n=== T8: Writeback hit updates line and sets dirty ===");
        apply_reset();
        @(negedge clk);
        dut.set_contents[0][1] = BLOCK_C;
        dut.tags[0][1]         = addr_tag(PA_S0T1);
        dut.set_valids[0][1]   = 1'b1;
        dut.set_dirty[0][1]    = 1'b0;
        send_l1_wb(PA_S0T1, BLOCK_D);
        chk_bit ("T8 writeback ack pulses",         l1_wb_ack, 1'b1);
        chk_wide("T8 writeback overwrites line",    dut.set_contents[0][1], BLOCK_D);
        chk_bit ("T8 dirty bit set on wb hit",      dut.set_dirty[0][1], 1'b1);
        chk_bit ("T8 LRU row marks hit way newer",  dut.lru_matrix[0][1][0], 1'b1);
        chk_bit ("T8 LRU column clears older way",  dut.lru_matrix[0][0][1], 1'b0);

        // T9: Writeback miss installs into invalid way
        $display("\n=== T9: Writeback miss installs into invalid way ===");
        apply_reset();
        send_l1_wb(PA_S3T0, BLOCK_E);
        chk_bit ("T9 writeback miss acks",        l1_wb_ack, 1'b1);
        chk_bit ("T9 line becomes valid",         dut.set_valids[3][0], 1'b1);
        chk_bit ("T9 line marked dirty",          dut.set_dirty[3][0],  1'b1);
        chk_wide("T9 line data installed",        dut.set_contents[3][0], BLOCK_E);
        count_busy_mshrs(busy_cnt);
        chk_int ("T9 no MSHR allocated for wb", busy_cnt, 0);

        // T10: Dirty victim on writeback miss queues correct block
        $display("\n=== T10: Dirty victim writeback queues the right block ===");
        apply_reset();
        clear_set(0);
        @(negedge clk);
        dut.set_contents[0][0] = BLOCK_A;
        dut.tags[0][0]         = addr_tag(PA_S0T0);
        dut.set_valids[0][0]   = 1'b1;
        dut.set_dirty[0][0]    = 1'b1;
        dut.set_contents[0][1] = BLOCK_B;
        dut.tags[0][1]         = addr_tag(PA_S0T1);
        dut.set_valids[0][1]   = 1'b1;
        dut.set_dirty[0][1]    = 1'b0;
        dut.set_contents[0][2] = BLOCK_C;
        dut.tags[0][2]         = addr_tag(PA_S0T2);
        dut.set_valids[0][2]   = 1'b1;
        dut.set_dirty[0][2]    = 1'b0;
        dut.set_contents[0][3] = BLOCK_D;
        dut.tags[0][3]         = addr_tag(PA_S0T3);
        dut.set_valids[0][3]   = 1'b1;
        dut.set_dirty[0][3]    = 1'b0;
        send_l1_req(PA_S0T1);
        send_l1_req(PA_S0T2);
        send_l1_req(PA_S0T3);
        send_l1_wb(PA_S0T4, BLOCK_E);
        chk_bit ("T10 wb miss acked",                   l1_wb_ack, 1'b1);
        chk_int ("T10 wb fifo count increments",        dut.wb_count, 1);
        chk_pa  ("T10 queued victim address is PA_S0T0", dut.wb_paddr_q[0], PA_S0T0);
        chk_wide("T10 queued victim data is BLOCK_A",    dut.wb_data_q[0],  BLOCK_A);
        chk_wide("T10 new writeback line installed",     dut.set_contents[0][0], BLOCK_E);

        // T11: WB FIFO has priority over read miss
        $display("\n=== T11: WB FIFO has priority over read miss issue ===");
        apply_reset();
        @(negedge clk);
        dut.wb_head       = '0;
        dut.wb_tail       = 1;
        dut.wb_count      = 1;
        dut.wb_paddr_q[0] = PA_S1T0;
        dut.wb_data_q[0]  = BLOCK_F;
        dut.mshr_state[0] = MS_UNRESOLVED;
        dut.mshr_paddr[0] = PA_S2T0;
        dut.mshr_mem_issued[0] = 1'b0;
        #1;
        chk_bit ("T11 mem_req_valid high",        mem_req_valid, 1'b1);
        chk_bit ("T11 writeback wins priority",   mem_req_is_write, 1'b1);
        chk_pa  ("T11 mem_req_addr shows wb head", mem_req_addr, PA_S1T0);
        chk_wide("T11 mem_req_wdata shows wb data", mem_req_wdata, BLOCK_F);
        accept_mem_req();
        chk_int ("T11 wb fifo count decrements after accept", dut.wb_count, 0);
        chk_bit ("T11 next request becomes read", mem_req_is_write, 1'b0);
        chk_pa  ("T11 read miss appears after wb drains", mem_req_addr, PA_S2T0);

        // T12: Resolved install stalls on full WB FIFO and resumes later
        $display("\n=== T12: Resolved install stalls when WB FIFO is full ===");
        apply_reset();
        clear_set(1);
        @(negedge clk);
        dut.set_contents[1][0] = BLOCK_A;
        dut.tags[1][0]         = addr_tag(PA_S1T0);
        dut.set_valids[1][0]   = 1'b1;
        dut.set_dirty[1][0]    = 1'b1;
        dut.set_contents[1][1] = BLOCK_B;
        dut.tags[1][1]         = addr_tag(PA_S1T1);
        dut.set_valids[1][1]   = 1'b1;
        dut.set_dirty[1][1]    = 1'b0;
        dut.set_contents[1][2] = BLOCK_C;
        dut.tags[1][2]         = addr_tag(PA_S1T2);
        dut.set_valids[1][2]   = 1'b1;
        dut.set_dirty[1][2]    = 1'b0;
        dut.set_contents[1][3] = BLOCK_D;
        dut.tags[1][3]         = addr_tag({20'h00023, 4'h1, 6'h00});
        dut.set_valids[1][3]   = 1'b1;
        dut.set_dirty[1][3]    = 1'b0;
        dut.lru_matrix[1][0][0] = 1'b0;
        dut.lru_matrix[1][1][1] = 1'b0;
        dut.lru_matrix[1][2][2] = 1'b0;
        dut.lru_matrix[1][3][3] = 1'b0;
        mark_way_mru(1, 1);
        mark_way_mru(1, 2);
        mark_way_mru(1, 3);
        @(negedge clk);
        dut.wb_head            = '0;
        dut.wb_tail            = '0;
        dut.wb_count           = WB_DEPTH;
        dut.wb_paddr_q[0]      = PA_S0T0;
        dut.wb_paddr_q[1]      = PA_S0T1;
        dut.wb_paddr_q[2]      = PA_S0T2;
        dut.wb_paddr_q[3]      = PA_S0T3;
        dut.wb_data_q[0]       = BLOCK_A;
        dut.wb_data_q[1]       = BLOCK_B;
        dut.wb_data_q[2]       = BLOCK_C;
        dut.wb_data_q[3]       = BLOCK_D;
        dut.mshr_state[0]      = MS_RESOLVED;
        dut.mshr_paddr[0]      = {20'h00024, 4'h1, 6'h00};
        dut.mshr_block[0]      = BLOCK_E;
        dut.mshr_mem_issued[0] = 1'b1;
        @(negedge clk);
        #1;
        chk_state("T12 resolved MSHR stays blocked while FIFO full", dut.mshr_state[0], MS_RESOLVED);
        chk_wide ("T12 victim line unchanged while blocked", dut.set_contents[1][0], BLOCK_A);
        accept_mem_req();
        @(negedge clk);
        #1;
        chk_state("T12 install completes after FIFO frees", dut.mshr_state[0], MS_IDLE);
        chk_wide ("T12 new block installed after unblocking", dut.set_contents[1][0], BLOCK_E);
        chk_int  ("T12 wb count returns to full after pop+push", dut.wb_count, WB_DEPTH);

        // T13: Back-to-back dirty evictions preserved in FIFO order
        $display("\n=== T13: Back-to-back dirty evictions stay ordered ===");
        apply_reset();
        clear_set(2);
        clear_set(3);
        @(negedge clk);
        dut.set_contents[2][0] = BLOCK_A;
        dut.tags[2][0]         = addr_tag(PA_S2T0);
        dut.set_valids[2][0]   = 1'b1;
        dut.set_dirty[2][0]    = 1'b1;
        dut.set_contents[2][1] = BLOCK_B;
        dut.tags[2][1]         = addr_tag(PA_S2T1);
        dut.set_valids[2][1]   = 1'b1;
        dut.set_dirty[2][1]    = 1'b0;
        dut.set_contents[2][2] = BLOCK_C;
        dut.tags[2][2]         = addr_tag({20'h00032, 4'h2, 6'h00});
        dut.set_valids[2][2]   = 1'b1;
        dut.set_dirty[2][2]    = 1'b0;
        dut.set_contents[2][3] = BLOCK_D;
        dut.tags[2][3]         = addr_tag({20'h00033, 4'h2, 6'h00});
        dut.set_valids[2][3]   = 1'b1;
        dut.set_dirty[2][3]    = 1'b0;
        dut.set_contents[3][0] = BLOCK_E;
        dut.tags[3][0]         = addr_tag(PA_S3T0);
        dut.set_valids[3][0]   = 1'b1;
        dut.set_dirty[3][0]    = 1'b1;
        dut.set_contents[3][1] = BLOCK_F;
        dut.tags[3][1]         = addr_tag(PA_S3T1);
        dut.set_valids[3][1]   = 1'b1;
        dut.set_dirty[3][1]    = 1'b0;
        dut.set_contents[3][2] = BLOCK_G;
        dut.tags[3][2]         = addr_tag({20'h00042, 4'h3, 6'h00});
        dut.set_valids[3][2]   = 1'b1;
        dut.set_dirty[3][2]    = 1'b0;
        dut.set_contents[3][3] = BLOCK_H;
        dut.tags[3][3]         = addr_tag({20'h00043, 4'h3, 6'h00});
        dut.set_valids[3][3]   = 1'b1;
        dut.set_dirty[3][3]    = 1'b0;
        mark_way_mru(2, 1);
        mark_way_mru(2, 2);
        mark_way_mru(2, 3);
        mark_way_mru(3, 1);
        mark_way_mru(3, 2);
        mark_way_mru(3, 3);
        @(negedge clk);
        dut.mshr_state[0]      = MS_RESOLVED;
        dut.mshr_paddr[0]      = {20'h00034, 4'h2, 6'h00};
        dut.mshr_block[0]      = BLOCK_I;
        dut.mshr_mem_issued[0] = 1'b1;
        dut.mshr_state[1]      = MS_RESOLVED;
        dut.mshr_paddr[1]      = {20'h00044, 4'h3, 6'h00};
        dut.mshr_block[1]      = BLOCK_J;
        dut.mshr_mem_issued[1] = 1'b1;
        @(negedge clk);
        @(negedge clk);
        #1;
        chk_int ("T13 wb count captures two dirty evictions", dut.wb_count, 2);
        chk_pa  ("T13 first queued victim is set2 way0", dut.wb_paddr_q[0], PA_S2T0);
        chk_pa  ("T13 second queued victim is set3 way0", dut.wb_paddr_q[1], PA_S3T0);

        // T14: 4-way matrix LRU victim
        $display("\n=== T14: 4-way matrix LRU chooses row-all-zero victim ===");
        apply_reset();
        clear_set(0);
        @(negedge clk);
        dut.set_contents[0][0] = BLOCK_A;
        dut.tags[0][0]         = addr_tag(PA_S0T0);
        dut.set_valids[0][0]   = 1'b1;
        dut.set_contents[0][1] = BLOCK_B;
        dut.tags[0][1]         = addr_tag(PA_S0T1);
        dut.set_valids[0][1]   = 1'b1;
        dut.set_contents[0][2] = BLOCK_C;
        dut.tags[0][2]         = addr_tag(PA_S0T2);
        dut.set_valids[0][2]   = 1'b1;
        dut.set_contents[0][3] = BLOCK_D;
        dut.tags[0][3]         = addr_tag(PA_S0T3);
        dut.set_valids[0][3]   = 1'b1;
        send_l1_req(PA_S0T0);
        send_l1_req(PA_S0T1);
        send_l1_req(PA_S0T2);
        send_l1_req(PA_S0T3);
        send_l1_wb(PA_S0T4, BLOCK_E);
        chk_wide("T14 way0 replaced after being LRU", dut.set_contents[0][0], BLOCK_E);
        chk_wide("T14 way1 preserved", dut.set_contents[0][1], BLOCK_B);
        chk_wide("T14 way2 preserved", dut.set_contents[0][2], BLOCK_C);
        chk_wide("T14 way3 preserved", dut.set_contents[0][3], BLOCK_D);

        // T15: Invalid beats LRU
        $display("\n=== T15: Invalid way beats LRU ===");
        apply_reset();
        clear_set(0);
        @(negedge clk);
        dut.set_contents[0][1] = BLOCK_B;
        dut.tags[0][1]         = addr_tag(PA_S0T1);
        dut.set_valids[0][1]   = 1'b1;
        dut.set_contents[0][2] = BLOCK_C;
        dut.tags[0][2]         = addr_tag(PA_S0T2);
        dut.set_valids[0][2]   = 1'b1;
        dut.set_contents[0][3] = BLOCK_D;
        dut.tags[0][3]         = addr_tag(PA_S0T3);
        dut.set_valids[0][3]   = 1'b1;
        send_l1_req(PA_S0T2);
        send_l1_req(PA_S0T3);
        send_l1_wb(PA_S0T5, BLOCK_F);
        chk_bit ("T15 invalid way0 chosen", dut.set_valids[0][0], 1'b1);
        chk_wide("T15 new line lands in invalid way", dut.set_contents[0][0], BLOCK_F);
        chk_wide("T15 existing valid line preserved", dut.set_contents[0][2], BLOCK_C);

        // T16: Wrong-address memory response ignored
        $display("\n=== T16: Wrong-address memory response is ignored ===");
        apply_reset();
        @(negedge clk);
        dut.mshr_state[0]      = MS_WAIT_MEM;
        dut.mshr_paddr[0]      = PA_S3T0;
        dut.mshr_block[0]      = BLOCK_ZERO;
        dut.mshr_mem_issued[0] = 1'b1;
        mem_return(PA_S3T1, BLOCK_G);
        chk_state("T16 wrong response leaves MSHR in WAIT_MEM", dut.mshr_state[0], MS_WAIT_MEM);
        chk_wide ("T16 wrong response leaves block unchanged",  dut.mshr_block[0], '0);

        // T17: Read miss followed by writeback to same block
        $display("\n=== T17: Read miss followed by writeback to same block ===");
        apply_reset();
        send_l1_req(PA_S1T0);
        chk_state("T17 read miss allocates unresolved MSHR", dut.mshr_state[0], MS_UNRESOLVED);
        send_l1_wb(PA_S1T0, BLOCK_H);
        chk_bit ("T17 writeback still acks",        l1_wb_ack, 1'b1);
        chk_state("T17 original read miss remains tracked", dut.mshr_state[0], MS_UNRESOLVED);
        chk_wide("T17 writeback installs block into cache", dut.set_contents[1][0], BLOCK_H);

        $display("\n==========================================");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("  ALL TESTS PASSED");
        else               $display("  *** FAILURES DETECTED ***");
        $display("==========================================\n");
        $finish;
    end

endmodule
