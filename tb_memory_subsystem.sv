`timescale 1ns/1ps

// Directed testbench for memory_subsystem (LSQ + TLB + L1 + L2 + mainmem).
//
// Strategy: drive the 121-bit trace stream; pre-load dut.u_l1.l2.mm.mem[]
// with known data; verify end-to-end that loads/stores reach L1 and L2.
//
// Trace bit layout (121 bits):
//   [120]      trace_value_valid
//   [119:56]   trace_value (64-bit store data);
//              [85:56] = trace_tlb_paddr for TLB_FILL (overlaps value[29:0])
//   [55]       trace_vaddr_valid  (EA known at dispatch)
//   [54:52]    trace_op
//   [51:48]    trace_id
//   [47:0]     trace_vaddr
//
// Addresses (chosen so VPN bits differ, avoiding TLB aliasing):
//   VA_A = 48'h0000_0001_0000  (VPN=1, offset=0) -> PA_A = 30'h100  (L1 set 0, L2 set 4, blk 4)
//   VA_B = 48'h0000_0002_0000  (VPN=2, offset=0) -> PA_B = 30'h200  (L1 set 0, L2 set 8, blk 8)
//
// Pipeline timing (from send_trace(mk_load) returning):
//   +1 posedge : LSQ issues (valid_out fires)
//   +2 posedges: L1 start_in fires + TLB lookup starts
//   +3 posedges: L1 tag-check posedge P (on miss: l2_miss_in fires)
//   +28 posedges: L1 block installed (P+25)
//   MEMSYS_MISS=32 posedges covers this with margin.
//   MEMSYS_HIT =5  posedges covers L1 hit path.
//   MEMSYS_RESOLVE=34 adds one extra posedge for RESOLVE->LQ_WAITING_ISSUE.

module tb_memory_subsystem;

    localparam int VA_WIDTH    = 48;
    localparam int PA_WIDTH    = 30;
    localparam int DATA_WIDTH  = 64;
    localparam int BLOCK_SIZE  = 64;
    localparam int TRACE_WIDTH = 121;

    // L1 geometry: CAPACITY=512, WAYS=2, BLOCK=64 -> 4 sets
    localparam int L1_SETS     = 4;
    localparam int INDEX_BITS  = 2;
    localparam int OFFSET_BITS = 6;
    localparam int TAG_BITS    = PA_WIDTH - INDEX_BITS - OFFSET_BITS;  // 22

    // L2 geometry: CAPACITY=4096, WAYS=4, BLOCK=64 -> 16 sets
    localparam int L2_SETS     = 16;

    localparam int MEMSYS_MISS    = 32;  // posedges after send_trace for cold miss
    localparam int MEMSYS_HIT     = 5;   // posedges after send_trace for L1 hit
    localparam int MEMSYS_RESOLVE = 34;  // posedges after send_trace(RESOLVE)

    // Operation encodings (matching memsys.sv)
    localparam [2:0] OP_LOAD     = 3'd0;
    localparam [2:0] OP_STORE    = 3'd1;
    localparam [2:0] OP_RESOLVE  = 3'd2;
    localparam [2:0] OP_TLB_FILL = 3'd4;

    // -------------------------------------------------------------------
    // Test addresses
    // VA_A -> PA_A: VPN=1, blk=4, L1 set=0, L2 set=4
    // VA_B -> PA_B: VPN=2, blk=8, L1 set=0, L2 set=8
    // -------------------------------------------------------------------
    localparam [VA_WIDTH-1:0] VA_A = 48'h0000_0001_0000;
    localparam [VA_WIDTH-1:0] VA_B = 48'h0000_0002_0000;
    localparam [PA_WIDTH-1:0] PA_A = 30'h000_0100;
    localparam [PA_WIDTH-1:0] PA_B = 30'h000_0200;

    localparam [BLOCK_SIZE*8-1:0] BLOCK_A  = {8{64'hAAAA_AAAA_AAAA_AAAA}};
    localparam [BLOCK_SIZE*8-1:0] BLOCK_B  = {8{64'hBBBB_BBBB_BBBB_BBBB}};
    localparam [DATA_WIDTH-1:0]   DIRTY_DATA = 64'hFEED_FACE_DEAD_0123;

    // -------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------
    logic                    clk;
    logic                    rst_n;
    logic [TRACE_WIDTH-1:0]  trace_data;
    logic                    trace_valid;
    wire                     trace_ready;

    integer pass_cnt, fail_cnt;

    memory_subsystem dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .trace_data  (trace_data),
        .trace_valid (trace_valid),
        .trace_ready (trace_ready)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------
    // Check helpers
    // -------------------------------------------------------------------
    task automatic chk_bit;
        input [255:0] name; input got; input exp;
        if (got === exp) begin
            $display("  PASS  %s", name); pass_cnt++;
        end else begin
            $display("  FAIL  %s  got=%b exp=%b @%0t", name, got, exp, $time);
            fail_cnt++;
        end
    endtask

    task automatic chk_wide;
        input [255:0] name;
        input [BLOCK_SIZE*8-1:0] got, exp;
        if (got === exp) begin
            $display("  PASS  %s", name); pass_cnt++;
        end else begin
            $display("  FAIL  %s  got=%0h exp=%0h @%0t", name, got, exp, $time);
            fail_cnt++;
        end
    endtask

    task automatic chk_64;
        input [255:0] name; input [63:0] got, exp;
        if (got === exp) begin
            $display("  PASS  %s", name); pass_cnt++;
        end else begin
            $display("  FAIL  %s  got=%0h exp=%0h @%0t", name, got, exp, $time);
            fail_cnt++;
        end
    endtask

    // -------------------------------------------------------------------
    // Trace builder functions
    //
    // TLB_FILL: PA stored in trace_value[29:0] = trace_data[85:56]
    //   trace_data = {value_valid=0, 34'b0, pa[29:0], vaddr_valid=0,
    //                 op=4, id=0, va[47:0]}
    // -------------------------------------------------------------------
    function automatic [TRACE_WIDTH-1:0] mk_tlb_fill;
        input [VA_WIDTH-1:0] va;
        input [PA_WIDTH-1:0] pa;
        // {1, 34, 30, 1, 3, 4, 48} = 121
        return {1'b0, 34'b0, pa, 1'b0, OP_TLB_FILL, 4'b0, va};
    endfunction

    function automatic [TRACE_WIDTH-1:0] mk_load;
        input [3:0]          id;
        input [VA_WIDTH-1:0] va;
        // vaddr_valid=1 (EA known at dispatch)
        return {1'b0, 64'b0, 1'b1, OP_LOAD, id, va};
    endfunction

    function automatic [TRACE_WIDTH-1:0] mk_load_no_ea;
        input [3:0] id;
        // vaddr_valid=0, vaddr=0 — EA unknown at dispatch
        return {1'b0, 64'b0, 1'b0, OP_LOAD, id, 48'b0};
    endfunction

    function automatic [TRACE_WIDTH-1:0] mk_store;
        input [3:0]           id;
        input [VA_WIDTH-1:0]  va;
        input [DATA_WIDTH-1:0] dat;
        // value_valid=1, vaddr_valid=1
        return {1'b1, dat, 1'b1, OP_STORE, id, va};
    endfunction

    function automatic [TRACE_WIDTH-1:0] mk_resolve;
        input [3:0]          id;
        input [VA_WIDTH-1:0] va;
        // Provides EA for a previously-unknown-EA op
        return {1'b0, 64'b0, 1'b1, OP_RESOLVE, id, va};
    endfunction

    // -------------------------------------------------------------------
    // Drive one trace entry for exactly one clock period.
    // Starts at next negedge, returns at the following negedge.
    // Between two consecutive send_trace calls there is a 1-cycle idle gap.
    // -------------------------------------------------------------------
    task automatic send_trace;
        input [TRACE_WIDTH-1:0] data;
        @(negedge clk);
        trace_data  = data;
        trace_valid = 1'b1;
        @(negedge clk);
        trace_valid = 1'b0;
        trace_data  = '0;
    endtask

    // -------------------------------------------------------------------
    // Reset helpers
    // -------------------------------------------------------------------
    task automatic apply_reset;
        trace_data  = '0;
        trace_valid = 1'b0;
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
    endtask

    // -------------------------------------------------------------------
    // Main test body
    // -------------------------------------------------------------------
    initial begin
        pass_cnt = 0; fail_cnt = 0;
        trace_data  = '0;
        trace_valid = 1'b0;
        rst_n = 1'b1;

        // Pre-load mainmem with known blocks.
        // mainmem.mem[] survives all rst_n cycles.
        dut.u_l1.l2.mm.mem[4] = BLOCK_A;   // PA_A blk 4
        dut.u_l1.l2.mm.mem[8] = BLOCK_B;   // PA_B blk 8

        // ==============================================================
        // T1: Reset — L1 idle, TLB ready, LSQ ready
        // ==============================================================
        $display("\n=== T1: Reset ===");
        apply_reset();
        @(negedge clk);
        chk_bit("T1 L1 stall_out low",        dut.u_l1.stall_out,    1'b0);
        chk_bit("T1 TLB ready",               dut.u_tlb.ready,       1'b1);
        chk_bit("T1 LSQ lq_ready",            dut.u_lsq.lq_ready,    1'b1);
        chk_bit("T1 LSQ sq_ready",            dut.u_lsq.sq_ready,    1'b1);
        chk_bit("T1 trace_ready asserted",    trace_ready,            1'b1);
        chk_bit("T1 L1 valid[0][0] clear",    dut.u_l1.valid[0][0],  1'b0);

        // ==============================================================
        // T2: TLB_FILL(VA_A->PA_A) + cold LOAD fills L1[0][0] and L2[4][3]
        // ==============================================================
        $display("\n=== T2: TLB_FILL + cold LOAD fills L1 and L2 ===");
        send_trace(mk_tlb_fill(VA_A, PA_A));
        send_trace(mk_load(4'd0, VA_A));      // id=0, vaddr_valid=1
        repeat (MEMSYS_MISS) @(posedge clk);
        @(negedge clk);
        chk_bit ("T2 L1.valid[0][0] set",             dut.u_l1.valid[0][0],        1'b1);
        chk_wide("T2 L1.contents[0][0] = BLOCK_A",    dut.u_l1.contents[0][0],     BLOCK_A);
        chk_bit ("T2 L1.valid[0][1] untouched",        dut.u_l1.valid[0][1],        1'b0);
        chk_bit ("T2 L2.valid[4][3] set",             dut.u_l1.l2.valid[4][3],     1'b1);
        chk_wide("T2 L2.contents[4][3] = BLOCK_A",    dut.u_l1.l2.contents[4][3],  BLOCK_A);
        chk_bit ("T2 L1 stall low after fill",         dut.u_l1.stall_out,          1'b0);

        // ==============================================================
        // T3: LOAD hit — no new L2 miss, lru[0] updates to 1
        // (continuing T2 state: L1[0][0]=PA_A, lru[0]=0 after cold fill)
        // ==============================================================
        $display("\n=== T3: LOAD hit — no L2 miss, lru update ===");
        send_trace(mk_load(4'd1, VA_A));     // id=1
        repeat (MEMSYS_HIT) @(posedge clk);
        @(negedge clk);
        chk_bit("T3 l2_miss_in[0] silent on hit",  dut.u_l1.l2_miss_in[0], 1'b0);
        chk_bit("T3 l2_miss_in[1] silent on hit",  dut.u_l1.l2_miss_in[1], 1'b0);
        // hit on way0 -> lru[0] = ~0 = 1
        chk_bit("T3 lru[0]=1 after way0 hit",      dut.u_l1.lru[0],         1'b1);
        chk_bit("T3 stall low on hit",             dut.u_l1.stall_out,      1'b0);

        // ==============================================================
        // T4: STORE hit — dirty bit set, wdata written into L1 contents
        // (lru[0]=1 after T3, way0 still has PA_A)
        // ==============================================================
        $display("\n=== T4: STORE hit — dirty bit and wdata ===");
        send_trace(mk_store(4'd2, VA_A, DIRTY_DATA));  // id=2
        repeat (MEMSYS_HIT) @(posedge clk);
        @(negedge clk);
        chk_bit("T4 L1.dirty[0][0] set",               dut.u_l1.dirty[0][0],          1'b1);
        chk_64 ("T4 L1.contents[0][0][63:0]=DIRTY_DATA", dut.u_l1.contents[0][0][63:0], DIRTY_DATA);
        chk_bit("T4 stall low on store hit",            dut.u_l1.stall_out,            1'b0);

        // ==============================================================
        // T5: LOAD with late EA (vaddr_ready=0) + RESOLVE
        //
        // After reset: L1 is clean, lru[0]=0 -> PA_B fills into way0.
        // Sequence:
        //   1. TLB_FILL(VA_B, PA_B)
        //   2. LOAD(id=3, no EA) -> LSQ entry in LQ_WAITING_ADDR, no issue
        //   3. Verify L1.valid[0][0]=0 (no fill happened yet)
        //   4. RESOLVE(id=3, VA_B) -> LSQ entry to LQ_WAITING_ISSUE
        //   5. Wait MEMSYS_RESOLVE -> L1.valid[0][0]=1, contents=BLOCK_B
        // ==============================================================
        $display("\n=== T5: LOAD with late EA + RESOLVE ===");
        apply_reset();
        send_trace(mk_tlb_fill(VA_B, PA_B));
        send_trace(mk_load_no_ea(4'd3));          // id=3, vaddr unknown
        // Wait a few cycles — LSQ should not issue (LQ_WAITING_ADDR)
        repeat (4) @(posedge clk);
        @(negedge clk);
        chk_bit("T5 L1.valid[0][0] still clear before RESOLVE",
                dut.u_l1.valid[0][0], 1'b0);
        // Provide the EA via RESOLVE
        send_trace(mk_resolve(4'd3, VA_B));
        repeat (MEMSYS_RESOLVE) @(posedge clk);
        @(negedge clk);
        chk_bit ("T5 L1.valid[0][0] set after RESOLVE+fill",   dut.u_l1.valid[0][0],       1'b1);
        chk_wide("T5 L1.contents[0][0] = BLOCK_B",             dut.u_l1.contents[0][0],    BLOCK_B);
        chk_bit ("T5 L2.valid[8][3] set",                      dut.u_l1.l2.valid[8][3],    1'b1);

        $display("\n==========================================");
        $display("  PASSED: %0d    FAILED: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("  ALL TESTS PASSED");
        else               $display("  *** FAILURES DETECTED ***");
        $display("==========================================\n");
        $finish;
    end

    initial begin
        #2_000_000;
        $display("[TB] TIMEOUT");
        $finish;
    end

endmodule
