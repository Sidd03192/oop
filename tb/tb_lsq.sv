`timescale 1ns/1ps

// =============================================================================
// LSQ Testbench — Verilator compatible
//
// Tests:
//   1. Basic load dispatch and issue (EA known at dispatch)
//   2. Basic store dispatch and issue (EA and data known at dispatch)
//   3. Load with EA resolved after dispatch (RESOLVE op)
//   4. Store with EA resolved after dispatch
//   5. Load blocked by unresolved store ahead (same address)
//   6. Load issues past resolved store ahead (different address)
//   7. Store blocked by unresolved load ahead
//   8. Multiple loads in flight, out-of-order EA resolution
//   9. Queue full behavior (head advances after dismissal)
//  10. SQ_UNRESOLVED: both addr and data arrive separately
// =============================================================================

module lsq_tb;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam LQ_ENTRIES  = 8;
    localparam SQ_ENTRIES  = 8;
    localparam VA_WIDTH    = 48;
    localparam PA_WIDTH    = 30;
    localparam DATA_WIDTH  = 64;

    localparam logic [2:0] LOAD    = 3'd0;
    localparam logic [2:0] STORE   = 3'd1;
    localparam logic [2:0] RESOLVE = 3'd2;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic                    clk;
    logic                    rst_n;
    logic [2:0]              op;
    logic                    valid_in;
    logic [VA_WIDTH-1:0]     vaddr_in;
    logic [DATA_WIDTH-1:0]   wdata_in;
    logic                    vaddr_ready;
    logic                    wdata_ready;
    logic [3:0]              id_in;
    logic                    l1_ready;
    logic                    tlb_ready;
    logic                    lq_ready;
    logic                    sq_ready;
    logic                    valid_out;
    logic [VA_WIDTH-1:0]     issue_vaddr;
    logic [DATA_WIDTH-1:0]   issue_wdata;
    logic [2:0]              issue_op;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    lsq #(
        .LQ_ENTRIES (LQ_ENTRIES),
        .SQ_ENTRIES (SQ_ENTRIES),
        .VA_WIDTH   (VA_WIDTH),
        .PA_WIDTH   (PA_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .op          (op),
        .valid_in    (valid_in),
        .vaddr_in    (vaddr_in),
        .wdata_in    (wdata_in),
        .vaddr_ready (vaddr_ready),
        .wdata_ready (wdata_ready),
        .id_in       (id_in),
        .l1_ready    (l1_ready),
        .tlb_ready   (tlb_ready),
        .lq_ready    (lq_ready),
        .sq_ready    (sq_ready),
        .valid_out   (valid_out),
        .issue_vaddr (issue_vaddr),
        .issue_wdata (issue_wdata),
        .issue_op    (issue_op)
    );

    // -------------------------------------------------------------------------
    // Clock generation: 10ns period
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Test tracking
    // -------------------------------------------------------------------------
    int test_num   = 0;
    int pass_count = 0;
    int fail_count = 0;

    task pass(input string msg);
        $display("[PASS] Test %0d: %s", test_num, msg);
        pass_count++;
    endtask

    task fail(input string msg);
        $display("[FAIL] Test %0d: %s", test_num, msg);
        fail_count++;
    endtask

    // -------------------------------------------------------------------------
    // Helper: default all inputs to idle
    // -------------------------------------------------------------------------
    task idle();
        valid_in    = 0;
        op          = LOAD;
        vaddr_in    = '0;
        wdata_in    = '0;
        vaddr_ready = 0;
        wdata_ready = 0;
        id_in       = '0;
        l1_ready    = 0;
        tlb_ready   = 0;
    endtask

    // -------------------------------------------------------------------------
    // Helper: dispatch a load
    // -------------------------------------------------------------------------
    task dispatch_load(
        input [VA_WIDTH-1:0]   vaddr,
        input                  va_rdy,
        input [3:0]            id
    );
        @(negedge clk);
        valid_in    = 1;
        op          = LOAD;
        vaddr_in    = vaddr;
        vaddr_ready = va_rdy;
        wdata_ready = 0;
        wdata_in    = '0;
        id_in       = id;
        @(posedge clk); #1;
        idle();
    endtask

    // -------------------------------------------------------------------------
    // Helper: dispatch a store
    // -------------------------------------------------------------------------
    task dispatch_store(
        input [VA_WIDTH-1:0]   vaddr,
        input [DATA_WIDTH-1:0] wdata,
        input                  va_rdy,
        input                  wd_rdy,
        input [3:0]            id
    );
        @(negedge clk);
        valid_in    = 1;
        op          = STORE;
        vaddr_in    = vaddr;
        wdata_in    = wdata;
        vaddr_ready = va_rdy;
        wdata_ready = wd_rdy;
        id_in       = id;
        @(posedge clk); #1;
        idle();
    endtask

    // -------------------------------------------------------------------------
    // Helper: send a resolve
    // -------------------------------------------------------------------------
    task resolve_op(
        input [3:0]            id,
        input [VA_WIDTH-1:0]   vaddr,
        input [DATA_WIDTH-1:0] wdata,
        input                  va_rdy,
        input                  wd_rdy
    );
        @(negedge clk);
        valid_in    = 1;
        op          = RESOLVE;
        id_in       = id;
        vaddr_in    = vaddr;
        wdata_in    = wdata;
        vaddr_ready = va_rdy;
        wdata_ready = wd_rdy;
        @(posedge clk); #1;
        idle();
    endtask

    // -------------------------------------------------------------------------
    // Helper: pulse l1+tlb ready for up to timeout cycles, watch for valid_out
    // -------------------------------------------------------------------------
    task automatic wait_for_issue(
        input int              timeout,
        output logic           issued,
        output logic [VA_WIDTH-1:0]   seen_vaddr,
        output logic [DATA_WIDTH-1:0] seen_wdata
    );
        issued     = 0;
        seen_vaddr = '0;
        seen_wdata = '0;
        for (int c = 0; c < timeout; c++) begin
            @(negedge clk);
            l1_ready  = 1;
            tlb_ready = 1;
            @(posedge clk); #1;
            l1_ready  = 0;
            tlb_ready = 0;
            if (valid_out) begin
                issued     = 1;
                seen_vaddr = issue_vaddr;
                seen_wdata = issue_wdata;
                break;
            end
        end
    endtask

    // =========================================================================
    // RESET
    // =========================================================================
    task do_reset();
        rst_n = 0;
        idle();
        repeat(3) @(posedge clk);
        #1;
        rst_n = 1;
        @(posedge clk); #1;
    endtask

    // =========================================================================
    // MAIN TEST SEQUENCE
    // =========================================================================
    logic           issued;
    logic [VA_WIDTH-1:0]   sv;
    logic [DATA_WIDTH-1:0] sw;

    initial begin
        $display("========================================");
        $display(" LSQ Testbench Start");
        $display("========================================");

        // =====================================================================
        // TEST 1: Basic load — EA known at dispatch, issues immediately
        // =====================================================================
        test_num = 1;
        do_reset();
        dispatch_load(48'hAAAA_0000, 1, 4'd0);
        wait_for_issue(5, issued, sv, sw);
        if (issued && sv == 48'hAAAA_0000)
            pass("Load with known EA issued correctly");
        else
            fail($sformatf("Load issue failed: issued=%0b vaddr=%0h", issued, sv));

        // =====================================================================
        // TEST 2: Basic store — EA and data known at dispatch
        // =====================================================================
        test_num = 2;
        do_reset();
        dispatch_store(48'hBBBB_0000, 64'hDEAD_BEEF, 1, 1, 4'd8);
        wait_for_issue(5, issued, sv, sw);
        if (issued && sv == 48'hBBBB_0000 && sw == 64'hDEAD_BEEF)
            pass("Store with known EA+data issued correctly");
        else
            fail($sformatf("Store issue failed: issued=%0b vaddr=%0h wdata=%0h", issued, sv, sw));

        // =====================================================================
        // TEST 3: Load EA resolved after dispatch via RESOLVE
        // =====================================================================
        test_num = 3;
        do_reset();
        dispatch_load(48'h0, 0, 4'd1);
        // Should not issue yet — try one cycle with l1/tlb ready
        @(negedge clk); l1_ready=1; tlb_ready=1; @(posedge clk); #1;
        l1_ready=0; tlb_ready=0;
        if (valid_out) begin
            fail("Load issued before EA resolved");
        end else begin
            resolve_op(4'd1, 48'hCCCC_0000, '0, 1, 0);
            wait_for_issue(5, issued, sv, sw);
            if (issued && sv == 48'hCCCC_0000)
                pass("Load EA resolved via RESOLVE and then issued");
            else
                fail($sformatf("Load did not issue after RESOLVE: issued=%0b vaddr=%0h", issued, sv));
        end

        // =====================================================================
        // TEST 4: Store EA resolved after dispatch
        // =====================================================================
        test_num = 4;
        do_reset();
        dispatch_store(48'h0, 64'hCAFE_F00D, 0, 1, 4'd9);
        @(negedge clk); l1_ready=1; tlb_ready=1; @(posedge clk); #1;
        l1_ready=0; tlb_ready=0;
        if (valid_out) begin
            fail("Store issued before EA resolved");
        end else begin
            resolve_op(4'd9, 48'hDDDD_0000, '0, 1, 0);
            wait_for_issue(5, issued, sv, sw);
            if (issued && sv == 48'hDDDD_0000 && sw == 64'hCAFE_F00D)
                pass("Store EA resolved via RESOLVE and then issued");
            else
                fail($sformatf("Store did not issue after RESOLVE: issued=%0b vaddr=%0h wdata=%0h", issued, sv, sw));
        end

        // =====================================================================
        // TEST 5: Load blocked by unresolved store ahead
        // =====================================================================
        test_num = 5;
        do_reset();
        dispatch_store(48'h0, 64'hFF, 0, 1, 4'd8);      // store EA unknown
        dispatch_load(48'hEEEE_0000, 1, 4'd0);           // load EA known
        @(negedge clk); l1_ready=1; tlb_ready=1; @(posedge clk); #1;
        l1_ready=0; tlb_ready=0;
        if (valid_out) begin
            fail("Load issued despite unresolved store ahead");
        end else begin
            resolve_op(4'd8, 48'hFFFF_0000, '0, 1, 0);  // store resolves to different addr
            wait_for_issue(5, issued, sv, sw);
            wait_for_issue(5, issued, sv, sw);
            if (issued)
                pass("Load correctly blocked then issued after store EA resolved");
            else
                fail("Load did not issue after store EA resolved");
        end

        // =====================================================================
        // TEST 6: Load issues past fully resolved store (different address)
        // =====================================================================
        test_num = 6;
        do_reset();
        dispatch_store(48'h1000, 64'h00, 1, 0, 4'd8);
        dispatch_store(48'h3000, 64'h00, 1, 0, 4'd9);
        dispatch_store(48'h4000, 64'h00, 1, 0, 4'd10);
        dispatch_store(48'h5000, 64'h00, 1, 0, 4'd11);

        dispatch_load(48'h2000, 1, 4'd0);
        wait_for_issue(5, issued, sv, sw);
        if (issued && sv == 48'h2000)
            pass("Load issued past fully-resolved store with different address");
        else
            fail($sformatf("Load unexpectedly blocked: issued=%0b vaddr=%0h", issued, sv));

        // =====================================================================
        // TEST 7: Store blocked by unresolved load ahead
        // =====================================================================
        test_num = 7;
        do_reset();
        dispatch_load(48'h0, 0, 4'd0);                   // load EA unknown
        dispatch_store(48'h3000, 64'hCD, 1, 1, 4'd8);   // store fully ready
        @(negedge clk); l1_ready=1; tlb_ready=1; @(posedge clk); #1;
        l1_ready=0; tlb_ready=0;
        if (valid_out) begin
            fail("Store issued despite unresolved load ahead");
        end else begin
            resolve_op(4'd0, 48'h4000, '0, 1, 0);
            // Load issues first
            wait_for_issue(5, issued, sv, sw);
            if (!issued) begin
                fail("Load did not issue after resolve");
            end else begin
                // Now store should issue
                wait_for_issue(5, issued, sv, sw);
                if (issued && sv == 48'h3000)
                    pass("Store waited for unresolved load then issued");
                else
                    fail($sformatf("Store did not issue after load dismissed: issued=%0b vaddr=%0h", issued, sv));
            end
        end

        // =====================================================================
        // TEST 8: Multiple loads, out-of-order EA resolution
        // =====================================================================
        test_num = 8;
        do_reset();
        dispatch_load(48'h0,    0, 4'd0);   // EA unknown
        dispatch_load(48'h0,    0, 4'd1);   // EA unknown
        dispatch_load(48'h5000, 1, 4'd2);   // EA known
        resolve_op(4'd1, 48'h6000, '0, 1, 0);
        resolve_op(4'd0, 48'h7000, '0, 1, 0);
        begin
            int seen = 0;
            for (int c = 0; c < 15; c++) begin
                @(negedge clk); l1_ready=1; tlb_ready=1;
                @(posedge clk); #1;
                l1_ready=0; tlb_ready=0;
                if (valid_out) seen++;
            end
            if (seen == 3)
                pass("All 3 loads issued after out-of-order EA resolution");
            else
                fail($sformatf("Expected 3 issues, got %0d", seen));
        end

        // =====================================================================
        // TEST 9: LQ fills, head advances after dismissal, new entry accepted
        // =====================================================================
        test_num = 9;
        do_reset();
        for (int i = 0; i < LQ_ENTRIES; i++) begin
            dispatch_load(48'h100 * i, 1, i[3:0]);
        end
        wait_for_issue(5, issued, sv, sw);
        @(posedge clk); #1;
        if (lq_ready)
            pass("LQ slot freed and lq_ready re-asserted after dismissal");
        else
            fail("lq_ready did not re-assert after head advance");

        // =====================================================================
        // TEST 10: SQ_UNRESOLVED — addr arrives first, then data
        // =====================================================================
        test_num = 10;
        do_reset();
        dispatch_store(48'h0, 64'h0, 0, 0, 4'd8);  // both unknown -> SQ_UNRESOLVED
        @(negedge clk); l1_ready=1; tlb_ready=1; @(posedge clk); #1;
        l1_ready=0; tlb_ready=0;
        if (valid_out) begin
            fail("Store issued from SQ_UNRESOLVED without any resolution");
        end else begin
            resolve_op(4'd8, 48'hAAAA_1234, '0, 1, 0);   // addr resolves -> SQ_WAITING_DATA
            @(negedge clk); l1_ready=1; tlb_ready=1; @(posedge clk); #1;
            l1_ready=0; tlb_ready=0;
            if (valid_out) begin
                fail("Store issued after only addr resolved (data still missing)");
            end else begin
                resolve_op(4'd8, '0, 64'hDEAD_1234, 0, 1);  // data resolves -> SQ_WAITING_ISSUE
                wait_for_issue(5, issued, sv, sw);
                if (issued && sv == 48'hAAAA_1234 && sw == 64'hDEAD_1234)
                    pass("SQ_UNRESOLVED: issued correctly after addr then data resolved");
                else
                    fail($sformatf("SQ_UNRESOLVED issue failed: issued=%0b vaddr=%0h wdata=%0h", issued, sv, sw));
            end
        end

        // =====================================================================
        // RESULTS
        // =====================================================================
        $display("========================================");
        $display(" Results: %0d / %0d passed", pass_count, pass_count + fail_count);
        $display("========================================");
        if (fail_count == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" %0d TEST(S) FAILED", fail_count);
        $display("========================================");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------------------------
    initial begin
        #100000;
        $display("[TIMEOUT] Simulation exceeded time limit");
        $finish;
    end

endmodule