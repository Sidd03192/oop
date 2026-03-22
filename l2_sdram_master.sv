// =============================================================================
// l2_sdram_master_v2.sv
//
// Avalon-MM Burst Master: L2 Cache <-> HPS f2h_sdram port
// Target board : DE10-Nano (Cyclone V SX)
// SDRAM bridge : f2h_sdram0  (64-bit Avalon-MM slave on HPS side)
// Cache line   : 64 bytes  -> 8 x 64-bit bursts per transfer
//
// Interface contract with your L2:
//   - Assert req_valid with req_addr (byte-aligned to 64B) and req_wr.
//   - For writes: provide full 512-bit req_wdata before asserting req_valid.
//   - For reads:  rdata_out[511:0] is valid when valid pulses.
//   - ready is high when the module can accept a new request.
//   - valid pulses for one cycle on completion.
// =============================================================================

module l2_sdram_master (
    // -------------------------------------------------------------------------
    // System
    // -------------------------------------------------------------------------
    input  logic        clk,
    input  logic        rst_n,

    // -------------------------------------------------------------------------
    // L2 cache interface
    // -------------------------------------------------------------------------
    input  logic         req_valid,
    input  logic [29:0]  req_addr,     // Byte address, must be 64-byte aligned
    input  logic         req_wr,       // 1 = write (eviction), 0 = read (fill)
    input  logic [511:0] req_wdata,    // Full cache line write data

    output logic [511:0] rdata_out,    // Full cache line read data, valid when valid=1
    output logic [29:0]  paddr_out,    // For L2 MSHR to know which address is being resolved
    output logic         ready,        // High when module can accept new request
    output logic         valid,        // Single-cycle pulse on completion

    // -------------------------------------------------------------------------
    // Avalon-MM Master port  (wire to f2h_sdram0_data in Platform Designer)
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        S_IDLE,
        S_WRITE_CMD,
        S_WRITE_DATA,
        S_READ_CMD,
        S_READ_DATA,
        S_DONE
    } state_t;

    state_t state;

    // -------------------------------------------------------------------------
    // Internal registers
    // -------------------------------------------------------------------------
    logic [28:0] r_addr;
    logic [2:0]  burst_cnt;
    logic [63:0] r_val_burst [0:7];

    // Slice write data into 8 x 64-bit bursts
    logic [63:0] w_val_burst [0:7];
    assign w_val_burst[0] = req_wdata[63:0];
    assign w_val_burst[1] = req_wdata[127:64];
    assign w_val_burst[2] = req_wdata[191:128];
    assign w_val_burst[3] = req_wdata[255:192];
    assign w_val_burst[4] = req_wdata[319:256];
    assign w_val_burst[5] = req_wdata[383:320];
    assign w_val_burst[6] = req_wdata[447:384];
    assign w_val_burst[7] = req_wdata[511:448];

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    assign avm_burstcount = 8'd8;
    assign avm_byteenable = 8'hFF;

    // -------------------------------------------------------------------------
    // Avalon-MM combinational outputs
    // -------------------------------------------------------------------------
    always_comb begin
        avm_read      = 1'b0;
        avm_write     = 1'b0;
        avm_address   = r_addr;
        avm_writedata = w_val_burst[burst_cnt];

        case (state)
            S_WRITE_CMD,
            S_WRITE_DATA: avm_write = 1'b1;
            S_READ_CMD:   avm_read  = 1'b1;
            default: ;
        endcase
    end

    // -------------------------------------------------------------------------
    // FSM sequential
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            r_addr    <= '0;
            burst_cnt <= '0;
            paddr_out <= '0; 
        end else begin
            case (state)

                S_IDLE: begin
                    burst_cnt <= '0;
                    if (req_valid) begin
                        r_addr <= {2'b0, req_addr[29:6], 3'b0};
                        paddr_out <= req_addr;
                        if (req_wr) begin
                            state <= S_WRITE_CMD;
                        end else begin
                            state <= S_READ_CMD;
                        end
                    end
                end

                // Burst 0 data is already on avm_writedata via combinational block.
                // Wait for bridge to accept it then move to data phase.
                S_WRITE_CMD: begin
                    if (!avm_waitrequest) begin
                        burst_cnt <= burst_cnt + 1'b1;
                        state     <= S_WRITE_DATA;
                    end
                end

                S_WRITE_DATA: begin
                    if (!avm_waitrequest) begin
                        if (burst_cnt == 3'd7)
                            state <= S_DONE;
                        else
                            burst_cnt <= burst_cnt + 1'b1;
                    end
                end

                // avm_read is high combinationally while in this state.
                // Wait for bridge to accept the command then collect bursts.
                S_READ_CMD: begin
                    if (!avm_waitrequest)
                        state <= S_READ_DATA;
                end

                S_READ_DATA: begin
                    if (avm_readdatavalid) begin
                        r_val_burst[burst_cnt] <= avm_readdata;
                        if (burst_cnt == 3'd7)
                            state <= S_DONE;
                        else
                            burst_cnt <= burst_cnt + 1'b1;
                    end
                end

                S_DONE: begin
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;

            endcase
        end
    end

    // -------------------------------------------------------------------------
    // L2-facing outputs
    // -------------------------------------------------------------------------
    assign ready = (state == S_IDLE);
    assign valid = (state == S_DONE);

    assign rdata_out = {r_val_burst[7], r_val_burst[6], r_val_burst[5], r_val_burst[4],
                        r_val_burst[3], r_val_burst[2], r_val_burst[1], r_val_burst[0]};

endmodule
