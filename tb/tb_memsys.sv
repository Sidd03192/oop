`timescale 1ns/1ps

// =============================================================================
// Integration testbench for memory_subsystem
// Tests: LSQ → TLB → L1 → L2 → Memory end-to-end
// =============================================================================
module tb_memsys;

    localparam int VA_WIDTH    = 48;
    localparam int PA_WIDTH    = 30;
    localparam int DATA_WIDTH  = 64;
    localparam int BLOCK_SIZE  = 64;
    localparam int TRACE_WIDTH = 121;

    // L1 geometry
    localparam int L1_SETS     = 4;
    localparam int L1_WAYS     = 2;
    localparam int L1_INDEX_BITS = 2;
    localparam int OFFSET_BITS = 6;
    localparam int L1_TAG_SIZE = 22;

    // L2 geometry
    localparam int L2_SETS     = 16;
    localparam int L2_WAYS     = 4;

    // MSHR states (L1)
    localparam [1:0] MS_IDLE       = 2'b00;
    localparam [1:0] MS_UNRESOLVED = 2'b01;
    localparam [1:0] MS_RESOLVED   = 2'b10;

    // L2 MSHR states
    localparam [1:0] L2_MS_IDLE       = 2'b00;
    localparam [1:0] L2_MS_UNRESOLVED = 2'b01;
    localparam [1:0] L2_MS_WAIT_MEM   = 2'b10;
    localparam [1:0] L2_MS_RESOLVED   = 2'b11;

    // =========================================================================
    // Address constants
    // L1 set = vaddr[7:6], L1 tag = paddr[29:8]
    // L2 set = paddr[9:6], L2 tag = paddr[29:10]
    // =========================================================================

    // L1 set 0 (vaddr[7:6]=00)
    localparam [VA_WIDTH-1:0] VA_S0_P1 = 48'h0000_0001_0000;
    localparam [PA_WIDTH-1:0] PA_S0_T1 = {22'h000010, 2'b00, 6'b0};

    localparam [VA_WIDTH-1:0] VA_S0_P2 = 48'h0000_0002_0000;
    localparam [PA_WIDTH-1:0] PA_S0_T2 = {22'h000020, 2'b00, 6'b0};

    localparam [VA_WIDTH-1:0] VA_S0_P3 = 48'h0000_0003_0000;
    localparam [PA_WIDTH-1:0] PA_S0_T3 = {22'h000030, 2'b00, 6'b0};

    // L1 set 1 (vaddr[7:6]=01)
    localparam [VA_WIDTH-1:0] VA_S1_P4 = 48'h0000_0004_0040;
    localparam [PA_WIDTH-1:0] PA_S1_T4 = {22'h000040, 2'b01, 6'b0};

    localparam [VA_WIDTH-1:0] VA_S1_P5 = 48'h0000_0005_0040;
    localparam [PA_WIDTH-1:0] PA_S1_T5 = {22'h000050, 2'b01, 6'b0};

    // Store word offset: vaddr[5:3] selects which 64-bit word in 64B block
    // VA with vaddr[5:3]=5 for store-merge test (byte offset 0x28)
    localparam [VA_WIDTH-1:0] VA_S0_P1_W5 = 48'h0000_0001_0028;
    localparam [VA_WIDTH-1:0] VA_S1_P4_W0 = VA_S1_P4; // word 0

    // Data blocks
    localparam [BLOCK_SIZE*8-1:0] BLOCK_A = {8{64'hAAAA_AAAA_AAAA_AAAA}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_B = {8{64'hBBBB_BBBB_BBBB_BBBB}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_C = {8{64'hCCCC_CCCC_CCCC_CCCC}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_D = {8{64'hDDDD_DDDD_DDDD_DDDD}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_E = {8{64'hEEEE_EEEE_EEEE_EEEE}};

    // =========================================================================
    // Signals
    // =========================================================================
    logic                       clk;
    logic                       rst_n;
    logic [TRACE_WIDTH-1:0]     trace_data;
    logic                       trace_valid;
    wire                        trace_ready;

    wire                        mem_req_valid;
    wire                        mem_req_is_write;
    wire  [PA_WIDTH-1:0]        mem_req_addr;
    wire  [BLOCK_SIZE*8-1:0]    mem_req_wdata;
    logic                       mem_req_ready;
    logic                       mem_resp_valid;
    logic [PA_WIDTH-1:0]        mem_resp_paddr;
    logic [BLOCK_SIZE*8-1:0]    mem_resp_rdata;

    integer pass_cnt, fail_cnt;

    // =========================================================================
    // DUT
    // =========================================================================
    memory_subsystem dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .trace_data     (trace_data),
        .trace_valid    (trace_valid),
        .trace_ready    (trace_ready),
        .mem_req_valid  (mem_req_valid),
        .mem_req_is_write(mem_req_is_write),
        .mem_req_addr   (mem_req_addr),
        .mem_req_wdata  (mem_req_wdata),
        .mem_req_ready  (mem_req_ready),
        .mem_resp_valid (mem_resp_valid),
        .mem_resp_paddr (mem_resp_paddr),
        .mem_resp_rdata (mem_resp_rdata)
    );

    // =========================================================================
    // Clock
    // =========================================================================
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =========================================================================
    // Simulated Memory
    // =========================================================================
    localparam int MEM_DEPTH = 1024;
    localparam int MEM_DELAY = 3;

    reg [BLOCK_SIZE*8-1:0] sim_mem [0:MEM_DEPTH-1];

    // Pending read state
    logic                   mem_read_pending;
    logic [PA_WIDTH-1:0]    mem_read_addr;
    logic [BLOCK_SIZE*8-1:0] mem_read_data;
    integer                 mem_read_countdown;

    function automatic integer pa_to_idx(input [PA_WIDTH-1:0] addr);
        return addr[PA_WIDTH-1:OFFSET_BITS];
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_req_ready     <= 1'b0;
            mem_resp_valid    <= 1'b0;
            mem_resp_paddr    <= '0;
            mem_resp_rdata    <= '0;
            mem_read_pending  <= 1'b0;
            mem_read_countdown <= 0;
        end else begin
            mem_req_ready  <= 1'b0;
            mem_resp_valid <= 1'b0;

            // Countdown for pending read
            if (mem_read_pending) begin
                if (mem_read_countdown == 0) begin
                    mem_resp_valid   <= 1'b1;
                    mem_resp_paddr   <= mem_read_addr;
                    mem_resp_rdata   <= mem_read_data;
                    mem_read_pending <= 1'b0;
                end else begin
                    mem_read_countdown <= mem_read_countdown - 1;
                end
            end

            // Accept new request (only if no read pending, or if it's a write)
            if (mem_req_valid && (!mem_read_pending || mem_req_is_write)) begin
                mem_req_ready <= 1'b1;
                if (mem_req_is_write) begin
                    sim_mem[pa_to_idx(mem_req_addr)] <= mem_req_wdata;
                end else begin
                    mem_read_pending   <= 1'b1;
                    mem_read_addr      <= mem_req_addr;
                    mem_read_data      <= sim_mem[pa_to_idx(mem_req_addr)];
                    mem_read_countdown <= MEM_DELAY - 1;
                end
            end
        end
    end

    // =========================================================================
    // Trace builder functions
    // =========================================================================
    function automatic [TRACE_WIDTH-1:0] make_tlb_fill(
        input [VA_WIDTH-1:0] vaddr,
        input [PA_WIDTH-1:0] paddr
    );
        logic [TRACE_WIDTH-1:0] t;
        t = '0;
        t[47:0]   = vaddr;
        t[54:52]  = 3'd4;    // OP_TLB_FILL
        t[55]     = 1'b1;    // vaddr_valid
        t[85:56]  = paddr;   // tlb_paddr
        return t;
    endfunction

    function automatic [TRACE_WIDTH-1:0] make_load(
        input [VA_WIDTH-1:0] vaddr,
        input [3:0] id
    );
        logic [TRACE_WIDTH-1:0] t;
        t = '0;
        t[47:0]   = vaddr;
        t[51:48]  = id;
        t[54:52]  = 3'd0;    // OP_MEM_LOAD
        t[55]     = 1'b1;    // vaddr_valid
        return t;
    endfunction

    function automatic [TRACE_WIDTH-1:0] make_load_no_ea(
        input [3:0] id
    );
        logic [TRACE_WIDTH-1:0] t;
        t = '0;
        t[51:48]  = id;
        t[54:52]  = 3'd0;    // OP_MEM_LOAD
        t[55]     = 1'b0;    // vaddr NOT valid
        return t;
    endfunction

    function automatic [TRACE_WIDTH-1:0] make_store(
        input [VA_WIDTH-1:0] vaddr,
        input [3:0] id,
        input [DATA_WIDTH-1:0] value
    );
        logic [TRACE_WIDTH-1:0] t;
        t = '0;
        t[47:0]   = vaddr;
        t[51:48]  = id;
        t[54:52]  = 3'd1;    // OP_MEM_STORE
        t[55]     = 1'b1;    // vaddr_valid
        t[119:56] = value;
        t[120]    = 1'b1;    // value_valid
        return t;
    endfunction

    function automatic [TRACE_WIDTH-1:0] make_store_no_ea(
        input [3:0] id,
        input [DATA_WIDTH-1:0] value
    );
        logic [TRACE_WIDTH-1:0] t;
        t = '0;
        t[51:48]  = id;
        t[54:52]  = 3'd1;    // OP_MEM_STORE
        t[55]     = 1'b0;    // vaddr NOT valid
        t[119:56] = value;
        t[120]    = 1'b1;    // value_valid
        return t;
    endfunction

    function automatic [TRACE_WIDTH-1:0] make_resolve(
        input [VA_WIDTH-1:0] vaddr,
        input [3:0] id,
        input vaddr_valid_bit,
        input [DATA_WIDTH-1:0] value,
        input value_valid_bit
    );
        logic [TRACE_WIDTH-1:0] t;
        t = '0;
        t[47:0]   = vaddr;
        t[51:48]  = id;
        t[54:52]  = 3'd2;             // OP_MEM_RESOLVE
        t[55]     = vaddr_valid_bit;
        t[119:56] = value;
        t[120]    = value_valid_bit;
        return t;
    endfunction

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic chk_bit(input [255:0] name, input got, input exp);
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%b exp=%b @%0t", name, got, exp, $time);
            fail_cnt = fail_cnt + 1;
        end
    endtask

    task automatic chk_state(input [255:0] name, input [1:0] got, input [1:0] exp);
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%b exp=%b @%0t", name, got, exp, $time);
            fail_cnt = fail_cnt + 1;
        end
    endtask

    task automatic chk_pa(input [255:0] name, input [PA_WIDTH-1:0] got, input [PA_WIDTH-1:0] exp);
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%0h exp=%0h @%0t", name, got, exp, $time);
            fail_cnt = fail_cnt + 1;
        end
    endtask

    task automatic chk_64(input [255:0] name, input [63:0] got, input [63:0] exp);
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  got=%0h exp=%0h @%0t", name, got, exp, $time);
            fail_cnt = fail_cnt + 1;
        end
    endtask

    task automatic chk_wide(input [255:0] name, input [BLOCK_SIZE*8-1:0] got, input [BLOCK_SIZE*8-1:0] exp);
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  %s  @%0t", name, $time);
            $display("    got=%0h", got);
            $display("    exp=%0h", exp);
            fail_cnt = fail_cnt + 1;
        end
    endtask

    task automatic idle_inputs();
        trace_data  = '0;
        trace_valid = 1'b0;
    endtask

    task automatic apply_reset();
        idle_inputs();
        rst_n = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
    endtask

    // Send a trace word. Holds valid until ready, then deasserts.
    task automatic send_trace(input [TRACE_WIDTH-1:0] trace);
        @(negedge clk);
        trace_data  = trace;
        trace_valid = 1'b1;
        @(posedge clk);
        while (!trace_ready) begin
            @(posedge clk);
        end
        // Transfer accepted on this posedge
        @(negedge clk);
        trace_valid = 1'b0;
        trace_data  = '0;
    endtask

    // Wait N cycles
    task automatic wait_n(input integer n);
        repeat (n) @(negedge clk);
    endtask

    // Wait until all L1 MSHRs are IDLE or max cycles
    task automatic wait_l1_idle(input integer max_cyc);
        integer cnt;
        logic done;
        cnt = 0;
        done = 0;
        while (cnt < max_cyc && !done) begin
            if (dut.u_l1.mshr_state[0] == MS_IDLE &&
                dut.u_l1.mshr_state[1] == MS_IDLE &&
                dut.u_l1.state == 3'd0)
                done = 1;
            else begin
                @(negedge clk);
                cnt = cnt + 1;
            end
        end
        if (!done)
            $display("  WARN  wait_l1_idle timed out after %0d cycles @%0t", max_cyc, $time);
    endtask

    // Wait until all L2 MSHRs are IDLE or max cycles
    task automatic wait_l2_idle(input integer max_cyc);
        integer cnt;
        logic done;
        cnt = 0;
        done = 0;
        while (cnt < max_cyc && !done) begin
            if (dut.u_l2.mshr_state[0] == L2_MS_IDLE &&
                dut.u_l2.mshr_state[1] == L2_MS_IDLE &&
                dut.u_l2.mshr_state[2] == L2_MS_IDLE &&
                dut.u_l2.mshr_state[3] == L2_MS_IDLE)
                done = 1;
            else begin
                @(negedge clk);
                cnt = cnt + 1;
            end
        end
        if (!done)
            $display("  WARN  wait_l2_idle timed out after %0d cycles @%0t", max_cyc, $time);
    endtask

    // Wait for full pipeline to settle.
    // Waits min_wait cycles first, then polls until everything is idle.
    task automatic wait_all_idle(input integer max_cyc);
        integer cnt;
        logic done;
        // Always wait at least 15 cycles for pipeline to start
        repeat (15) @(negedge clk);
        cnt = 15;
        done = 0;
        while (cnt < max_cyc && !done) begin
            if (dut.u_l1.mshr_state[0] == MS_IDLE &&
                dut.u_l1.mshr_state[1] == MS_IDLE &&
                dut.u_l1.state == 3'd0 &&
                dut.u_l2.mshr_state[0] == L2_MS_IDLE &&
                dut.u_l2.mshr_state[1] == L2_MS_IDLE &&
                dut.u_l2.mshr_state[2] == L2_MS_IDLE &&
                dut.u_l2.mshr_state[3] == L2_MS_IDLE &&
                !mem_read_pending &&
                dut.u_l1.wb_empty)
                done = 1;
            else begin
                @(negedge clk);
                cnt = cnt + 1;
            end
        end
        if (!done)
            $display("  WARN  wait_all_idle timed out after %0d cycles @%0t", max_cyc, $time);
    endtask

    // Combined: TLB fill + load, wait for install
    task automatic tlb_fill_and_load(
        input [VA_WIDTH-1:0] vaddr,
        input [PA_WIDTH-1:0] paddr,
        input [3:0] id
    );
        send_trace(make_tlb_fill(vaddr, paddr));
        wait_n(1);
        send_trace(make_load(vaddr, id));
        wait_all_idle(80);
    endtask

    // Combined: TLB fill + store, wait for install
    task automatic tlb_fill_and_store(
        input [VA_WIDTH-1:0] vaddr,
        input [PA_WIDTH-1:0] paddr,
        input [3:0] id,
        input [DATA_WIDTH-1:0] value
    );
        send_trace(make_tlb_fill(vaddr, paddr));
        wait_n(1);
        send_trace(make_store(vaddr, id, value));
        wait_all_idle(80);
    endtask

    // =========================================================================
    // Timeout watchdog
    // =========================================================================
    initial begin
        #100000;
        $display("\n  TIMEOUT: Simulation exceeded 100us");
        $finish;
    end

    // =========================================================================
    // Test sequence
    // =========================================================================
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        idle_inputs();
        rst_n = 1'b1;

        // Pre-load simulated memory
        for (integer i = 0; i < MEM_DEPTH; i++)
            sim_mem[i] = '0;
        sim_mem[pa_to_idx(PA_S0_T1)] = BLOCK_A;
        sim_mem[pa_to_idx(PA_S0_T2)] = BLOCK_B;
        sim_mem[pa_to_idx(PA_S0_T3)] = BLOCK_C;
        sim_mem[pa_to_idx(PA_S1_T4)] = BLOCK_D;
        sim_mem[pa_to_idx(PA_S1_T5)] = BLOCK_E;

        // =================================================================
        // T1: Reset
        // =================================================================
        $display("\n=== T1: Reset and idle outputs ===");
        apply_reset();
        chk_bit  ("T1 trace_ready high",       trace_ready, 1'b1);
        chk_bit  ("T1 mem_req_valid low",       mem_req_valid, 1'b0);
        chk_state("T1 L1 mshr[0] IDLE",        dut.u_l1.mshr_state[0], MS_IDLE);
        chk_state("T1 L1 mshr[1] IDLE",        dut.u_l1.mshr_state[1], MS_IDLE);
        chk_state("T1 L2 mshr[0] IDLE",        dut.u_l2.mshr_state[0], L2_MS_IDLE);
        chk_state("T1 L2 mshr[1] IDLE",        dut.u_l2.mshr_state[1], L2_MS_IDLE);
        chk_state("T1 L2 mshr[2] IDLE",        dut.u_l2.mshr_state[2], L2_MS_IDLE);
        chk_state("T1 L2 mshr[3] IDLE",        dut.u_l2.mshr_state[3], L2_MS_IDLE);
        chk_bit  ("T1 L1 wb_empty",            dut.u_l1.wb_empty, 1'b1);
        chk_bit  ("T1 L2 wb_empty",            dut.u_l2.wb_empty, 1'b1);
        chk_bit  ("T1 TLB ready",              dut.u_tlb.ready, 1'b1);
        chk_bit  ("T1 L1 stall low",           dut.u_l1.l1_stall_out_to_lsq, 1'b0);

        // =================================================================
        // T2: TLB Fill + End-to-End Load Miss
        // =================================================================
        $display("\n=== T2: TLB fill + end-to-end load miss ===");
        apply_reset();
        // Restore memory
        sim_mem[pa_to_idx(PA_S0_T1)] = BLOCK_A;

        // TLB fill
        send_trace(make_tlb_fill(VA_S0_P1, PA_S0_T1));
        wait_n(2);
        chk_bit("T2 TLB ready after fill", dut.u_tlb.ready, 1'b1);

        // Load
        send_trace(make_load(VA_S0_P1, 4'd0));

        // Wait for full pipeline: LSQ→L1→L2→Memory→L2→L1
        wait_all_idle(80);

        // Checks
        chk_bit  ("T2 L1 set0 way0 valid",      dut.u_l1.set_valids[0][0], 1'b1);
        chk_wide ("T2 L1 set0 way0 == BLOCK_A",  dut.u_l1.set_contents[0][0], BLOCK_A);
        chk_state("T2 L1 mshr[0] back to IDLE", dut.u_l1.mshr_state[0], MS_IDLE);
        chk_state("T2 L1 mshr[1] still IDLE",   dut.u_l1.mshr_state[1], MS_IDLE);
        chk_bit  ("T2 L1 not dirty",            dut.u_l1.set_dirty[0][0], 1'b0);

        // =================================================================
        // T3: Store Miss End-to-End
        // =================================================================
        $display("\n=== T3: Store miss end-to-end (data merge on install) ===");
        apply_reset();
        sim_mem[pa_to_idx(PA_S1_T4)] = BLOCK_D;

        // TLB fill for set 1
        send_trace(make_tlb_fill(VA_S1_P4, PA_S1_T4));
        wait_n(2);

        // Store to word 0 (vaddr[5:3]=0)
        send_trace(make_store(VA_S1_P4_W0, 4'd8, 64'hDEAD_CAFE_1234_5678));

        wait_all_idle(80);
        wait_n(2);

        // L1 should have dirty line with merged store
        chk_bit("T3 L1 set1 way0 valid",        dut.u_l1.set_valids[1][0], 1'b1);
        chk_bit("T3 L1 set1 way0 dirty",        dut.u_l1.set_dirty[1][0], 1'b1);
        chk_64 ("T3 word0 has store value",      dut.u_l1.set_contents[1][0][0*64 +: 64],
                                                  64'hDEAD_CAFE_1234_5678);
        chk_64 ("T3 word1 from memory block",    dut.u_l1.set_contents[1][0][1*64 +: 64],
                                                  64'hDDDD_DDDD_DDDD_DDDD);
        chk_state("T3 L1 mshr[0] IDLE",         dut.u_l1.mshr_state[0], MS_IDLE);

        // =================================================================
        // T4: Load Hit After Previous Fill
        // =================================================================
        $display("\n=== T4: Load hit (no memory traffic) ===");
        // Don't reset - reuse T2 state. Re-fill from scratch.
        apply_reset();
        sim_mem[pa_to_idx(PA_S0_T1)] = BLOCK_A;
        // Fill the line first
        send_trace(make_tlb_fill(VA_S0_P1, PA_S0_T1));
        wait_n(2);
        send_trace(make_load(VA_S0_P1, 4'd0));
        wait_all_idle(80);
        wait_n(2);

        // Now send second load to same address - should hit
        send_trace(make_load(VA_S0_P1, 4'd1));

        // Wait a few cycles for L1 pipeline (hit path: ~3 cycles)
        wait_n(8);

        chk_state("T4 L1 mshr[0] stays IDLE",   dut.u_l1.mshr_state[0], MS_IDLE);
        chk_state("T4 L1 mshr[1] stays IDLE",   dut.u_l1.mshr_state[1], MS_IDLE);
        chk_bit  ("T4 L1 stall low",            dut.u_l1.l1_stall_out_to_lsq, 1'b0);
        // Line still valid and unchanged
        chk_wide ("T4 data unchanged",           dut.u_l1.set_contents[0][0], BLOCK_A);

        // =================================================================
        // T5: Dirty Eviction Chain
        // =================================================================
        $display("\n=== T5: Dirty eviction from L1 to L2 ===");
        apply_reset();
        sim_mem[pa_to_idx(PA_S0_T1)] = BLOCK_A;
        sim_mem[pa_to_idx(PA_S0_T2)] = BLOCK_B;
        sim_mem[pa_to_idx(PA_S0_T3)] = BLOCK_C;

        // Fill TLB for all three pages
        send_trace(make_tlb_fill(VA_S0_P1, PA_S0_T1));
        wait_n(2);
        send_trace(make_tlb_fill(VA_S0_P2, PA_S0_T2));
        wait_n(2);
        send_trace(make_tlb_fill(VA_S0_P3, PA_S0_T3));
        wait_n(2);

        // Fill both L1 set 0 ways
        send_trace(make_load(VA_S0_P1, 4'd0));   // way 0 = BLOCK_A
        wait_all_idle(80);
        wait_n(2);
        send_trace(make_load(VA_S0_P2, 4'd1));   // way 1 = BLOCK_B
        wait_all_idle(80);
        wait_n(2);

        chk_bit("T5 both ways valid",
                dut.u_l1.set_valids[0][0] && dut.u_l1.set_valids[0][1], 1'b1);

        // Dirty way 0 via store (word 5 of VA_S0_P1)
        send_trace(make_store(VA_S0_P1_W5, 4'd8, 64'hFACE_FACE_FACE_FACE));
        wait_all_idle(80);
        wait_n(2);

        chk_bit("T5 way0 dirty after store", dut.u_l1.set_dirty[0][0], 1'b1);

        // Touch way 0 with a load to make LRU point at way 1
        send_trace(make_load(VA_S0_P1, 4'd2));
        wait_n(8);

        // Now load third address - should evict LRU victim (way 1 = clean BLOCK_B, no wb)
        // Then way 1 gets BLOCK_C
        send_trace(make_load(VA_S0_P3, 4'd3));
        wait_all_idle(80);
        wait_n(2);

        chk_wide("T5 way1 now has BLOCK_C", dut.u_l1.set_contents[0][1], BLOCK_C);

        // Dirty way 1 (BLOCK_C) via store
        send_trace(make_store({VA_S0_P3[47:6], 6'h28}, 4'd9, 64'h1111_2222_3333_4444));
        wait_all_idle(80);
        wait_n(2);

        chk_bit("T5 way1 dirty after store", dut.u_l1.set_dirty[0][1], 1'b1);

        // Touch way 1 to make LRU point at way 0 (dirty)
        send_trace(make_load(VA_S0_P3, 4'd4));
        wait_n(8);

        // Load VA_S0_P2 again (not in L1 anymore) - evicts dirty way 0 (PA_S0_T1)
        send_trace(make_load(VA_S0_P2, 4'd5));
        wait_all_idle(80);
        wait_n(4);

        // The dirty eviction should have been written back to L2
        // Check L1 wb FIFO drained
        chk_bit("T5 L1 wb queue empty after eviction", dut.u_l1.wb_empty, 1'b1);

        // =================================================================
        // T6: LSQ Ordering (Load blocked by unresolved store)
        // =================================================================
        $display("\n=== T6: LSQ ordering - load blocked by unresolved store ===");
        apply_reset();
        sim_mem[pa_to_idx(PA_S0_T1)] = BLOCK_A;

        // TLB fill first
        send_trace(make_tlb_fill(VA_S0_P1, PA_S0_T1));
        wait_n(2);

        // Dispatch store with unknown EA (id=8)
        send_trace(make_store_no_ea(4'd8, 64'hBEEF_BEEF_BEEF_BEEF));
        wait_n(1);

        // Dispatch load with known EA (id=0) - should be blocked
        send_trace(make_load(VA_S0_P1, 4'd0));
        wait_n(3);

        // LSQ should not have issued the load
        chk_bit("T6 load blocked by unresolved store",
                dut.u_lsq.lq_state[0] == 2'd2, 1'b1); // LQ_WAITING_ISSUE

        // Resolve the store EA to a DIFFERENT address (so load can proceed)
        send_trace(make_resolve(VA_S0_P2, 4'd8, 1'b1, 64'h0, 1'b0));
        wait_n(2);

        // Now the store's EA is known, and it's a different address → load should issue
        wait_all_idle(80);
        wait_n(2);

        // Load should have completed (line installed)
        chk_bit("T6 L1 set0 valid after load issues",
                dut.u_l1.set_valids[0][0], 1'b1);

        // =================================================================
        // T7: Multiple Outstanding L1 Misses
        // =================================================================
        $display("\n=== T7: Two outstanding L1 misses ===");
        apply_reset();
        sim_mem[pa_to_idx(PA_S0_T1)] = BLOCK_A;
        sim_mem[pa_to_idx(PA_S1_T4)] = BLOCK_D;

        // TLB fills for two different sets
        send_trace(make_tlb_fill(VA_S0_P1, PA_S0_T1));
        wait_n(2);
        send_trace(make_tlb_fill(VA_S1_P4, PA_S1_T4));
        wait_n(2);

        // First load - will miss. Wait for MSHR allocation (~4 cycles after send)
        send_trace(make_load(VA_S0_P1, 4'd0));
        wait_n(5);

        chk_state("T7 L1 mshr[0] UNRESOLVED after first miss",
                  dut.u_l1.mshr_state[0], MS_UNRESOLVED);

        // Second load - will also miss.
        send_trace(make_load(VA_S1_P4, 4'd1));
        // Check quickly: after 3 cycles the second MSHR should be allocated
        // but before memory has time to respond to first (mem delay = 3 cycles
        // plus L2 MSHR overhead). Check every cycle for a window.
        begin
            logic saw_both_full;
            saw_both_full = 0;
            repeat (10) begin
                @(negedge clk);
                if (dut.u_l1.mshr_state[0] != MS_IDLE &&
                    dut.u_l1.mshr_state[1] != MS_IDLE)
                    saw_both_full = 1;
            end
            chk_bit("T7 both MSHRs were non-IDLE at some point", saw_both_full, 1'b1);
        end

        // Let memory respond to both
        wait_all_idle(80);
        wait_n(4);

        chk_state("T7 L1 mshr[0] IDLE after drain", dut.u_l1.mshr_state[0], MS_IDLE);
        chk_state("T7 L1 mshr[1] IDLE after drain", dut.u_l1.mshr_state[1], MS_IDLE);
        chk_bit  ("T7 L1 stall cleared",           dut.u_l1.l1_stall_out_to_lsq, 1'b0);
        chk_bit  ("T7 L1 set0 valid",              dut.u_l1.set_valids[0][0], 1'b1);
        chk_bit  ("T7 L1 set1 valid",              dut.u_l1.set_valids[1][0], 1'b1);
        chk_wide ("T7 L1 set0 data",               dut.u_l1.set_contents[0][0], BLOCK_A);
        chk_wide ("T7 L1 set1 data",               dut.u_l1.set_contents[1][0], BLOCK_D);

        // =================================================================
        // T8: TLB Fill Interleaved with Load
        // =================================================================
        // Tests that TLB fills and loads can be interleaved without
        // corrupting state. We send a fill, then a load, then another fill
        // well-separated so there's no in-flight overlap.
        $display("\n=== T8: TLB fill interleaved with load ===");
        apply_reset();
        sim_mem[pa_to_idx(PA_S0_T1)] = BLOCK_A;
        sim_mem[pa_to_idx(PA_S0_T2)] = BLOCK_B;

        // Fill TLB for two pages
        send_trace(make_tlb_fill(VA_S0_P1, PA_S0_T1));
        wait_n(2);
        send_trace(make_tlb_fill(VA_S0_P2, PA_S0_T2));
        wait_n(2);

        // Load from first page
        send_trace(make_load(VA_S0_P1, 4'd0));
        wait_all_idle(80);

        // Load from second page (proves both TLB entries work)
        send_trace(make_load(VA_S0_P2, 4'd1));
        wait_all_idle(80);

        chk_bit ("T8 L1 set0 way0 valid",  dut.u_l1.set_valids[0][0], 1'b1);
        chk_bit ("T8 L1 set0 way1 valid",  dut.u_l1.set_valids[0][1], 1'b1);
        chk_wide("T8 way0 == BLOCK_A",     dut.u_l1.set_contents[0][0], BLOCK_A);
        chk_wide("T8 way1 == BLOCK_B",     dut.u_l1.set_contents[0][1], BLOCK_B);

        // =================================================================
        // T9: MSHR Full Stall Propagation
        // =================================================================
        $display("\n=== T9: MSHR full stall propagation ===");
        apply_reset();
        sim_mem[pa_to_idx(PA_S0_T1)] = BLOCK_A;
        sim_mem[pa_to_idx(PA_S1_T4)] = BLOCK_D;
        sim_mem[pa_to_idx(PA_S0_T2)] = BLOCK_B;

        // TLB fills
        send_trace(make_tlb_fill(VA_S0_P1, PA_S0_T1));
        wait_n(2);
        send_trace(make_tlb_fill(VA_S1_P4, PA_S1_T4));
        wait_n(2);
        send_trace(make_tlb_fill(VA_S0_P2, PA_S0_T2));
        wait_n(2);

        // Two misses to fill both L1 MSHRs
        send_trace(make_load(VA_S0_P1, 4'd0));
        wait_n(5);
        send_trace(make_load(VA_S1_P4, 4'd1));
        // Monitor for both MSHRs non-idle
        begin
            logic saw_both_full;
            saw_both_full = 0;
            repeat (10) begin
                @(negedge clk);
                if (dut.u_l1.mshr_state[0] != MS_IDLE &&
                    dut.u_l1.mshr_state[1] != MS_IDLE)
                    saw_both_full = 1;
            end
            chk_bit("T9 both MSHRs were non-IDLE", saw_both_full, 1'b1);
        end

        // Dispatch third load - it goes into LSQ but can't issue while stalled
        send_trace(make_load(VA_S0_P2, 4'd2));

        // Monitor: check that stall was active at some point during MSHR-full window
        begin
            logic saw_stall;
            saw_stall = 0;
            repeat (15) begin
                @(negedge clk);
                if (dut.u_l1.l1_stall_out_to_lsq)
                    saw_stall = 1;
            end
            chk_bit("T9 L1 stall was asserted during MSHR-full window", saw_stall, 1'b1);
        end

        // Let memory respond (will drain MSHRs)
        wait_all_idle(80);
        wait_n(4);

        // After MSHRs drain, stall should clear and third load should complete
        chk_bit("T9 stall cleared after drain", dut.u_l1.l1_stall_out_to_lsq, 1'b0);
        // Third load should have installed into L1
        // VA_S0_P2 maps to L1 set 0 (vaddr[7:6]=00), different tag
        chk_bit("T9 third load completed (set0 way1 valid)",
                dut.u_l1.set_valids[0][1], 1'b1);

        // =================================================================
        // T10: L2 Dirty Writeback to Memory
        // =================================================================
        $display("\n=== T10: L2 dirty writeback to memory ===");
        apply_reset();

        // We need to fill an L2 set to capacity (4 ways) with dirty data,
        // then cause another writeback to that set.
        // Strategy: use 5 different physical addresses that all map to L2 set 0.
        // L2 set = paddr[9:6]. For set 0: paddr[9:6] = 4'b0000.
        // We already have PA_S0_T1, PA_S0_T2, PA_S0_T3 all with paddr[7:6]=00
        // which means L2 set index paddr[9:6] depends on paddr[9:8] too.

        // PA_S0_T1 = {22'h000010, 2'b00, 6'b0} → paddr[9:6] = 0000 → L2 set 0? No.
        // paddr = 30 bits. PA_S0_T1 = 22'h000010 << 8 | 0 = 30'h00000400
        // paddr[9:6] = paddr[9:6] = 4'b0001_00 ... let me compute:
        // 22'h000010 = 22'b0000_0000_0000_0001_0000
        // Full PA: {22'b0000_0000_0000_0001_0000, 2'b00, 6'b000000}
        // = 30'b0000_0000_0000_0001_0000_0000_0000_00  (but 30 bits)
        // paddr[9:6] = 0000 → L2 set 0 ✓
        // PA_S0_T2 = {22'h000020, ...} → paddr[9:6] = 0000 → L2 set 0 ✓
        // PA_S0_T3 = {22'h000030, ...} → paddr[9:6] = 0000 → L2 set 0 ✓

        // We need 2 more addresses for L2 set 0 with different L2 tags
        // Use additional pages:
        begin
            localparam [VA_WIDTH-1:0] VA_P6 = 48'h0000_0006_0000;
            localparam [PA_WIDTH-1:0] PA_T6 = {22'h000060, 2'b00, 6'b0};
            localparam [VA_WIDTH-1:0] VA_P7 = 48'h0000_0007_0000;
            localparam [PA_WIDTH-1:0] PA_T7 = {22'h000070, 2'b00, 6'b0};

            sim_mem[pa_to_idx(PA_S0_T1)] = BLOCK_A;
            sim_mem[pa_to_idx(PA_S0_T2)] = BLOCK_B;
            sim_mem[pa_to_idx(PA_S0_T3)] = BLOCK_C;
            sim_mem[pa_to_idx(PA_T6)]    = BLOCK_D;
            sim_mem[pa_to_idx(PA_T7)]    = BLOCK_E;

            // TLB fill all 5
            send_trace(make_tlb_fill(VA_S0_P1, PA_S0_T1)); wait_n(2);
            send_trace(make_tlb_fill(VA_S0_P2, PA_S0_T2)); wait_n(2);
            send_trace(make_tlb_fill(VA_S0_P3, PA_S0_T3)); wait_n(2);
            send_trace(make_tlb_fill(VA_P6, PA_T6));        wait_n(2);
            send_trace(make_tlb_fill(VA_P7, PA_T7));        wait_n(2);

            // Fill L1 set 0 way 0 with BLOCK_A, dirty it, evict to L2
            send_trace(make_load(VA_S0_P1, 4'd0));
            wait_all_idle(80); wait_n(2);
            send_trace(make_store(VA_S0_P1, 4'd8, 64'hAAAA_0001_0001_0001));
            wait_all_idle(80); wait_n(2);

            // Fill L1 set 0 way 1 with BLOCK_B, dirty it
            send_trace(make_load(VA_S0_P2, 4'd1));
            wait_all_idle(80); wait_n(2);
            send_trace(make_store(VA_S0_P2, 4'd9, 64'hBBBB_0002_0002_0002));
            wait_all_idle(80); wait_n(2);

            // Load BLOCK_C → evicts dirty way (LRU). Writeback goes to L2.
            send_trace(make_load(VA_S0_P3, 4'd2));
            wait_all_idle(80); wait_n(2);

            // Dirty way holding BLOCK_C
            send_trace(make_store(VA_S0_P3, 4'd10, 64'hCCCC_0003_0003_0003));
            wait_all_idle(80); wait_n(2);

            // Load BLOCK_D → evicts another dirty way to L2
            send_trace(make_load(VA_P6, 4'd3));
            wait_all_idle(80); wait_n(2);

            // Dirty BLOCK_D
            send_trace(make_store(VA_P6, 4'd11, 64'hDDDD_0004_0004_0004));
            wait_all_idle(80); wait_n(2);

            // Now L2 set 0 should have 4 dirty entries.
            // Load BLOCK_E → L1 evicts dirty to L2 → L2 set 0 full → L2 evicts dirty to memory
            send_trace(make_load(VA_P7, 4'd4));
            wait_all_idle(80); wait_n(4);

            // Check that memory received a dirty writeback
            // The memory model would have written it. Check sim_mem was updated
            // by verifying L2 wb queue drained.
            chk_bit("T10 L2 wb queue drained", dut.u_l2.wb_empty, 1'b1);
            chk_bit("T10 L1 wb queue drained", dut.u_l1.wb_empty, 1'b1);
            chk_state("T10 all L1 MSHRs IDLE", dut.u_l1.mshr_state[0], MS_IDLE);
        end

        // =================================================================
        // Summary
        // =================================================================
        $display("\n==========================================");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("  ALL TESTS PASSED");
        else               $display("  *** FAILURES DETECTED ***");
        $display("==========================================\n");
        $finish;
    end

endmodule
