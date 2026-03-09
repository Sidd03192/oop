`timescale 1ns/1ps
//TODO: set ready to take in inputs from lsq as output for lsq.
module l1_cache #(
    parameter L1_CAPACITY   = 512,
    parameter L1_WAYS       = 2,
    parameter BLOCK_SIZE    = 64,
    parameter NUM_MSHRS     = 2,
    parameter VA_WIDTH      = 48,
    parameter PA_WIDTH      = 30,
    parameter DATA_WIDTH    = 64,
    parameter TAG_SIZE      = 24  // always
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
    output logic                        l1_stall_out_to_lsq ,             // Can't accept request 
    // output logic                        resp_valid,         // Response ready (MISSING in memsys)
    // output logic [DATA_WIDTH-1:0]       resp_rdata,         // Load data (MISSING in memsys)

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

    localparam int L1_SETS = L1_CAPACITY / (BLOCK_SIZE * L1_WAYS);
    localparam int INDEX_BITS = $clog2(L1_SETS);
    
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
    logic                  curr_is_write;
    logic [DATA_WIDTH-1:0]  curr_wdata;


// evict temporaries — declared at module scope (can't declare logic inside always_ff)
logic                evict_way_l;
logic [PA_WIDTH-1:0] evict_pa;
logic                mshr_install_done; // flag to process only one RESOLVED slot per cycle (replaces break)

// ------------------------- Logic for MSHR
logic [1:0] mshr_state [NUM_MSHRS];
logic [PA_WIDTH-1:0]     mshr_paddr    [NUM_MSHRS];
logic [INDEX_BITS-1:0]   mshr_index    [NUM_MSHRS];
logic                    mshr_is_write [NUM_MSHRS];
logic [DATA_WIDTH-1:0]   mshr_wdata    [NUM_MSHRS];
logic [BLOCK_SIZE*8-1:0] mshr_block    [NUM_MSHRS];

localparam [1:0] MS_IDLE       = 2'b00;  // free
localparam [1:0] MS_UNRESOLVED = 2'b01;  // waiting for L2
localparam [1:0] MS_RESOLVED   = 2'b10;  // L2 returned


// values for writeback buffer. 
logic wb_valid;
logic [PA_WIDTH-1:0]     wb_paddr;
logic [BLOCK_SIZE*8-1:0] wb_value;



// Writeback buffer drives L2 ports combinationally
assign l2_wb_valid = wb_valid;
assign l2_wb_paddr = wb_paddr;
assign l2_wb_data  = wb_value;

// Combinationally scan all MSHR slots. If any is UNRESOLVED (waiting for L2),
// assert l2_req_valid and put that slot's address on l2_req_paddr.
// No clock edge needed — L2 sees the request the same cycle the MSHR is allocated.
// If both slots are UNRESOLVED, the highest index wins. 
always_comb begin
    l2_req_valid = 1'b0;
    l2_req_paddr = '0;
    for (int i = 0; i < NUM_MSHRS; i++)
        if (mshr_state[i] == MS_UNRESOLVED) begin
            l2_req_valid = 1'b1;
            l2_req_paddr = mshr_paddr[i];
        end
end

// ------------------

///////////////////// Combinational logic to find empty spot in MSHR
logic                         mshr_full; // if full 
logic [$clog2(NUM_MSHRS)-1:0] mshr_free_idx; // index of free spot. 

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
            l1_stall_out_to_lsq <= 1'b0;
            curr_index <= '0;
            curr_is_write <= '0;
            curr_wdata <= '0;
            // TODO: reset mshr
            // reset valid and dirty and lru
                    for (int i = 0; i < L1_SETS; i++) begin
                        set_valids[i] <= '0;
                        set_dirty[i]  <= '0;
                    end
                    lru <= '0;
            for (int i = 0; i < NUM_MSHRS; i++)
                mshr_state[i] <= MS_IDLE;
            wb_valid <= 1'b0;
            wb_paddr <= '0;
            wb_value <= '0;

        end else begin
            // Clear writeback buffer if l2 say we good. 
            if (wb_valid && l2_wb_ack)
                wb_valid <= 1'b0;

            case (state)
            3'd0: begin  // IDLE

                //TODO: make this go through states and 2 cycles. 
                // Check if any MSHR entry has data back from L2 
                mshr_install_done = 1'b0;
                for (integer i = 0; i < NUM_MSHRS; i++) begin
                    if (!mshr_install_done && mshr_state[i] == MS_RESOLVED) begin
                        evict_way_l = lru[mshr_index[i]];

                        if (set_dirty[mshr_index[i]][evict_way_l] && set_valids[mshr_index[i]][evict_way_l]) begin
                            wb_valid <= 1'b1;
                            wb_paddr <= {tags[mshr_index[i]][evict_way_l], mshr_index[i], {(PA_WIDTH-TAG_SIZE-INDEX_BITS){1'b0}}};
                            wb_value <= set_contents[mshr_index[i]][evict_way_l];
                        end

                        set_contents[mshr_index[i]][evict_way_l] <= mshr_block[i];
                        tags[mshr_index[i]][evict_way_l]         <= mshr_paddr[i][PA_WIDTH-1 -: TAG_SIZE];
                        set_valids[mshr_index[i]][evict_way_l]   <= 1'b1;
                        set_dirty[mshr_index[i]][evict_way_l]    <= mshr_is_write[i];
                        lru[mshr_index[i]]                       <= ~evict_way_l;
                        mshr_state[i]                            <= MS_IDLE;
                        mshr_install_done = 1'b1;
                    end
                end


                if (start_index) begin
                    curr_index    <= trace_vaddr[7:6];
                    curr_is_write <= is_write;
                    curr_wdata    <= wdata;
                    state         <= 3'd1;
                      
                end

                
            end

            3'd1: begin  // tag wait
                if (start_tag) begin
                    if (hit) begin
                        // HIT - handle read/write
                        if (curr_is_write) begin
                            set_contents[curr_index][hit_way] <= curr_wdata;
                            set_dirty[curr_index][hit_way]    <= 1'b1;
                        end
                        // lru update
                        lru[curr_index] <= hit_way[0];
                        state <= 3'd0;  // set to idle
                    end else begin
                        // MISS - go to MSHR

                        if (!mshr_full) begin // if full then
                            mshr_paddr[mshr_free_idx]    <= tlb_paddr;
                            mshr_index[mshr_free_idx]    <= curr_index;
                            mshr_is_write[mshr_free_idx] <= curr_is_write;
                            mshr_wdata[mshr_free_idx]    <= curr_wdata;
                            mshr_state[mshr_free_idx]    <= MS_UNRESOLVED;
                            l1_stall_out_to_lsq          <= 1'b0; 

                        end
                        else begin
                            l1_stall_out_to_lsq <= 1'b1;
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

        end
    end





  //////////////////////////////////////////////////////////////////////////////////////   

    

endmodule


