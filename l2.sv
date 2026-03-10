module l2_cache #(
    parameter L2_CAPACITY   = 4096,
    parameter L2_WAYS       = 4,
    parameter BLOCK_SIZE    = 64,
    parameter L1_MSHRS      = 2,
    parameter L2_MSHRS      = 4,
    parameter PA_WIDTH      = 30,
    parameter DATA_WIDTH    = 64,
    parameter TAG_SIZE      = 20
)(
    input   logic                        clk,
    input   logic                        rst_n,

    // eviction buffer from L1 to L2
    input   logic                           evict_in,
    input   logic[PA_WIDTH-1:0]             e_paddr_in,
    input   logic                           e_dirty_in,
    input   logic[BLOCK_SIZE*8-1:0]         e_data_in,

    // input from superior MSHRS
    input   logic                           miss_in[L1_MSHRS],
    input   logic[PA_WIDTH-1:0]             paddr_in[L1_MSHRS],
    input   logic                           w_in[L1_MSHRS],
    input   logic[BLOCK_SIZE*8-1:0]         data_in[L1_MSHRS],

    // output to superior MSHRS
    output  logic                           empty_out[L1_MSHRS],
    output  logic                           resolve_out[L1_MSHRS],
    output  logic[BLOCK_SIZE*8-1:0]         superior_data_out[L1_MSHRS]
);


    localparam int L2_SETS = L2_CAPACITY / (BLOCK_SIZE * L2_WAYS);
    localparam int OFFSET_BITS = $clog2(BLOCK_SIE);
    localparam int INDEX_BITS = $clog2(L2_SETS);
    localparam int TAG_BITS = PA_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam int WAY_BITS = $clog2(L2_WAYS);
    localparam int L2_MSHR_BITS = $clog2(L2_MSHRS);
    localparam int L1_MSHR_BITS = $clog2(L1_MSHRS);


    // cache state
    logic [BLOCK_SIZE * 8 - 1:0]    contents    [L2_SETS][L2_WAYS];
    logic [TAG_BITS - 1:0]          tags        [L2_SETS][L2_WAYS];
    logic                           lru_mat     [L2_SETS][L2_WAYS][L2_WAYS];
    logic [WAY_BITS-1:0]            lru         [L2_SETS];
    logic                           valid       [L2_SETS][L2_WAYS];
    logic                           dirty       [L2_SETS][L2_WAYS];

    // TODO add in_l1 bit and ensure blocks in l1 are never evicted from L2

    always_comb begin
        logic row_empty;
        for (int i = 0; i < L2_SETS; i++) begin
            lru[i] = '0;
            for (int j = 0; j < L2_WAYS; j++) begin
                row_empty = 1'b1;
                for (int k = 0; k < L2_WAYS; k++)
                    row_empty &= ~lru_mat[i][j][k];
                if (row_empty)
                    lru[i] = j[WAY_BITS-1:0];
            end
        end
    end

    // mshr input parsing
    logic                   miss;
    logic[L1_MSHR_BITS-1:0] miss_mshr_index;
    logic[PA_WIDTH-1]       miss_paddr;
    logic                   miss_w;
    logic[BLOCK_SIZE-1:0]   miss_data;
    logic[INDEX_BITS-1:0]   miss_index;
    logic[TAG_BITS-1:0]     miss_tag;
    assign                  miss = |miss_in;
    assign                  miss_paddr = paddr_in[miss_mshr_index];
    assign                  miss_w = w_in[miss_mshr_index];
    assign                  miss_data = data_in[miss_mshr_index];
    assign                  miss_index = miss_paddr[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
    assign                  miss_tag = miss_paddr[PA_WIDTH-1:PA_WIDTH-TAG_BITS];

    always_comb begin
        for (int i = 0; i < L1_MSHRS; i++) begin
            if (miss_in[i]) begin
                miss_index = i[L1_MSHR_BITS-1:0];
            end
        end
    end

    logic[TAG_BITS-1:0]     e_tag;
    logic[INDEX_BITS-1:0]   e_index;
    assign                  e_tag = e_paddr_in[PA_WIDTH-1:PA_WIDTH-TAG_BITS];
    assign                  e_index = e_paddr_in[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];

    logic                   hit;
    logic[WAY_BITS-1:0]     hit_way;
    logic                   e_hit;
    logic[WAY_BITS-1:0]     e_hit_way;
    always_comb begin
        hit = 0;
        hit_way = '0;
        e_hit = 0;
        e_hit_way = '0;
        for (int w = 0; w < L1_WAYS; w++) begin
            if (valids[miss_index][w] && tags[miss_index][w] == miss_tag) begin
                hit = 1;
                hit_way = w[WAY_BITS-1:0];
            end
            if (valid[e_index][w] && tags[e_index][w] == e_tag) begin
                e_hit = 1;
                e_hit_way = w[WAY_BITS-1:0];
            end
        end
    end



    // MSHR state
    logic[INDEX_BITS-1:0]           mshr_index_buf[L2_MSHRS];
    logic[TAG_BITS-1:0]             mshr_tag_buf[L2_MSHRS];
    
    // L2 -> memory eviction buffer
    logic                           evict_in;
    logic[PA_WIDTH-1:0]             e_paddr_in;
    logic                           e_dirty_in;
    logic[BLOCK_SIZE*8-1:0]         e_data_in;

    // mainmem input from L2
    logic                           mm_miss_in[L2_MSHRS];
    logic[PA_WIDTH-1:0]             mm_paddr_in[L2_MSHRS];
    logic                           mm_w_in[L2_MSHRS];
    logic[BLOCK_SIZE*8-1:0]         mm_data_in[L2_MSHRS];

    // mainmem output to L2
    logic                           mm_empty_out[L2_MSHRS],
    logic                           mm_resolve_out[L2_MSHRS];
    logic[BLOCK_SIZE*8-1:0]         mm_superior_data_out[L2_MSHRS];
    logic                           mm_stall_out;

    assign                          mm_stall_out = ~|mm_empty_out;

    always_ff @(posedge clk, or negedge rst_n) begin
        if (rst_n) begin
            empty_out = '1;
            resolve_out = '0;
            superior_data_out = 0'
        end else begin
            // reset out signals
            resolve_out = '0;

            if (evict_in) begin
                // process l1 eviction buffer
                if (e_hit) begin
                    if (e_dirty_in) begin
                        contents[e_index][e_hit_way] = e_data_in;
                        // touch lru
                        for (int k = 0; k < L2_WAYS; k++) begin
                            lru_mat[e_index][e_hit_way][k] = 1'b1;  // set row
                            lru_mat[e_index][k][e_hit_way] = 1'b0;  // clear column
                        end
                        // TODO modify in_l1 flag
                    end
                end else begin
                    // shouldn't happen
                end
            end

            // process l1 request
            if (miss) begin
                empty_out[miss_mshr_index] = 0;
                if (hit) begin
                    // return, touch LRU
                    if (w_in[miss_mshr_index]) begin
                        contents[miss_index][hit_way] = data_in[miss_mshr_index];
                    end
                    resolve_out[miss_mshr_index] = 1;
                    superior_data_out[miss_mshr_index] = contents[miss_index][hit_way];
                    // update lru_mat with touch at miss_index, hit_tag
                    // touch lru
                    for (int k = 0; k < L2_WAYS; k++) begin
                        lru_mat[miss_index][hit_way][k] = 1'b1;  // set row
                        lru_mat[miss_index][k][hit_way] = 1'b0;  // clear column
                    end
                end else begin
                    // go to L2 MSHR
                end
            end
            
        end
    end


endmodule