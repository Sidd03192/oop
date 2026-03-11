`timescale 1ns/1ps

//==============================================================================
// MEMORY SUBSYSTEM
//==============================================================================
// Instantiates and connects:
//   1. LSQ  — load/store queue (dispatches from trace, issues to L1)
//   2. TLB  — address translation (filled from trace, queried on LSQ issue)
//   3. L1   — l1_cache, which embeds l2_cache, which embeds mainmem
//
// No external memory interface: mainmem is a behavioural model inside L1.
//
// Trace format (121 bits):
//   [120]     trace_value_valid  (store data valid)
//   [119:56]  trace_value        (64-bit store data)
//   [55]      trace_vaddr_valid  (EA known at dispatch)
//   [54:52]   trace_op           (OP_MEM_LOAD/STORE/RESOLVE/TLB_FILL)
//   [51:48]   trace_id           (4-bit op ID)
//   [47:0]    trace_vaddr        (48-bit virtual address)
//   [85:56]   trace_tlb_paddr    (30-bit physical address, TLB_FILL only;
//                                 overlaps with trace_value[29:0])
//
// Two-cycle L1 issue protocol (same as tb_l1_accurate.sv):
//   Cycle 0 (lsq.valid_out=1): start_in=1 + trace_vaddr_in=issue_vaddr
//                               TLB lookup starts simultaneously
//   Cycle 1 (tlb.valid=1):     start_tag_in=1 + tlb_paddr_in=result_paddr
//==============================================================================

module memory_subsystem #(
    parameter VA_WIDTH      = 48,
    parameter PA_WIDTH      = 30,
    parameter DATA_WIDTH    = 64,
    parameter BLOCK_SIZE    = 64,
    parameter TRACE_WIDTH   = 121,
    parameter LQ_ENTRIES    = 8,
    parameter SQ_ENTRIES    = 8,
    parameter L1_CAPACITY   = 512,
    parameter L1_WAYS       = 2,
    parameter L1_MSHRS      = 2
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // Trace stream
    input  logic [TRACE_WIDTH-1:0]  trace_data,
    input  logic                    trace_valid,
    output logic                    trace_ready
);

    // ------------------------------------------------------------------
    // Trace decode
    // ------------------------------------------------------------------
    localparam [2:0] OP_LOAD    = 3'd0;
    localparam [2:0] OP_STORE   = 3'd1;
    localparam [2:0] OP_RESOLVE = 3'd2;
    localparam [2:0] OP_TLB_FILL = 3'd4;

    wire                  trace_value_valid = trace_data[120];
    wire [DATA_WIDTH-1:0] trace_value       = trace_data[119:56];
    wire                  trace_vaddr_valid = trace_data[55];
    wire [2:0]            trace_op          = trace_data[54:52];
    wire [3:0]            trace_id          = trace_data[51:48];
    wire [VA_WIDTH-1:0]   trace_vaddr       = trace_data[47:0];
    // TLB_FILL paddr overlaps bits [85:56]; same bit range as trace_value[29:0]
    wire [PA_WIDTH-1:0]   trace_tlb_paddr   = trace_data[85:56];

    wire is_load     = (trace_op == OP_LOAD);
    wire is_store    = (trace_op == OP_STORE);
    wire is_resolve  = (trace_op == OP_RESOLVE);
    wire is_tlb_fill = (trace_op == OP_TLB_FILL);
    wire is_mem_op   = is_load || is_store || is_resolve;

    // ------------------------------------------------------------------
    // LSQ instance
    // ------------------------------------------------------------------
    logic                  lsq_lq_ready, lsq_sq_ready;
    logic                  lsq_valid_out;
    logic [VA_WIDTH-1:0]   lsq_issue_vaddr;
    logic [DATA_WIDTH-1:0] lsq_issue_wdata;
    logic [2:0]            lsq_issue_op;

    // Back-pressure from L1 and TLB to LSQ
    wire  l1_stall;                            // driven by u_l1.stall_out
    logic tlb_ready_sig, tlb_valid_sig;
    logic [PA_WIDTH-1:0] tlb_result_paddr;
    logic tlb_panic;

    // LSQ should not issue while TLB is processing a fill (would conflict)
    wire lsq_tlb_ready = tlb_ready_sig && !(trace_valid && is_tlb_fill);

    lsq #(
        .LQ_ENTRIES (LQ_ENTRIES),
        .SQ_ENTRIES (SQ_ENTRIES),
        .VA_WIDTH   (VA_WIDTH),
        .PA_WIDTH   (PA_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_lsq (
        .clk        (clk),
        .rst_n      (rst_n),

        // Dispatch from trace
        .valid_in    (trace_valid && is_mem_op && trace_ready),
        .op          (trace_op),
        .vaddr_in    (trace_vaddr),
        .wdata_in    (trace_value),
        .vaddr_ready (trace_vaddr_valid),
        .wdata_ready (trace_value_valid),
        .id_in       (trace_id),

        // Status from L1 / TLB
        .l1_ready    (~l1_stall),
        .tlb_ready   (lsq_tlb_ready),

        // Queue-space signals (used for trace_ready)
        .lq_ready    (lsq_lq_ready),
        .sq_ready    (lsq_sq_ready),

        // Issue outputs (drive TLB + L1)
        .valid_out   (lsq_valid_out),
        .issue_vaddr (lsq_issue_vaddr),
        .issue_wdata (lsq_issue_wdata),
        .issue_op    (lsq_issue_op)
    );

    // ------------------------------------------------------------------
    // trace_ready back-pressure
    // ------------------------------------------------------------------
    // TLB_FILL and RESOLVE never allocate queue entries — always accepted.
    // LOAD needs LQ space; STORE needs SQ space.
    assign trace_ready = !trace_valid
                       || is_tlb_fill
                       || is_resolve
                       || (is_load  && lsq_lq_ready)
                       || (is_store && lsq_sq_ready);

    // ------------------------------------------------------------------
    // TLB instance
    // ------------------------------------------------------------------
    // TLB is started by:
    //   a) a TLB_FILL from the trace (to add a new translation)
    //   b) an LSQ issue (to translate the issued vaddr before L1 tag check)
    // Fill takes priority; the two should not overlap in a well-formed trace
    // since LSQ waits for tlb_ready (which is 0 while TLB is processing).

    wire tlb_start_w   = (trace_valid && is_tlb_fill) || lsq_valid_out;
    wire tlb_is_fill_w = is_tlb_fill && trace_valid && !lsq_valid_out;
    wire [VA_WIDTH-1:0] tlb_vaddr_w = (is_tlb_fill && trace_valid)
                                       ? trace_vaddr : lsq_issue_vaddr;

    tlb u_tlb (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (tlb_start_w),
        .is_tlb_fill    (tlb_is_fill_w),
        .vaddr          (tlb_vaddr_w),
        .paddr          (trace_tlb_paddr),
        .ready          (tlb_ready_sig),
        .valid          (tlb_valid_sig),
        .result_paddr   (tlb_result_paddr),
        .panic_tlb_miss (tlb_panic)
    );

    // ------------------------------------------------------------------
    // L1 cache (l2_cache + mainmem embedded inside)
    // ------------------------------------------------------------------
    // Two-cycle protocol:
    //   Cycle 0 (lsq_valid_out=1): start_in=1, trace_vaddr_in=issue_vaddr
    //                               TLB lookup starts simultaneously
    //   Cycle 1 (tlb_valid_sig=1): start_tag_in=1, tlb_paddr_in=result_paddr

    l1_cache #(
        .L1_CAPACITY (L1_CAPACITY),
        .L1_WAYS     (L1_WAYS),
        .L1_MSHRS    (L1_MSHRS)
    ) u_l1 (
        .clk            (clk),
        .rst_n          (rst_n),

        // Cycle 0: vaddr from LSQ issue
        .start_in       (lsq_valid_out),
        .trace_vaddr_in (lsq_issue_vaddr),
        .w_in           (lsq_issue_op == OP_STORE),
        .wdata_in       (lsq_issue_wdata[BLOCK_SIZE-1:0]),

        // Cycle 1: paddr from TLB (fires one cycle after lsq_valid_out)
        .start_tag_in   (tlb_valid_sig),
        .tlb_paddr_in   (tlb_result_paddr),

        // Back-pressure to LSQ
        .stall_out      (l1_stall)
    );

endmodule
