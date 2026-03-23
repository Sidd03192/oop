`timescale 1ns/1ps

// Accurate directed testbench for l1_cache.sv.
//
// Test plan:
//   T1  Reset and idle outputs
//       Confirms the cache, MSHRs, stall signal, and writeback queue reset cleanly.
//
//   T2  State-1 stall timing
//       Sends one request and checks that stall rises as soon as the request is latched
//       into the cache's internal pipeline while the TLB/tag result is still pending.
//
//   T3  Cold miss -> MSHR allocation -> L2 request
//       Verifies a miss allocates an UNRESOLVED MSHR entry and advertises the block
//       address on the L2 request interface.
//
//   T4  L2 response -> RESOLVED -> install
//       Verifies the returned block updates the MSHR, installs into the cache, and
//       frees the MSHR on the following install cycle.
//
//   T5  Store hit updates only the selected word
//       Verifies write hits set the dirty bit and modify only the chosen 64-bit word.
//
//   T6  Same-set LRU replacement and dirty writeback
//       Fills both ways in one set, makes one way dirty, steers LRU to evict that way,
//       then checks the writeback address/data and the new installed line.
//
//   T7  Two outstanding MSHRs and arbitration
//       Creates two misses in different sets, checks both MSHRs are occupied, verifies
//       l2_req advertises the oldest unresolved entry first, and confirms stall when
//       all MSHRs are occupied.
//
//   T8  Stall auto-clear after MSHR drain
//       Returns data to one MSHR and verifies stall drops automatically once one slot
//       becomes free again.
//
//   T9  Writeback FIFO queues back-to-back dirty evictions
//       Forces two dirty evictions on consecutive install cycles without acknowledging
//       the first writeback, then checks both writebacks are preserved and drain in order.
//
//   T10 Spurious L2 response is ignored
//       Drives l2_data_valid with an address that matches no outstanding miss and checks
//       that no MSHR state changes.

module tb_l1_accurate;

    localparam int PA_WIDTH    = 30;
    localparam int VA_WIDTH    = 48;
    localparam int BLOCK_SIZE  = 64;
    localparam int DATA_WIDTH  = 64;
    localparam int NUM_MSHRS   = 2;
    localparam int L1_CAPACITY = 512;
    localparam int L1_WAYS     = 2;
    localparam int L1_SETS     = L1_CAPACITY / (BLOCK_SIZE * L1_WAYS);
    localparam int INDEX_BITS  = $clog2(L1_SETS);
    localparam int OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam int TAG_SIZE    = PA_WIDTH - INDEX_BITS - OFFSET_BITS;

    localparam [1:0] MS_IDLE       = 2'b00;
    localparam [1:0] MS_UNRESOLVED = 2'b01;
    localparam [1:0] MS_RESOLVED   = 2'b10;

    // Physical addresses: {tag, index, 6'b0}
    localparam [PA_WIDTH-1:0] PA_S0T0 = {22'h000001, 2'b00, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T1 = {22'h000002, 2'b00, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S0T2 = {22'h000003, 2'b00, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S1T0 = {22'h000004, 2'b01, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S1T1 = {22'h000005, 2'b01, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S1T2 = {22'h000006, 2'b01, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S2T0 = {22'h000010, 2'b10, 6'h00};
    localparam [PA_WIDTH-1:0] PA_S3T0 = {22'h000011, 2'b11, 6'h00};

    // Virtual addresses: only index and word-offset bits matter.
    localparam [VA_WIDTH-1:0] VA_S0W0 = 48'h0000_0000_0000;
    localparam [VA_WIDTH-1:0] VA_S0W5 = 48'h0000_0000_0028;
    localparam [VA_WIDTH-1:0] VA_S1W0 = 48'h0000_0000_0040;
    localparam [VA_WIDTH-1:0] VA_S2W0 = 48'h0000_0000_0080;
    localparam [VA_WIDTH-1:0] VA_S3W0 = 48'h0000_0000_00C0;

    localparam [BLOCK_SIZE*8-1:0] BLOCK_A = {8{64'hAAAA_AAAA_AAAA_AAAA}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_B = {8{64'hBBBB_BBBB_BBBB_BBBB}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_C = {8{64'hCCCC_CCCC_CCCC_CCCC}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_D = {8{64'hDDDD_DDDD_DDDD_DDDD}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_E = {8{64'hEEEE_EEEE_EEEE_EEEE}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_F = {8{64'hF0F0_F0F0_F0F0_F0F0}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_ZERO = '0;

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

    integer pass_cnt;
    integer fail_cnt;

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

    initial clk = 1'b0;
    always #5 clk = ~clk;

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

    task automatic chk_64;
        input [255:0] name;
        input [63:0]  got;
        input [63:0]  exp;
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
            start_tag     = 1'b0;
            tlb_paddr     = '0;
            start_index   = 1'b0;
            trace_vaddr   = '0;
            is_write      = 1'b0;
            wdata         = '0;
            l2_wb_ack     = 1'b0;
            l2_data_valid = 1'b0;
            l2_data_paddr = '0;
            l2_data       = '0;
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
        input [63:0]         data;
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

    task automatic l2_return;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] block;
        begin
            @(negedge clk);
            l2_data_valid = 1'b1;
            l2_data_paddr = paddr;
            l2_data       = block;

            @(negedge clk);
            l2_data_valid = 1'b0;
            l2_data_paddr = '0;
            l2_data       = '0;
        end
    endtask

    task automatic full_miss;
        input [VA_WIDTH-1:0]     vaddr;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] block;
        begin
            send_req(vaddr, paddr, 1'b0, '0);
            l2_return(paddr, block);
            @(negedge clk);
            @(negedge clk);
        end
    endtask

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        idle_inputs();
        rst_n = 1'b1;

        // T1: Reset and idle outputs
        $display("\n=== T1: Reset and idle outputs ===");
        apply_reset();
        chk_state("T1 mshr[0] reset to IDLE", dut.mshr_state[0], MS_IDLE);
        chk_state("T1 mshr[1] reset to IDLE", dut.mshr_state[1], MS_IDLE);
        chk_bit  ("T1 stall low after reset", l1_stall_out_to_lsq, 1'b0);
        chk_bit  ("T1 l2_req_valid low",      l2_req_valid,        1'b0);
        chk_bit  ("T1 l2_wb_valid low",       l2_wb_valid,         1'b0);
        chk_bit  ("T1 wb queue empty",        dut.wb_empty,        1'b1);

        // T2: State-1 stall timing
        $display("\n=== T2: State-1 stall timing ===");
        apply_reset();
        @(negedge clk);
        start_index = 1'b1;
        trace_vaddr = VA_S0W0;
        is_write    = 1'b0;
        wdata       = '0;
        @(negedge clk);
        start_index = 1'b0;
        chk_bit("T2 stall rises during TLB wait", l1_stall_out_to_lsq, 1'b1);
        chk_bit("T2 no l2 request before tag",    l2_req_valid,        1'b0);
        start_tag = 1'b1;
        tlb_paddr = PA_S0T0;
        @(negedge clk);
        start_tag = 1'b0;
        tlb_paddr = '0;
        @(negedge clk);
        chk_bit("T2 stall drops after miss allocates", l1_stall_out_to_lsq, 1'b0);

        // T2b: Overlap one request tagging while the next request indexes
        $display("\n=== T2b: Overlap index of request B with tag of request A ===");
        apply_reset();
        @(negedge clk);
        start_index = 1'b1;
        trace_vaddr = VA_S0W0;
        is_write    = 1'b0;
        wdata       = '0;
        @(negedge clk);
        start_tag   = 1'b1;
        tlb_paddr   = PA_S0T0;
        start_index = 1'b1;
        trace_vaddr = VA_S1W0;
        @(negedge clk);
        start_tag   = 1'b0;
        tlb_paddr   = '0;
        start_index = 1'b0;
        chk_state("T2b request A becomes unresolved", dut.mshr_state[0], MS_UNRESOLVED);
        chk_pa   ("T2b first miss requests PA_S0T0",  dut.mshr_paddr[0], PA_S0T0);
        chk_bit  ("T2b request B remains buffered",   (dut.state == 3'd1), 1'b1);
        chk_pa   ("T2b l2_req still points at A",     l2_req_paddr, PA_S0T0);
        @(negedge clk);
        chk_bit  ("T2b stall high while B waits for tag", l1_stall_out_to_lsq, 1'b1);
        start_tag = 1'b1;
        tlb_paddr = PA_S1T0;
        @(negedge clk);
        start_tag = 1'b0;
        tlb_paddr = '0;
        @(negedge clk);
        chk_state("T2b request B becomes unresolved", dut.mshr_state[1], MS_UNRESOLVED);
        chk_pa   ("T2b second miss requests PA_S1T0", dut.mshr_paddr[1], PA_S1T0);
        chk_bit  ("T2b request buffer drains after second tag", (dut.state == 3'd0), 1'b1);

        // T3: Cold miss -> MSHR allocation -> L2 request
        $display("\n=== T3: Cold miss allocates an MSHR ===");
        apply_reset();
        @(negedge clk);
        start_index = 1'b1;
        trace_vaddr = VA_S0W0;
        is_write    = 1'b0;
        wdata       = '0;
        @(negedge clk);
        start_index = 1'b0;
        start_tag   = 1'b1;
        tlb_paddr   = PA_S0T0;
        @(negedge clk);
        start_tag   = 1'b0;
        tlb_paddr   = '0;
        @(negedge clk);
        chk_state("T3 mshr[0] becomes UNRESOLVED", dut.mshr_state[0], MS_UNRESOLVED);
        chk_pa   ("T3 mshr[0] captures paddr",     dut.mshr_paddr[0], PA_S0T0);
        chk_bit  ("T3 l2_req_valid asserted",      l2_req_valid,      1'b1);
        chk_pa   ("T3 l2_req_paddr matches miss",  l2_req_paddr,      PA_S0T0);

        // T4: L2 response -> RESOLVED -> install
        $display("\n=== T4: L2 response installs the line and frees the MSHR ===");
        apply_reset();
        @(negedge clk);
        start_index = 1'b1;
        trace_vaddr = VA_S0W0;
        @(negedge clk);
        start_index = 1'b0;
        start_tag   = 1'b1;
        tlb_paddr   = PA_S0T0;
        @(negedge clk);
        start_tag   = 1'b0;
        tlb_paddr   = '0;
        @(negedge clk);
        l2_return(PA_S0T0, BLOCK_A);
        chk_state("T4 mshr[0] becomes RESOLVED", dut.mshr_state[0], MS_RESOLVED);
        chk_bit  ("T4 l2_req drops after response", l2_req_valid, 1'b0);
        @(negedge clk);
        @(negedge clk);
        chk_state("T4 mshr[0] returns to IDLE",      dut.mshr_state[0], MS_IDLE);
        chk_bit  ("T4 set0 way0 valid",              dut.set_valids[0][0], 1'b1);
        chk_wide ("T4 set0 way0 data matches block", dut.set_contents[0][0], BLOCK_A);

        // T5: Store hit updates only the selected word
        $display("\n=== T5: Store hit updates one word and sets dirty ===");
        apply_reset();
        full_miss(VA_S0W0, PA_S0T0, BLOCK_A);
        send_req(VA_S0W5, PA_S0T0, 1'b1, 64'hDEAD_CAFE_1234_5678);
        @(negedge clk);
        chk_bit("T5 set0 way0 dirty after store hit", dut.set_dirty[0][0], 1'b1);
        chk_64 ("T5 word5 overwritten",               dut.set_contents[0][0][5*64 +: 64],
                                                      64'hDEAD_CAFE_1234_5678);
        chk_64 ("T5 word0 unchanged",                 dut.set_contents[0][0][0*64 +: 64],
                                                      64'hAAAA_AAAA_AAAA_AAAA);
        chk_64 ("T5 word7 unchanged",                 dut.set_contents[0][0][7*64 +: 64],
                                                      64'hAAAA_AAAA_AAAA_AAAA);

        // T6: Same-set LRU replacement and dirty writeback
        $display("\n=== T6: Same-set LRU chooses the correct dirty victim ===");
        apply_reset();
        full_miss(VA_S0W0, PA_S0T0, BLOCK_A);
        full_miss(VA_S0W0, PA_S0T1, BLOCK_B);
        send_req(VA_S0W5, PA_S0T1, 1'b1, 64'hFACE_FACE_FACE_FACE);
        @(negedge clk);
        send_req(VA_S0W0, PA_S0T0, 1'b0, '0);
        @(negedge clk);
        chk_bit("T6 LRU points to way1 after hit on way0", dut.lru[0], 1'b1);
        send_req(VA_S0W0, PA_S0T2, 1'b0, '0);
        l2_return(PA_S0T2, BLOCK_C);
        @(negedge clk);
        @(negedge clk);
        chk_bit("T6 writeback asserted for dirty victim", l2_wb_valid, 1'b1);
        chk_pa ("T6 writeback address is PA_S0T1",        l2_wb_paddr, PA_S0T1);
        chk_64 ("T6 victim data keeps stored word",       l2_wb_data[5*64 +: 64],
                                                         64'hFACE_FACE_FACE_FACE);
        chk_wide("T6 replacement line installed",         dut.set_contents[0][1], BLOCK_C);

        // T7: Two outstanding MSHRs and arbitration
        $display("\n=== T7: Two misses occupy both MSHRs and arbitrate oldest first ===");
        apply_reset();
        send_req(VA_S0W0, PA_S0T0, 1'b0, '0);
        @(negedge clk);
        send_req(VA_S1W0, PA_S1T0, 1'b0, '0);
        @(negedge clk);
        chk_state("T7 mshr[0] unresolved", dut.mshr_state[0], MS_UNRESOLVED);
        chk_state("T7 mshr[1] unresolved", dut.mshr_state[1], MS_UNRESOLVED);
        chk_bit  ("T7 stall high when full", l1_stall_out_to_lsq, 1'b1);
        chk_pa   ("T7 l2_req shows oldest miss first", l2_req_paddr, PA_S0T0);

        // T8: Stall auto-clear after one MSHR drains
        $display("\n=== T8: Stall auto-clears when one MSHR becomes free ===");
        l2_return(PA_S0T0, BLOCK_A);
        chk_state("T8 mshr[0] resolved after response", dut.mshr_state[0], MS_RESOLVED);
        chk_pa   ("T8 l2_req moves to second miss",      l2_req_paddr,      PA_S1T0);
        @(negedge clk);
        @(negedge clk);
        chk_state("T8 mshr[0] freed after install", dut.mshr_state[0], MS_IDLE);
        chk_bit  ("T8 stall drops once one slot is free", l1_stall_out_to_lsq, 1'b0);
        l2_return(PA_S1T0, BLOCK_B);
        @(negedge clk);
        @(negedge clk);
        chk_state("T8 mshr[1] eventually returns to IDLE", dut.mshr_state[1], MS_IDLE);

        // T9: Writeback FIFO queues back-to-back dirty evictions
        $display("\n=== T9: Writeback FIFO keeps two dirty evictions in order ===");
        apply_reset();
        full_miss(VA_S0W0, PA_S0T0, BLOCK_A);
        full_miss(VA_S0W0, PA_S0T1, BLOCK_B);
        send_req(VA_S0W0, PA_S0T0, 1'b1, 64'h1111_1111_1111_1111);
        @(negedge clk);
        send_req(VA_S0W0, PA_S0T1, 1'b0, '0);
        @(negedge clk);
        full_miss(VA_S1W0, PA_S1T0, BLOCK_D);
        full_miss(VA_S1W0, PA_S1T1, BLOCK_E);
        send_req(VA_S1W0, PA_S1T0, 1'b1, 64'h2222_2222_2222_2222);
        @(negedge clk);
        send_req(VA_S1W0, PA_S1T1, 1'b0, '0);
        @(negedge clk);
        chk_bit("T9 set0 victim is dirty before eviction", dut.set_dirty[0][0], 1'b1);
        chk_bit("T9 set0 LRU points at dirty way0",        dut.lru[0],         1'b0);
        chk_bit("T9 set1 victim is dirty before eviction", dut.set_dirty[1][0], 1'b1);
        chk_bit("T9 set1 LRU points at dirty way0",        dut.lru[1],         1'b0);

        send_req(VA_S0W0, PA_S0T2, 1'b0, '0);
        @(negedge clk);
        send_req(VA_S1W0, PA_S1T2, 1'b0, '0);
        @(negedge clk);
        chk_bit("T9 both MSHRs occupied before responses", l1_stall_out_to_lsq, 1'b1);

        l2_return(PA_S0T2, BLOCK_C);
        l2_return(PA_S1T2, BLOCK_F);
        @(negedge clk);
        @(negedge clk);
        chk_state("T9 mshr[0] drained after responses", dut.mshr_state[0], MS_IDLE);
        chk_state("T9 mshr[1] drained after responses", dut.mshr_state[1], MS_IDLE);
        chk_bit("T9 wb_valid high after first queued eviction", l2_wb_valid, 1'b1);
        chk_pa ("T9 first queued writeback is set0 victim",     l2_wb_paddr, PA_S0T0);
        chk_bit("T9 wb_count reaches 2",                        (dut.wb_count == 2), 1'b1);

        @(negedge clk);
        l2_wb_ack = 1'b1;
        @(negedge clk);
        l2_wb_ack = 1'b0;
        @(negedge clk);
        chk_bit("T9 wb_valid stays high after first ack", l2_wb_valid, 1'b1);
        chk_pa ("T9 second queued writeback is set1 victim", l2_wb_paddr, PA_S1T0);

        @(negedge clk);
        l2_wb_ack = 1'b1;
        @(negedge clk);
        l2_wb_ack = 1'b0;
        @(negedge clk);
        chk_bit("T9 wb_valid clears after second ack", l2_wb_valid, 1'b0);
        chk_bit("T9 wb queue empty after both acks",   dut.wb_empty, 1'b1);

        // T10: Spurious L2 response is ignored
        $display("\n=== T10: Spurious L2 response does not corrupt MSHRs ===");
        apply_reset();
        @(negedge clk);
        l2_data_valid = 1'b1;
        l2_data_paddr = PA_S3T0;
        l2_data       = BLOCK_ZERO;
        @(negedge clk);
        l2_data_valid = 1'b0;
        l2_data_paddr = '0;
        l2_data       = '0;
        @(negedge clk);
        chk_state("T10 mshr[0] stays IDLE", dut.mshr_state[0], MS_IDLE);
        chk_state("T10 mshr[1] stays IDLE", dut.mshr_state[1], MS_IDLE);
        chk_bit  ("T10 no l2 request appears", l2_req_valid, 1'b0);

        $display("\n==========================================");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("  ALL TESTS PASSED");
        else               $display("  *** FAILURES DETECTED ***");
        $display("==========================================\n");
        $finish;
    end

endmodule
