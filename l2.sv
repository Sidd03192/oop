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

    // 4 way n^2 matrix for each set (fully unpacked for iverilog)
    logic lru_matrix [L2_SETS][L2_WAYS][L2_WAYS];

    // MSHRs
    logic [1:0]              mshr_state      [NUM_MSHRS];
    logic [PA_WIDTH-1:0]     mshr_paddr      [NUM_MSHRS];
    logic [BLOCK_SIZE*8-1:0] mshr_block      [NUM_MSHRS];
    logic                    mshr_mem_issued [NUM_MSHRS];
    logic                    mshr_issued_one;

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
    logic                          req_hit;
    logic [$clog2(L2_WAYS)-1:0]   req_hit_way;
    logic                          mshr_dup;
    logic                          mshr_full_l2;
    logic [$clog2(NUM_MSHRS)-1:0]  mshr_free_idx; 

    // Combinational: address decode for L1 writeback
    logic [INDEX_BITS-1:0] wb_index_in;
    logic [TAG_SIZE-1:0]   wb_tag_in;
    assign wb_index_in = l1_wb_paddr[OFFSET_BITS +: INDEX_BITS];
    assign wb_tag_in   = l1_wb_paddr[PA_WIDTH-1 -: TAG_SIZE];

    logic                          wb_hit;
    logic [$clog2(L2_WAYS)-1:0]    wb_hit_way;
    logic [$clog2(L2_WAYS)-1:0]    wb_victim_way;
    logic                          wb_found_invalid;
    logic                          wb_victim_dirty;
    logic                          wb_is_lru;


    // MSHR temps
    logic                          mshr_install_done;
    logic [INDEX_BITS-1:0]         mshr_inst_index;
    logic [TAG_SIZE-1:0]           mshr_inst_tag;
    logic [$clog2(L2_WAYS)-1:0]   mshr_inst_victim;
    logic                          mshr_inst_found_invalid;
    logic                          mshr_inst_victim_dirty;
    logic                          mshr_inst_is_lru;


    
   //-------------------------------------------------------------
   // handle assiging ouput for next thing we ant mem to do 

        always_comb begin
            mem_req_valid    = 1'b0;
            mem_req_is_write = 1'b0;
            mem_req_addr     = '0;
            mem_req_wdata    = '0;

            if (!wb_empty) begin // give it wb , if thats emtpy then do mshr 
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

   //-------------------------------------------------------------

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
                for (int r = 0; r < L2_WAYS; r++)
                    for (int c = 0; c < L2_WAYS; c++)
                        lru_matrix[i][r][c] <= 1'b0;
            end

            // Reset MSHRs
            for (int i = 0; i < NUM_MSHRS; i++) begin
                mshr_state[i]      <= MS_IDLE;
                mshr_paddr[i]      <= '0;
                mshr_block[i]      <= '0;
                mshr_mem_issued[i] <= 1'b0;
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

            // check if MSHR response from mem (on next cycle we cna add it ito the cache)
            if (mem_resp_valid) begin
                for (int i = 0; i < NUM_MSHRS; i++) begin
                    if (mshr_state[i] == MS_WAIT_MEM && mshr_paddr[i] == mem_resp_paddr) begin
                        mshr_block[i] <= mem_resp_rdata;
                        mshr_state[i] <= MS_RESOLVED;
                    end
                end
            end


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
            

            // actually install the mshr block once we get it (1 cycle delay. )
            mshr_install_done = 1'b0; // only do onec. 
            for (int i = 0; i < NUM_MSHRS; i++) begin
                // find first resolved block
                if (!mshr_install_done && mshr_state[i] == MS_RESOLVED) begin
                    // get data. 
                    mshr_inst_index = mshr_paddr[i][OFFSET_BITS +: INDEX_BITS];
                    mshr_inst_tag   = mshr_paddr[i][PA_WIDTH-1 -: TAG_SIZE];

                    // find victim: invalid first
                    mshr_inst_found_invalid = 1'b0;
                    mshr_inst_victim = '0;
                    for (int w = 0; w < L2_WAYS; w++) begin
                        if (!set_valids[mshr_inst_index][w] && !mshr_inst_found_invalid) begin
                            mshr_inst_victim = w[$clog2(L2_WAYS)-1:0];
                            mshr_inst_found_invalid = 1'b1;
                        end
                    end

                    // if no invalid, then do lru 
                    if (!mshr_inst_found_invalid) begin
                        for (int w = 0; w < L2_WAYS; w++) begin
                            mshr_inst_is_lru = 1'b1;
                            for (int j = 0; j < L2_WAYS; j++)
                                if (j != w && lru_matrix[mshr_inst_index][w][j])
                                    mshr_inst_is_lru = 1'b0;
                            if (mshr_inst_is_lru)
                                mshr_inst_victim = w[$clog2(L2_WAYS)-1:0];
                        end
                    end


                    // reuse logic for kicking smtg out. 
                    mshr_inst_victim_dirty = set_dirty[mshr_inst_index][mshr_inst_victim] &&
                                            set_valids[mshr_inst_index][mshr_inst_victim];

                    if (!(mshr_inst_victim_dirty && wb_full)) begin
                        if (mshr_inst_victim_dirty) begin
                            wb_push       = 1'b1;
                            wb_push_paddr = {tags[mshr_inst_index][mshr_inst_victim], mshr_inst_index, {OFFSET_BITS{1'b0}}};
                            wb_push_data  = set_contents[mshr_inst_index][mshr_inst_victim];
                        end

                        set_contents[mshr_inst_index][mshr_inst_victim] <= mshr_block[i];
                        tags[mshr_inst_index][mshr_inst_victim]         <= mshr_inst_tag;
                        set_valids[mshr_inst_index][mshr_inst_victim]   <= 1'b1;
                        set_dirty[mshr_inst_index][mshr_inst_victim]    <= 1'b0; // clean fill

                        for (int k = 0; k < L2_WAYS; k++) begin
                            lru_matrix[mshr_inst_index][mshr_inst_victim][k] <= 1'b1;
                            lru_matrix[mshr_inst_index][k][mshr_inst_victim] <= 1'b0;
                        end

                        // return to L1
                        l1_data_valid <= 1'b1;
                        l1_data_paddr <= mshr_paddr[i];
                        l1_data       <= mshr_block[i];

                        // free the mshr entry. 
                        mshr_state[i] <= MS_IDLE;
                        mshr_mem_issued[i] <= 1'b0;
                        mshr_install_done = 1'b1;
                    end
                end
            end






            if (l1_req_valid) begin // handle MSHR of l1 
                // find it in l1 
                req_hit = 1'b0;
                req_hit_way = '0;
                for (int w = 0; w < L2_WAYS; w++) begin
                    if (set_valids[req_index][w] && tags[req_index][w] == req_tag) begin
                        req_hit = 1'b1;
                        req_hit_way = w[$clog2(L2_WAYS)-1:0];
                    end
                end

                if (req_hit) begin
                    // send the output back on wires. 
                    l1_data_valid <= 1'b1;
                    l1_data_paddr <= l1_req_paddr;
                    l1_data       <= set_contents[req_index][req_hit_way];
                    // update LRU
                    for (int i = 0; i < L2_WAYS; i++) begin
                        lru_matrix[req_index][req_hit_way][i] <= 1'b1;
                        lru_matrix[req_index][i][req_hit_way] <= 1'b0;
                    end
                end
                else begin
                    // miss — check for duplicate, then allocate MSHR
                    mshr_dup = 1'b0;
                    mshr_full_l2 = 1'b1;
                    mshr_free_idx = '0;

                    for (int i = 0; i < NUM_MSHRS; i++) begin
                        // duplicate check: already tracking this address
                        if (mshr_state[i] != MS_IDLE && mshr_paddr[i] == l1_req_paddr)
                            mshr_dup = 1'b1;
                        // find first free slot
                        if (mshr_state[i] == MS_IDLE && mshr_full_l2) begin
                            mshr_full_l2 = 1'b0;
                            mshr_free_idx = i[$clog2(NUM_MSHRS)-1:0];
                        end
                    end

                    if (!mshr_dup && !mshr_full_l2) begin
                        mshr_state[mshr_free_idx] <= MS_UNRESOLVED;
                        mshr_paddr[mshr_free_idx] <= l1_req_paddr;
                        mshr_mem_issued[mshr_free_idx] <= 1'b0;
                    end
                    // if dup: already in flight, L1 will get data when MSHR resolves
                    // if full: L1 must retry
                end
            end


            // hnadle updating after mem responds. 
            if (mem_req_valid && mem_req_ready) begin
                if (mem_req_is_write) begin
                    wb_pop = 1'b1;
                end else begin
                    mshr_issued_one = 1'b0;
                    for (int i = 0; i < NUM_MSHRS; i++) begin
                        if (mshr_state[i] == MS_UNRESOLVED && !mshr_mem_issued[i] && !mshr_issued_one) begin
                            mshr_state[i] <= MS_WAIT_MEM;
                            mshr_mem_issued[i] <= 1'b1;
                            mshr_issued_one = 1'b1;
                        end
                    end
                end
            end

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
