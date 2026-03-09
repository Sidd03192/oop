`timescale 1ns/1ps

/*
    Single-entry MSHR. Instantiate NUM_MSHRS of these in l1_cache.
    States:
        S_IDLE    - free
        S_WAIT_L2 - fetch request sent to L2, waiting for block
        S_EVICT   - block received, evicting LRU line this cycle
        S_EACK    - dirty writeback sent to L2, waiting for ack
*/
module mshr #(
    parameter PA_WIDTH   = 30,
    parameter BLOCK_SIZE = 64,
    parameter DATA_WIDTH = 64,
    parameter TAG_SIZE   = 24
)(
    input  logic                        clk,
    input  logic                        rst_n,

    // ── From L1 on miss ──────────────────────────────────────
    input  logic                        alloc,
    input  logic [PA_WIDTH-1:0]         alloc_paddr,
    input  logic                        alloc_is_write,
    input  logic [DATA_WIDTH-1:0]       alloc_wdata,

    // ── From L2 ──────────────────────────────────────────────
    input  logic                        l2_valid,       // L2 returning a block
    input  logic [PA_WIDTH-1:0]         l2_paddr,       // which address
    input  logic [BLOCK_SIZE*8-1:0]     l2_data,        // fetched block
    input  logic                        l2_eack,        // L2 acked dirty writeback

    // ── Eviction info from L1 (combinational, no latency) ────
    input  logic                        evict_dirty,    // LRU line is dirty
    input  logic [PA_WIDTH-1:0]         evict_paddr,    // LRU line's address
    input  logic [BLOCK_SIZE*8-1:0]     evict_data,     // LRU line's contents

    // ── To L1 ────────────────────────────────────────────────
    output logic                        empty,          // slot is free
    output logic                        install_valid,  // L1 should install block now
    output logic [PA_WIDTH-1:0]         install_paddr,
    output logic [BLOCK_SIZE*8-1:0]     install_block,
    output logic                        install_is_write,
    output logic [DATA_WIDTH-1:0]       install_wdata,

    // ── To L2 ────────────────────────────────────────────────
    output logic                        req_valid,      // fetch request
    output logic [PA_WIDTH-1:0]         req_paddr,
    output logic                        wb_valid,       // dirty writeback
    output logic [PA_WIDTH-1:0]         wb_paddr,
    output logic [BLOCK_SIZE*8-1:0]     wb_data
);

    localparam logic [1:0] S_IDLE    = 2'b00;
    localparam logic [1:0] S_WAIT_L2 = 2'b01;
    localparam logic [1:0] S_EVICT   = 2'b10;
    localparam logic [1:0] S_EACK    = 2'b11;

    logic [1:0]              state;
    logic [PA_WIDTH-1:0]     paddr;
    logic                    is_write;
    logic [DATA_WIDTH-1:0]   wdata;
    logic [BLOCK_SIZE*8-1:0] block;

    // ── Combinational outputs ─────────────────────────────────
    assign empty           = (state == S_IDLE);
    assign req_valid       = (state == S_WAIT_L2);
    assign req_paddr       = paddr;
    assign install_valid   = (state == S_EVICT);
    assign install_paddr   = paddr;
    assign install_block   = block;
    assign install_is_write = is_write;
    assign install_wdata   = wdata;

    // ── Sequential state machine ──────────────────────────────
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            wb_valid <= 1'b0;
            wb_paddr <= '0;
            wb_data  <= '0;
            paddr    <= '0;
            is_write <= 1'b0;
            wdata    <= '0;
            block    <= '0;
        end else begin
            case (state)

                S_IDLE: begin
                    if (alloc) begin
                        state    <= S_WAIT_L2;
                        paddr    <= alloc_paddr;
                        is_write <= alloc_is_write;
                        wdata    <= alloc_wdata;
                    end
                end

                S_WAIT_L2: begin
                    // Wait for L2 to return the block for our address
                    if (l2_valid && l2_paddr == paddr) begin
                        block <= l2_data;
                        state <= S_EVICT;
                    end
                end

                S_EVICT: begin
                    // install_valid is high this cycle — L1 writes to cache arrays.
                    // Simultaneously decide if we need a dirty writeback.
                    if (evict_dirty) begin
                        wb_valid <= 1'b1;
                        wb_paddr <= evict_paddr;
                        wb_data  <= evict_data;
                        state    <= S_EACK;
                    end else begin
                        state    <= S_IDLE;   // clean eviction, done
                    end
                end

                S_EACK: begin
                    if (l2_eack) begin
                        wb_valid <= 1'b0;
                        state    <= S_IDLE;
                    end
                end

            endcase
        end
    end

endmodule
