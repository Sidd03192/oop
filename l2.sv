`timescale 1ns/1ps

// =============================================================================
// L2 Cache — optimized for Cyclone V (DE10-Nano)
//
// Optimizations vs original:
//
//  1. PLRU (3-bit binary tree) replaces lru_matrix[L2_SETS][4][4].
//     48 flops total instead of 256, plus three eliminated nested-loop
//     victim searches.
//
//  2. M10K-friendly RAM structure.
//     Four completely isolated always_ff blocks (one per way) each containing
//     ONLY the RAM array access — no other logic.  Write-enable, write-address,
//     write-data, and read-address are all plain logic signals computed purely
//     combinationally from registered pipeline state.  Quartus infers each as
//     a simple-dual-port M10K without hesitation.
//
//     Critical rule satisfied: ram_wr_en/addr/data and ram_rd_addr are driven
//     from a single always_comb block only — no always_ff driver — so there
//     is no multi-driver conflict and the signals look like clean RAM controls.
//
//  3. Shared combinational victim finder.
//     One always_comb block computes victim_way / victim_dirty for all three
//     paths (wb-miss, mshr-install, req-miss) instead of three copies.
//
//  4. WB FIFO push inlined into the data_rd_pending case directly (no separate
//     wb_push/wb_pop variables that created blocking/non-blocking mix issues).
//
// Pipeline behaviour and all interfaces are identical to the original.
// =============================================================================
module l2_cache #(
    parameter L2_CAPACITY = 4096,
    parameter L2_WAYS     = 4,
    parameter BLOCK_SIZE  = 64,
    parameter NUM_MSHRS   = 4,
    parameter PA_WIDTH    = 30,
    parameter DATA_WIDTH  = 64
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // L1 -> L2: writeback
    input  logic                    l1_wb_valid,
    input  logic [PA_WIDTH-1:0]     l1_wb_paddr,
    input  logic [BLOCK_SIZE*8-1:0] l1_wb_data,
    output logic                    l1_wb_ack,

    // L1 -> L2: miss request
    input  logic                    l1_req_valid,
    input  logic [PA_WIDTH-1:0]     l1_req_paddr,

    // L2 -> L1: data return
    output logic                    l1_data_valid,
    output logic [PA_WIDTH-1:0]     l1_data_paddr,
    output logic [BLOCK_SIZE*8-1:0] l1_data,

    // L2 -> Memory
    output logic                    mem_req_valid,
    output logic                    mem_req_is_write,
    output logic [PA_WIDTH-1:0]     mem_req_addr,
    output logic [BLOCK_SIZE*8-1:0] mem_req_wdata,
    input  logic                    mem_req_ready,

    // Memory -> L2
    input  logic                    mem_resp_valid,
    input  logic [PA_WIDTH-1:0]     mem_resp_paddr,
    input  logic [BLOCK_SIZE*8-1:0] mem_resp_rdata
);

    // =========================================================================
    // Geometry
    // =========================================================================
    localparam int L2_SETS     = L2_CAPACITY / (BLOCK_SIZE * L2_WAYS); // 16
    localparam int INDEX_BITS  = $clog2(L2_SETS);                       //  4
    localparam int OFFSET_BITS = $clog2(BLOCK_SIZE);                    //  6
    localparam int TAG_SIZE    = PA_WIDTH - INDEX_BITS - OFFSET_BITS;   // 20
    localparam int LINE_W      = BLOCK_SIZE * 8;                        // 512
    localparam int WAY_BITS    = $clog2(L2_WAYS);                       //  2

    // =========================================================================
    // PLRU — 3 bits per set (binary tree, 4-way)
    //
    //   bit 0: top split    0=left(ways 0,1)  1=right(ways 2,3)
    //   bit 1: left split   0=evict way 0     1=evict way 1
    //   bit 2: right split  0=evict way 2     1=evict way 3
    // =========================================================================
    logic [2:0] plru [L2_SETS];

    function automatic logic [WAY_BITS-1:0] plru_victim(input logic [2:0] p);
        if (!p[0]) return p[1] ? WAY_BITS'(0) : WAY_BITS'(1);
        else       return p[2] ? WAY_BITS'(2) : WAY_BITS'(3);
    endfunction

    function automatic logic [2:0] plru_update(input logic [2:0] p,
                                                input logic [WAY_BITS-1:0] w);
        logic [2:0] np;
        np    = p;
        np[0] = w[1];
        if (!w[1]) np[1] = w[0];
        else       np[2] = w[0];
        return np;
    endfunction

    // =========================================================================
    // Tag / valid / dirty  (LUTRAM — 1280 bits total, too small for M10K)
    // =========================================================================
    logic [TAG_SIZE-1:0] tags       [L2_SETS][L2_WAYS];
    logic [L2_WAYS-1:0]  set_valids [L2_SETS];
    logic [L2_WAYS-1:0]  set_dirty  [L2_SETS];

    // =========================================================================
    // Cache data RAMs — M10K inference
    //
    // Key constraints met:
    //   1. Each way_ram_N lives in its OWN always_ff with NOTHING else inside.
    //   2. ram_wr_en/addr/data are driven ONLY from always_comb (ram_write_ports).
    //      They are never assigned in always_ff.
    //   3. ram_rd_addr is driven ONLY from always_comb (ram_read_addr_mux).
    //   4. No resets on the RAM arrays themselves.
    //
    // Read is registered (synchronous M10K): ram_rd_data[w] is valid the
    // cycle AFTER ram_rd_addr is presented, matching the data_rd_pending stage.
    // =========================================================================
    logic [INDEX_BITS-1:0] ram_rd_addr;
    logic [LINE_W-1:0]     ram_rd_data [L2_WAYS];
    logic [LINE_W-1:0]     set_contents [L2_WAYS][L2_SETS];

    logic                  ram_wr_en   [L2_WAYS];
    logic [INDEX_BITS-1:0] ram_wr_addr [L2_WAYS];
    logic [LINE_W-1:0]     ram_wr_data [L2_WAYS];

    (* ramstyle = "M10K" *) logic [LINE_W-1:0] way_ram_0 [L2_SETS];
    (* ramstyle = "M10K" *) logic [LINE_W-1:0] way_ram_1 [L2_SETS];
    (* ramstyle = "M10K" *) logic [LINE_W-1:0] way_ram_2 [L2_SETS];
    (* ramstyle = "M10K" *) logic [LINE_W-1:0] way_ram_3 [L2_SETS];

    always_ff @(posedge clk) begin
        if (ram_wr_en[0]) way_ram_0[ram_wr_addr[0]] <= ram_wr_data[0];
        ram_rd_data[0] <= way_ram_0[ram_rd_addr];
    end
    always_ff @(posedge clk) begin
        if (ram_wr_en[1]) way_ram_1[ram_wr_addr[1]] <= ram_wr_data[1];
        ram_rd_data[1] <= way_ram_1[ram_rd_addr];
    end
    always_ff @(posedge clk) begin
        if (ram_wr_en[2]) way_ram_2[ram_wr_addr[2]] <= ram_wr_data[2];
        ram_rd_data[2] <= way_ram_2[ram_rd_addr];
    end
    always_ff @(posedge clk) begin
        if (ram_wr_en[3]) way_ram_3[ram_wr_addr[3]] <= ram_wr_data[3];
        ram_rd_data[3] <= way_ram_3[ram_rd_addr];
    end

    genvar set_gen;
    generate
        for (set_gen = 0; set_gen < L2_SETS; set_gen = set_gen + 1) begin : gen_set_contents
            assign set_contents[0][set_gen] = way_ram_0[set_gen];
            assign set_contents[1][set_gen] = way_ram_1[set_gen];
            assign set_contents[2][set_gen] = way_ram_2[set_gen];
            assign set_contents[3][set_gen] = way_ram_3[set_gen];
        end
    endgenerate

    // =========================================================================
    // MSHR
    // =========================================================================
    localparam [1:0] MS_IDLE       = 2'b00;
    localparam [1:0] MS_UNRESOLVED = 2'b01;
    localparam [1:0] MS_WAIT_MEM   = 2'b10;
    localparam [1:0] MS_RESOLVED   = 2'b11;

    logic [1:0]          mshr_state      [NUM_MSHRS];
    logic [PA_WIDTH-1:0] mshr_paddr      [NUM_MSHRS];
    logic [LINE_W-1:0]   mshr_block      [NUM_MSHRS];
    logic                mshr_mem_issued [NUM_MSHRS];

    // =========================================================================
    // Pipeline registers
    // =========================================================================
    logic                req_pending_valid;
    logic [PA_WIDTH-1:0] req_pending_paddr;

    logic                install_pending_valid;
    logic [PA_WIDTH-1:0] install_pending_paddr;
    logic [LINE_W-1:0]   install_pending_block;

    localparam logic [1:0] DATA_RD_NONE       = 2'b00;
    localparam logic [1:0] DATA_RD_REQ_HIT    = 2'b01;
    localparam logic [1:0] DATA_RD_WB_EVICT   = 2'b10;
    localparam logic [1:0] DATA_RD_FILL_EVICT = 2'b11;

    logic                  data_rd_pending;
    logic [1:0]            data_rd_kind;
    logic [INDEX_BITS-1:0] data_rd_index;
    logic [WAY_BITS-1:0]   data_rd_way;
    logic [PA_WIDTH-1:0]   data_rd_paddr;
    logic [PA_WIDTH-1:0]   data_rd_wb_paddr;
    logic [TAG_SIZE-1:0]   data_rd_new_tag;
    logic [LINE_W-1:0]     data_rd_new_line;

    // =========================================================================
    // Writeback FIFO
    // =========================================================================
    localparam int WB_DEPTH = NUM_MSHRS;
    localparam int WB_PTR_W = (WB_DEPTH > 1) ? $clog2(WB_DEPTH) : 1;

    logic [PA_WIDTH-1:0]  wb_paddr_q [WB_DEPTH];
    logic [LINE_W-1:0]    wb_data_q  [WB_DEPTH];
    logic [WB_PTR_W-1:0]  wb_head, wb_tail;
    logic [WB_PTR_W:0]    wb_count;

    logic wb_empty, wb_full;
    assign wb_empty = (wb_count == '0);
    assign wb_full  = (wb_count == WB_DEPTH);

    // =========================================================================
    // Address decode
    // =========================================================================
    logic [INDEX_BITS-1:0] req_index;
    logic [TAG_SIZE-1:0]   req_tag;
    assign req_index = req_pending_paddr[OFFSET_BITS +: INDEX_BITS];
    assign req_tag   = req_pending_paddr[PA_WIDTH-1 -: TAG_SIZE];

    logic [INDEX_BITS-1:0] wb_index_in;
    logic [TAG_SIZE-1:0]   wb_tag_in;
    assign wb_index_in = l1_wb_paddr[OFFSET_BITS +: INDEX_BITS];
    assign wb_tag_in   = l1_wb_paddr[PA_WIDTH-1 -: TAG_SIZE];

    // =========================================================================
    // Shared combinational victim finder
    // =========================================================================
    logic [WAY_BITS-1:0] victim_way;
    logic                victim_dirty;

    always_comb begin : victim_finder
        logic [INDEX_BITS-1:0] vidx;
        logic                  found_inv;

        if (!data_rd_pending && install_pending_valid)
            vidx = install_pending_paddr[OFFSET_BITS +: INDEX_BITS];
        else if (!data_rd_pending && req_pending_valid)
            vidx = req_index;
        else
            vidx = wb_index_in;

        found_inv  = 1'b0;
        victim_way = plru_victim(plru[vidx]);
        for (int w = 0; w < L2_WAYS; w++) begin
            if (!set_valids[vidx][w] && !found_inv) begin
                victim_way = WAY_BITS'(w);
                found_inv  = 1'b1;
            end
        end

        victim_dirty = set_dirty[vidx][victim_way] && set_valids[vidx][victim_way];
    end

    // =========================================================================
    // RAM read address mux — purely combinational
    // =========================================================================
    always_comb begin : ram_read_addr_mux
        if (!data_rd_pending && l1_wb_valid)
            ram_rd_addr = wb_index_in;
        else if (!data_rd_pending && install_pending_valid)
            ram_rd_addr = install_pending_paddr[OFFSET_BITS +: INDEX_BITS];
        else
            ram_rd_addr = req_index;
    end

    // =========================================================================
    // RAM write port mux — purely combinational from registered state.
    //
    // At most one write can be active per cycle (the pipeline serialises them):
    //   - data_rd_pending eviction paths  (WB_EVICT / FILL_EVICT)
    //   - wb hit / clean-victim miss
    //   - mshr-install clean-victim
    //
    // The wb_hit comparison is a 4-entry tag scan on LUTRAM — negligible cost.
    // =========================================================================
    always_comb begin : ram_write_ports
        for (int w = 0; w < L2_WAYS; w++) begin
            ram_wr_en[w]   = 1'b0;
            ram_wr_addr[w] = '0;
            ram_wr_data[w] = '0;
        end

        if (data_rd_pending) begin
            // Eviction install: write new line into the vacated way
            if (data_rd_kind == DATA_RD_WB_EVICT || data_rd_kind == DATA_RD_FILL_EVICT) begin
                ram_wr_en  [data_rd_way] = 1'b1;
                ram_wr_addr[data_rd_way] = data_rd_index;
                ram_wr_data[data_rd_way] = data_rd_new_line;
            end
            // DATA_RD_REQ_HIT: read-only, no RAM write

        end else if (l1_wb_valid) begin
            // Tag lookup to decide hit vs miss (LUTRAM — cheap)
            begin
                logic                wb_hit_c;
                logic [WAY_BITS-1:0] wb_hit_way_c;
                wb_hit_c     = 1'b0;
                wb_hit_way_c = '0;
                for (int w = 0; w < L2_WAYS; w++) begin
                    if (set_valids[wb_index_in][w] && tags[wb_index_in][w] == wb_tag_in) begin
                        wb_hit_c     = 1'b1;
                        wb_hit_way_c = WAY_BITS'(w);
                    end
                end
                if (wb_hit_c) begin
                    ram_wr_en  [wb_hit_way_c] = 1'b1;
                    ram_wr_addr[wb_hit_way_c] = wb_index_in;
                    ram_wr_data[wb_hit_way_c] = l1_wb_data;
                end else if (!victim_dirty && !(victim_dirty && wb_full)) begin
                    // Clean victim: write directly
                    ram_wr_en  [victim_way] = 1'b1;
                    ram_wr_addr[victim_way] = wb_index_in;
                    ram_wr_data[victim_way] = l1_wb_data;
                end
                // Dirty victim: eviction read issued this cycle, write next cycle
                // via data_rd_pending / DATA_RD_WB_EVICT path above
            end

        end else if (install_pending_valid && !victim_dirty) begin
            // MSHR fill, clean victim: write directly
            ram_wr_en  [victim_way] = 1'b1;
            ram_wr_addr[victim_way] = install_pending_paddr[OFFSET_BITS +: INDEX_BITS];
            ram_wr_data[victim_way] = install_pending_block;
            // Dirty victim: handled via DATA_RD_FILL_EVICT next cycle
        end
    end

    // =========================================================================
    // Memory request output — combinational
    // =========================================================================
    always_comb begin
        mem_req_valid    = 1'b0;
        mem_req_is_write = 1'b0;
        mem_req_addr     = '0;
        mem_req_wdata    = '0;
        if (!wb_empty) begin
            mem_req_valid    = 1'b1;
            mem_req_is_write = 1'b1;
            mem_req_addr     = wb_paddr_q[wb_head];
            mem_req_wdata    = wb_data_q[wb_head];
        end else begin
            for (int i = 0; i < NUM_MSHRS; i++) begin
                if (mshr_state[i] == MS_UNRESOLVED && !mshr_mem_issued[i] && !mem_req_valid) begin
                    mem_req_valid = 1'b1;
                    mem_req_addr  = mshr_paddr[i];
                end
            end
        end
    end

    // =========================================================================
    // Sequential logic
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l1_wb_ack             <= 1'b0;
            l1_data_valid         <= 1'b0;
            req_pending_valid     <= 1'b0;
            req_pending_paddr     <= '0;
            install_pending_valid <= 1'b0;
            install_pending_paddr <= '0;
            install_pending_block <= '0;
            data_rd_pending       <= 1'b0;
            data_rd_kind          <= DATA_RD_NONE;
            data_rd_index         <= '0;
            data_rd_way           <= '0;
            data_rd_paddr         <= '0;
            data_rd_wb_paddr      <= '0;
            data_rd_new_tag       <= '0;
            data_rd_new_line      <= '0;
            wb_head               <= '0;
            wb_tail               <= '0;
            wb_count              <= '0;
            for (int i = 0; i < L2_SETS; i++) begin
                set_valids[i] <= '0;
                set_dirty[i]  <= '0;
                plru[i]       <= 3'b000;
            end
            for (int i = 0; i < NUM_MSHRS; i++) begin
                mshr_state[i]      <= MS_IDLE;
                mshr_paddr[i]      <= '0;
                mshr_block[i]      <= '0;
                mshr_mem_issued[i] <= 1'b0;
            end

        end else begin
            logic control_taken;

            l1_wb_ack     <= 1'b0;
            l1_data_valid <= 1'b0;
            control_taken = 1'b0;

            // ------------------------------------------------------------------
            // Memory response → MSHR
            // ------------------------------------------------------------------
            if (mem_resp_valid) begin
                for (int i = 0; i < NUM_MSHRS; i++) begin
                    if (mshr_state[i] == MS_WAIT_MEM && mshr_paddr[i] == mem_resp_paddr) begin
                        mshr_block[i] <= mem_resp_rdata;
                        mshr_state[i] <= MS_RESOLVED;
                    end
                end
            end

            // ------------------------------------------------------------------
            // Single-issue internal pipeline control
            // Priority:
            //   1) resolve current data_rd_pending
            //   2) handle one L1 writeback action
            //   3) capture one MS_RESOLVED MSHR
            //   4) process one install_pending fill
            //   5) process one req_pending request
            //   6) latch one new L1 request
            // ------------------------------------------------------------------
            if (data_rd_pending) begin
                case (data_rd_kind)

                    DATA_RD_REQ_HIT: begin
                        l1_data_valid       <= 1'b1;
                        l1_data_paddr       <= data_rd_paddr;
                        l1_data             <= ram_rd_data[data_rd_way];
                        plru[data_rd_index] <= plru_update(plru[data_rd_index], data_rd_way);
                        req_pending_valid   <= 1'b0;
                    end

                    DATA_RD_WB_EVICT: begin
                        wb_paddr_q[wb_tail]                  <= data_rd_wb_paddr;
                        wb_data_q[wb_tail]                   <= ram_rd_data[data_rd_way];
                        wb_tail                              <= wb_tail + 1'b1;
                        wb_count                             <= wb_count + 1'b1;
                        tags[data_rd_index][data_rd_way]     <= data_rd_new_tag;
                        set_valids[data_rd_index][data_rd_way] <= 1'b1;
                        set_dirty[data_rd_index][data_rd_way]  <= 1'b1;
                        plru[data_rd_index]                  <= plru_update(plru[data_rd_index], data_rd_way);
                        l1_wb_ack                            <= 1'b1;
                    end

                    DATA_RD_FILL_EVICT: begin
                        wb_paddr_q[wb_tail]                  <= data_rd_wb_paddr;
                        wb_data_q[wb_tail]                   <= ram_rd_data[data_rd_way];
                        wb_tail                              <= wb_tail + 1'b1;
                        wb_count                             <= wb_count + 1'b1;
                        tags[data_rd_index][data_rd_way]     <= data_rd_new_tag;
                        set_valids[data_rd_index][data_rd_way] <= 1'b1;
                        set_dirty[data_rd_index][data_rd_way]  <= 1'b0;
                        plru[data_rd_index]                  <= plru_update(plru[data_rd_index], data_rd_way);
                        l1_data_valid                        <= 1'b1;
                        l1_data_paddr                        <= data_rd_paddr;
                        l1_data                              <= data_rd_new_line;
                        install_pending_valid                <= 1'b0;
                    end

                    default: ;
                endcase

                data_rd_pending <= 1'b0;
                data_rd_kind    <= DATA_RD_NONE;
                control_taken   = 1'b1;
            end else begin
                if (!control_taken && l1_wb_valid) begin
                    logic                wb_hit;
                    logic [WAY_BITS-1:0] wb_hit_way;

                    wb_hit     = 1'b0;
                    wb_hit_way = '0;
                    for (int w = 0; w < L2_WAYS; w++) begin
                        if (set_valids[wb_index_in][w] && tags[wb_index_in][w] == wb_tag_in) begin
                            wb_hit     = 1'b1;
                            wb_hit_way = WAY_BITS'(w);
                        end
                    end

                    if (wb_hit) begin
                        set_dirty[wb_index_in][wb_hit_way] <= 1'b1;
                        plru[wb_index_in]                  <= plru_update(plru[wb_index_in], wb_hit_way);
                        l1_wb_ack                          <= 1'b1;
                        control_taken                      = 1'b1;
                    end else if (!(victim_dirty && wb_full)) begin
                        if (victim_dirty) begin
                            data_rd_pending  <= 1'b1;
                            data_rd_kind     <= DATA_RD_WB_EVICT;
                            data_rd_index    <= wb_index_in;
                            data_rd_way      <= victim_way;
                            data_rd_paddr    <= '0;
                            data_rd_wb_paddr <= {tags[wb_index_in][victim_way],
                                                 wb_index_in, {OFFSET_BITS{1'b0}}};
                            data_rd_new_tag  <= wb_tag_in;
                            data_rd_new_line <= l1_wb_data;
                        end else begin
                            tags[wb_index_in][victim_way]       <= wb_tag_in;
                            set_valids[wb_index_in][victim_way] <= 1'b1;
                            set_dirty[wb_index_in][victim_way]  <= 1'b1;
                            plru[wb_index_in]                   <= plru_update(plru[wb_index_in], victim_way);
                            l1_wb_ack                           <= 1'b1;
                        end
                        control_taken = 1'b1;
                    end
                end

                if (!control_taken && !install_pending_valid) begin
                    logic install_done;

                    install_done = 1'b0;
                    for (int i = 0; i < NUM_MSHRS; i++) begin
                        if (!install_done && mshr_state[i] == MS_RESOLVED) begin
                            install_pending_valid <= 1'b1;
                            install_pending_paddr <= mshr_paddr[i];
                            install_pending_block <= mshr_block[i];
                            mshr_state[i]         <= MS_IDLE;
                            mshr_mem_issued[i]    <= 1'b0;
                            install_done          = 1'b1;
                            control_taken         = 1'b1;
                        end
                    end
                end

                if (!control_taken && install_pending_valid) begin
                    logic [INDEX_BITS-1:0] inst_index;
                    logic [TAG_SIZE-1:0]   inst_tag;

                    inst_index = install_pending_paddr[OFFSET_BITS +: INDEX_BITS];
                    inst_tag   = install_pending_paddr[PA_WIDTH-1 -: TAG_SIZE];
                    control_taken = 1'b1;

                    if (!(victim_dirty && wb_full)) begin
                        if (victim_dirty) begin
                            data_rd_pending  <= 1'b1;
                            data_rd_kind     <= DATA_RD_FILL_EVICT;
                            data_rd_index    <= inst_index;
                            data_rd_way      <= victim_way;
                            data_rd_paddr    <= install_pending_paddr;
                            data_rd_wb_paddr <= {tags[inst_index][victim_way],
                                                 inst_index, {OFFSET_BITS{1'b0}}};
                            data_rd_new_tag  <= inst_tag;
                            data_rd_new_line <= install_pending_block;
                        end else begin
                            tags[inst_index][victim_way]       <= inst_tag;
                            set_valids[inst_index][victim_way] <= 1'b1;
                            set_dirty[inst_index][victim_way]  <= 1'b0;
                            plru[inst_index]                   <= plru_update(plru[inst_index], victim_way);
                            l1_data_valid                      <= 1'b1;
                            l1_data_paddr                      <= install_pending_paddr;
                            l1_data                            <= install_pending_block;
                            install_pending_valid              <= 1'b0;
                        end
                    end
                end

                if (!control_taken && req_pending_valid) begin
                    logic                req_hit;
                    logic [WAY_BITS-1:0] req_hit_way;
                    logic                mshr_dup, mshr_full_l2;
                    logic [$clog2(NUM_MSHRS)-1:0] mshr_free_idx;

                    req_hit     = 1'b0;
                    req_hit_way = '0;
                    for (int w = 0; w < L2_WAYS; w++) begin
                        if (set_valids[req_index][w] && tags[req_index][w] == req_tag) begin
                            req_hit     = 1'b1;
                            req_hit_way = WAY_BITS'(w);
                        end
                    end

                    control_taken = 1'b1;
                    if (req_hit) begin
                        data_rd_pending  <= 1'b1;
                        data_rd_kind     <= DATA_RD_REQ_HIT;
                        data_rd_index    <= req_index;
                        data_rd_way      <= req_hit_way;
                        data_rd_paddr    <= req_pending_paddr;
                        data_rd_wb_paddr <= '0;
                        data_rd_new_tag  <= '0;
                        data_rd_new_line <= '0;
                    end else begin
                        mshr_dup      = 1'b0;
                        mshr_full_l2  = 1'b1;
                        mshr_free_idx = '0;
                        for (int i = 0; i < NUM_MSHRS; i++) begin
                            if (mshr_state[i] != MS_IDLE && mshr_paddr[i] == req_pending_paddr)
                                mshr_dup = 1'b1;
                            if (mshr_state[i] == MS_IDLE && mshr_full_l2) begin
                                mshr_full_l2  = 1'b0;
                                mshr_free_idx = i[$clog2(NUM_MSHRS)-1:0];
                            end
                        end
                        if (!mshr_dup && !mshr_full_l2) begin
                            mshr_state[mshr_free_idx]      <= MS_UNRESOLVED;
                            mshr_paddr[mshr_free_idx]      <= req_pending_paddr;
                            mshr_mem_issued[mshr_free_idx] <= 1'b0;
                            req_pending_valid              <= 1'b0;
                        end else if (mshr_dup) begin
                            req_pending_valid <= 1'b0;
                        end
                    end
                end

                if (!control_taken && !req_pending_valid && l1_req_valid) begin
                    req_pending_valid <= 1'b1;
                    req_pending_paddr <= l1_req_paddr;
                    control_taken     = 1'b1;
                end
            end

            // ------------------------------------------------------------------
            // mem_req handshake
            // ------------------------------------------------------------------
            if (mem_req_valid && mem_req_ready) begin
                if (mem_req_is_write) begin
                    wb_head  <= wb_head + 1'b1;
                    wb_count <= wb_count - 1'b1;
                end else begin
                    logic mshr_issued_one;
                    mshr_issued_one = 1'b0;
                    for (int i = 0; i < NUM_MSHRS; i++) begin
                        if (mshr_state[i] == MS_UNRESOLVED && !mshr_mem_issued[i]
                                && !mshr_issued_one) begin
                            mshr_state[i]      <= MS_WAIT_MEM;
                            mshr_mem_issued[i] <= 1'b1;
                            mshr_issued_one     = 1'b1;
                        end
                    end
                end
            end

        end
    end

endmodule
