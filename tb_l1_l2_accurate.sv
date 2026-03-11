`timescale 1ns/1ps

// Accurate directed integration testbench for l1_cache.sv + l2_cache.sv.
//
// Test plan:
//   T1  Reset and idle outputs
//       Confirms both caches reset cleanly, with no outstanding requests,
//       no writebacks, and no memory traffic.
//
//   T2  L1 miss serviced by L2 hit
//       Preloads L2 only, sends an L1 request, and checks the cycle-by-cycle
//       flow: L1 allocates an MSHR, L2 hits and returns data, L1 captures the
//       return one cycle later, and then installs the line.
//
//   T3  End-to-end miss to memory fill
//       Misses in both L1 and L2, checks L2 memory request timing, accepts the
//       read, returns memory data, and confirms both L2 and then L1 install it.
//
//   T4  End-to-end store miss
//       Misses in both caches on a store, fills from memory, then verifies L2
//       keeps the clean fetched block while L1 installs the modified dirty line.
//
//   T5  Dirty L1 eviction writes back into L2 and drains correctly
//       Forces an L1 replacement of a dirty line, checks the writeback address/data,
//       confirms L2 accepts and updates its copy, and verifies L1 drains its WB queue.
//
//   T6  Two outstanding misses synchronize across both levels
//       Creates two L1 misses, checks both L1 and L2 MSHRs track them correctly,
//       accepts/returns them one at a time, and verifies stall clears only after
//       L1 regains a free MSHR slot.

module tb_l1_l2_accurate;

    localparam int PA_WIDTH     = 30;
    localparam int VA_WIDTH     = 48;
    localparam int BLOCK_SIZE   = 64;
    localparam int DATA_WIDTH   = 64;
    localparam int L1_CAPACITY  = 512;
    localparam int L1_WAYS      = 2;
    localparam int L1_SETS      = L1_CAPACITY / (BLOCK_SIZE * L1_WAYS);
    localparam int L1_INDEX_BITS = $clog2(L1_SETS);
    localparam int L1_TAG_SIZE   = PA_WIDTH - L1_INDEX_BITS - $clog2(BLOCK_SIZE);
    localparam int L2_CAPACITY  = 4096;
    localparam int L2_WAYS      = 4;
    localparam int L2_SETS      = L2_CAPACITY / (BLOCK_SIZE * L2_WAYS);
    localparam int L2_INDEX_BITS = $clog2(L2_SETS);
    localparam int L2_TAG_SIZE   = PA_WIDTH - L2_INDEX_BITS - $clog2(BLOCK_SIZE);
    localparam int OFFSET_BITS  = $clog2(BLOCK_SIZE);
    localparam int WORD_BITS    = $clog2(BLOCK_SIZE * 8 / DATA_WIDTH);

    localparam [1:0] L1_MS_IDLE       = 2'b00;
    localparam [1:0] L1_MS_UNRESOLVED = 2'b01;
    localparam [1:0] L1_MS_RESOLVED   = 2'b10;

    localparam [1:0] L2_MS_IDLE       = 2'b00;
    localparam [1:0] L2_MS_UNRESOLVED = 2'b01;
    localparam [1:0] L2_MS_WAIT_MEM   = 2'b10;
    localparam [1:0] L2_MS_RESOLVED   = 2'b11;

    // Physical addresses use {tag, l2_index, 6'b0}. The low two index bits map L1 sets.
    localparam [PA_WIDTH-1:0] PA_S0T0 = {20'h00010, 4'h0, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T1 = {20'h00011, 4'h0, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T2 = {20'h00012, 4'h0, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S1T0 = {20'h00020, 4'h1, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S1T1 = {20'h00021, 4'h1, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S2T0 = {20'h00030, 4'h2, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S2T1 = {20'h00031, 4'h2, 6'h00};

    // Virtual addresses: only L1 index and word-offset bits matter.
    localparam [VA_WIDTH-1:0] VA_S0W0 = 48'h0000_0000_0000;
    localparam [VA_WIDTH-1:0] VA_S0W4 = 48'h0000_0000_0020;
    localparam [VA_WIDTH-1:0] VA_S0W5 = 48'h0000_0000_0028;
    localparam [VA_WIDTH-1:0] VA_S1W0 = 48'h0000_0000_0040;
    localparam [VA_WIDTH-1:0] VA_S2W0 = 48'h0000_0000_0080;

    localparam [BLOCK_SIZE*8-1:0] BLOCK_A = {8{64'hAAAA_AAAA_AAAA_AAAA}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_B = {8{64'hBBBB_BBBB_BBBB_BBBB}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_C = {8{64'hCCCC_CCCC_CCCC_CCCC}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_D = {8{64'hDDDD_DDDD_DDDD_DDDD}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_E = {8{64'hEEEE_EEEE_EEEE_EEEE}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_F = {8{64'hF0F0_F0F0_F0F0_F0F0}};

    logic                     clk;
    logic                     rst_n;

    // L1 front-end stimulus
    logic                     start_tag;
    logic [PA_WIDTH-1:0]      tlb_paddr;
    logic                     start_index;
    logic [VA_WIDTH-1:0]      trace_vaddr;
    logic                     is_write;
    logic [DATA_WIDTH-1:0]    wdata;

    // L1 <-> L2 wires
    wire                      l1_stall_out_to_lsq;
    wire                      l1_l2_wb_valid;
    wire [PA_WIDTH-1:0]       l1_l2_wb_paddr;
    wire [BLOCK_SIZE*8-1:0]   l1_l2_wb_data;
    wire                      l2_l1_wb_ack;
    wire                      l1_l2_req_valid;
    wire [PA_WIDTH-1:0]       l1_l2_req_paddr;
    wire                      l2_l1_data_valid;
    wire [PA_WIDTH-1:0]       l2_l1_data_paddr;
    wire [BLOCK_SIZE*8-1:0]   l2_l1_data;

    // L2 <-> memory wires
    logic                     mem_req_ready;
    logic                     mem_resp_valid;
    logic [PA_WIDTH-1:0]      mem_resp_paddr;
    logic [BLOCK_SIZE*8-1:0]  mem_resp_rdata;
    wire                      mem_req_valid;
    wire                      mem_req_is_write;
    wire [PA_WIDTH-1:0]       mem_req_addr;
    wire [BLOCK_SIZE*8-1:0]   mem_req_wdata;

    integer pass_cnt;
    integer fail_cnt;
    integer i;
    integer busy_cnt;

    l1_cache u_l1 (
        .clk                (clk),
        .rst_n              (rst_n),
        .start_tag          (start_tag),
        .tlb_paddr          (tlb_paddr),
        .start_index        (start_index),
        .trace_vaddr        (trace_vaddr),
        .is_write           (is_write),
        .wdata              (wdata),
        .l1_stall_out_to_lsq(l1_stall_out_to_lsq),
        .l2_wb_valid        (l1_l2_wb_valid),
        .l2_wb_paddr        (l1_l2_wb_paddr),
        .l2_wb_data         (l1_l2_wb_data),
        .l2_wb_ack          (l2_l1_wb_ack),
        .l2_req_valid       (l1_l2_req_valid),
        .l2_req_paddr       (l1_l2_req_paddr),
        .l2_data_valid      (l2_l1_data_valid),
        .l2_data_paddr      (l2_l1_data_paddr),
        .l2_data            (l2_l1_data)
    );

    l2_cache u_l2 (
        .clk          (clk),
        .rst_n        (rst_n),
        .l1_wb_valid  (l1_l2_wb_valid),
        .l1_wb_paddr  (l1_l2_wb_paddr),
        .l1_wb_data   (l1_l2_wb_data),
        .l1_wb_ack    (l2_l1_wb_ack),
        .l1_req_valid (l1_l2_req_valid),
        .l1_req_paddr (l1_l2_req_paddr),
        .l1_data_valid(l2_l1_data_valid),
        .l1_data_paddr(l2_l1_data_paddr),
        .l1_data      (l2_l1_data),
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

    function automatic [L1_INDEX_BITS-1:0] l1_index_from_pa(input [PA_WIDTH-1:0] paddr);
        begin
            l1_index_from_pa = paddr[OFFSET_BITS +: L1_INDEX_BITS];
        end
    endfunction

    function automatic [L1_TAG_SIZE-1:0] l1_tag_from_pa(input [PA_WIDTH-1:0] paddr);
        begin
            l1_tag_from_pa = paddr[PA_WIDTH-1 -: L1_TAG_SIZE];
        end
    endfunction

    function automatic [L2_INDEX_BITS-1:0] l2_index_from_pa(input [PA_WIDTH-1:0] paddr);
        begin
            l2_index_from_pa = paddr[OFFSET_BITS +: L2_INDEX_BITS];
        end
    endfunction

    function automatic [L2_TAG_SIZE-1:0] l2_tag_from_pa(input [PA_WIDTH-1:0] paddr);
        begin
            l2_tag_from_pa = paddr[PA_WIDTH-1 -: L2_TAG_SIZE];
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
            start_tag      = 1'b0;
            tlb_paddr      = '0;
            start_index    = 1'b0;
            trace_vaddr    = '0;
            is_write       = 1'b0;
            wdata          = '0;
            mem_req_ready  = 1'b0;
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

    task automatic send_req;
        input [VA_WIDTH-1:0] vaddr;
        input [PA_WIDTH-1:0] paddr;
        input                wr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(negedge clk);
            start_index = 1'b1;
            trace_vaddr = vaddr;
            is_write    = wr;
            wdata       = data;

            @(negedge clk);
            start_index = 1'b0;
            start_tag   = 1'b1;
            tlb_paddr   = paddr;

            @(negedge clk);
            start_tag   = 1'b0;
            tlb_paddr   = '0;
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

    task automatic preload_l2_line;
        input integer            way;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] block;
        input                    dirty;
        integer set_idx;
        begin
            @(negedge clk);
            set_idx = l2_index_from_pa(paddr);
            u_l2.set_contents[set_idx][way] = block;
            u_l2.tags[set_idx][way]         = l2_tag_from_pa(paddr);
            u_l2.set_valids[set_idx][way]   = 1'b1;
            u_l2.set_dirty[set_idx][way]    = dirty;
        end
    endtask

    task automatic preload_l1_line;
        input integer            way;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] block;
        input                    dirty;
        integer set_idx;
        begin
            @(negedge clk);
            set_idx = l1_index_from_pa(paddr);
            u_l1.set_contents[set_idx][way] = block;
            u_l1.tags[set_idx][way]         = l1_tag_from_pa(paddr);
            u_l1.set_valids[set_idx][way]   = 1'b1;
            u_l1.set_dirty[set_idx][way]    = dirty;
        end
    endtask

    task automatic count_busy_l2_mshrs;
        output integer count;
        integer idx;
        begin
            count = 0;
            for (idx = 0; idx < 4; idx = idx + 1)
                if (u_l2.mshr_state[idx] != L2_MS_IDLE)
                    count = count + 1;
        end
    endtask

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        busy_cnt = 0;
        idle_inputs();
        rst_n = 1'b1;

        // T1: Reset and idle
        $display("\n=== T1: Reset and idle outputs ===");
        apply_reset();
        chk_state("T1 l1 mshr[0] idle", u_l1.mshr_state[0], L1_MS_IDLE);
        chk_state("T1 l1 mshr[1] idle", u_l1.mshr_state[1], L1_MS_IDLE);
        chk_state("T1 l2 mshr[0] idle", u_l2.mshr_state[0], L2_MS_IDLE);
        chk_state("T1 l2 mshr[1] idle", u_l2.mshr_state[1], L2_MS_IDLE);
        chk_bit  ("T1 l1 stall low",    l1_stall_out_to_lsq, 1'b0);
        chk_bit  ("T1 no l1->l2 req",   l1_l2_req_valid,     1'b0);
        chk_bit  ("T1 no l1->l2 wb",    l1_l2_wb_valid,      1'b0);
        chk_bit  ("T1 no mem req",      mem_req_valid,       1'b0);

        // T2: L1 miss served by L2 hit
        $display("\n=== T2: L1 miss serviced by L2 hit ===");
        apply_reset();
        preload_l2_line(0, PA_S0T0, BLOCK_A, 1'b0);
        send_req(VA_S0W0, PA_S0T0, 1'b0, '0);
        chk_state("T2 l1 mshr becomes UNRESOLVED", u_l1.mshr_state[0], L1_MS_UNRESOLVED);
        chk_bit  ("T2 l1 advertises request to l2", l1_l2_req_valid, 1'b1);
        chk_pa   ("T2 l1 request address correct",  l1_l2_req_paddr, PA_S0T0);
        @(negedge clk);
        chk_bit  ("T2 l2 returns hit data", l2_l1_data_valid, 1'b1);
        chk_pa   ("T2 l2 return address matches", l2_l1_data_paddr, PA_S0T0);
        chk_bit  ("T2 no memory request on l2 hit", mem_req_valid, 1'b0);
        @(negedge clk);
        chk_state("T2 l1 mshr becomes RESOLVED after l2 data", u_l1.mshr_state[0], L1_MS_RESOLVED);
        @(negedge clk);
        chk_state("T2 l1 mshr frees after install", u_l1.mshr_state[0], L1_MS_IDLE);
        chk_bit  ("T2 l1 line valid after install", u_l1.set_valids[0][0], 1'b1);
        chk_wide ("T2 l1 installed block matches", u_l1.set_contents[0][0], BLOCK_A);

        // T3: End-to-end miss to memory fill
        $display("\n=== T3: End-to-end miss to memory fill ===");
        apply_reset();
        send_req(VA_S1W0, PA_S1T0, 1'b0, '0);
        chk_state("T3 l1 mshr unresolved", u_l1.mshr_state[0], L1_MS_UNRESOLVED);
        @(negedge clk);
        chk_state("T3 l2 mshr unresolved", u_l2.mshr_state[0], L2_MS_UNRESOLVED);
        chk_bit  ("T3 l2 drives memory request", mem_req_valid, 1'b1);
        chk_bit  ("T3 memory request is read", mem_req_is_write, 1'b0);
        chk_pa   ("T3 memory request address matches", mem_req_addr, PA_S1T0);
        accept_mem_req();
        chk_state("T3 l2 mshr advances to WAIT_MEM", u_l2.mshr_state[0], L2_MS_WAIT_MEM);
        mem_return(PA_S1T0, BLOCK_B);
        chk_state("T3 memory response sets RESOLVED", u_l2.mshr_state[0], L2_MS_RESOLVED);
        @(negedge clk);
        chk_state("T3 l2 mshr frees after install", u_l2.mshr_state[0], L2_MS_IDLE);
        chk_bit  ("T3 l2 returns block to l1", l2_l1_data_valid, 1'b1);
        chk_wide ("T3 l2 installed block matches", u_l2.set_contents[1][0], BLOCK_B);
        @(negedge clk);
        chk_state("T3 l1 mshr becomes RESOLVED", u_l1.mshr_state[0], L1_MS_RESOLVED);
        @(negedge clk);
        chk_state("T3 l1 mshr frees after install", u_l1.mshr_state[0], L1_MS_IDLE);
        chk_wide ("T3 l1 installed block matches", u_l1.set_contents[1][0], BLOCK_B);

        // T4: End-to-end store miss
        $display("\n=== T4: End-to-end store miss ===");
        apply_reset();
        send_req(VA_S0W5, PA_S0T1, 1'b1, 64'hDEAD_CAFE_1234_5678);
        @(negedge clk);
        chk_state("T4 l2 allocates unresolved miss", u_l2.mshr_state[0], L2_MS_UNRESOLVED);
        accept_mem_req();
        mem_return(PA_S0T1, BLOCK_C);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        chk_bit ("T4 l1 installed line is dirty", u_l1.set_dirty[0][0], 1'b1);
        chk_wide("T4 l2 keeps clean fetched block", u_l2.set_contents[0][0], BLOCK_C);
        chk_bit ("T4 l2 fetched line stays clean", u_l2.set_dirty[0][0], 1'b0);
        chk_wide("T4 l1 line contains store-updated block",
                 u_l1.set_contents[0][0],
                 {64'hCCCC_CCCC_CCCC_CCCC, 64'hCCCC_CCCC_CCCC_CCCC,
                  64'hDEAD_CAFE_1234_5678, 64'hCCCC_CCCC_CCCC_CCCC,
                  64'hCCCC_CCCC_CCCC_CCCC, 64'hCCCC_CCCC_CCCC_CCCC,
                  64'hCCCC_CCCC_CCCC_CCCC, 64'hCCCC_CCCC_CCCC_CCCC});

        // T5: Dirty L1 eviction writeback to L2
        $display("\n=== T5: Dirty L1 eviction writes back into L2 ===");
        apply_reset();
        preload_l1_line(0, PA_S0T0, BLOCK_A, 1'b1);
        preload_l1_line(1, PA_S0T1, BLOCK_B, 1'b0);
        @(negedge clk);
        u_l1.set_contents[0][0][4*64 +: 64] = 64'hFACE_FACE_FACE_FACE;
        u_l1.lru[0] = 1'b0;
        preload_l2_line(0, PA_S0T0, BLOCK_A, 1'b0);
        preload_l2_line(1, PA_S0T2, BLOCK_D, 1'b0);
        send_req(VA_S0W0, PA_S0T2, 1'b0, '0);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        chk_bit ("T5 l1 writeback queue drives l2 wb", l1_l2_wb_valid, 1'b1);
        chk_pa  ("T5 l1 writeback address is victim", l1_l2_wb_paddr, PA_S0T0);
        @(negedge clk);
        chk_pa  ("T5 l2 acknowledges writeback",      l2_l1_wb_ack,    1'b1);
        chk_wide("T5 l2 copy updated with dirty victim data", u_l2.set_contents[0][0], u_l1.wb_data_q[u_l1.wb_head]);
        @(negedge clk);
        chk_bit ("T5 l1 wb queue drains after ack", u_l1.wb_empty, 1'b1);
        chk_wide("T5 l1 new fill installed", u_l1.set_contents[0][0], BLOCK_D);

        // T6: Two outstanding misses across both levels
        $display("\n=== T6: Two outstanding misses synchronize across both levels ===");
        apply_reset();
        send_req(VA_S0W0, PA_S0T0, 1'b0, '0);
        @(negedge clk);
        send_req(VA_S1W0, PA_S1T1, 1'b0, '0);
        @(negedge clk);
        chk_state("T6 l1 mshr[0] unresolved", u_l1.mshr_state[0], L1_MS_UNRESOLVED);
        chk_state("T6 l1 mshr[1] unresolved", u_l1.mshr_state[1], L1_MS_UNRESOLVED);
        chk_bit  ("T6 l1 stall high when both mshrs busy", l1_stall_out_to_lsq, 1'b1);
        count_busy_l2_mshrs(busy_cnt);
        chk_int  ("T6 l2 only tracks first miss until l1 advances", busy_cnt, 1);
        chk_pa   ("T6 first memory request is oldest miss", mem_req_addr, PA_S0T0);
        accept_mem_req();
        chk_state("T6 first l2 mshr enters WAIT_MEM", u_l2.mshr_state[0], L2_MS_WAIT_MEM);
        mem_return(PA_S0T0, BLOCK_E);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        chk_bit  ("T6 stall clears after first l1 mshr frees", l1_stall_out_to_lsq, 1'b0);
        @(negedge clk);
        count_busy_l2_mshrs(busy_cnt);
        chk_int  ("T6 l2 allocates second miss after first drains", busy_cnt, 1);
        chk_pa   ("T6 second memory request appears after first drain", mem_req_addr, PA_S1T1);
        accept_mem_req();
        mem_return(PA_S1T1, BLOCK_F);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        chk_state("T6 l1 mshr[0] returns to IDLE", u_l1.mshr_state[0], L1_MS_IDLE);
        chk_state("T6 l1 mshr[1] returns to IDLE", u_l1.mshr_state[1], L1_MS_IDLE);
        chk_wide ("T6 first returned block installed", u_l1.set_contents[0][0], BLOCK_E);
        chk_wide ("T6 second returned block installed", u_l1.set_contents[1][0], BLOCK_F);

        $display("\n==========================================");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("  ALL TESTS PASSED");
        else               $display("  *** FAILURES DETECTED ***");
        $display("==========================================\n");
        $finish;
    end

endmodule
