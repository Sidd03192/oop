`timescale 1ns/1ps

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
    output logic                        isfull,             // Can't accept request
    // output logic                        resp_valid,         // Response ready (MISSING in memsys)
    // output logic [DATA_WIDTH-1:0]       resp_rdata,         // Load data (MISSING in memsys)


    // input from MSHR

    // output to MSHR
    

    //TODO: MSHR + Reset Buffer
);

    localparam int L1_SETS = L1_CAPACITY / (BLOCK_SIZE * L1_WAYS);
    
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
            state <= 0;
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
        end else begin
            case (state)
            3'd0: begin  // IDLE

                if (start_index) begin // cycle 1
                    curr_index    <= trace_vaddr[7:6];
                    curr_is_write <= is_write;
                    curr_wdata    <= wdata;
                    state         <= 3'd1;
                      
                end
                // if MSHR not full set that stuff and go to state 3. 

            end

            3'd1: begin  // tag wait
                if (start_tag) begin //
                    if (hit) begin
                        // HIT - handle read/write
                        if (curr_is_write) begin
                            set_contents[curr_index][hit_way] <= curr_wdata;
                            set_dirty[curr_index][hit_way]    <= 1'b1;
                        end
                        // lru update
                        lru[curr_index] <= ~hit_way[0];
                        state <= 3'd0;  // set to idle
                    end else begin
                        // MISS - go to MSHR
                        
                        // TODO: Create MSHR Entry

                        state <= 3'd0;
                    end
                end
            end
            
                
        end
    end





  //////////////////////////////////////////////////////////////////////////////////////   

    

endmodule




module mshr # 
(
    parameter PA_WIDTH          = 30,
    parameter DATA_WIDTH        = 64,
    parameter BLOCK_SIZE        = 64,
    parameter INDEX_BITS        = 2,
    parameter TAG_SIZE          = 24,
    parameter QUEUE_DEPTH       = 4
    
)(
    input logic clk,
    input logic rest_n

    // allocate from l1 on miss
    input logic l1_alloc,
    input logic l1_is_write,
    input logic [PA_WIDTH-1:0] l1_alloc_paddr,
    input logic [DATA_WIDTH -1:0] l1_w_data,

    input logic l1_acknowledge, // l1 has dealt with an entry and we can clear it
    
    // ouputs to 1l (status) 
    output logic full, // no more emtpy slots
    output logic entry_ready, 
    output logic [PA_WIDTH-1:0] entry_paddr,
    output logic entry_is_write
    output logic [DATA_WIDTH-1:0]       l1_ready_wdata,     // Store data to apply
    output logic [BLOCK_SIZE*8-1:0]     l1_ready_block,     // Block data from L2

)
    parameter NUM_MSHR = 2;

    // States
    localparam IDLE      = 2'b00;
    localparam WAIT_MEM  = 2'b01;
    localparam WAIT_DATA = 2'b10;
    localparam READY     = 2'b11;

    
    // Data per slot
    logic [PA_WIDTH-1:0]        slot_paddr    [NUM_MSHR];
    logic                       slot_is_write [NUM_MSHR];
    logic [DATA_WIDTH-1:0]      slot_wdata    [NUM_MSHR];
    logic [BLOCK_SIZE*8-1:0]    slot_block    [NUM_MSHR];
    logic [1:0] slot_state [NUM_MSHR];

    logic [NUM_MSHR]ready_slot; // what we decide to show to l1 as ready

// auto set full TODO: CHECK if this works
always_comb begin
        full = 1'b1;
        for (int i=0; i<NUM_MSHR; i++) if (slot_state[i] == IDLE) full = 1'b0;
    end

always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i=0; i<NUM_MSHR; i++) slot_state[i] <= IDLE;
        end else begin
            // 1. find free slot and alloc 
            if (l1_alloc && !full) begin
                for (int i=0; i<NUM_MSHR; i++) begin
                    if (slot_state[i] == IDLE) begin
                        slot_state[i]    <= WAIT_MEM;
                        slot_paddr[i]    <= l1_alloc_paddr;
                        slot_is_write[i] <= l1_is_write;
                        slot_wdata[i]    <= l1_w_data;
                        break; 
                    end
                end
            end

            // need to handle litteraly everythign else. 
        end
    end

endmodule