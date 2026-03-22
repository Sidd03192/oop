`timescale 1ns/1ps

module tb_l1_cache;

    // ── Parameters ────────────────────────────────────────────────────────
    localparam PA_WIDTH   = 30;
    localparam BLOCK_SIZE = 64;
    localparam DATA_WIDTH = 64;
    localparam TAG_SIZE   = 24;
    localparam NUM_MSHRS  = 2;

    localparam [1:0] MS_IDLE       = 2'b00;
    localparam [1:0] MS_UNRESOLVED = 2'b01;
    localparam [1:0] MS_RESOLVED   = 2'b10;

    // ── Test addresses (all at module scope for Icarus compatibility) ──────
    // PA layout: [29:6]=tag(24b)  [5:4]=index(2b)  [3:0]=offset(4b)
    // vaddr[7:6] maps to index

    localparam [PA_WIDTH-1:0]     PADDR_A = {24'hABCDEF, 2'b00, 4'b0000};
    localparam [47:0]             VADDR_A = {40'h0, 2'b00, 6'h0};
    localparam [PA_WIDTH-1:0]     PADDR_B = {24'h123456, 2'b01, 4'b0000};
    localparam [47:0]             VADDR_B = {40'h0, 2'b01, 6'h0};
    localparam [PA_WIDTH-1:0]     PADDR_C = {24'hC00001, 2'b10, 4'b0};
    localparam [47:0]             VADDR_C = {40'h0, 2'b10, 6'h0};
    localparam [PA_WIDTH-1:0]     PADDR_D = {24'hD00002, 2'b11, 4'b0};
    localparam [47:0]             VADDR_D = {40'h0, 2'b11, 6'h0};
    localparam [PA_WIDTH-1:0]     PADDR_E = {24'hE00003, 2'b00, 4'b0};
    localparam [47:0]             VADDR_E = {40'h0, 2'b00, 6'h0};
    localparam [PA_WIDTH-1:0]     PADDR_F = {24'hFFFFFF, 2'b00, 4'b0};
    localparam [47:0]             VADDR_F = {40'h0, 2'b00, 6'h0};

    // 512-bit test blocks
    localparam [BLOCK_SIZE*8-1:0] BLOCK_A = 512'hDEADBEEFCAFEBABE_DEADBEEFCAFEBABE_DEADBEEFCAFEBABE_DEADBEEFCAFEBABE_DEADBEEFCAFEBABE_DEADBEEFCAFEBABE_DEADBEEFCAFEBABE_DEADBEEFCAFEBABE;
    localparam [BLOCK_SIZE*8-1:0] BLOCK_B = 512'hAAAAAAAABBBBBBBB_CCCCCCCCDDDDDDDD_EEEEEEEEFFFFFFF_001122334455667_8899AABBCCDDEEFF_0011223344556677_8899AABBCCDDEEFF_0011223344556677;
    localparam [BLOCK_SIZE*8-1:0] BLOCK_F = 512'hFFFFFFFFFFFFFFFF_FFFFFFFFFFFFFFFF_FFFFFFFFFFFFFFFF_FFFFFFFFFFFFFFFF_FFFFFFFFFFFFFFFF_FFFFFFFFFFFFFFFF_FFFFFFFFFFFFFFFF_FFFFFFFFFFFFFFFF;

    // ── DUT signals ───────────────────────────────────────────────────────
    reg                    clk;
    reg                    rst_n;
    reg                    start_tag;
    reg  [PA_WIDTH-1:0]    tlb_paddr;
    reg                    start_index;
    reg  [47:0]            trace_vaddr;
    reg                    is_write;
    reg  [DATA_WIDTH-1:0]  wdata;
    reg                    l2_wb_ack;
    reg                    l2_data_valid;
    reg  [PA_WIDTH-1:0]    l2_data_paddr;
    reg  [BLOCK_SIZE*8-1:0] l2_data;

    wire                    l1_stall_out_to_lsq;
    wire                    l2_wb_valid;
    wire [PA_WIDTH-1:0]     l2_wb_paddr;
    wire [BLOCK_SIZE*8-1:0] l2_wb_data;
    wire                    l2_req_valid;
    wire [PA_WIDTH-1:0]     l2_req_paddr;

    // ── DUT ───────────────────────────────────────────────────────────────
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

    // ── Clock ─────────────────────────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Pass/fail ─────────────────────────────────────────────────────────
    integer pass_cnt;
    integer fail_cnt;

    task check_bit;
        input [63:0] line_num;
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
        input [63:0]      line_num;
        input [255:0]     name;
        input [PA_WIDTH-1:0] got;
        input [PA_WIDTH-1:0] expected;
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

    task check_state;
        input [63:0]  line_num;
        input [255:0] name;
        input [1:0]   got;
        input [1:0]   expected;
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

    // ── idle all inputs ───────────────────────────────────────────────────
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

    // ── send a 2-cycle request (index cycle then tag cycle) ───────────────
    task send_request;
        input [47:0]          vaddr;
        input [PA_WIDTH-1:0]  paddr;
        input                 wr;
        input [DATA_WIDTH-1:0] data;
    begin
        @(negedge clk);
        start_index = 1;
        trace_vaddr = vaddr;
        is_write    = wr;
        wdata       = data;
        @(negedge clk);
        start_index = 0;
        start_tag   = 1;
        tlb_paddr   = paddr;
        @(negedge clk);
        start_tag   = 0;
        tlb_paddr   = 0;
    end
    endtask

    // ── simulate L2 returning a block for one cycle ───────────────────────
    task l2_respond;
        input [PA_WIDTH-1:0]     paddr;
        input [BLOCK_SIZE*8-1:0] block;
    begin
        @(negedge clk);
        l2_data_valid = 1;
        l2_data_paddr = paddr;
        l2_data       = block;
        @(negedge clk);
        l2_data_valid = 0;
        l2_data_paddr = 0;
        l2_data       = 0;
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

        check_state(0, "T1 mshr_state[0]==IDLE", dut.mshr_state[0], MS_IDLE);
        check_state(0, "T1 mshr_state[1]==IDLE", dut.mshr_state[1], MS_IDLE);
        check_bit  (0, "T1 wb_valid==0",          dut.wb_valid,      1'b0);
        check_bit  (0, "T1 l2_req_valid==0",       l2_req_valid,      1'b0);

        // ─────────────────────────────────────────────────────────────────
        // T2: MISS -> MSHR allocation, l2_req_valid asserts same clock
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T2: Miss -> MSHR allocation ===");
        send_request(VADDR_A, PADDR_A, 1'b0, 64'h0);
        @(negedge clk);

        check_state(0, "T2 mshr_state[0]==UNRESOLVED", dut.mshr_state[0], MS_UNRESOLVED);
        check_vec  (0, "T2 mshr_paddr[0]==PADDR_A",    dut.mshr_paddr[0], PADDR_A);
        check_bit  (0, "T2 l2_req_valid==1",            l2_req_valid,      1'b1);
        check_vec  (0, "T2 l2_req_paddr==PADDR_A",      l2_req_paddr,      PADDR_A);

        // ─────────────────────────────────────────────────────────────────
        // T3: L2 data return -> MSHR transitions to RESOLVED
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T3: L2 data return -> RESOLVED ===");
        l2_respond(PADDR_A, BLOCK_A);

        check_state(0, "T3 mshr_state[0]==RESOLVED", dut.mshr_state[0], MS_RESOLVED);
        check_bit  (0, "T3 l2_req_valid==0",          l2_req_valid,      1'b0);

        // ─────────────────────────────────────────────────────────────────
        // T4: Cache install (state-0 loop installs the resolved block)
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T4: Cache install ===");
        @(negedge clk);
        @(negedge clk);

        check_state(0, "T4 mshr_state[0]==IDLE after install", dut.mshr_state[0], MS_IDLE);
        check_bit  (0, "T4 set_valids[0][0]==1",               dut.set_valids[0][0], 1'b1);

        // ─────────────────────────────────────────────────────────────────
        // T5: Second miss fills another MSHR slot
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T5: Second MSHR slot ===");
        send_request(VADDR_B, PADDR_B, 1'b0, 64'h0);
        @(negedge clk);

        check_bit(0, "T5 l2_req_valid==1 after miss B", l2_req_valid, 1'b1);
        check_vec(0, "T5 l2_req_paddr==PADDR_B",        l2_req_paddr, PADDR_B);

        // respond so we can continue
        l2_respond(PADDR_B, BLOCK_B);
        @(negedge clk); @(negedge clk); @(negedge clk);

        // ─────────────────────────────────────────────────────────────────
        // T6: MSHR full -> stall signal
        // Fill both slots without L2 responding
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T6: MSHR full stall ===");
        send_request(VADDR_C, PADDR_C, 1'b0, 64'h0);
        @(negedge clk);
        send_request(VADDR_D, PADDR_D, 1'b0, 64'h0);
        @(negedge clk);
        // Third miss with both slots occupied
        send_request(VADDR_E, PADDR_E, 1'b0, 64'h0);
        @(negedge clk);

        check_bit(0, "T6 l1_stall_out_to_lsq==1 when full", l1_stall_out_to_lsq, 1'b1);

        // drain
        l2_respond(PADDR_C, 512'hCC);
        @(negedge clk);
        l2_respond(PADDR_D, 512'hDD);
        @(negedge clk); @(negedge clk); @(negedge clk);

        // ─────────────────────────────────────────────────────────────────
        // T7: Dirty writeback
        // Store hit at PADDR_A marks line dirty, then eviction triggers wb
        // ─────────────────────────────────────────────────────────────────
        $display("\n=== T7: Dirty writeback ===");
        // Store hit (PADDR_A line was installed in T4)
        send_request(VADDR_A, PADDR_A, 1'b1, 64'hDEAD_CAFE);
        @(negedge clk);
        check_bit(0, "T7 set_dirty[0][0]==1 after store hit", dut.set_dirty[0][0], 1'b1);

        // Bring in a new block at index=0 with different tag.
        // Since this is a 2-way cache and way 1 is still invalid, this should
        // fill the empty way and not trigger a writeback yet.
        send_request(VADDR_F, PADDR_F, 1'b0, 64'h0);
        @(negedge clk);
        l2_respond(PADDR_F, BLOCK_F);
        @(negedge clk); @(negedge clk);

        check_bit(0, "T7 no wb when filling empty way", l2_wb_valid, 1'b0);

        // One more miss to the same set forces a real eviction.
        // A should now be the LRU victim and since it is dirty we should see
        // a writeback for PADDR_A.
        send_request(VADDR_E, PADDR_E, 1'b0, 64'h0);
        @(negedge clk);
        l2_respond(PADDR_E, 512'hEE);
        @(negedge clk); @(negedge clk);

        check_bit(0, "T7 l2_wb_valid==1 after dirty evict", l2_wb_valid, 1'b1);
        check_vec(0, "T7 l2_wb_paddr==PADDR_A",             l2_wb_paddr, PADDR_A);

        // L2 acks writeback
        @(negedge clk);
        l2_wb_ack = 1;
        @(negedge clk);
        l2_wb_ack = 0;
        @(negedge clk);
        check_bit(0, "T7 l2_wb_valid cleared after ack", l2_wb_valid, 1'b0);

        // ─────────────────────────────────────────────────────────────────
        $display("\n==========================================");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        $display("==========================================\n");
        $finish;
    end

endmodule
