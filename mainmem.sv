`timescale 1ns/1ps

// Behavioral main memory for Verilator simulation.
//
// ---------------------------------------------------------------
// TO REPLACE WITH FPGA DRAM (DE10-Nano HPS SDRAM via F2H bridge):
//
//   1. Keep all top-level ports exactly as-is.
//   2. Remove the "mem" array and the countdown/resolve logic below.
//   3. Add an Avalon-MM master that drives the SDRAM controller.
//      Wire these signals to Platform Designer's SDRAM controller port:
//
//        output logic [PA_WIDTH-1:0]        avl_addr        // block-aligned byte address
//        output logic                       avl_read_req
//        output logic                       avl_write_req
//        output logic [BLOCK_SIZE-1:0]      avl_be          // all-ones for full block
//        output logic [BLOCK_SIZE*8-1:0]    avl_wdata
//        output logic [0:0]                 avl_burstcount  // = 1 (one block per txn)
//        input  logic                       avl_ready       // asserted when cmd accepted
//        input  logic                       avl_rdata_valid
//        input  logic [BLOCK_SIZE*8-1:0]    avl_rdata
//
//   4. Use a small state machine per MSHR: issue avl_read_req/avl_write_req,
//      wait for avl_ready, then wait for avl_rdata_valid to assert resolve_out.
// ---------------------------------------------------------------

module mainmem #(
    parameter BLOCK_SIZE    = 64,           // bytes per cache block
    parameter PA_WIDTH      = 30,           // 2^30 = 1 GB physical
    parameter L2_MSHRS      = 4,
    parameter MEM_LATENCY   = 20,           // simulated DRAM latency in cycles

    // Simulation array depth in blocks. Full depth is (1<<PA_WIDTH)/BLOCK_SIZE = 16M,
    // which needs 1 GB of simulator RAM. Reduce here for faster simulation;
    // accesses wrap modulo SIM_DEPTH. Increase for larger working sets.
    parameter SIM_DEPTH     = 16384         // 16K blocks = 1 MB
)(
    input  logic                        clk,
    input  logic                        rst_n,

    // L2 dirty writeback (no response needed)
    input  logic                        evict_in,
    input  logic [PA_WIDTH-1:0]         e_paddr_in,
    input  logic                        e_dirty_in,
    input  logic [BLOCK_SIZE*8-1:0]     e_data_in,

    // requests from L2 MSHRs
    input  logic                        miss_in             [L2_MSHRS],
    input  logic [PA_WIDTH-1:0]         paddr_in            [L2_MSHRS],
    input  logic                        w_in                [L2_MSHRS],
    input  logic [BLOCK_SIZE*8-1:0]     data_in             [L2_MSHRS],

    // responses to L2 MSHRs (same protocol as L2 -> L1)
    output logic                        empty_out           [L2_MSHRS],
    output logic                        resolve_out         [L2_MSHRS],
    output logic [BLOCK_SIZE*8-1:0]     superior_data_out   [L2_MSHRS]
);

    localparam int OFFSET_BITS  = $clog2(BLOCK_SIZE);
    localparam int DEPTH_BITS   = $clog2(SIM_DEPTH);
    localparam int LAT_BITS     = $clog2(MEM_LATENCY + 2);

    // ---------------------------------------------------------------
    // Simulation memory array — remove this section for FPGA
    // ---------------------------------------------------------------
    logic [BLOCK_SIZE*8-1:0] mem [SIM_DEPTH];

    // extract block index from a physical address (wraps for sim)
    function automatic logic [DEPTH_BITS-1:0] blk(input logic [PA_WIDTH-1:0] pa);
        return pa[OFFSET_BITS +: DEPTH_BITS];
    endfunction

    // per-MSHR state
    logic [LAT_BITS-1:0]    countdown   [L2_MSHRS];
    logic [PA_WIDTH-1:0]    mshr_paddr  [L2_MSHRS];
    logic                   mshr_active [L2_MSHRS];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < L2_MSHRS; i++) begin
                empty_out[i]            <= 1'b1;
                resolve_out[i]          <= 1'b0;
                superior_data_out[i]    <= '0;
                countdown[i]            <= '0;
                mshr_paddr[i]           <= '0;
                mshr_active[i]          <= 1'b0;
            end
        end else begin
            // resolve is a one-cycle strobe
            for (int i = 0; i < L2_MSHRS; i++)
                resolve_out[i] <= 1'b0;

            // dirty evictions write through immediately
            if (evict_in && e_dirty_in)
                mem[blk(e_paddr_in)] <= e_data_in;

            // accept new requests into free slots
            for (int i = 0; i < L2_MSHRS; i++) begin
                if (miss_in[i] && empty_out[i]) begin
                    empty_out[i]    <= 1'b0;
                    mshr_paddr[i]   <= paddr_in[i];
                    mshr_active[i]  <= 1'b1;
                    countdown[i]    <= LAT_BITS'(MEM_LATENCY);
                    if (w_in[i])
                        mem[blk(paddr_in[i])] <= data_in[i];
                end
            end

            // count down and return data
            for (int i = 0; i < L2_MSHRS; i++) begin
                if (mshr_active[i]) begin
                    if (countdown[i] == '0) begin
                        resolve_out[i]          <= 1'b1;
                        superior_data_out[i]    <= mem[blk(mshr_paddr[i])];
                        empty_out[i]            <= 1'b1;
                        mshr_active[i]          <= 1'b0;
                    end else begin
                        countdown[i] <= countdown[i] - 1'b1;
                    end
                end
            end
        end
    end

endmodule
