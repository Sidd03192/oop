`timescale 1ns/1ps

module l2_cache #(
    parameter L2_CAPACITY   = 4096,
    parameter L2_WAYS       = 4,
    parameter BLOCK_SIZE    = 64,
    parameter NUM_MSHRS     = 4,
    parameter PA_WIDTH      = 30,
    parameter DATA_WIDTH    = 64
)(
    input  logic                        clk,              
    input  logic                        rst_n,            

    // L1 -> L2: writeback (L1 evicting a dirty block)
    input  logic                        l1_wb_valid,      // L1 has a dirty block to write back
    input  logic [PA_WIDTH-1:0]         l1_wb_paddr,      // physical address of the evicted block
    input  logic [BLOCK_SIZE*8-1:0]     l1_wb_data,       // full cache line data being written back
    output logic                        l1_wb_ack,        // L2 accepted the writeback this cycle

    // L1 -> L2: miss request (L1 needs a block)
    input  logic                        l1_req_valid,     // l1 MSHR need
    input  logic [PA_WIDTH-1:0]         l1_req_paddr,     

    // L2 -> L1: data return
    output logic                        l1_data_valid,    //l1 MSHR ready
    output logic [PA_WIDTH-1:0]         l1_data_paddr,    // 
    output logic [BLOCK_SIZE*8-1:0]     l1_data,          // block

    // L2 -> Memory: request (read miss or dirty writeback)
    output logic                        mem_req_valid,    // L2 has a pending request for memory
    output logic                        mem_req_is_write, // 0=read (miss fill), 1=write (dirty eviction)
    output logic [PA_WIDTH-1:0]         mem_req_addr,     // physical address for the memory request
    output logic [BLOCK_SIZE*8-1:0]     mem_req_wdata,    // write data for dirty evictions (ignored on reads)
    input  logic                        mem_req_ready,    // memory can accept the request this cycle

    // Memory -> L2: response (address-tagged fill)
    input  logic                        mem_resp_valid,   // memory is returning data this cycle
    input  logic [PA_WIDTH-1:0]         mem_resp_paddr,   // address tag so L2 can match to the right MSHR
    input  logic [BLOCK_SIZE*8-1:0]     mem_resp_rdata    // fill data from memory
);

    // Geometry
    localparam int L2_SETS     = L2_CAPACITY / (BLOCK_SIZE * L2_WAYS);
    localparam int INDEX_BITS  = $clog2(L2_SETS);
    localparam int OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam int TAG_SIZE    = PA_WIDTH - INDEX_BITS - OFFSET_BITS;

    // MSHR states
    localparam [1:0] MS_IDLE       = 2'b00;
    localparam [1:0] MS_UNRESOLVED = 2'b01;
    localparam [1:0] MS_WAIT_MEM   = 2'b10;
    localparam [1:0] MS_RESOLVED   = 2'b11;

    // cache arrays
    logic [BLOCK_SIZE*8-1:0]  set_contents [L2_SETS][L2_WAYS];
    logic [TAG_SIZE-1:0]      tags         [L2_SETS][L2_WAYS];
    logic [L2_WAYS-1:0]       set_valids   [L2_SETS];
    logic [L2_WAYS-1:0]       set_dirty    [L2_SETS];

    // 4 way n^2 matrix for each set. 
    logic [L2_WAYS-1:0][L2_WAYS-1:0] lru_matrix [L2_SETS];

    // MSHRs
    logic [1:0]              mshr_state      [NUM_MSHRS];
    logic [PA_WIDTH-1:0]     mshr_paddr      [NUM_MSHRS];
    logic                    mshr_mem_issued [NUM_MSHRS];
    logic [BLOCK_SIZE*8-1:0] mshr_block      [NUM_MSHRS];

    // Writeback queue fifo to memory
    localparam int WB_DEPTH = NUM_MSHRS;
    localparam int WB_PTR_W = (WB_DEPTH > 1) ? $clog2(WB_DEPTH) : 1;

    logic [PA_WIDTH-1:0]     wb_paddr_q [WB_DEPTH];
    logic [BLOCK_SIZE*8-1:0] wb_data_q  [WB_DEPTH];
    logic [WB_PTR_W-1:0]     wb_head;
    logic [WB_PTR_W-1:0]     wb_tail;
    logic [WB_PTR_W:0]       wb_count;
    logic                    wb_push;
    logic [PA_WIDTH-1:0]     wb_push_paddr;
    logic [BLOCK_SIZE*8-1:0] wb_push_data;
    logic                    wb_pop;
    logic                    wb_empty;
    logic                    wb_full;

    assign wb_empty = (wb_count == '0);
    assign wb_full  = (wb_count == WB_DEPTH);

//-------------------------------------------------------------
    // Combinational: address decode for L1 request
    logic [INDEX_BITS-1:0] req_index;
    logic [TAG_SIZE-1:0]   req_tag;
    assign req_index = l1_req_paddr[OFFSET_BITS +: INDEX_BITS];
    assign req_tag   = l1_req_paddr[PA_WIDTH-1 -: TAG_SIZE];
     

    // Combinational: address decode for L1 writeback
    logic [INDEX_BITS-1:0] wb_index_in;
    logic [TAG_SIZE-1:0]   wb_tag_in;
    assign wb_index_in = l1_wb_paddr[OFFSET_BITS +: INDEX_BITS];
    assign wb_tag_in   = l1_wb_paddr[PA_WIDTH-1 -: TAG_SIZE];

    logic                          wb_hit;
    logic [$clog2(L2_WAYS)-1:0]   wb_hit_way;
    logic [$clog2(L2_WAYS)-1:0]   wb_victim_way;
    logic                          wb_found_invalid;
    logic                          wb_victim_dirty;
    logic                          wb_is_lru;

    logic [$clog2(L2_WAYS)-1:0] wb_hit_way;
    logic [$clog2(L2_WAYS)-1:0] wb_victim_way;


    
    logic [2:0] states;


//-------------------------------------------------------------
    // Sequential block
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs
            l1_wb_ack    <= 1'b0;
            l1_data_valid <= 1'b0;

            // Reset cache arrays
            for (int i = 0; i < L2_SETS; i++) begin
                set_valids[i] <= '0;
                set_dirty[i]  <= '0;
                lru_matrix[i] <= '0;
            end

            // Reset MSHRs
            for (int i = 0; i < NUM_MSHRS; i++) begin
                mshr_state[i]      <= MS_IDLE;
                mshr_paddr[i]      <= '0;
                mshr_mem_issued[i] <= 1'b0;
                mshr_block[i]      <= '0;
            end

            // Reset writeback FIFO
            wb_head  <= '0;
            wb_tail  <= '0;
            wb_count <= '0;

        end else begin
            // reset these 
            l1_wb_ack     <= 1'b0;
            l1_data_valid <= 1'b0;
            wb_push       = 1'b0;
            wb_pop        = 1'b0;

            if (l1_wb_valid) begin // if on the writeback, then it is a write. 
                // handle writeback. 
                // get tag of writeback
                wb_hit = 1'b0;
                wb_hit_way='0;
                
                // index and tags
                for (int w = 0; w< L2_WAYS; w++) begin
                    if (set_valids[wb_index_in][w] && tags[wb_index_in][w] == wb_tag_in) begin
                        wb_hit =1'b1;
                        wb_hit_way = w[$clog2(L2_WAYS)-1:0];
                    end
                end

                if (wb_hit) begin
                    set_contents[wb_index_in][wb_hit_way] <= l1_wb_data;
                    set_dirty[wb_index_in][wb_hit_way] <= 1'b1;
                    //update LRU 
                    for (int i = 0; i < L2_WAYS; i++) begin
                        lru_matrix[wb_index_in][wb_hit_way][i] <= 1'b1;
                        lru_matrix[wb_index_in][i][wb_hit_way] <= 1'b0;
                    end
                    l1_wb_ack <=1; // we handled writeback 
                end
                else begin // miss for writeback
                    wb_found_invalid = 1'b0;
                    wb_victim_way = '0;

                    //  look for invalid way
                    for (int w = 0; w < L2_WAYS; w++) begin
                        if (!set_valids[wb_index_in][w] && !wb_found_invalid) begin
                            wb_victim_way = w[$clog2(L2_WAYS)-1:0];
                            wb_found_invalid = 1'b1;
                        end
                    end

                    if (!wb_found_invalid) begin // do lru to find victim
                        for (int w = 0; w < L2_WAYS; w++) begin
                            wb_is_lru = 1'b1;
                            for (int j = 0; j < L2_WAYS; j++)
                                if (j != w && lru_matrix[wb_index_in][w][j])
                                    wb_is_lru = 1'b0;
                            if (wb_is_lru)
                                wb_victim_way = w[$clog2(L2_WAYS)-1:0];
                        end
                    end
                    // is victim dirty
                    wb_victim_dirty = set_dirty[wb_index_in][wb_victim_way] &&
                          set_valids[wb_index_in][wb_victim_way];

                    // if wb is full, then we do nothing (no ack on the l1 so l1 holds val)
                    if (!(wb_victim_dirty && wb_full)) begin
                        if (wb_victim_dirty) begin // if dirty add to buffer
                            wb_push       = 1'b1;
                            wb_push_paddr = {tags[wb_index_in][wb_victim_way], wb_index_in, {OFFSET_BITS{1'b0}}};
                            wb_push_data  = set_contents[wb_index_in][wb_victim_way];
                        end

                        // now that the dirty is saved we can update the way with wb data. 
                        set_contents[wb_index_in][wb_victim_way] <= l1_wb_data;
                        tags[wb_index_in][wb_victim_way]         <= wb_tag_in;
                        set_valids[wb_index_in][wb_victim_way]   <= 1'b1;
                        set_dirty[wb_index_in][wb_victim_way]    <= 1'b1;
                        
                        // touch this new block to simulate lru 
                        for (int i = 0; i < L2_WAYS; i++) begin
                            lru_matrix[wb_index_in][wb_victim_way][i] <= 1'b1;
                            lru_matrix[wb_index_in][i][wb_victim_way] <= 1'b0;
                        end
                        l1_wb_ack <= 1'b1;
                    end    
                    
                end

                
                





            end

            





            // ---- Priority 1: Capture memory response into matching MSHR ----
            // TODO: match mem_resp_paddr to MSHR, save block, move to MS_RESOLVED


            // ---- Priority 2: Install one resolved MSHR into cache ----
            // TODO: pick resolved MSHR, choose victim way (invalid first, then LRU)
            //       if victim dirty, push to wb FIFO
            //       install block, update tag/valid/dirty/lru
            //       return block to L1 via l1_data_valid
            //       free MSHR

            // ---- Priority 3: Accept one L1 writeback ----
            // TODO: if l1_wb_valid, lookup hit/miss in L2
            //       hit:  overwrite line, set dirty, update LRU, ack
            //       miss: pick victim, evict if dirty, install, ack

            // ---- Priority 4: Process one L1 miss request ----
            // TODO: if l1_req_valid, lookup hit/miss in L2
            //       hit:  return line to L1 immediately
            //       miss: check duplicate MSHR, allocate if free

            // ---- Priority 5: Issue one memory request (handled combinationally above) ----
            // TODO: on mem_req_valid && mem_req_ready:
            //       if writeback: pop FIFO
            //       if read: move MSHR to MS_WAIT_MEM

            // ---- Writeback FIFO pointer update ----
            if (wb_pop && !wb_push) begin
                wb_head  <= wb_head + 1'b1;
                wb_count <= wb_count - 1'b1;
            end else if (wb_push && !wb_pop) begin
                wb_paddr_q[wb_tail] <= wb_push_paddr;
                wb_data_q[wb_tail]  <= wb_push_data;
                wb_tail             <= wb_tail + 1'b1;
                wb_count            <= wb_count + 1'b1;
            end else if (wb_push && wb_pop) begin
                wb_paddr_q[wb_tail] <= wb_push_paddr;
                wb_data_q[wb_tail]  <= wb_push_data;
                wb_tail             <= wb_tail + 1'b1;
                wb_head             <= wb_head + 1'b1;
            end

        end
    end





//-------------------------------------------------------------


endmodule
