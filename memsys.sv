`timescale 1ns/1ps

//==============================================================================
// MEMORY SUBSYSTEM - Top Level Module
//==============================================================================
// This module instantiates and connects:
//   1. LSQ            - Load-Store Queue (16 entries)
//   2. TLB            - Translation Lookaside Buffer (16 entries)
//   3. L1 Cache       - PIVT, 512B, 2-way, 2 MSHRs
//   4. L2 Cache       - PIPT, 4KB, 4-way, 4 MSHRs
//   5. Memory         - Interface to physical memory (array or DRAM)
//
// Trace parsing is done inline (no separate module needed).
//==============================================================================

module memory_subsystem #(
    parameter VA_WIDTH      = 48,       
    parameter PA_WIDTH      = 30,       
    parameter DATA_WIDTH    = 64,      
    parameter BLOCK_SIZE    = 64,       

    // Trace parameters
    parameter TRACE_WIDTH   = 121,      

    // Component sizes
    parameter LSQ_ENTRIES   = 16,
    parameter TLB_ENTRIES   = 16,
    parameter L1_CAPACITY   = 512,      
    parameter L1_WAYS       = 2,
    parameter L1_MSHRS      = 2,
    parameter L2_CAPACITY   = \,     
    parameter L2_WAYS       = 4,
    parameter L2_MSHRS      = 4
)(
    input  logic                        clk,
    input  logic                        rst_n,

    
    // TRACE INPUT 
    
    input  logic [TRACE_WIDTH-1:0]      trace_data,
    input  logic                        trace_valid,
    output logic                        trace_ready,

    
    // MEMORY INTERFACE
    output logic                        mem_req_valid,
    output logic                        mem_req_is_write,
    output logic [PA_WIDTH-1:0]         mem_req_addr,
    output logic [BLOCK_SIZE*8-1:0]     mem_req_wdata,  // Full cache line
    input  logic                        mem_req_ready,
    input  logic                        mem_resp_valid,
    input  logic [BLOCK_SIZE*8-1:0]     mem_resp_rdata
);
    
    // Trace format (121 bits):
    //   [120]     - trace_value_valid (stores only)
    //   [119:56]  - trace_value (64-bit store data)
    //   [55]      - trace_vaddr_valid
    //   [54:52]   - trace_op (operation type)
    //   [51:48]   - trace_id (4-bit operation ID)
    //   [47:0]    -  (48-bit virtual address)
    //   [85:56]   - trace_tlb_paddr (for TLB_FILL only, 30-bit physical addr)
    

    // Operation types
    localparam [2:0] OP_MEM_LOAD    = 3'd0;
    localparam [2:0] OP_MEM_STORE   = 3'd1;
    localparam [2:0] OP_MEM_RESOLVE = 3'd2;
    localparam [2:0] OP_TLB_FILL    = 3'd4;

    // input wires for LSQ From trace. 
    wire [2:0]              trace_op          = trace_data[54:52];
    wire [3:0]              trace_id          = trace_data[51:48];
    wire [VA_WIDTH-1:0]     trace_vaddr      = trace_data[47:0];
    wire                    trace_vaddr_valid = trace_data[55];
    wire [DATA_WIDTH-1:0]   trace_value       = trace_data[119:56];
    wire                    trace_value_valid = trace_data[120];
    wire [PA_WIDTH-1:0]     trace_tlb_paddr   = trace_data[85:56];

    // Determine operation type
    wire is_load    = (trace_op == OP_MEM_LOAD);
    wire is_store   = (trace_op == OP_MEM_STORE);
    wire is_resolve = (trace_op == OP_MEM_RESOLVE);
    // for TLB 
    wire is_tlb_fill = (trace_op == OP_TLB_FILL);
    wire is_mem_op  = is_load || is_store || is_resolve;

    // Route to LSQ or TLB based on operation type
    wire lsq_trace_valid  = trace_valid && is_mem_op;
    logic lsq_trace_ready;
    // TLB Signals
    logic tlb_start;
    logic tlb_ready;
    logic tlb_valid;
    logic [PA_WIDTH-1:0] tlb_result_paddr;
    logic tlb_panic_miss;
    assign tlb_start = trace_valid && is_tlb_fill;

    //lsq
    logic                       l1_busy_to_lsq;
    logic [VA_WIDTH-1:0]        lsq_vaddr_to_l1;
    logic                       lsq_valid_to_l1;
    logic                       lsq_is_write_to_l1;
    logic [DATA_WIDTH-1:0]      lsq_wdata_to_l1;
    logic                       l1_resp_valid_to_lsq;
    logic [DATA_WIDTH-1:0]      l1_resp_rdata_to_lsq;

    // L1 <-> L2 signals. L2 is not implemented in this file yet, so the
    // response/ack side is tied idle and the request side is left internal.
    logic                       l1_l2_wb_valid;
    logic [PA_WIDTH-1:0]        l1_l2_wb_paddr;
    logic [BLOCK_SIZE*8-1:0]    l1_l2_wb_data;
    logic                       l2_l1_wb_ack;
    logic                       l1_l2_req_valid;
    logic [PA_WIDTH-1:0]        l1_l2_req_paddr;
    logic                       l2_l1_data_valid;
    logic [PA_WIDTH-1:0]        l2_l1_data_paddr;
    logic [BLOCK_SIZE*8-1:0]    l2_l1_data;

    assign l2_l1_wb_ack    = 1'b0;
    assign l2_l1_data_valid = 1'b0;
    assign l2_l1_data_paddr = '0;
    assign l2_l1_data       = '0;


  



    lsq #(
        .NUM_ENTRIES    (LSQ_ENTRIES),
        .VA_WIDTH       (VA_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .ID_WIDTH       (4)
    ) u_lsq (
        .clk                (clk),
        .rst_n              (rst_n),

        // Trace inputs
        .trace_valid        (lsq_trace_valid),
        .trace_op           (trace_op),
        .trace_id           (trace_id),
        .trace_vaddr        (trace_vaddr),
        .trace_vaddr_valid  (trace_vaddr_valid),
        .trace_value        (trace_value),
        .trace_value_valid  (trace_value_valid),
        .trace_ready        (lsq_trace_ready),

        // Outputs to L1 (use actual LSQ port names)
        .l1_req_valid       (lsq_valid_to_l1),
        .l1_req_is_write    (lsq_is_write_to_l1),
        .l1_req_vaddr       (lsq_vaddr_to_l1),
        .l1_req_wdata       (lsq_wdata_to_l1),

        // Input from L1
        .l1_req_ready       (~l1_busy_to_lsq) // if stall
        // .l1_resp_valid      (l1_resp_valid_to_lsq),
        // .l1_resp_rdata      (l1_resp_rdata_to_lsq)
    );

    tlb u_tlb (
        .clk            (clk),
        .rst_n          (rst_n),

        .start          (tlb_start),
        .is_tlb_fill    (is_tlb_fill),

        // inputs
        .vaddr          (trace_vaddr),
        .paddr          (trace_tlb_paddr),

        // Outputs
        .ready          (tlb_ready),
        .valid          (tlb_valid),
        .result_paddr   (tlb_result_paddr),
        .panic_tlb_miss (tlb_panic_miss)
    );
    l1_cache #(
        .L1_CAPACITY    (L1_CAPACITY),
        .L1_WAYS        (L1_WAYS)
    ) u_l1 (
        .clk            (clk),
        .rst_n          (rst_n),

        // From TLB
        .start_tag      (tlb_valid),
        .tlb_paddr      (tlb_result_paddr),

        // From LSQ
        .start_index    (lsq_valid_to_l1),
        .trace_vaddr    (lsq_vaddr_to_l1),
        .is_write       (lsq_is_write_to_l1),
        .wdata          (lsq_wdata_to_l1),
 
        // To LSQ
        .l1_stall_out_to_lsq (l1_busy_to_lsq),
 
        // To / From L2
        .l2_wb_valid    (l1_l2_wb_valid),
        .l2_wb_paddr    (l1_l2_wb_paddr),
        .l2_wb_data     (l1_l2_wb_data),
        .l2_wb_ack      (l2_l1_wb_ack),
        .l2_req_valid   (l1_l2_req_valid),
        .l2_req_paddr   (l1_l2_req_paddr),
        .l2_data_valid  (l2_l1_data_valid),
        .l2_data_paddr  (l2_l1_data_paddr),
        .l2_data        (l2_l1_data)

        // .resp_valid     (l1_resp_valid_to_lsq),
        // .resp_rdata     (l1_resp_rdata_to_lsq)
    );
 

endmodule

