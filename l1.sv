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
    input  logic [DATA_WIDTH-1:0]       wdata_in,           // Store data (MISSING in memsys)

    // to lsq
    output logic                        stall_out,          // Can't accept request
);

    localparam int L1_SETS = L1_CAPACITY / (BLOCK_SIZE * L1_WAYS);
    localparam int OFFSET_BITS = $clog2(BLOCK_SIE);
    localparam int INDEX_BITS = $clog2(L1_SETS);
    localparam int TAG_BITS = PA_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam int MSHR_BITS = $clog2(L1_MSHRS);
    localparam int WAY_BITS = $clog2(L1_WAYS);

    // cache state
    logic [BLOCK_SIZE * 8 - 1:0]    contents [L1_SETS][L1_WAYS];
    logic [TAG_BITS - 1:0]          tags [L1_SETS][L1_WAYS];
    logic                           lru   [L1_SETS];   // This only works when L1_WAYS = 2, otherwise 
    logic                           valid [L1_SETS][L1_WAYS];
    logic                           dirty [L1_SETS][L1_WAYS];

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
    logic [DATA_WIDTH-1:0]  cur_wdata;


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
            if (valids[curr_index][w] && tags[curr_index][w] == incoming_tag) begin
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
    logic[INDEX_BITS-1:0]           mshr_index_buf[L1_MSHRS];
    logic[TAG_BITS-1:0]             mshr_tag_buf[L1_MSHRS];
    
    // L1 -> L2 eviction buffer
    logic                           evict_in;
    logic[PA_WIDTH-1:0]             e_paddr_in;
    logic                           e_dirty_in;
    logic[BLOCK_SIZE*8-1:0]         e_data_in;

    // L2 input from L1
    logic                           l2_miss_in[L1_MSHRS];
    logic[PA_WIDTH-1:0]             l2_paddr_in[L1_MSHRS];
    logic                           l2_w_in[L1_MSHRS];
    logic[BLOCK_SIZE*8-1:0]         l2_data_in[L1_MSHRS];

    // L2 output to L1
    logic                           l2_empty_out[L1_MSHRS],
    logic                           l2_resolve_out[L1_MSHRS];
    logic[BLOCK_SIZE*8-1:0]         l2_superior_data_out[L1_MSHRS];
    logic                           l2_stall_out;
    assign                          l2_stall_out = ~|l2_empty_out;

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
        .wd_in(l2_w_in),
        .data_in(l2_data_in),

        // output to L1-L2 MSHRs
        .empty_out(l2_empty_out),
        .resolve_out(l2_resolve_out),
        .superior_data_out(l2_superior_data_out),
        .stall_out(l2_stall_out)
    );


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
            
            // there will be at most one mshr resolution on a given positive clock edge
            generate
                for (genvar int i = 0; i < NUM_MSHRS; i++) begin
                    if (l2_resolve_out[i]) begin
                        // do LRU, evict, update eviction buffer
                        // process mshr returns
                        logic[INDEX_BITS-1:0]   set;
                        logic                   way = lru[set];
                        assign                  set = mshr_index_buf[i];

                        evict_in = 1;
                        e_paddr_in = l2_paddr_in[i];
                        e_dirty_in = dirty[set][way];
                        e_data_in = contents[set][way];

                        dirty[set][way] = 0;
                        contents[set][way] = l2_superior_data_out[i];
                        tags[set][way] = mshr_tag_buf[i];
                    end
                end
            endgenerate


            if (state == 0) begin
                if (start_in && free_mshr_valid) begin
                    // handle input, advance state
                    cur_index = trace_vaddr_in[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
                    cur_w = w_in;
                    cur_wdata = wdata_in;
                    state = 1;
                end
            end else if (state == 1) begin
                // got paddr, now see if we have a hit, advance state
                state = 0;
                paddr_reg = tlb_paddr_in;
                if (hit) begin
                    // DO LRU on set, (write & set dirty)
                    lru[cur_index] = ~hit_way[0];
                    if (cur_w) begin
                        dirty[cur_index][hit_way] = 1;
                        contents[cur_index][hit_way] = cur_wdata;
                    end
                end else begin
                    // miss, go to MSHR
                    if (free_mshr_valid) begin
                        l2_miss_in[free_mshr_idx] = 1;
                        l2_paddr_in[free_mshr_idx] = paddr_reg;
                        l2_w_in[free_mshr_idx] = cur_w;
                        l2_data_in[free_mshr_idx] = cur_wdata;
                        mshr_index_buf[free_mshr_idx] = cur_index;
                        mshr_tag_buf[free_mshr_idx] = incoming_tag;
                    end else begin
                        // shouldn't happen
                    end
                end
            end
        end
    end


endmodule