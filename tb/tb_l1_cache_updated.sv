`timescale 1ns/1ps

module tb_l1_cache_updated;

    //==========================================================================
    // Geometry used by the current DUT
    //==========================================================================
    localparam PA_WIDTH   = 30;
    localparam VA_WIDTH   = 48;
    localparam DATA_WIDTH = 64;
    localparam BLOCK_SIZE = 64;
    localparam NUM_MSHRS  = 2;
    localparam L1_CAPACITY = 512;
    localparam L1_WAYS     = 2;

    localparam L1_SETS     = L1_CAPACITY / (BLOCK_SIZE * L1_WAYS);
    localparam INDEX_BITS  = $clog2(L1_SETS);
    localparam OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam WORD_BITS   = $clog2(BLOCK_SIZE * 8 / DATA_WIDTH);
    localparam TAG_BITS    = PA_WIDTH - INDEX_BITS - OFFSET_BITS;

    localparam [1:0] MS_IDLE       = 2'b00;
    localparam [1:0] MS_UNRESOLVED = 2'b01;
    localparam [1:0] MS_RESOLVED   = 2'b10;

    function automatic [PA_WIDTH-1:0] make_pa(
        input [TAG_BITS-1:0] tag,
        input [INDEX_BITS-1:0] index
    );
    begin
        make_pa = {tag, index, {OFFSET_BITS{1'b0}}};
    end
    endfunction

    function automatic [VA_WIDTH-1:0] make_va(
        input [INDEX_BITS-1:0] index,
        input [WORD_BITS-1:0] word
    );
    begin
        make_va = '0;
        make_va[OFFSET_BITS +: INDEX_BITS] = index;
        make_va[OFFSET_BITS-1 -: WORD_BITS] = word;
    end
    endfunction

    function automatic [TAG_BITS-1:0] pa_tag(
        input [PA_WIDTH-1:0] paddr
    );
    begin
        pa_tag = paddr[PA_WIDTH-1 -: TAG_BITS];
    end
    endfunction

    //==========================================================================
    // Test addresses
    //==========================================================================
    localparam [TAG_BITS-1:0] TAG_A = 22'h2AAAAA;
    localparam [TAG_BITS-1:0] TAG_B = 22'h155555;
    localparam [TAG_BITS-1:0] TAG_C = 22'h300001;
    localparam [TAG_BITS-1:0] TAG_D = 22'h300002;
    localparam [TAG_BITS-1:0] TAG_E = 22'h300003;
    localparam [TAG_BITS-1:0] TAG_F = 22'h300004;
    localparam [TAG_BITS-1:0] TAG_G = 22'h300005;
    localparam [TAG_BITS-1:0] TAG_H = 22'h300006;
    localparam [TAG_BITS-1:0] TAG_I = 22'h300007;

    localparam [PA_WIDTH-1:0] PADDR_A = make_pa(TAG_A, 2'd0);
    localparam [PA_WIDTH-1:0] PADDR_B = make_pa(TAG_B, 2'd1);
    localparam [PA_WIDTH-1:0] PADDR_C = make_pa(TAG_C, 2'd2);
    localparam [PA_WIDTH-1:0] PADDR_D = make_pa(TAG_D, 2'd3);
    localparam [PA_WIDTH-1:0] PADDR_E = make_pa(TAG_E, 2'd0);
    localparam [PA_WIDTH-1:0] PADDR_F = make_pa(TAG_F, 2'd0);
    localparam [PA_WIDTH-1:0] PADDR_G = make_pa(TAG_G, 2'd0);
    localparam [PA_WIDTH-1:0] PADDR_H = make_pa(TAG_H, 2'd1);
    localparam [PA_WIDTH-1:0] PADDR_I = make_pa(TAG_I, 2'd1);

    localparam [VA_WIDTH-1:0] VADDR_A_W0 = make_va(2'd0, 3'd0);
    localparam [VA_WIDTH-1:0] VADDR_A_W3 = make_va(2'd0, 3'd3);
    localparam [VA_WIDTH-1:0] VADDR_B_W0 = make_va(2'd1, 3'd0);
    localparam [VA_WIDTH-1:0] VADDR_C_W0 = make_va(2'd2, 3'd0);
    localparam [VA_WIDTH-1:0] VADDR_D_W0 = make_va(2'd3, 3'd0);
    localparam [VA_WIDTH-1:0] VADDR_E_W0 = make_va(2'd0, 3'd0);
    localparam [VA_WIDTH-1:0] VADDR_F_W0 = make_va(2'd0, 3'd0);
    localparam [VA_WIDTH-1:0] VADDR_G_W0 = make_va(2'd0, 3'd0);
    localparam [VA_WIDTH-1:0] VADDR_H_W0 = make_va(2'd1, 3'd0);
    localparam [VA_WIDTH-1:0] VADDR_I_W0 = make_va(2'd1, 3'd0);

    localparam [BLOCK_SIZE*8-1:0] BLOCK_A = 512'hA000000000000000_A100000000000001_A200000000000002_A300000000000003_A400000000000004_A500000000000005_A600000000000006_A700000000000007;
    localparam [BLOCK_SIZE*8-1:0] BLOCK_B = 512'hB000000000000000_B100000000000001_B200000000000002_B300000000000003_B400000000000004_B500000000000005_B600000000000006_B700000000000007;
    localparam [BLOCK_SIZE*8-1:0] BLOCK_C = 512'hC000000000000000_C100000000000001_C200000000000002_C300000000000003_C400000000000004_C500000000000005_C600000000000006_C700000000000007;
    localparam [BLOCK_SIZE*8-1:0] BLOCK_D = 512'hD000000000000000_D100000000000001_D200000000000002_D300000000000003_D400000000000004_D500000000000005_D600000000000006_D700000000000007;
    localparam [BLOCK_SIZE*8-1:0] BLOCK_E = 512'hE000000000000000_E100000000000001_E200000000000002_E300000000000003_E400000000000004_E500000000000005_E600000000000006_E700000000000007;
    localparam [BLOCK_SIZE*8-1:0] BLOCK_F = 512'hF000000000000000_F100000000000001_F200000000000002_F300000000000003_F400000000000004_F500000000000005_F600000000000006_F700000000000007;
    localparam [BLOCK_SIZE*8-1:0] BLOCK_G = 512'h7100000000000000_7200000000000001_7300000000000002_7400000000000003_7500000000000004_7600000000000005_7700000000000006_7800000000000007;
    localparam [BLOCK_SIZE*8-1:0] BLOCK_H = 512'h8100000000000000_8200000000000001_8300000000000002_8400000000000003_8500000000000004_8600000000000005_8700000000000006_8800000000000007;
    localparam [BLOCK_SIZE*8-1:0] BLOCK_I = 512'h1100000000000000_1200000000000001_1300000000000002_1400000000000003_1500000000000004_1600000000000005_1700000000000006_1800000000000007;

    localparam [DATA_WIDTH-1:0] STORE_W0 = 64'hAAAA_BBBB_CCCC_DDDD;
    localparam [DATA_WIDTH-1:0] STORE_W3 = 64'h1111_2222_3333_4444;
    localparam [DATA_WIDTH-1:0] STORE_B0 = 64'h5555_6666_7777_8888;

    //==========================================================================
    // DUT interface
    //==========================================================================
    logic                    clk;
    logic                    rst_n;
    logic                    start_tag;
    logic [PA_WIDTH-1:0]     tlb_paddr;
    logic                    start_index;
    logic [VA_WIDTH-1:0]     trace_vaddr;
    logic                    is_write;
    logic [DATA_WIDTH-1:0]   wdata;
    logic                    l2_wb_ack;
    logic                    l2_data_valid;
    logic [PA_WIDTH-1:0]     l2_data_paddr;
    logic [BLOCK_SIZE*8-1:0] l2_data;

    wire                     l1_stall_out_to_lsq;
    wire                     l2_wb_valid;
    wire [PA_WIDTH-1:0]      l2_wb_paddr;
    wire [BLOCK_SIZE*8-1:0]  l2_wb_data;
    wire                     l2_req_valid;
    wire [PA_WIDTH-1:0]      l2_req_paddr;

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

    //==========================================================================
    // Clock and check helpers
    //==========================================================================
    integer pass_cnt;
    integer fail_cnt;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic check_bit(input [255:0] name, input got, input exp);
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%b expected=%b", name, got, exp);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task automatic check_state(input [255:0] name, input [1:0] got, input [1:0] exp);
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%b expected=%b", name, got, exp);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task automatic check_paddr(input [255:0] name, input [PA_WIDTH-1:0] got, input [PA_WIDTH-1:0] exp);
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%h expected=%h", name, got, exp);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task automatic check_tag(input [255:0] name, input [TAG_BITS-1:0] got, input [TAG_BITS-1:0] exp);
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%h expected=%h", name, got, exp);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task automatic check_data64(input [255:0] name, input [DATA_WIDTH-1:0] got, input [DATA_WIDTH-1:0] exp);
    begin
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%h expected=%h", name, got, exp);
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

    task automatic reset_dut;
    begin
        idle_inputs();
        rst_n = 1'b0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
    end
    endtask

    // Two-phase request used by the DUT: index phase, then tag phase.
    task automatic send_request(
        input [VA_WIDTH-1:0]   vaddr,
        input [PA_WIDTH-1:0]   paddr,
        input                  wr,
        input [DATA_WIDTH-1:0] data
    );
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

    task automatic l2_respond(
        input [PA_WIDTH-1:0]     paddr,
        input [BLOCK_SIZE*8-1:0] block
    );
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

    task automatic wait_for_install;
    begin
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
    end
    endtask

    task automatic fill_line(
        input [VA_WIDTH-1:0]     vaddr,
        input [PA_WIDTH-1:0]     paddr,
        input [BLOCK_SIZE*8-1:0] block
    );
    begin
        send_request(vaddr, paddr, 1'b0, '0);
        @(negedge clk);
        l2_respond(paddr, block);
        wait_for_install();
    end
    endtask

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        idle_inputs();

        //======================================================================
        // T1: Reset and default outputs
        //======================================================================
        $display("\n=== T1: Reset and idle outputs ===");
        reset_dut();
        check_state("T1 mshr0 idle", dut.mshr_state[0], MS_IDLE);
        check_state("T1 mshr1 idle", dut.mshr_state[1], MS_IDLE);
        check_bit  ("T1 no l2 req",  l2_req_valid, 1'b0);
        check_bit  ("T1 no wb",      l2_wb_valid,  1'b0);
        check_bit  ("T1 no stall",   l1_stall_out_to_lsq, 1'b0);

        //======================================================================
        // T2: Miss allocation, outstanding request, wrong response ignored,
        // and final install. This validates the basic MSHR request/response flow.
        //======================================================================
        $display("\n=== T2: Single miss round-trip ===");
        reset_dut();
        send_request(VADDR_A_W0, PADDR_A, 1'b0, '0);
        @(negedge clk);
        check_state("T2 mshr0 unresolved", dut.mshr_state[0], MS_UNRESOLVED);
        check_paddr("T2 l2 req address A", l2_req_paddr, PADDR_A);
        check_bit  ("T2 l2 req valid",     l2_req_valid, 1'b1);

        l2_respond(PADDR_B, BLOCK_B);
        @(negedge clk);
        check_state("T2 wrong response ignored", dut.mshr_state[0], MS_UNRESOLVED);

        l2_respond(PADDR_A, BLOCK_A);
        wait_for_install();
        check_state("T2 mshr0 back to idle", dut.mshr_state[0], MS_IDLE);
        check_bit  ("T2 line installed valid", dut.set_valids[0][0], 1'b1);
        check_tag  ("T2 installed tag matches A", dut.tags[0][0], pa_tag(PADDR_A));

        //======================================================================
        // T3: Read hit should not allocate an MSHR or issue an L2 request.
        // This is the best read-path check possible without a load response port.
        //======================================================================
        $display("\n=== T3: Read hit stays local ===");
        reset_dut();
        fill_line(VADDR_A_W0, PADDR_A, BLOCK_A);
        send_request(VADDR_A_W0, PADDR_A, 1'b0, '0);
        @(negedge clk);
        check_state("T3 read hit leaves mshr0 idle", dut.mshr_state[0], MS_IDLE);
        check_bit  ("T3 read hit does not issue l2 req", l2_req_valid, 1'b0);
        check_bit  ("T3 read hit does not dirty line", dut.set_dirty[0][0], 1'b0);

        //======================================================================
        // T4: Two outstanding misses, full-stall behavior, and drain.
        // This checks MSHR allocation for both slots and that stall tracks full.
        //======================================================================
        $display("\n=== T4: Dual MSHRs and stall ===");
        reset_dut();
        send_request(VADDR_B_W0, PADDR_B, 1'b0, '0);
        @(negedge clk);
        send_request(VADDR_C_W0, PADDR_C, 1'b0, '0);
        @(negedge clk);
        check_state("T4 mshr0 unresolved", dut.mshr_state[0], MS_UNRESOLVED);
        check_state("T4 mshr1 unresolved", dut.mshr_state[1], MS_UNRESOLVED);

        send_request(VADDR_D_W0, PADDR_D, 1'b0, '0);
        @(negedge clk);
        check_bit("T4 stall when both MSHRs full", l1_stall_out_to_lsq, 1'b1);

        l2_respond(PADDR_C, BLOCK_C);
        wait_for_install();
        check_state("T4 mshr1 drained", dut.mshr_state[1], MS_IDLE);
        check_bit  ("T4 stall clears after free slot", l1_stall_out_to_lsq, 1'b0);
        check_paddr("T4 remaining visible request is B", l2_req_paddr, PADDR_B);

        l2_respond(PADDR_B, BLOCK_B);
        wait_for_install();
        check_state("T4 mshr0 drained", dut.mshr_state[0], MS_IDLE);
        check_bit  ("T4 no request after drain", l2_req_valid, 1'b0);

        //======================================================================
        // T5: Filling an empty second way must not evict or write back.
        //======================================================================
        $display("\n=== T5: Fill empty way before eviction ===");
        reset_dut();
        fill_line(VADDR_A_W0, PADDR_A, BLOCK_A);
        fill_line(VADDR_F_W0, PADDR_F, BLOCK_F);
        check_tag("T5 way0 tag is A", dut.tags[0][0], pa_tag(PADDR_A));
        check_tag("T5 way1 tag is F", dut.tags[0][1], pa_tag(PADDR_F));
        check_bit("T5 no writeback on empty-way fill", l2_wb_valid, 1'b0);

        //======================================================================
        // T6: LRU on hit. After filling A then F, a hit on A should make F the
        // next victim. A later miss should keep A and replace F.
        //======================================================================
        $display("\n=== T6: LRU update on hit ===");
        reset_dut();
        fill_line(VADDR_A_W0, PADDR_A, BLOCK_A);
        fill_line(VADDR_F_W0, PADDR_F, BLOCK_F);
        send_request(VADDR_A_W0, PADDR_A, 1'b0, '0);
        @(negedge clk);
        fill_line(VADDR_E_W0, PADDR_E, BLOCK_E);
        check_tag("T6 A remains after being most recently used", dut.tags[0][0], pa_tag(PADDR_A));
        check_tag("T6 E replaced F in victim way", dut.tags[0][1], pa_tag(PADDR_E));

        //======================================================================
        // T7: Store hit updates the addressed 64-bit word, not just word 0.
        // This checks correct word-offset handling on hits.
        //======================================================================
        $display("\n=== T7: Store hit updates selected word ===");
        reset_dut();
        fill_line(VADDR_A_W0, PADDR_A, BLOCK_A);
        send_request(VADDR_A_W3, PADDR_A, 1'b1, STORE_W3);
        @(negedge clk);
        check_bit   ("T7 line marked dirty after store hit", dut.set_dirty[0][0], 1'b1);
        check_data64("T7 word3 updated", dut.set_contents[0][0][3*DATA_WIDTH +: DATA_WIDTH], STORE_W3);
        check_data64("T7 word0 unchanged", dut.set_contents[0][0][0 +: DATA_WIDTH], BLOCK_A[0 +: DATA_WIDTH]);

        //======================================================================
        // T8: Dirty writeback should fire when a dirty victim is evicted.
        // Sequence:
        //   1. Fill A and F in the same set.
        //   2. Dirty A with a store hit.
        //   3. Read F so A becomes the LRU victim.
        //   4. Miss on G to evict dirty A.
        //======================================================================
        $display("\n=== T8: Dirty victim writeback ===");
        reset_dut();
        fill_line(VADDR_A_W0, PADDR_A, BLOCK_A);
        fill_line(VADDR_F_W0, PADDR_F, BLOCK_F);
        send_request(VADDR_A_W0, PADDR_A, 1'b1, STORE_W0);
        @(negedge clk);
        send_request(VADDR_F_W0, PADDR_F, 1'b0, '0);
        @(negedge clk);
        send_request(VADDR_G_W0, PADDR_G, 1'b0, '0);
        @(negedge clk);
        l2_respond(PADDR_G, BLOCK_G);
        wait_for_install();
        check_bit  ("T8 writeback valid after dirty eviction", l2_wb_valid, 1'b1);
        check_paddr("T8 writeback address is A", l2_wb_paddr, PADDR_A);
        check_data64("T8 writeback data contains stored word0", l2_wb_data[0 +: DATA_WIDTH], STORE_W0);
        @(negedge clk);
        l2_wb_ack = 1'b1;
        @(negedge clk);
        l2_wb_ack = 1'b0;
        @(negedge clk);
        check_bit("T8 writeback clears after ack", l2_wb_valid, 1'b0);

        //======================================================================
        // T9: Store miss merges the store data into the returned block.
        // This directly checks the T8-style bug in the old RTL.
        //======================================================================
        $display("\n=== T9: Store miss merges returned block ===");
        reset_dut();
        send_request(VADDR_A_W3, PADDR_A, 1'b1, STORE_W3);
        @(negedge clk);
        check_state("T9 store miss allocates mshr0", dut.mshr_state[0], MS_UNRESOLVED);
        l2_respond(PADDR_A, BLOCK_A);
        wait_for_install();
        check_bit   ("T9 installed line is dirty", dut.set_dirty[0][0], 1'b1);
        check_data64("T9 word3 merged with store data", dut.set_contents[0][0][3*DATA_WIDTH +: DATA_WIDTH], STORE_W3);
        check_data64("T9 word0 still from fetched block", dut.set_contents[0][0][0 +: DATA_WIDTH], BLOCK_A[0 +: DATA_WIDTH]);

        //======================================================================
        // T10: Writeback FIFO edge case. Queue two dirty evictions before acking
        // the first one, then confirm the second becomes visible after the first
        // ack is consumed.
        //======================================================================
        $display("\n=== T10: Two queued writebacks before ack ===");
        reset_dut();

        // Set 0: dirty A, make A LRU victim, then evict with G.
        fill_line(VADDR_A_W0, PADDR_A, BLOCK_A);
        fill_line(VADDR_F_W0, PADDR_F, BLOCK_F);
        send_request(VADDR_A_W0, PADDR_A, 1'b1, STORE_W0);
        @(negedge clk);
        send_request(VADDR_F_W0, PADDR_F, 1'b0, '0);
        @(negedge clk);
        send_request(VADDR_G_W0, PADDR_G, 1'b0, '0);
        @(negedge clk);
        l2_respond(PADDR_G, BLOCK_G);
        wait_for_install();

        // Set 1: dirty B, make B LRU victim, then evict with I.
        fill_line(VADDR_B_W0, PADDR_B, BLOCK_B);
        fill_line(VADDR_H_W0, PADDR_H, BLOCK_H);
        send_request(VADDR_B_W0, PADDR_B, 1'b1, STORE_B0);
        @(negedge clk);
        send_request(VADDR_H_W0, PADDR_H, 1'b0, '0);
        @(negedge clk);
        send_request(VADDR_I_W0, PADDR_I, 1'b0, '0);
        @(negedge clk);
        l2_respond(PADDR_I, BLOCK_I);
        wait_for_install();

        // First queued writeback should still be the set-0 victim.
        check_bit  ("T10 first queued wb visible", l2_wb_valid, 1'b1);
        check_paddr("T10 first queued wb address is A", l2_wb_paddr, PADDR_A);

        // Ack first writeback; second one should rotate into view.
        @(negedge clk);
        l2_wb_ack = 1'b1;
        @(negedge clk);
        l2_wb_ack = 1'b0;
        @(negedge clk);
        check_bit  ("T10 second queued wb now visible", l2_wb_valid, 1'b1);
        check_paddr("T10 second queued wb address is B", l2_wb_paddr, PADDR_B);

        @(negedge clk);
        l2_wb_ack = 1'b1;
        @(negedge clk);
        l2_wb_ack = 1'b0;
        @(negedge clk);
        check_bit("T10 queue empty after second ack", l2_wb_valid, 1'b0);

        $display("\n==========================================");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        $display("==========================================\n");
        $finish;
    end

endmodule
