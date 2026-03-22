`timescale 1ns/1ps
//TODO: set ready to take in inputs from lsq as output for lsq.
module l1_cache #(
    parameter L1_CAPACITY   = 512,
    parameter L1_WAYS       = 2,
    parameter BLOCK_SIZE    = 64,
    parameter NUM_MSHRS     = 2,
    parameter VA_WIDTH      = 48,
    parameter PA_WIDTH      = 30,
    parameter DATA_WIDTH    = 64
)(
    input  logic                        clk,
    input  logic                        rst_n,

    // FROM TLB
    input  logic                        start_tag,          // TLB has valid output
    input  logic [PA_WIDTH-1:0]         tlb_paddr,          // Physical address from TLB

    // from lsq
    input  logic                        start_index,        // LSQ has valid request
    input  logic [VA_WIDTH-1:0]         trace_vaddr,        // Virtual address from LSQ
    input  logic                        is_write,           // 0=load, 1=store
    input  logic [DATA_WIDTH-1:0]       wdata,              // Store data (MISSING in memsys)

    // to lsq
    output logic                    l1_stall_out_to_lsq ,             // Can't accept request 

    output logic                    l2_wb_valid,
    output logic [PA_WIDTH-1:0]     l2_wb_paddr,
    output logic [BLOCK_SIZE*8-1:0] l2_wb_data,
    input  logic                    l2_wb_ack,

    // L1 → L2: fetch request tell l2 which mshr we need if any
    output logic                    l2_req_valid,   // if we have mshr req l2 needs
    output logic [PA_WIDTH-1:0]     l2_req_paddr,   // physical address of the block we need

    // L2 → L1: data return L2 got the output and we good. 
    input  logic                    l2_data_valid,          // L2 has a block ready
    input  logic [PA_WIDTH-1:0]     l2_data_paddr,          // which address it belongs to
    input  logic [BLOCK_SIZE*8-1:0] l2_data                 // the actual block data
    

    //TODO: MSHR + Reset Buffer
);

    localparam int L1_SETS    = L1_CAPACITY / (BLOCK_SIZE * L1_WAYS);
    localparam int INDEX_BITS = $clog2(L1_SETS);
    localparam int OFFSET_BITS = $clog2(BLOCK_SIZE);           // 6 for 64-byte blocks
    localparam int WORD_BITS   = $clog2(BLOCK_SIZE * 8 / DATA_WIDTH); // 3: 8 words/block
    localparam int WORDS_PER_BLOCK = BLOCK_SIZE * 8 / DATA_WIDTH;
    localparam int TAG_SIZE    = PA_WIDTH - INDEX_BITS - OFFSET_BITS; // 30-2-6 = 22
    
    // TODO: Add actual cache structure (wires)
    // Cache data
    logic [BLOCK_SIZE * 8 - 1:0] set_contents [L1_SETS][L1_WAYS];
    logic [TAG_SIZE - 1:0] tags [L1_SETS][L1_WAYS];
    logic [L1_SETS-1:0] lru;   // This only works when L1_WAYS = 2, otherwise 
    logic [L1_WAYS-1:0] set_valids [L1_SETS];
    logic [L1_WAYS-1:0] set_dirty [L1_SETS];



    // state machine data
logic [2:0] state ;
logic [INDEX_BITS-1:0]  curr_index;
logic                   curr_is_write;
logic [DATA_WIDTH-1:0]  curr_wdata;
logic [WORD_BITS-1:0]   curr_word_offset; // which 64-bit word within the block for miss to same line
logic                   mshr_dup;
logic [$clog2(NUM_MSHRS)-1:0] mshr_dup_idx;


logic                evict_way_l;
logic [PA_WIDTH-1:0] evict_pa;
logic                mshr_install_done; // flag to process only one RESOLVED slot per cycle (replaces break)

// ------------------------- Logic for MSHR
logic [1:0] mshr_state [NUM_MSHRS];
logic [PA_WIDTH-1:0]     mshr_paddr    [NUM_MSHRS];
logic [INDEX_BITS-1:0]   mshr_index    [NUM_MSHRS];
logic [BLOCK_SIZE*8-1:0] mshr_block    [NUM_MSHRS];
logic [WORDS_PER_BLOCK-1:0] mshr_store_mask [NUM_MSHRS];
logic [BLOCK_SIZE*8-1:0]    mshr_store_data [NUM_MSHRS];
logic [BLOCK_SIZE*8-1:0] install_block;
logic                         mshr_full;
logic [$clog2(NUM_MSHRS)-1:0] mshr_free_idx;

localparam [1:0] MS_IDLE       = 2'b00;  // free
localparam [1:0] MS_UNRESOLVED = 2'b01;  // waiting for L2
localparam [1:0] MS_RESOLVED   = 2'b10;  // L2 returned


// Small writeback FIFO so dirty evictions do not overwrite each other when
// L2 applies backpressure.
localparam int WB_DEPTH = 2;
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
logic                    victim_dirty;
logic [PA_WIDTH-1:0]     victim_paddr;
logic [BLOCK_SIZE*8-1:0] victim_data;

assign wb_empty = (wb_count == '0);
assign wb_full  = (wb_count == WB_DEPTH);

// Oldest queued writeback drives the L2 output port.
assign l2_wb_valid = !wb_empty;
assign l2_wb_paddr = wb_paddr_q[wb_head];
assign l2_wb_data  = wb_data_q[wb_head];

// Stall LSQ whenever L1 can't accept a new request:
//   - state != 0: TLB lookup in flight, new start_index would be silently dropped
//   - mshr_full:  all MSHRs occupied, a miss cannot be allocated
assign l1_stall_out_to_lsq = (state != 3'd0) || mshr_full;

// Combinationally scan all MSHR slots. If any is UNRESOLVED (waiting for L2),
// assert l2_req_valid and put that slot's address on l2_req_paddr.
// If both slots are UNRESOLVED, the highest index wins. 
always_comb begin
    l2_req_valid = 1'b0;
    l2_req_paddr = '0;
    for (int i = 0; i < NUM_MSHRS; i++)
        if (mshr_state[i] == MS_UNRESOLVED && !l2_req_valid) begin
            l2_req_valid = 1'b1;
            l2_req_paddr = mshr_paddr[i];
        end
end

// ------------------

///////////////////// Combinational logic to find empty spot in MSHR
always_comb begin
    mshr_full     = 1'b1;
    mshr_free_idx = '0;
    for (int i = 0; i < NUM_MSHRS; i++)
        if (mshr_state[i] == MS_IDLE && mshr_full) begin
            mshr_full     = 1'b0;
            mshr_free_idx = i[$clog2(NUM_MSHRS)-1:0];
        end
end
////////////////////////





//////////////////////////////////////////////////////////////////
    // TAG CHECK COMBINATIONAL LOGIC
    // Tag from TLB
    logic [TAG_SIZE-1:0] incoming_tag;
    assign incoming_tag = tlb_paddr[PA_WIDTH-1 -: TAG_SIZE];
    logic [PA_WIDTH-1:0] incoming_line_paddr;
    assign incoming_line_paddr = {tlb_paddr[PA_WIDTH-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
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
////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////
    // Sequential block - state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
            curr_index       <= '0;
            curr_is_write    <= '0;
            curr_wdata       <= '0;
            curr_word_offset <= '0;
            // TODO: reset mshr
            // reset valid and dirty and lru
                    for (int i = 0; i < L1_SETS; i++) begin
                        set_valids[i] <= '0;
                        set_dirty[i]  <= '0;
                    end
                    lru <= '0;
            for (int i = 0; i < NUM_MSHRS; i++) begin
                mshr_state[i]       <= MS_IDLE;
                mshr_paddr[i]       <= '0;
                mshr_index[i]       <= '0;
                mshr_block[i]       <= '0;
                mshr_store_mask[i]  <= '0;
                mshr_store_data[i]  <= '0;
            end
            wb_head  <= '0;
            wb_tail  <= '0;
            wb_count <= '0;
            for (int i = 0; i < WB_DEPTH; i++) begin
                wb_paddr_q[i] <= '0;
                wb_data_q[i]  <= '0;
            end

        end else begin
            wb_pop  = l2_wb_ack && !wb_empty;
            wb_push = 1'b0;
            wb_push_paddr = '0;
            wb_push_data  = '0;

            case (state)
            3'd0: begin  // IDLE

                //TODO: make this go through states and 2 cycles. 
                // Check if any MSHR entry has data back from L2 
                mshr_install_done = 1'b0;
                for (integer i = 0; i < NUM_MSHRS; i++) begin
                    if (!mshr_install_done && mshr_state[i] == MS_RESOLVED) begin
                        // se if anything invalid / do lru 
                        if (!set_valids[mshr_index[i]][0])
                            evict_way_l = 1'b0;
                        else if (!set_valids[mshr_index[i]][1])
                            evict_way_l = 1'b1;
                        else
                            evict_way_l = lru[mshr_index[i]];

                        victim_dirty = set_dirty[mshr_index[i]][evict_way_l] &&
                                       set_valids[mshr_index[i]][evict_way_l];
                        victim_paddr = {tags[mshr_index[i]][evict_way_l], mshr_index[i], {OFFSET_BITS{1'b0}}};
                        victim_data  = set_contents[mshr_index[i]][evict_way_l];

                        // If the writeback queue is full, leave the MSHR resolved
                        // and retry next cycle rather than dropping a dirty victim.
                        if (!(victim_dirty && wb_full && !wb_pop)) begin
                            if (victim_dirty) begin
                                wb_push       = 1'b1;
                                wb_push_paddr = victim_paddr;
                                wb_push_data  = victim_data;
                            end

                            install_block = mshr_block[i];
                            // replace the parts we need
                            for (int w = 0; w < WORDS_PER_BLOCK; w++) begin
                                if (mshr_store_mask[i][w]) begin
                                    install_block[w * DATA_WIDTH +: DATA_WIDTH] = mshr_store_data[i][w * DATA_WIDTH +: DATA_WIDTH];
                                end
                            end

                            set_contents[mshr_index[i]][evict_way_l] <= install_block;
                            tags[mshr_index[i]][evict_way_l]         <= mshr_paddr[i][PA_WIDTH-1 -: TAG_SIZE];
                            set_valids[mshr_index[i]][evict_way_l]   <= 1'b1;
                            set_dirty[mshr_index[i]][evict_way_l]    <= (mshr_store_mask[i] != '0);
                            lru[mshr_index[i]]                       <= ~evict_way_l;
                            mshr_state[i]                            <= MS_IDLE;
                            mshr_store_mask[i]                       <= '0;
                            mshr_store_data[i]                       <= '0;
                            mshr_install_done = 1'b1;
                        end
                    end
                end

                // start doing lsq request. 
                if (start_index) begin
                    curr_index       <= trace_vaddr[OFFSET_BITS +: INDEX_BITS];
                    curr_word_offset <= trace_vaddr[OFFSET_BITS-1 -: WORD_BITS];
                    curr_is_write    <= is_write;
                    curr_wdata       <= wdata;
                    state            <= 3'd1;
                end

            end

            3'd1: begin  // tag wait
                if (start_tag) begin
                    if (hit) begin
                        // HIT - handle read/write
                        if (curr_is_write) begin
                            set_contents[curr_index][hit_way][curr_word_offset * DATA_WIDTH +: DATA_WIDTH] <= curr_wdata;
                            set_dirty[curr_index][hit_way]    <= 1'b1;
                        end
                        // lru update
                        lru[curr_index] <= ~hit_way[0];
                        state <= 3'd0;  // set to idle
                    end else begin
                        // MISS - go to MSHR
                        mshr_dup = 1'b0; // find if dupblicate miss to line
                        mshr_dup_idx = '0;
                        for (int i = 0; i < NUM_MSHRS; i++) begin
                            if (!mshr_dup && mshr_state[i] != MS_IDLE && mshr_paddr[i] == incoming_line_paddr) begin
                                mshr_dup = 1'b1;
                                mshr_dup_idx = i[$clog2(NUM_MSHRS)-1:0];
                            end
                        end

                        // if we alr have miss duplicate, then update store data
                        if (mshr_dup) begin
                            if (curr_is_write) begin
                                mshr_store_data[mshr_dup_idx][curr_word_offset * DATA_WIDTH +: DATA_WIDTH] <= curr_wdata;
                                mshr_store_mask[mshr_dup_idx][curr_word_offset] <= 1'b1;
                            end
                        end else if (!mshr_full) begin // if not full then
                            mshr_paddr[mshr_free_idx]    <= incoming_line_paddr;
                            mshr_index[mshr_free_idx]    <= curr_index;
                            mshr_state[mshr_free_idx]    <= MS_UNRESOLVED;
                            mshr_store_mask[mshr_free_idx] <= '0;
                            mshr_store_data[mshr_free_idx] <= '0;
                            if (curr_is_write) begin
                                mshr_store_data[mshr_free_idx][curr_word_offset * DATA_WIDTH +: DATA_WIDTH] <= curr_wdata;
                                mshr_store_mask[mshr_free_idx][curr_word_offset] <= 1'b1;
                            end
                        end

                        state <= 3'd0;
                    end
                end
            end

            endcase

            // When L2 pulses l2_data_valid, scan all slots for an address match.
            // On match: save the returned block and flip to RESOLVED so the
            // state-0 install loop picks it up on the next cycle.
            for (integer i = 0; i < NUM_MSHRS; i++)
                if (mshr_state[i] == MS_UNRESOLVED && l2_data_valid && l2_data_paddr == mshr_paddr[i]) begin
                    mshr_block[i] <= l2_data;      // save the fetched block
                    mshr_state[i] <= MS_RESOLVED;  // ready to install into cache
                end

            if (wb_pop) begin
                wb_head  <= wb_head + 1'b1;
                wb_count <= wb_count - 1'b1;
            end

            if (wb_push) begin
                wb_paddr_q[wb_tail] <= wb_push_paddr;
                wb_data_q[wb_tail]  <= wb_push_data;
                wb_tail             <= wb_tail + 1'b1;
                wb_count            <= wb_count + (wb_pop ? '0 : 1'b1);
            end else if (wb_pop) begin
                wb_count <= wb_count - 1'b1;
            end

        end
    end





  //////////////////////////////////////////////////////////////////////////////////////   

    

endmodule

