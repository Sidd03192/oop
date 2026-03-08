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
    localparam int INDEX_BITS = $clog2(L1_SETS)
    localparam int TAG_BITS = PA_WIDTH - INDEX_BITS - OFFSET_BITS;

    // cache state
    logic [BLOCK_SIZE * 8 - 1:0] set_contents [L1_SETS][L1_WAYS];
    logic [TAG_SIZE - 1:0] tags [L1_SETS][L1_WAYS];
    logic [L1_SETS-1:0] lru;   // This only works when L1_WAYS = 2, otherwise 
    logic [L1_SETS-1:0] set_valids [L1_WAYS];
    logic [L1_SETS-1:0] set_dirty [L1_WAYS];

    /*
        States
            0 - Wait
            1 - Tagging
            2 - Stalling
    */
    // state machine data
    logic [1:0] state;
    logic [INDEX_BITS-1:0]  cur_index;
    logic                   cur_w;
    logic [DATA_WIDTH-1:0]  cur_wdata;


    // TAG CHECK COMBINATIONAL LOGIC
    // Tag from TLB
    logic [TAG_SIZE-1:0] incoming_tag;
    assign incoming_tag = tlb_paddr_in[PA_WIDTH-1 -: TAG_SIZE];
    logic hit;
    logic [$clog2(L1_WAYS)-1:0] hit_way;

    always_comb begin
        hit = 1'b0;
        hit_way = '0;
        for (int w = 0; w < L1_WAYS; w++) begin
            if (set_valids[curr_index][w] && tags[curr_index][w] == incoming_tag) begin
                hit = 1'b1;
                hit_way = w[$clog2(L1_WAYS)-1:0];
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


    // TODO finish implementing where the comments in the always block say
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset 
            set_contents <= '0;
            tags <= '0;
            lru <= '0;
            set_valids <= '0;
            set_dirty <= 0'
            state <= '0;
            cur_index <= '0;
            cur_w <= '0;
            cur_wdata <= '0;
        end else begin

            generate
                for (genvar i = 0; i < NUM_MSHRS; i++) begin
                    // check MSHR[i]
                    if (mshr_pending_einfo_out[i]) begin
                        // evict, tell mshr
                    end
                end
            endgenerate


            if (state == 0) begin
                // handle input, advance state
                state = 1;

            end else if (state == 1) begin
                // got paddr, now see if we have a hit, advance state
                state = 2;
                if (hit) begin
                    // DO LRU on set, (write & set dirty)
                end else begin
                    // miss, go to MSHR
                end
            end else if (state == 2) begin
                // unstall if an mshr is now empty
            end
        end



    end


endmodule