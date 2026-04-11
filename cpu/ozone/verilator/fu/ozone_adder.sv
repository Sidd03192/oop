// input assumptions are commented in 






module ozone_rs_adder
  import ozone_pkg::*;
#(
  parameter DEPTH = 4
)(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  // --- dispatch allocates an entry ---
  input  logic        alloc_valid,
  input  rs_entry_add_t alloc_entry,
  // ---- RS full to dispatch ---
  output logic        full,

  // --- CDB snoop --- TODO: may update based on how we do cdb
  input  cdb_broadcast_t  cdb_in,

  // --- CDB broadcast out ---
  output cdb_broadcast_t cdb_out,
  input  logic        cdb_granted       // if cdb accepted :)
);

  // RS entries
  rs_entry_add_t entries [0:DEPTH-1];

  // set RS full.
  always_comb begin
    full = 1'b1;
    for (int i = 0; i < DEPTH; i++)
      if (!entries[i].valid) full = 1'b0;
  end

  // -------------------------------------------------------
  // Holds Results if CDB not ready
  // -------------------------------------------------------
  cdb_broadcast_t result;

  // only accept new value when output register free.

  //TODO: try to optimize but combinationally selecting this ? so we dont unecessarily stall.
  logic fu_ready;
  assign fu_ready = !result.valid;

  // -------------------------------------------------------
  // Next thing logic
  // -------------------------------------------------------
  logic       issue_valid;
  rs_entry_add_t issue_entry;

  // Look through RS for next thing to compute if things are not done. RS tags cant be 0 
  always_comb begin
    issue_valid = 1'b0;
    issue_entry = '0;
    for (int i = 0; i < DEPTH; i++) begin
      if (entries[i].valid &&
          entries[i].Qj == '0 &&
          entries[i].Qk == '0 &&
          fu_ready) begin
        // oldest first
        if (!issue_valid ||
            entries[i].rob_tag < issue_entry.rob_tag) begin
          issue_valid = 1'b1;
          issue_entry = entries[i];
        end
      end
    end
  end

  // -------------------------------------------------------
  // Adder
  // -------------------------------------------------------
  logic [63:0] add_result;
  logic [3:0]  add_nzcv;
  logic        add_flags_valid;
  logic        add_br_valid;
  logic        add_br_taken;
  logic [63:0] add_br_target;

  // Extended results for carry detection
  logic [64:0] add_result_ext;  // 65-bit for carry out
  logic [64:0] sub_result_ext;

  // Intermediate signals for flag computation
  logic add_carry, add_overflow;
  logic sub_carry, sub_overflow;

  always_comb begin
    // Compute extended results for carry detection
    // ADD: C = carry out of bit 63
    add_result_ext = {1'b0, issue_entry.Vj} + {1'b0, issue_entry.Vk};
    add_carry      = add_result_ext[64];
    // ADD overflow: sign(Vj) == sign(Vk) && sign(result) != sign(Vj)
    add_overflow   = (issue_entry.Vj[63] == issue_entry.Vk[63]) &&
                     (add_result_ext[63] != issue_entry.Vj[63]);

    // SUB: C = NOT borrow = (Vj >= Vk) unsigned
    // Implemented as Vj + (~Vk) + 1, carry out means no borrow
    sub_result_ext = {1'b0, issue_entry.Vj} + {1'b0, ~issue_entry.Vk} + 65'd1;
    sub_carry      = sub_result_ext[64];
    // SUB overflow: sign(Vj) != sign(Vk) && sign(result) != sign(Vj)
    sub_overflow   = (issue_entry.Vj[63] != issue_entry.Vk[63]) &&
                     (sub_result_ext[63] != issue_entry.Vj[63]);

    // Default outputs
    add_result      = issue_entry.Vj + issue_entry.Vk;
    add_flags_valid = 1'b0;
    add_nzcv        = 4'b0;
    add_br_valid    = 1'b0;
    add_br_taken    = 1'b0;
    add_br_target   = '0;

    case (issue_entry.op)
      OP_ADD: begin
        add_result = issue_entry.Vj + issue_entry.Vk;
      end

      // add and set nzcv
      OP_ADDS: begin
        add_result      = add_result_ext[63:0];
        add_flags_valid = 1'b1;
        add_nzcv[3]     = add_result[63];           // N
        add_nzcv[2]     = (add_result == 64'b0);    // Z
        add_nzcv[1]     = add_carry;                // C
        add_nzcv[0]     = add_overflow;             // V
      end

      OP_SUB: begin
        add_result = issue_entry.Vj - issue_entry.Vk;
      end

      OP_SUBS: begin
        add_result      = sub_result_ext[63:0];
        add_flags_valid = 1'b1;
        add_nzcv[3]     = add_result[63];           // N
        add_nzcv[2]     = (add_result == 64'b0);    // Z
        add_nzcv[1]     = sub_carry;                // C (no borrow)
        add_nzcv[0]     = sub_overflow;             // V
      end

      // compare — no dest value, just flags (same as SUBS)
      OP_CMP: begin
        add_result      = sub_result_ext[63:0];
        add_flags_valid = 1'b1;
        add_nzcv[3]     = add_result[63];           // N
        add_nzcv[2]     = (add_result == 64'b0);    // Z
        add_nzcv[1]     = sub_carry;                // C
        add_nzcv[0]     = sub_overflow;             // V
      end

      // compare negative — flags only (same as ADDS)
      OP_CMN: begin
        add_result      = add_result_ext[63:0];
        add_flags_valid = 1'b1;
        add_nzcv[3]     = add_result[63];           // N
        add_nzcv[2]     = (add_result == 64'b0);    // Z
        add_nzcv[1]     = add_carry;                // C
        add_nzcv[0]     = add_overflow;             // V
      end

      // ADRP ADD portion: Vj = (PC & ~0xFFF), Vk = (imm << 12)
      // The AND is done by the logic unit; we just add here
      OP_ADRP_ADD: begin
        add_result = issue_entry.Vj + issue_entry.Vk;
      end

      // unconditional branch (Vj = branch PC, Vk = branch offset)
      OP_B: begin
        add_br_valid  = 1'b1;
        add_br_taken  = 1'b1;
        add_br_target = issue_entry.Vj + issue_entry.Vk;
      end

      // branch and link (Vj = PC, Vk = branch offset)
      OP_BL: begin // no result. TODO: branches no result remember
        add_br_valid  = 1'b1;
        add_br_taken  = 1'b1;
        add_br_target = issue_entry.Vj + issue_entry.Vk;
      end

      OP_BCOND: begin
        // NZCV bit positions: [3]=N, [2]=Z, [1]=C, [0]=V
        add_br_valid  = 1'b1;
        case (issue_entry.branch_cond)
          COND_EQ: add_br_taken = issue_entry.nzcv[2];                                      // Z == 1
          COND_NE: add_br_taken = !issue_entry.nzcv[2];                                     // Z == 0
          COND_CS: add_br_taken = issue_entry.nzcv[1];                                      // C == 1 (HS)
          COND_CC: add_br_taken = !issue_entry.nzcv[1];                                     // C == 0 (LO)
          COND_MI: add_br_taken = issue_entry.nzcv[3];                                      // N == 1
          COND_PL: add_br_taken = !issue_entry.nzcv[3];                                     // N == 0
          COND_VS: add_br_taken = issue_entry.nzcv[0];                                      // V == 1
          COND_VC: add_br_taken = !issue_entry.nzcv[0];                                     // V == 0
          COND_HI: add_br_taken = issue_entry.nzcv[1] && !issue_entry.nzcv[2];              // C == 1 && Z == 0
          COND_LS: add_br_taken = !issue_entry.nzcv[1] || issue_entry.nzcv[2];              // C == 0 || Z == 1
          COND_GE: add_br_taken = (issue_entry.nzcv[3] == issue_entry.nzcv[0]);             // N == V
          COND_LT: add_br_taken = (issue_entry.nzcv[3] != issue_entry.nzcv[0]);             // N != V
          COND_GT: add_br_taken = !issue_entry.nzcv[2] &&
                                  (issue_entry.nzcv[3] == issue_entry.nzcv[0]);             // Z == 0 && N == V
          COND_LE: add_br_taken = issue_entry.nzcv[2] ||
                                  (issue_entry.nzcv[3] != issue_entry.nzcv[0]);             // Z == 1 || N != V
          COND_AL: add_br_taken = 1'b1;                                                     // always
          COND_NV: add_br_taken = 1'b1;                                                     // always (NV behaves like AL)
          default: add_br_taken = 1'b0;
        endcase
        add_br_target = issue_entry.Vj + issue_entry.Vk; // target = PC + offset
      end

      default: begin
        add_result = issue_entry.Vj + issue_entry.Vk;
      end

    endcase
  end

  // -------------------------------------------------------
  // Sequential logic — RS management + result register
  // -------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      for (int i = 0; i < DEPTH; i++)
        entries[i].valid <= 1'b0;
      result <= '0;

    end else begin

      // --- CDB snoop ---
      if (cdb_in.valid) begin
        for (int i = 0; i < DEPTH; i++) begin
          if (entries[i].valid) begin
            if (entries[i].Qj != '0 &&
                entries[i].Qj == cdb_in.rob_tag) begin
                  // if this is a B.cond, we need to update the condition flags instead of the value
              if (entries[i].op == OP_BCOND) begin
                if (cdb_in.update_nzcv) begin
                  entries[i].nzcv <= cdb_in.nzcv;
                  entries[i].Qj   <= '0;
                end
              end else begin
                entries[i].Vj <= cdb_in.value;
                entries[i].Qj <= '0;
              end
            end
            if (entries[i].Qk != '0 &&
                entries[i].Qk == cdb_in.rob_tag) begin
              entries[i].Vk <= cdb_in.value;
              entries[i].Qk <= '0;
            end
          end
        end
      end

      // --- alloc new entry from dispatch ---
      if (alloc_valid && !full) begin
        for (int i = 0; i < DEPTH; i++) begin
          if (!entries[i].valid) begin
            entries[i]       <= alloc_entry;
            entries[i].valid <= 1'b1;
            break;
          end
        end
      end

      // --- issue + compute ---
      // if we have a ready entry AND result register is empty
      if (issue_valid && fu_ready) begin
        // clear the issued entry
        for (int i = 0; i < DEPTH; i++) begin
          if (entries[i].valid    &&
              entries[i].Qj == '0 &&
              entries[i].Qk == '0 &&
              entries[i].rob_tag == issue_entry.rob_tag) begin
            entries[i].valid <= 1'b0;
            break;
          end
        end

        // connect result wires
        result.valid       <= 1'b1;
        result.rob_tag     <= issue_entry.rob_tag;
        result.value       <= add_result;
        result.update_nzcv <= add_flags_valid;
        result.nzcv        <= add_nzcv;
        result.br_valid    <= add_br_valid;
        result.br_taken    <= add_br_taken;
        result.br_target   <= add_br_target;
        result.exc         <= 1'b0;
        result.exc_code    <= '0;
      end

      // --- CDB granted this cycle ---
      // clear result register so we can accept next issue
      if (result.valid && cdb_granted)
        result.valid <= 1'b0;

    end
  end

  // -------------------------------------------------------
  // CDB request outputs — directly from result register
  // -------------------------------------------------------
  assign cdb_out = result;

endmodule
