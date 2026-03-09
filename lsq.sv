`timescale 1ns/1ps

// =============================================================================
// LSQ — combined load/store queue
//
// Two separate entry arrays (LQ: 10 entries, SQ: 6 entries) with independent
// head/tail pointers, sharing a single module and interface.
//
// Load lifecycle:
//   LQ_EMPTY -> LQ_WAITING_ADDR -> LQ_WAITING_ISSUE -> LQ_EMPTY
//
// Store lifecycle:
//   SQ_EMPTY -> SQ_WAITING_ADDR / DATA -> SQ_WAITING_ISSUE -> SQ_EMPTY
//
// Assumptions:
//   - Higher module drives vaddr to TLB and L1 simultaneously on EA resolve
//   - Store data is always known at dispatch (from trace)
//   - No return values needed for either loads or stores
//   - Loads dismiss as soon as EA known + no unresolved stores ahead + L1/TLB ready
//   - Stores retire from head only when EA resolved and L1 ready
// =============================================================================
module lsq #(
    parameter LQ_ENTRIES  = 10,
    parameter SQ_ENTRIES  = 6,
    parameter VA_WIDTH    = 48,
    parameter PA_WIDTH    = 30,
    parameter DATA_WIDTH  = 64
)(
    input  logic clk,
    input  logic rst_n,

    // -------------------------------------------------------------------------
    // LOAD DISPATCH
    // -------------------------------------------------------------------------
    input  logic                            lq_valid_in
    input  logic [VA_WIDTH-1:0]             lq_vaddr_in,
    input  logic                            lq_vaddr_ready,  // EA known at dispatch
    output logic                            lq_ready_out,

    // LOAD effective address resolution (arrives after dispatch if not ready)
    input  logic                            lq_ea_resolve,
    input  logic [3:0]                      lq_ea_tag,
    input  logic [VA_WIDTH-1:0]             lq_ea_vaddr,

    // LOAD issue — exposed so higher module can drive TLB/L1 with correct vaddr
    output logic                            lq_issue_valid,
    output logic [VA_WIDTH-1:0]             lq_issue_vaddr,
    input  logic                            lq_l1_ready,    // L1 accepted load
    input  logic                            lq_tlb_ready,   // TLB accepted load

    // -------------------------------------------------------------------------
    // STORE DISPATCH
    // -------------------------------------------------------------------------
    input  logic                            sq_valid_in
    input  logic [VA_WIDTH-1:0]             sq_vaddr_in,
    input  logic                            sq_vaddr_ready,  // EA known at dispatch
    input  logic [DATA_WIDTH-1:0]           sq_wdata_in,      // always valid at dispatch
    input  logic                            sq_wdata_ready,   // data value known at dispatch
    output logic                            sq_ready_out,

    // STORE effective address resolution
    input  logic                            sq_ea_resolve,
    input  logic [$clog2(SQ_ENTRIES)-1:0]   sq_ea_tag,
    input  logic [VA_WIDTH-1:0]             sq_ea_vaddr,

    // STORE retirement — exposed so higher module can drive TLB/L1
    output logic                            sq_issue_valid,
    output logic [VA_WIDTH-1:0]             sq_issue_vaddr,
    output logic [DATA_WIDTH-1:0]           sq_issue_wdata,
    input  logic                            sq_l1_ready,    // L1 accepted store
    input  logic                            sq_tlb_ready    // TLB accepted store
);

    localparam int LQ_PTR_WIDTH = $clog2(LQ_ENTRIES);
    localparam int SQ_PTR_WIDTH = $clog2(SQ_ENTRIES);

    // =========================================================================
    // LOAD QUEUE STATE
    // =========================================================================
    typedef enum logic [1:0] {
        LQ_EMPTY         = 2'd0,
        LQ_WAITING_ADDR  = 2'd1,  // dispatched, EA not yet known
        LQ_WAITING_ISSUE = 2'd2   // EA known, waiting for clear path to L1
    } lq_state_t;

    lq_state_t                    lq_state   [LQ_ENTRIES];
    logic [VA_WIDTH - 1:0]        lq_vaddr   [LQ_ENTRIES];
    logic [3:0]                   lq_tags    [LQ_ENTRIES];
    logic [SQ_PTR_WIDTH - 1:0]    lq_sq_idx  [LQ_ENTRIES];  // index of sq tail when load was added

    logic [LQ_PTR_WIDTH - 1:0] lq_head, lq_tail;

    assign lq_ready_out = ((lq_tail + 1'b1) != lq_head);

    // =========================================================================
    // STORE QUEUE STATE
    // =========================================================================
    typedef enum logic [1:0] {
        SQ_EMPTY         = 2'd0,
        SQ_WAITING_ADDR  = 2'd1,  // EA not yet known
        SQ_WAITING_DATA  = 2'd2,  // EA known, waiting for TLB
        SQ_WAITING_ISSUE = 2'd3   // EA resolved, ready to retire at head
    } sq_state_t;

    sq_state_t                  sq_state  [SQ_ENTRIES];
    logic [VA_WIDTH - 1:0]      sq_vaddr  [SQ_ENTRIES];
    logic [DATA_WIDTH - 1:0]    sq_wdata  [SQ_ENTRIES];
    logic [3:0]                 sq_tags   [SQ_ENTRIES];
    logic [LQ_PTR_WIDTH - 1:0]  sq_lq_idx [SQ_ENTRIES];  // index of lq tail when store was added
 
    // Flat addr_ready vector for cheap combinational scan
    logic [SQ_ENTRIES - 1:0] sq_addr_ready;

    logic [SQ_PTR_WIDTH - 1:0] sq_head, sq_tail;

    assign sq_ready_out = ((sq_tail + 1'b1) != sq_head);

    // =========================================================================
    // LOAD ISSUE ARBITRATION
    // Oldest LQ_WAITING_ISSUE entry, gated by has_unresolved
    // =========================================================================
    logic                    lq_found;
    logic [LQ_PTR_WIDTH-1:0] lq_found_entry;

    always_comb begin
        lq_found       = 1'b0;
        lq_found_entry = '0;
        for (int i = 0; i < LQ_ENTRIES; i++) begin
            logic [LQ_PTR_WIDTH-1:0] idx;
            idx = lq_head + i[LQ_PTR_WIDTH - 1:0];
            if (!lq_found && lq_state[idx] == LQ_WAITING_ISSUE) begin
                lq_found       = 1'b1;
                lq_found_entry = idx;
            end
        end
    end


    // =========================================================================
    // INTERNAL: has_unresolved
    // Combinational scan of SQ from sq_head to lq_issue_tag (exclusive).
    // Blocks a load from issuing if any older store has an unknown address.
    // =========================================================================
    logic has_unresolved;

    always_comb begin
   `     has_unresolved = 1'b0;
        for (int i = 0; i < SQ_ENTRIES; i++) begin
            logic [SQ_PTR_WIDTH - 1:0] idx;
            idx = sq_head + i[SQ_PTR_WIDTH - 1:0];
            if (sq_state[idx] != SQ_EMPTY && !sq_addr_ready[idx]) begin
                has_unresolved = 1'b1;
            end
            if (idx == lq_sq_idx[lq_found_entry]) begin
                break;
            end
        end
    end

    // =========================================================================
    // SEQUENTIAL LOGIC
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lq_head      <= '0;
            lq_tail      <= '0;
            sq_head      <= '0;
            sq_tail      <= '0;
            sq_addr_ready <= '0;
            for (int i = 0; i < LQ_ENTRIES; i++) begin
                lq_state[i] <= LQ_EMPTY;
                lq_vaddr[i] <= '0;
                lq_tags[i]  <= '0;
                lq_sq_idx[i]  <= '0;
            end
            for (int i = 0; i < SQ_ENTRIES; i++) begin
                sq_state[i] <= SQ_EMPTY;
                sq_vaddr[i] <= '0;
                sq_wdata[i] <= '0;
                sq_tags[i]  <= '0;
                sq_lq_idx[i]  <= '0;
            end

        end else begin

            // -----------------------------------------------------------------
            // LOAD DISPATCH
            // -----------------------------------------------------------------
            if (lq_valid_in && lq_ready_out) begin
                lq_vaddr[lq_tail] <= lq_vaddr_in;
                lq_state[lq_tail] <= lq_vaddr_ready ? LQ_WAITING_ISSUE : LQ_WAITING_ADDR;
                lq_tail           <= lq_tail + 1'b1;
            end

            // -----------------------------------------------------------------
            // LOAD EA resolution
            // -----------------------------------------------------------------
            if (lq_ea_resolve) begin
                for (int i = 0; i < LQ_ENTRIES; i++) begin
                    idx = lq_head + i[LQ_PTR_WIDTH - 1:0];
                    if (lq_tags[idx] == lq_ea_tag && lq_state[idx] == LQ_WAITING_ADDR) begin
                        lq_vaddr[idx] <= lq_ea_vaddr;
                        lq_state[idx] <= LQ_WAITING_ISSUE;
                    end
                end
            end

            // -----------------------------------------------------------------
            // LOAD dismissal — L1 and TLB both accepted, no unresolved stores
            // -----------------------------------------------------------------
            if (lq_l1_ready && lq_tlb_ready && lq_found) begin
                lq_state[lq_found_entry] <= LQ_EMPTY;
                if (lq_found_entry == lq_head) begin
                    lq_head <= lq_head + 1'b1;
                end
                lq_issue_valid <= !has_unresolved;
                lq_issue_vaddr <= lq_vaddr[lq_found_entry];
            end

            // Drain consecutive empty entries from LQ head
            if (lq_head != lq_tail && lq_state[lq_head] == LQ_EMPTY)
                lq_head <= lq_head + 1'b1;

            // -----------------------------------------------------------------
            // STORE DISPATCH
            // -----------------------------------------------------------------
            if (sq_valid_in && sq_ready_out) begin
                sq_vaddr[sq_tail]      <= sq_vaddr_in;
                sq_wdata[sq_tail]      <= sq_wdata_in;
                sq_addr_ready[sq_tail] <= sq_vaddr_ready;
                sq_state[sq_tail]      <= sq_wdata_ready ? (sq_vaddr_ready ? SQ_WAITING_ISSUE : SQ_WAITING_ADDRESS) 
                                                           : SQ_WAITING_DATA;
                sq_tail                <= sq_tail + 1'b1;
            end

            // -----------------------------------------------------------------
            // STORE EA resolution
            // -----------------------------------------------------------------
            if (sq_ea_resolve && sq_state[sq_ea_tag] == SQ_WAITING_ADDR) begin
                sq_vaddr[sq_ea_tag]      <= sq_ea_vaddr;
                sq_addr_ready[sq_ea_tag] <= 1'b1;
                sq_state[sq_ea_tag]      <= SQ_WAITING_ISSUE;
            end

            // -----------------------------------------------------------------
            // STORE retirement — head accepted by L1 & TLB
            // -----------------------------------------------------------------
            if (sq_issue_valid && sq_l1_ready) begin
                sq_issue_valid <= (sq_head != sq_tail) && (sq_state[sq_head] == SQ_WAITING_ISSUE);
                sq_issue_vaddr <= sq_vaddr[sq_head];
                sq_issue_wdata <= sq_wdata[sq_head];
                sq_state[sq_head]      <= SQ_EMPTY;
                sq_addr_ready[sq_head] <= 1'b0;
                sq_head                <= sq_head + 1'b1;
            end

        end
    end

endmodule