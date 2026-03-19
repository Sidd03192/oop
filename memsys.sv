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
    parameter L2_CAPACITY   = 4096,     
    parameter L2_WAYS       = 4,
    parameter L2_MSHRS      = 4
)(
    input  logic                        clk,
    input  logic                        rst_n,

    
    // TRACE INPUT 
    input  logic [2:0]       trace_addr,
    input  logic [31:0]      trace_data,
    input  logic             trace_valid,
    output logic             trace_ready,

    // TO SDRAM PORTS
    output logic [28:0] avm_address,
    output logic  [7:0] avm_burstcount,
    output logic        avm_read,
    output logic        avm_write,
    output logic [63:0] avm_writedata,
    output logic  [7:0] avm_byteenable,
    input  logic [63:0] avm_readdata,
    input  logic        avm_readdatavalid,
    input  logic        avm_waitrequest
);
    
    // Trace format (121 bits):
    //   [120]     - trace_value_valid (stores only)
    //   [119:56]  - trace_value (64-bit store data)
    //   [55]      - trace_vaddr_valid
    //   [54:52]   - trace_op (operation type)
    //   [51:48]   - trace_id (4-bit operation ID)
    //   [47:0]    -  (48-bit virtual address)
    //   [85:56]   - trace_tlb_paddr (for TLB_FILL only, 30-bit physical addr)

    logic [TRACE_WIDTH-1:0] trace_line;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        trace_line <= '0;
    end else begin
        if (trace_valid) begin
            case (trace_addr)
                2'd0: trace_line[31:0]   <= trace_data;
                2'd1: trace_line[63:32]  <= trace_data;
                2'd2: trace_line[95:64]  <= trace_data;
                2'd3: trace_line[120:96] <= trace_data[24:0];
            endcase
        end
    end
end
    

    // Operation types
    localparam [2:0] OP_MEM_LOAD    = 3'd0;
    localparam [2:0] OP_MEM_STORE   = 3'd1;
    localparam [2:0] OP_MEM_RESOLVE = 3'd2;
    localparam [2:0] OP_TLB_FILL    = 3'd4;

    // input wires for LSQ From trace. 
    wire [2:0]              trace_op          = trace_line[54:52];
    wire [3:0]              trace_id          = trace_line[51:48];
    wire [VA_WIDTH-1:0]     trace_vaddr      = trace_line[47:0];
    wire                    trace_vaddr_valid = trace_line[55];
    wire [DATA_WIDTH-1:0]   trace_value       = trace_line[119:56];
    wire                    trace_value_valid = trace_line[120];
    wire [PA_WIDTH-1:0]     trace_tlb_paddr   = trace_line[85:56];

    wire is_load    = (trace_op == OP_MEM_LOAD);
    wire is_store   = (trace_op == OP_MEM_STORE);
    wire is_resolve = (trace_op == OP_MEM_RESOLVE);
    // for TLB 
    wire is_tlb_fill = (trace_op == OP_TLB_FILL);
    wire is_mem_op  = is_load || is_store || is_resolve;

    wire trace_fire = trace_valid && trace_ready;

    wire lsq_trace_valid  = trace_fire && is_mem_op;

    // TLB Signals
    logic tlb_ready;
    logic tlb_valid;
    logic [PA_WIDTH-1:0] tlb_result_paddr;

    // TLB fill happening this cycle (used for collision prevention)
    wire is_tlb_fill_now = trace_fire && is_tlb_fill;

    // LSQ → issue buffer wires
    logic                       l1_busy_to_lsq;
    logic [VA_WIDTH-1:0]        lsq_vaddr_to_l1;
    logic                       lsq_valid_to_l1;
    logic [DATA_WIDTH-1:0]      lsq_wdata_to_l1;
    logic [2:0]                 lsq_issue_op;
    logic                       lsq_lq_ready;
    logic                       lsq_sq_ready;

    // One-entry issue buffer decouples LSQ dequeue from L1/TLB launch.
    logic                    issue_buf_valid;
    logic [VA_WIDTH-1:0]     issue_buf_vaddr;
    logic [DATA_WIDTH-1:0]   issue_buf_wdata;
    logic [2:0]              issue_buf_op;
    wire                     issue_buf_empty = !issue_buf_valid;
    wire                     issue_buf_is_write = (issue_buf_op == OP_MEM_STORE);

    // lsq only dq when empyty
    wire lsq_issue_slot_ready = issue_buf_empty;

// send on ready
    wire launch_issue_now = issue_buf_valid && !is_tlb_fill_now && !l1_busy_to_lsq && tlb_ready;

    wire tlb_start = is_tlb_fill_now || launch_issue_now;

    // fill uses trace_vaddr, lookup uses LSQ issue_vaddr
    wire [VA_WIDTH-1:0] tlb_vaddr_mux = is_tlb_fill_now ? trace_vaddr : issue_buf_vaddr;

    // Gate L1 start_index so it doesn't fire during a TLB fill collision
    wire l1_start_from_lsq = launch_issue_now;

    assign trace_ready = is_tlb_fill ? tlb_ready
                       : is_load     ? lsq_lq_ready
                       : is_store    ? lsq_sq_ready
                       : is_resolve  ? 1'b1
                       :               1'b0;

    // L1 <-> L2 signals.
    logic                       l1_l2_wb_valid;
    logic [PA_WIDTH-1:0]        l1_l2_wb_paddr;
    logic [BLOCK_SIZE*8-1:0]    l1_l2_wb_data;
    logic                       l2_l1_wb_ack;
    logic                       l1_l2_req_valid;
    logic [PA_WIDTH-1:0]        l1_l2_req_paddr;
    logic                       l2_l1_data_valid;
    logic [PA_WIDTH-1:0]        l2_l1_data_paddr;
    logic [BLOCK_SIZE*8-1:0]    l2_l1_data;

    lsq #(
        .LQ_ENTRIES     (LSQ_ENTRIES / 2),  // 8 loads
        .SQ_ENTRIES     (LSQ_ENTRIES / 2),  // 8 stores
        .VA_WIDTH       (VA_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH)
    ) u_lsq (
        .clk            (clk),
        .rst_n          (rst_n),

        // Trace inputs
        .op             (trace_op),
        .valid_in       (lsq_trace_valid),
        .vaddr_in       (trace_vaddr),
        .wdata_in       (trace_value),
        .vaddr_ready    (trace_vaddr_valid),
        .wdata_ready    (trace_value_valid),
        .id_in          (trace_id),

        // From L1 / TLB
        .l1_ready       (lsq_issue_slot_ready),
        .tlb_ready      (lsq_issue_slot_ready),

        // Outputs
        .lq_ready       (lsq_lq_ready),
        .sq_ready       (lsq_sq_ready),
        .valid_out      (lsq_valid_to_l1),
        .issue_vaddr    (lsq_vaddr_to_l1),
        .issue_wdata    (lsq_wdata_to_l1),
        .issue_op       (lsq_issue_op)
    );

    tlb u_tlb (
        .clk            (clk),
        .rst_n          (rst_n),

        .start          (tlb_start),
        .is_tlb_fill    (is_tlb_fill_now),

        // inputs — mux: fill uses trace_vaddr, lookup uses LSQ issue_vaddr
        .vaddr          (tlb_vaddr_mux),
        .paddr          (trace_tlb_paddr),

        // Outputs
        .ready          (tlb_ready),
        .valid          (tlb_valid),
        .result_paddr   (tlb_result_paddr)
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

        // From LSQ (gated: no start during TLB fill collision)
        .start_index    (l1_start_from_lsq),
        .trace_vaddr    (issue_buf_vaddr),
        .is_write       (issue_buf_is_write),
        .wdata          (issue_buf_wdata),

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
    );

        // MEMORY INTERFACE
    logic                        mem_req_valid;
    logic                        mem_req_is_write;
    logic [PA_WIDTH-1:0]         mem_req_addr;
    logic [BLOCK_SIZE*8-1:0]     mem_req_wdata;  // Full cache line
    logic                        mem_req_ready;
    logic                        mem_resp_valid;
    logic [PA_WIDTH-1:0]         mem_resp_paddr;
    logic [BLOCK_SIZE*8-1:0]     mem_resp_rdata;

    l2_cache #(
        .L2_CAPACITY    (L2_CAPACITY),
        .L2_WAYS        (L2_WAYS),
        .BLOCK_SIZE     (BLOCK_SIZE),
        .NUM_MSHRS      (L2_MSHRS),
        .PA_WIDTH       (PA_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH)
    ) u_l2 (
        .clk            (clk),
        .rst_n          (rst_n),

        // From L1
        .l1_wb_valid    (l1_l2_wb_valid),
        .l1_wb_paddr    (l1_l2_wb_paddr),
        .l1_wb_data     (l1_l2_wb_data),
        .l1_wb_ack      (l2_l1_wb_ack),
        .l1_req_valid   (l1_l2_req_valid),
        .l1_req_paddr   (l1_l2_req_paddr),

        // Back to L1
        .l1_data_valid  (l2_l1_data_valid),
        .l1_data_paddr  (l2_l1_data_paddr),
        .l1_data        (l2_l1_data),

        // To memory
        .mem_req_valid  (mem_req_valid),
        .mem_req_is_write(mem_req_is_write),
        .mem_req_addr   (mem_req_addr),
        .mem_req_wdata  (mem_req_wdata),
        .mem_req_ready  (mem_req_ready),

        // From memory
        .mem_resp_valid (mem_resp_valid),
        .mem_resp_paddr (mem_resp_paddr),
        .mem_resp_rdata (mem_resp_rdata)
    );

    l2_sdram_master avm_sdram (
        .clk   (clk),
        .rst_n (rst_n),

        // From L2
        .req_valid (mem_req_valid),
        .req_addr  (mem_req_addr),
        .req_wr    (mem_req_is_write),
        .req_wdata (mem_req_wdata),

        // To L2
        .rdata_out (mem_resp_rdata),
        .paddr_out (mem_resp_paddr),
        .ready     (mem_req_ready),
        .valid     (mem_resp_valid),

        // TO SDRAM PORTS
        .avm_address       (avm_address),
        .avm_burstcount    (avm_burstcount),
        .avm_read          (avm_read),
        .avm_write         (avm_write),
        .avm_writedata     (avm_writedata),
        .avm_byteenable    (avm_byteenable),
        .avm_readdata      (avm_readdata),
        .avm_readdatavalid (avm_readdatavalid),
        .avm_waitrequest   (avm_waitrequest)
    );

// comb logic to handle issue buffer. 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            issue_buf_valid <= 1'b0;
            issue_buf_vaddr <= '0;
            issue_buf_wdata <= '0;
            issue_buf_op    <= '0;
        end else begin
            if (launch_issue_now) begin
                issue_buf_valid <= 1'b0;
            end

            if (lsq_valid_to_l1) begin
                issue_buf_valid <= 1'b1;
                issue_buf_vaddr <= lsq_vaddr_to_l1;
                issue_buf_wdata <= lsq_wdata_to_l1;
                issue_buf_op    <= lsq_issue_op;
            end
        end
    end

endmodule

