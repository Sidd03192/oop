module memory_subsystem_avl_wrapper #(
    parameter VA_WIDTH    = 48,
    parameter PA_WIDTH    = 30,
    parameter DATA_WIDTH  = 64,
    parameter BLOCK_SIZE  = 64,
    parameter TRACE_WIDTH = 121,
    parameter LSQ_ENTRIES = 16,
    parameter TLB_ENTRIES = 16,
    parameter L1_CAPACITY = 512,
    parameter L1_WAYS     = 2,
    parameter L1_MSHRS    = 2,
    parameter L2_CAPACITY = 4096,
    parameter L2_WAYS     = 4,
    parameter L2_MSHRS    = 4
)(
    input  logic        clk,
    input  logic        rst_n,

    // ── Avalon-MM slave (HPS → FPGA) ─────────────────────────────────
    // Platform Designer connects the HPS lightweight HPS-to-FPGA bridge here.
    // Address is word-addressed (2 bits → 4 registers):
    //   0x0  trace_addr  [1:0]   write-only
    //   0x4  trace_data  [31:0]  write-only
    //   0x8  trace_valid [0]     write-only
    //   0xC  trace_ready [0]     read-only
    input  logic [1:0]  avs_address,
    input  logic        avs_write,
    input  logic        avs_read,
    input  logic [31:0] avs_writedata,
    output logic [31:0] avs_readdata,

    // ── Avalon-MM master (FPGA → SDRAM) ──────────────────────────────
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
    logic [1:0]  trace_addr_reg;
    logic [31:0] trace_data_reg;
    logic        trace_valid_reg;
    logic        trace_ready_wire;

    // Pulse high for exactly one cycle when trace_data is written.
    // This is what actually clocks the chunk into trace_line inside
    // memory_subsystem — addr must already be set before this fires.
    logic trace_data_write_pulse;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trace_addr_reg        <= '0;
            trace_data_reg        <= '0;
            trace_valid_reg       <= '0;
            trace_data_write_pulse <= '0;
        end else begin
            // Default: pulse is only high for one cycle
            trace_data_write_pulse <= 1'b0;

            // Auto-clear the software request once the memsys handshake occurs
            // so one MMIO "valid=1" write can only submit one trace record.
            if (trace_valid_reg && trace_ready_wire)
                trace_valid_reg <= 1'b0;

            if (avs_write) begin
                case (avs_address)
                    2'd0: trace_addr_reg  <= avs_writedata[1:0];  // step 1
                    2'd1: begin
                        trace_data_reg        <= avs_writedata;    // step 2
                        trace_data_write_pulse <= 1'b1;            // fires chunk write
                    end
                    2'd2: trace_valid_reg <= avs_writedata[0];
                endcase
            end
        end
    end

    // Read handler
    always_comb begin
        case (avs_address)
            2'd0:    avs_readdata = {30'b0, trace_addr_reg};
            2'd1:    avs_readdata = trace_data_reg;
            2'd2:    avs_readdata = {31'b0, trace_valid_reg};
            2'd3:    avs_readdata = {31'b0, trace_ready_wire};
            default: avs_readdata = '0;
        endcase
    end

    // ── Instantiate your existing memory_subsystem unchanged ─────────
    memory_subsystem #(
        .VA_WIDTH      (VA_WIDTH),
        .PA_WIDTH      (PA_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH),
        .BLOCK_SIZE    (BLOCK_SIZE),
        .TRACE_WIDTH   (TRACE_WIDTH),
        .LSQ_ENTRIES   (LSQ_ENTRIES),
        .TLB_ENTRIES   (TLB_ENTRIES),
        .L1_CAPACITY   (L1_CAPACITY),
        .L1_WAYS       (L1_WAYS),
        .L1_MSHRS      (L1_MSHRS),
        .L2_CAPACITY   (L2_CAPACITY),
        .L2_WAYS       (L2_WAYS),
        .L2_MSHRS      (L2_MSHRS)
    ) u_mem_subsystem (
        .clk            (clk),
        .rst_n          (rst_n),

        // Trace — driven by the registered Avalon writes
        .trace_addr     (trace_addr_reg),
        .trace_data     (trace_data_reg),
        .trace_valid    (trace_valid_reg),
        .trace_write    (trace_data_write_pulse),
        .trace_ready    (trace_ready_wire),

        // SDRAM — pass straight through to top-level ports
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

endmodule
