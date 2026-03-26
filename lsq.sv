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
    parameter LQ_ENTRIES  = 8,
    parameter SQ_ENTRIES  = 8,
    parameter VA_WIDTH    = 48,
    parameter PA_WIDTH    = 30,
    parameter DATA_WIDTH  = 64
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [2:0] op,

    // -------------------------------------------------------------------------
    // INCOMING MEM OP
    // -------------------------------------------------------------------------
    input  logic                              valid_in,
    input  logic [VA_WIDTH - 1:0]             vaddr_in,
    input  logic [DATA_WIDTH -1:0]            wdata_in,
    input  logic                              vaddr_ready,  // EA known at dispatch
    input  logic                              wdata_ready,  // Write data known at dispatch
    input  logic [3:0]                        id_in,

    input  logic                            l1_ready,     // L1 accepted
    input  logic                            tlb_ready,    // TLB accepted  
    
    output logic                            lq_ready,
    output logic                            sq_ready,
    output logic                            valid_out,

    // MEM issue — exposed so higher module can drive TLB/L1 with correct vaddr
    output logic [VA_WIDTH-1:0]             issue_vaddr,
    output logic [DATA_WIDTH -1:0]          issue_wdata,
    output logic [2:0]                      issue_op
);

    localparam int LQ_PTR_WIDTH = $clog2(LQ_ENTRIES);
    localparam int SQ_PTR_WIDTH = $clog2(SQ_ENTRIES);

    localparam logic [2:0] LOAD         = 3'd0;  // reading from memory
    localparam logic [2:0] STORE        = 3'd1;  // writing to memory
    localparam logic [2:0] RESOLVE      = 3'd2;  // Resolving addr or value of a memory operation


    // =========================================================================
    // LOAD QUEUE STATE
    // =========================================================================
    typedef enum logic [1:0] {
        LQ_EMPTY         = 2'd0,
        LQ_WAITING_ADDR  = 2'd1,  // dispatched, EA not yet known
        LQ_WAITING_ISSUE = 2'd2   // EA known, waiting for clear path to L1
    } lq_state_t;

    lq_state_t                   lq_state      [LQ_ENTRIES];
    logic [VA_WIDTH - 1:0]       lq_vaddr      [LQ_ENTRIES];
    logic [3:0]                  lq_id         [LQ_ENTRIES];
    logic [SQ_ENTRIES - 1:0]     lq_before_vec [LQ_ENTRIES];  // Store queue entries before the load


    logic [LQ_PTR_WIDTH - 1:0] lq_head, lq_tail;

    assign lq_ready = (lq_state[lq_tail] == LQ_EMPTY);

    // =========================================================================
    // STORE QUEUE STATE
    // =========================================================================
    typedef enum logic [2:0] {
        SQ_EMPTY         = 3'd0,
        SQ_UNRESOLVED    = 3'd1,  // EA & WDATA NOT KNOWN
        SQ_WAITING_ADDR  = 3'd2,  // EA not yet known
        SQ_WAITING_DATA  = 3'd3,  // EA known, waiting for data
        SQ_WAITING_ISSUE = 3'd4   // EA resolved, ready to retire at head
    } sq_state_t;

    sq_state_t                   sq_state      [SQ_ENTRIES];
    logic [VA_WIDTH - 1:0]       sq_vaddr      [SQ_ENTRIES];
    logic [DATA_WIDTH - 1:0]     sq_wdata      [SQ_ENTRIES];
    logic [3:0]                  sq_id         [SQ_ENTRIES];
    logic [LQ_ENTRIES - 1:0]     sq_before_vec [SQ_ENTRIES];  // Load queue entries before the store

    logic [SQ_PTR_WIDTH - 1:0] sq_head, sq_tail;

    assign sq_ready = (sq_state[sq_tail] == SQ_EMPTY);

    // =========================================================================
    // LOAD ISSUE ARBITRATION
    // Oldest LQ_WAITING_ISSUE entry, gated by is_unresolved_store
    // =========================================================================
    logic                      lq_found;
    logic [LQ_PTR_WIDTH - 1:0] lq_found_entry;

    always_comb begin
        lq_found       =  1'b0;
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
    // INTERNAL: is_unresolved_store (i.e. an unresolved store)
    // Combinational scan of SQ from sq_head to lq_sq_idx of found entry.
    // Blocks a load from issuing if any older store has an unknown address.
    // =========================================================================
    logic is_unresolved_store;

    always_comb begin
        is_unresolved_store = 1'b0;
        for (int i = 0; i < SQ_ENTRIES; i++) begin
            logic [SQ_PTR_WIDTH - 1:0] idx;
            idx = sq_head + i[SQ_PTR_WIDTH - 1:0];
            if (lq_found) begin
                // go to before vector of load entry found. 
                // starting at the tail idx check both before @ idx == 1 && vaddr @ idx
                // if vaddr is unresolved; mark flag, cannot issue load.
                if (!is_unresolved_store && lq_before_vec[lq_found_entry][idx] == 1'b1 
                && (sq_state[idx] == SQ_WAITING_ADDR || sq_state[idx] == SQ_UNRESOLVED 
                || (sq_state[idx] == SQ_WAITING_DATA && sq_vaddr[idx] == lq_vaddr[lq_found_entry]))) begin
                    is_unresolved_store = 1'b1;
                end
            end
        end
    end


    // =========================================================================
    // STORE ISSUE ARBITRATION
    // Oldest SQ_WAITING_ISSUE entry, gated by is_unresolved_load
    // =========================================================================
    logic                      sq_found;
    logic [SQ_PTR_WIDTH - 1:0] sq_found_entry;
    logic                      sq_unresolved;

    always_comb begin
        sq_found       = 1'b0;
        sq_found_entry = sq_head;
        sq_unresolved  = 1'b0;

        // If the head is ready, we issue. 
        if (sq_state[sq_head] == SQ_WAITING_ISSUE) begin
            sq_found = 1'b1;
        end
        // If the head is valid but NOT ready, it blocks the queue.
        else if (sq_state[sq_head] != SQ_EMPTY) begin
            sq_unresolved = 1'b1;
        end
    end


    // =========================================================================
    // INTERNAL: is_unresolved_load and unresolved_val_store 
    // (i.e. an unresolved load or a store of matching vaddr waiting on its value)
    // Combinational scan of LQ from lq_head to lq_sq_idx of found entry.
    // Blocks a load from issuing if any older store has an unknown address.
    // =========================================================================
    logic is_unresolved_load;
    // logic unresolved_val_store;
    // logic terminate_loop;

    always_comb begin
        is_unresolved_load = 1'b0;
        // unresolved_val_store = 1'b0;
        // terminate_loop = 1'b0;
        for (int i = 0; i < LQ_ENTRIES; i++) begin
            logic [LQ_PTR_WIDTH - 1:0] idx;
            idx = lq_head + i[LQ_PTR_WIDTH - 1:0];
            if (sq_found) begin
                // go to before vector of load entry found. 
                // starting at the tail idx check both before @ idx == 1 && vaddr @ idx
                // if vaddr is unresolved; mark flag, cannot issue load.
                if (!is_unresolved_load && sq_before_vec[sq_found_entry][idx] == 1'b1 && lq_state[idx] == LQ_WAITING_ADDR) begin
                    is_unresolved_load = 1'b1;
                end
            end
        end
        // for (int i = 0; i < SQ_ENTRIES; i++) begin
        //     logic [SQ_PTR_WIDTH-1:0] idx;
        //     idx = sq_head + i[SQ_PTR_WIDTH - 1:0];
        //     if (sq_found) begin
        //         if (idx == sq_found_entry) begin
        //             terminate_loop = 1'b1;
        //         end
        //         else if (!terminate_loop && !unresolved_val_store && (sq_vaddr[sq_found_entry] == sq_vaddr[idx]) && sq_state[idx] == SQ_WAITING_DATA) begin
        //             unresolved_val_store = 1'b1;
        //             terminate_loop = 1'b1;
        //         end
        //     end
        // end
    end

    // =========================================================================
    // SEQUENTIAL LOGIC
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out  <= '0;
            lq_head      <= '0;
            lq_tail      <= '0;
            sq_head      <= '0;
            sq_tail      <= '0;
            for (int i = 0; i < LQ_ENTRIES; i++) begin
                lq_state[i] <= LQ_EMPTY;
            end
            for (int i = 0; i < SQ_ENTRIES; i++) begin
                sq_state[i] <= SQ_EMPTY;
            end

        end else begin
            valid_out <= 0;
            // -----------------------------------------------------------------
            // DISPATCH
            // -----------------------------------------------------------------
            // Assumes higher module checks lq_ready before asserting valid_in
            if (valid_in && op == LOAD) begin
                lq_vaddr[lq_tail]  <= vaddr_in;
                lq_id[lq_tail]     <= id_in;
                lq_state[lq_tail]  <= vaddr_ready ? LQ_WAITING_ISSUE : LQ_WAITING_ADDR;
                for (int i = 0; i < SQ_ENTRIES; i++) begin
                    lq_before_vec[lq_tail][i] <= (sq_state[i] != SQ_EMPTY);
                end
                lq_tail           <= lq_tail + 1'b1;
            end
            // Assumes higher module checks sq_ready before asserting valid_in
            if (valid_in && op == STORE) begin
                sq_vaddr[sq_tail]      <= vaddr_in;
                sq_wdata[sq_tail]      <= wdata_in;
                sq_id[sq_tail]         <= id_in;
                sq_state[sq_tail]      <= wdata_ready ? (vaddr_ready ? SQ_WAITING_ISSUE : SQ_WAITING_ADDR) 
                                                      : (vaddr_ready ? SQ_WAITING_DATA : SQ_UNRESOLVED);
                for (int i = 0; i < LQ_ENTRIES; i++) begin
                    sq_before_vec[sq_tail][i] <= (lq_state[i] != LQ_EMPTY);
                end
                sq_tail                <= sq_tail + 1'b1;
            end

            // -----------------------------------------------------------------
            // EA resolution
            // -----------------------------------------------------------------
            if (valid_in && op == RESOLVE) begin
                if (id_in < 4'd8) begin // loads assumed to have IDs 0-7, stores 8-15
                    for (int i = 0; i < LQ_ENTRIES; i++) begin
                        if (lq_id[i] == id_in && lq_state[i] == LQ_WAITING_ADDR) begin
                            if (vaddr_ready) begin
                                lq_vaddr[i] <= vaddr_in;
                                lq_state[i] <= LQ_WAITING_ISSUE;
                            end
                        end
                    end
                end
                else begin
                    for (int i = 0; i < SQ_ENTRIES; i++) begin   
                        if (sq_id[i] == id_in && (sq_state[i] != SQ_EMPTY && sq_state[i] != SQ_WAITING_ISSUE)) begin
                            
                            if (vaddr_ready) sq_vaddr[i] <= vaddr_in;
                            if (wdata_ready) sq_wdata[i] <= wdata_in;

                            if (sq_state[i] == SQ_UNRESOLVED) begin
                                if (vaddr_ready && wdata_ready) sq_state[i] <= SQ_WAITING_ISSUE;
                                else if (vaddr_ready)           sq_state[i] <= SQ_WAITING_DATA;
                                else if (wdata_ready)           sq_state[i] <= SQ_WAITING_ADDR;
                            end 
                            else if (sq_state[i] == SQ_WAITING_ADDR && vaddr_ready) begin
                                sq_state[i] <= SQ_WAITING_ISSUE;
                            end 
                            else if (sq_state[i] == SQ_WAITING_DATA && wdata_ready) begin
                                sq_state[i] <= SQ_WAITING_ISSUE;
                            end
                        end
                    end
                end
            end

            // -----------------------------------------------------------------
            // Dismissal — L1 and TLB both accepted
            // -----------------------------------------------------------------
            if (l1_ready && tlb_ready) begin
                if (lq_found && !is_unresolved_store 
                && (lq_before_vec[lq_found_entry][sq_head] == 1'b0 
                || (!sq_found) || (sq_found && (is_unresolved_load 
                || lq_before_vec[lq_found_entry][sq_found_entry] == 1'b0)))) begin
                    issue_vaddr <= lq_vaddr[lq_found_entry];
                    lq_state[lq_found_entry] <= LQ_EMPTY;
                    for (int i = 0; i < SQ_ENTRIES; i++) begin
                        sq_before_vec[i][lq_found_entry] <= 1'b0;
                    end
                    if (lq_found_entry == lq_head) begin
                        lq_head <= lq_head + 1'b1;
                    end
                    issue_op <= LOAD;
                    valid_out <= 1'b1;
                end
            else if (sq_found && !is_unresolved_load 
                && (sq_before_vec[sq_found_entry][lq_head] == 1'b0 
                || (!lq_found) || (lq_found && (is_unresolved_store 
                || sq_before_vec[sq_found_entry][lq_found_entry] == 1'b0)))) begin
                    issue_vaddr <= sq_vaddr[sq_found_entry];
                    issue_wdata <= sq_wdata[sq_found_entry];
                    sq_state[sq_found_entry] <= SQ_EMPTY;
                    for (int i = 0; i < LQ_ENTRIES; i++) begin
                        lq_before_vec[i][sq_found_entry] <= 1'b0;
                    end
                    if (sq_found_entry == sq_head) begin
                        sq_head <= sq_head + 1'b1;
                    end
                    issue_op <= STORE;
                    valid_out <= 1'b1;
                end
            end

            if (lq_state[lq_head] == LQ_EMPTY && lq_head != lq_tail) begin
                lq_head <= lq_head + 1'b1;
            end

            if (sq_state[sq_head] == SQ_EMPTY && sq_head != sq_tail) begin
                sq_head <= sq_head + 1'b1;
            end
        end
    end

endmodule
