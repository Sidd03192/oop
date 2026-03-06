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
                if (start_index) begin
                    curr_index    <= trace_vaddr[7:6];
                    curr_is_write <= is_write;
                    curr_wdata    <= wdata;
                    state         <= 3'd1;
                      
                end
                // if MSHR set that stuff and go to state 3. 

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




/*
    states:
        0 - Empty
        1 - Pending Resolution
        2 - Pending Eviction
*/
module MSHR #(
    parameter PADDR_LEN         = 48
)(
    input   logic                           miss,
    input   logic[PADDR_LEN-1:0]            paddr,
    input   logic                           resolve,
    input   logic[BLOCKBLOCK_SIZE*8-1:0]    data_in,
    output  logic                           empty,
    output  logic[BLOCKBLOCK_SIZE*8-1:0]    data_out,
    output  logic                           pending_resolution,
    output  logic                           valid_out
)
    


endmodule