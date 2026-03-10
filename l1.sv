`timescale 1ns/1ps

module l1_cache #(
    parameter L1_CAPACITY   = 512,
    parameter L1_WAYS       = 2,
    parameter BLOCK_SIZE    = 64,
    parameter L1_MSHRS     = 2,
    parameter VA_WIDTH      = 48,
    parameter PA_WIDTH      = 30
)(
    input  logic                        clk,
    input  logic                        rst_n,

    // FROM TLB
    input  logic                        start_tag_in,       // TLB has valid output
    input  logic [PA_WIDTH-1:0]         tlb_paddr_in,       // Physical address from TLB

    // from lsq
    input  logic                        start_in,           // LSQ has valid request
    input  logic [VA_WIDTH-1:0]         trace_vaddr_in,     // Virtual address from LSQ
    input  logic                        w_in,               // 0=load, 1=store
    input  logic [BLOCK_SIZE-1:0]       wdata_in,           // Store data (MISSING in memsys)

    // to lsq
    output logic                        stall_out           // Can't accept request
);

    localparam int L1_SETS = L1_CAPACITY / (BLOCK_SIZE * L1_WAYS);
    localparam int OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam int INDEX_BITS = $clog2(L1_SETS);
    localparam int TAG_BITS = PA_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam int MSHR_BITS = $clog2(L1_MSHRS);
    localparam int WAY_BITS = $clog2(L1_WAYS);

    // cache state
    // contents/tags: unpacked so variable indices work in iverilog (no reset needed — valid gates reads)
    logic [BLOCK_SIZE*8-1:0]            contents [L1_SETS][L1_WAYS];
    logic [TAG_BITS-1:0]                tags     [L1_SETS][L1_WAYS];
    // valid/dirty/lru: packed so <= '0 reset works
    logic [L1_SETS-1:0]                                              lru;   // This only works when L1_WAYS = 2, otherwise
    logic [L1_SETS-1:0][L1_WAYS-1:0]                                valid;
    logic [L1_SETS-1:0][L1_WAYS-1:0]                                dirty;

    /*
        States
            0 - Wait
            1 - Tagging
            2 - Stalling
    */
    // state machine data
    logic                   state;
    logic [INDEX_BITS-1:0]  cur_index;
    logic                   cur_w;
    logic [BLOCK_SIZE-1:0]  cur_wdata;


    // TAG CHECK COMBINATIONAL LOGIC
    // Tag from TLB
    logic [PA_WIDTH-1:0] paddr_reg;
    logic [TAG_BITS-1:0] incoming_tag;
    assign incoming_tag = paddr_reg[PA_WIDTH-1 -: TAG_BITS];
    logic hit;
    logic [WAY_BITS-1:0] hit_way;

    always_comb begin
        hit = 1'b0;
        hit_way = '0;
        for (int w = 0; w < L1_WAYS; w++) begin
            if (valid[cur_index][w] && tags[cur_index][w] == incoming_tag) begin
                hit = 1'b1;
                hit_way = w[WAY_BITS-1:0];
            end
        end
    end

    logic [MSHR_BITS-1:0]   free_mshr_idx;
    logic                   free_mshr_valid;
    assign stall_out = ~free_mshr_valid;

    always_comb begin
        free_mshr_idx   = '0;
        free_mshr_valid = 1'b0;
        for (int i = L1_MSHRS-1; i >= 0; i--) begin
            if (l2_empty_out[i]) begin
                free_mshr_idx   = i[MSHR_BITS-1:0];
                free_mshr_valid = 1'b1;
            end
        end
    end

    // MSHR state
    logic[L1_MSHRS-1:0][INDEX_BITS-1:0]           mshr_index_buf;
    logic[L1_MSHRS-1:0][TAG_BITS-1:0]             mshr_tag_buf;

    // L1 -> L2 eviction buffer
    logic                           evict_in;
    logic[PA_WIDTH-1:0]             e_paddr_in;
    logic                           e_dirty_in;
    logic[BLOCK_SIZE*8-1:0]         e_data_in;

    // L2 input from L1
    logic[L1_MSHRS-1:0]                     l2_miss_in;
    logic[L1_MSHRS-1:0][PA_WIDTH-1:0]       l2_paddr_in;
    logic[L1_MSHRS-1:0]                     l2_w_in;
    logic[L1_MSHRS-1:0][BLOCK_SIZE*8-1:0]   l2_data_in;

    // L2 output to L1
    logic[L1_MSHRS-1:0]                             l2_empty_out;
    logic[L1_MSHRS-1:0]                             l2_resolve_out;
    logic[L1_MSHRS-1:0][BLOCK_SIZE*8-1:0]           l2_superior_data_out;
    logic                                           l2_stall_out;
    assign                                          l2_stall_out = ~|l2_empty_out;

    l2_cache #(
        .L1_MSHRS(L1_MSHRS)
    ) l2 (
        .clk(clk),
        .rst_n(rst_n),

        // eviction buffer from L1 to L2
        .evict_in(evict_in),
        .e_paddr_in(e_paddr_in),
        .e_dirty_in(e_dirty_in),
        .e_data_in(e_data_in),

        // input from L1-L2 MSHRs
        .miss_in(l2_miss_in),
        .paddr_in(l2_paddr_in),
        .w_in(l2_w_in),
        .data_in(l2_data_in),

        // output to L1-L2 MSHRs
        .empty_out(l2_empty_out),
        .resolve_out(l2_resolve_out),
        .superior_data_out(l2_superior_data_out)
    );

    // resolution logic
    logic                           res;
    logic[MSHR_BITS-1:0]            res_mshr_index;
    logic[INDEX_BITS-1:0]           res_index;
    logic[TAG_BITS-1:0]             res_tag;
    logic[WAY_BITS-1:0]             res_way; // way to evict and replace with resolution

    assign res_index = mshr_index_buf[res_mshr_index];
    assign res_tag = mshr_tag_buf[res_mshr_index];
    assign res_way[0] = lru[res_index]; // only works with 1 way 

    // resolution mshr index
    always_comb begin
        res = 0;
        for (int i = 0; i < L1_MSHRS; i++) begin
            if (l2_resolve_out[i]) begin
                res = 1;
                res_mshr_index = i[MSHR_BITS-1:0];
            end
        end
    end


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset 
            contents <= '0;
            tags <= '0;
            lru <= '0;
            valid <= '0;
            dirty <= '0;
            state <= '0;
            cur_index <= '0;
            cur_w <= '0;
            cur_wdata <= '0;
            paddr_reg <= '0;
            l2_miss_in <= '0;
            l2_paddr_in <= '0;
            l2_w_in <= '0;
            l2_data_in <= '0;
        end else begin
            // ensure we don't send inadvertent signals to L2
            l2_miss_in = '0;
            evict_in = 0;
            
            // TODO find index of l2 resolution mshr and set flag with combinational logic, avoid for loop
            // there will be at most one mshr resolution on a given positive clock edge
            if (res) begin
                // do LRU, evict, update eviction buffer
                // process mshr returns
                evict_in <= 1;
                // e_paddr_in <= l2_paddr_in[res_mshr_index];
                e_paddr_in <= {tags[res_index][res_way], res_index[INDEX_BITS-1:0], {OFFSET_BITS{1'b0}}};
                e_dirty_in <= dirty[res_index][res_way];
                e_data_in <= contents[res_index][res_way];

                dirty[res_index][res_way] <= 0;
                valid[res_index][res_way] <= 1;
                contents[res_index][res_way] <= l2_superior_data_out[res_mshr_index];
                tags[res_index][res_way] <= mshr_tag_buf[i];
            end

            if (state == 0) begin
                if (start_in && free_mshr_valid) begin
                    // handle input, advance state
                    cur_index <= trace_vaddr_in[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
                    cur_w <= w_in;
                    cur_wdata <= wdata_in;
                    state <= 1;
                end
            end else if (state == 1) begin
                // got paddr, now see if we have a hit, advance state
                state <= 0;
                paddr_reg <= tlb_paddr_in;
                if (hit) begin
                    // DO LRU on set, (write & set dirty)
                    lru[cur_index] <= ~hit_way[0];
                    if (cur_w) begin
                        dirty[cur_index][hit_way] <= 1;
                        contents[cur_index][hit_way] <= cur_wdata;
                    end
                end else begin
                    // miss, go to MSHR
                    if (free_mshr_valid) begin
                        l2_miss_in[free_mshr_idx] <= 1;
                        l2_paddr_in[free_mshr_idx] <= paddr_reg;
                        l2_w_in[free_mshr_idx] <= cur_w;
                        l2_data_in[free_mshr_idx] <= cur_wdata;
                        mshr_index_buf[free_mshr_idx] <= cur_index;
                        mshr_tag_buf[free_mshr_idx] <= incoming_tag;
                    end else begin
                        // shouldn't happen
                    end
                end
            end
        end
    end


endmodule