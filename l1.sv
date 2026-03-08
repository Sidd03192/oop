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

    // mshr management
    logic [NUM_MSHRS-1:0] mshr_ready; // TODO wire this up to the mshrs correctly

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

    // TODO add MSHR modules, L2 cache and wire up here

    // TODO finish implementing where the comments in the always block say
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

        end else begin
            // check MSHR events, potentially unstall if stalling

            if (state == 0) begin
                // handle input, advance state
                state <= 1;

            end else if (state == 1) begin
                // got paddr, now see if we have a hit, advance state
                state <= 2;
                if (hit) begin
                    // DO LRU on set
                end else begin
                    // miss, go to MSHR
                end
            end
        end



    end


endmodule