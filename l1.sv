`timescale 1ns/1ps

module l1_cache #(
    parameter L1_CAPACITY   = 512,
    parameter L1_WAYS       = 2,
    parameter BLOCK_SIZE    = 64,
    parameter NUM_MSHRS     = 2,
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
    localparam int MSHR_BITS = $clog2(NUM_MSHRS);
    localparam int WAY_BITS = $clog2(L1_WAYS);

    // cache state
    logic [BLOCK_SIZE * 8 - 1:0]    contents [L1_SETS][L1_WAYS];
    logic [TAG_SIZE - 1:0]          tags [L1_SETS][L1_WAYS];
    logic                           lru   [L1_SETS];   // This only works when L1_WAYS = 2, otherwise 
    logic                           valid [L1_SETS][L1_WAYS];
    logic                           dirty [L1_SETS][L1_WAYS];
    logic                           stall [L1_SETS]; // set whenever an MSHR is fetching something for this set
    logic [MSHR_BITS-1:0]   stall_mshr_idx [L1_SETS];

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
    logic                   cur_stall;
    
    assign cur_stall = stall[cur_index];


    // TAG CHECK COMBINATIONAL LOGIC
    // Tag from TLB
    logic [PA_WIDTH-1:0] paddr_reg;
    logic [TAG_SIZE-1:0] incoming_tag;
    assign incoming_tag = paddr_reg[PA_WIDTH-1 -: TAG_SIZE];
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

    logic [MSHR_BITS-1:0] free_mshr_idx;
    logic                         free_mshr_valid;
    assign stall_out = ~free_mshr_valid;

    always_comb begin
        free_mshr_idx   = '0;
        free_mshr_valid = 1'b0;
        for (int i = NUM_MSHRS-1; i >= 0; i--) begin
            if (mshr_empty_out[i]) begin
                free_mshr_idx   = i[MSHR_BITS-1:0];
                free_mshr_valid = 1'b1;
            end
        end
    end

    // for MSHR consumption (from L1)
    logic                       mshr_miss_in[NUM_MSHRS];
    logic[BLOCK_SIZE*8-1:0]     mshr_paddr_in[NUM_MSHRS];
    logic                       mshr_wd_in[NUM_MSHRS];
    logic                       mshr_superior_data_in[NUM_MSHRS];
    logic                       mshr_evict_in[NUM_MSHRS];

    // for MSHR consumption (from L2)
    logic                       l2_resolve_out[NUM_MSHRS];
    logic                       l2_superior_data_out[NUM_MSHRS];
    logic                       l2_eack_out[NUM_MSHRS];

    // for L1 consumption
    logic                       mshr_empty_out[NUM_MSHRS];
    logic                       mshr_pending_einfo_out[NUM_MSHRS];

    // for L2 consumption
    logic                       mshr_pending_res_out[NUM_MSHRS];
    logic                       mshr_pending_eack_out[NUM_MSHRS];
    logic[PA_WIDTH-1:0]         mshr_paddr_out[NUM_MSHRS];
    logic                       mshr_wd_out[NUM_MSHRS];
    logic[BLOCK_SIZE*8-1:0]     mshr_data_out[NUM_MSHRS];

    // ensure we unstall a set after an MSHR in said set finishes
    always_comb begin
        generate
            for (genvar i = 0; i < L1_SETS; i++) begin
                stall[i] <= stall[i] & (~mshr_empty_out[stall_mshr_idx[i]]);
            end
        endgenerate
    end

    l2_cache l2 (
        .clk(clk),
        .rst_n(rst_n),
        
        // input from L1-L2 MSHRs
        .pending_res_in(mshr_pending_res_out),
        .pending_eack_in(mshr_pending_eack_out),
        .paddr_in(mshr_paddr_out),
        .wd_in(mshr_data_out),
        .data_in(mshr_data_out),

        // output to L1-L2 MSHRs
        .resolve_out(l2_resolve_out),
        .superior_data_out(l2_superior_data_out),
        .eack_out(l2_eack_out)
    );

    generate
        for (genvar i = 0; i < NUM_MSHRS; i++) begin
            MSHR #(PA_WIDTH, BLOCK_SIZE) m (
                .clk_in(clk),
                .rst_n(rst_n),

                // input from L1
                .miss_in(mshr_miss_in[i]),
                .paddr_in(mshr_paddr_in[i]),
                .wd_in(mshr_wd_in[i]),
                .superior_data_in(mshr_superior_data_in[i]),
                .evict_in(mshr_evict_in[i]),

                // input from L2
                .resolve_in(l2_resolve_out[i]),
                .inferior_data_in(l2_superior_data_out[i]),
                .eack_in(l2_eack_out[i]),

                // output for L1
                .empty_out(mshr_empty_out[i]),
                .pending_einfo_out(mshr_pending_einfo_out[i]),

                // output for L2
                .pending_res_out(mshr_pending_res_out[i]),
                .pending_eack_out(mshr_pending_eack_out[i]),
                .paddr_out(mshr_paddr_out[i]),
                .wd_out(mshr_wd_out[i]),

                // ouput for both
                .data_out(mshr_data_out[i])
            );
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset 
            contents <= '0;
            tags <= '0;
            lru <= '0;
            valid <= '0;
            dirty <= 0'
            state <= '0;
            cur_index <= '0;
            cur_w <= '0;
            cur_wdata <= '0;
        end else begin

            generate
                for (genvar int i = 0; i < NUM_MSHRS; i++) begin
                    if (mshr_pending_einfo_out[i]) begin
                        // evict, tell mshr, unstall set
                        logic [INDEX_BITS-1:0] set = mshr_paddr_out[i][OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
                        logic way = lru[set];
                        mshr_paddr_in[i] = {
                            tags[set][way],
                            set,
                            {OFFSET_BITS{1'b0}}
                        };
                        mshr_wd_in[i] = dirty[i][]
                        mshr_evict_in[i] = 1;
                        stall[set] = 1;
                        stall_mshr_idx[set] = i[MSHR_BITS-1:0];
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
                    lru[cur_index] = ~hit_way;
                    if (cur_w) begin
                        dirty[cur_index][hit_way] = 1;
                        contents[cur_index][hit_way] = cur_wdata;
                    end
                end else begin
                    // miss, go to MSHR, stall set
                    if (free_mshr_valid) begin
                        mshr_miss_in[free_mshr_idx] = 1;
                        mshr_paddr_in[free_mshr_idx] = paddr_reg;
                        mshr_wd_in[free_mshr_idx] = cur_w;
                        mshr_superior_data_in[free_mshr_idx] = cur_wdata;
                    end else begin
                        // shouldn't happen
                    end
                end
            end
        end
    end


endmodule