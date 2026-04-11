// Dispatch reads ROB entries for source operands to check if values are ready.
// Dispatch then requests a new ROB entry for the destination register (if applicable)
// and receives the allocated ROB index to tag onto the instruction.

module ozone_rob
  import ozone_pkg::*;
#(
    parameter ROB_DEPTH     = (1 << ROB_IDX_WIDTH),
    parameter ROB_IDX_BITS  = ROB_IDX_WIDTH
)(
    input  logic                        clk,
    input  logic                        rst_n,

    // dispatch reads for source operand readiness and values
    input  logic [ROB_IDX_BITS-1:0]     src1_rob_idx,       // ROB index for source 1
    input  logic [ROB_IDX_BITS-1:0]     src2_rob_idx,       // ROB index for source 2
    output logic                        src1_ready,         // source 1 value is ready
    output logic [63:0]                 src1_value,         // source 1 value (if ready)
    output logic                        src2_ready,         // source 2 value is ready
    output logic [63:0]                 src2_value,         // source 2 value (if ready)
    // dispatch requests to allocate a new rob entry. 
    input  logic                        alloc_valid,        // request to allocate a new entry
    input  logic                        alloc_has_dest,     // some ins dont have dest. 
    input  rob_entry_t                  alloc_data,         // initial data for the entry
    output logic [ROB_IDX_BITS-1:0]     alloc_rob_idx,      // allocated ROB index returned to dispatch

    output logic                        rob_full,           // stall dispatch if full

    // cdb broadcast. 
    input  cdb_broadcast_t              cdb_in,

    // commit to regfile
    output logic                        commit_valid,       // committing this cycle
    output rob_entry_t                  commit_data,        // data for regfile writeback
    output logic                        commit_reg_en,      // architectural GPR write commit
    output logic [4:0]                  commit_reg_addr,
    output logic [63:0]                 commit_reg_value,
    output logic [ROB_IDX_BITS-1:0]     commit_reg_rob_idx,
    output logic                        commit_nzcv_en,     
    output logic [3:0]                  commit_nzcv_value,
    output logic [ROB_IDX_BITS-1:0]     commit_nzcv_rob_idx,

    // TODO: Brayden update
    output logic                        lsq_store_commit,   // tell LSQ to write memory
    output logic [63:0]                 lsq_store_addr,
    output logic [63:0]                 lsq_store_data,

    // TODO: upate
    output logic                        bp_update_valid,
    output logic [63:0]                 bp_update_pc,
    output logic                        bp_update_taken,
    output logic [63:0]                 bp_update_target,

    // flush TODO: make sure clera on this
    output logic                        flush,              // flush entire pipeline
    output logic [63:0]                 flush_target_pc,    // where to restart fetch
    output logic                        exception_valid,
    output logic [63:0]                 exception_pc,       // faulting PC → ELR_EL1
    output logic [3:0]                  exception_code
);

    // rob entries
    rob_entry_t rob_entries [ROB_DEPTH-1:0];
    logic [ROB_IDX_BITS-1:0] head;  // oldest entry (commit pointer)
    logic [ROB_IDX_BITS-1:0] tail;  // next free entry (allocation pointer)
    logic [ROB_IDX_BITS:0]   count; // number of valid entries (extra bit for full detection)
    rob_entry_t              head_entry;
    logic                    head_can_commit;
    logic                    do_alloc;

    // Full/empty detection
    assign rob_full = (count == ROB_DEPTH);

   // dispatch reads source ops
    always_comb begin
        // Default: read from ROB entry
        src1_ready = rob_entries[src1_rob_idx].ready;
        src1_value = rob_entries[src1_rob_idx].value;
        src2_ready = rob_entries[src2_rob_idx].ready;
        src2_value = rob_entries[src2_rob_idx].value;

        // if CDB broadcast matches what we are reading from... forward.
        if (cdb_in.valid && cdb_in.rob_tag == src1_rob_idx) begin
            src1_ready = 1'b1;
            src1_value = cdb_in.value;
        end
        if (cdb_in.valid && cdb_in.rob_tag == src2_rob_idx) begin
            src2_ready = 1'b1;
            src2_value = cdb_in.value;
        end
    end

    assign alloc_rob_idx = tail;

    always_comb begin
        head_entry = '0;
        if (count != '0) begin
            head_entry = rob_entries[head];
        end

        head_can_commit     = (count != '0) && head_entry.valid && head_entry.ready;
        do_alloc            = alloc_valid && ((count != ROB_DEPTH) || head_can_commit);

        commit_valid        = head_can_commit;
        commit_data         = head_entry;

        commit_reg_en       = head_can_commit && head_entry.alloc_has_dest &&
                              (head_entry.dest_reg != 5'd31);
        commit_reg_addr     = head_entry.dest_reg;
        commit_reg_value    = head_entry.value;
        commit_reg_rob_idx  = head;

        commit_nzcv_en      = head_can_commit && head_entry.update_nzcv;
        commit_nzcv_value   = head_entry.nzcv;
        commit_nzcv_rob_idx = head;

        // TODO: need to amek sure we handle bp and lsq stuff. 
        lsq_store_commit    = 1'b0;
        lsq_store_addr      = '0;
        lsq_store_data      = '0;

        bp_update_valid     = 1'b0;
        bp_update_pc        = '0;
        bp_update_taken     = 1'b0;
        bp_update_target    = '0;

        flush               = 1'b0;
        flush_target_pc     = '0;
        exception_valid     = 1'b0;
        exception_pc        = '0;
        exception_code      = '0;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head  <= '0;
            tail  <= '0;
            count <= '0;
            for (int i = 0; i < ROB_DEPTH; i++) begin
                rob_entries[i] <= '0;
            end
        end else begin
            // Commit oldest ready head entry first.
            // (dispatch will still be able to read this entry because its comb )
            if (head_can_commit) begin
                head <= head + 1'b1;
            end

            // cdb writeback update (after commit, before alloc)
            if (cdb_in.valid) begin
                rob_entries[cdb_in.rob_tag].ready     <= 1'b1;
                rob_entries[cdb_in.rob_tag].value     <= cdb_in.value;
                rob_entries[cdb_in.rob_tag].update_nzcv <= cdb_in.update_nzcv;
                rob_entries[cdb_in.rob_tag].nzcv      <= cdb_in.nzcv;
                rob_entries[cdb_in.rob_tag].exc       <= cdb_in.exc;
                rob_entries[cdb_in.rob_tag].exc_code  <= cdb_in.exc_code[3:0];
                if (cdb_in.br_valid) begin // branch stuff if branch
                    rob_entries[cdb_in.rob_tag].br_taken  <= cdb_in.br_taken;
                    rob_entries[cdb_in.rob_tag].br_target <= cdb_in.br_target;
                end
            end

            // dispatch writes after CDB
            if (do_alloc) begin
                rob_entries[tail] <= alloc_data;
                rob_entries[tail].valid <= 1'b1;
                rob_entries[tail].alloc_has_dest <= alloc_has_dest;
                tail <= tail + 1'b1;  
            end

            if (head_can_commit && !do_alloc) begin
                count <= count - 1'b1;
            end else if (!head_can_commit && do_alloc) begin
                count <= count + 1'b1;
            end

        end
    end

endmodule
