// Notes for dispatychg
// In the same cycle, dispatch sends read addresses here and immediately gets back status *busy or not )
// Then dispatch immediately will decide vj vk qj qk
// Looks at ROB
// then it will drive wires for updating an entry (marking it busy)
// the above change will then take place on teh next clock cycle start.
//TODO: need to handle writing to x31 (return address register)




module ozone_regstate
  import ozone_pkg::*;
(
  input  logic                      clk,
  input  logic                      rst_n,
  input  logic                      flush,

  // dispatch will give registers it wants info for 
  input  logic [4:0]                src1_addr,      
  input  logic [4:0]                src2_addr,
  // we give output of those registers. -> combinationally 
  output reg_entry_t                src1_status,
  output reg_entry_t                src2_status,
  output reg_entry_t                nzcv_status,

  // Dispatch updats (we make a entry )
  input  logic                      disp_wr_en,
  input  logic [4:0]                disp_wr_addr,   // dest register
  input  logic [ROB_IDX_WIDTH-1:0]  disp_rob_idx,   // ROB tail
  // same rob entry can also update nczv
  input  logic                      disp_nzcv_wr_en, // if instruction updates nzcv
  input  logic [ROB_IDX_WIDTH-1:0]  disp_nzcv_rob_idx, // this is what updates nzcv now

  // rob comit
  input  logic                      commit_en, // if rob is even comitting
  input  logic [4:0]                commit_addr,
  input  logic [63:0]               commit_value,
  input  logic [ROB_IDX_WIDTH-1:0]  commit_rob_idx,
  input  logic                      commit_nzcv_en,
  input  logic [3:0]                commit_nzcv_value,
  input  logic [ROB_IDX_WIDTH-1:0]  commit_nzcv_rob_idx
);

  // actual regiters 
  reg_entry_t gp_reg [0:30];
  reg_entry_t nzcv_reg;


  // output status wires (if valid / not)
  always_comb begin
    // TODO: need to handle writing to 31 (return address register) 
    src1_status = gp_reg[src1_addr];
    src2_status = gp_reg[src2_addr];
    nzcv_status = nzcv_reg;
  end

 
  // Sequential logic
  // Priority/order within a cycle:
  // 1. reset/flush clears busy bits
  // 2. commit updates the architectural value and clears busy for the
  //    matching retiring ROB writer
  // 3. dispatch marks new destinations busy with new ROB tag
  // Dispatch comes after commit so a same-cycle commit+dispatch to the same
  // architectural destination leaves that entry busy for the newer writer.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset architectural state.
      for (int i = 0; i < 31; i++) begin
        gp_reg[i].value   <= 64'b0;
        gp_reg[i].busy    <= 1'b0;
        gp_reg[i].rob_idx <= {ROB_IDX_WIDTH{1'b0}};
      end
      nzcv_reg.value   <= 64'b0;
      nzcv_reg.busy    <= 1'b0;
      nzcv_reg.rob_idx <= {ROB_IDX_WIDTH{1'b0}};
    end else if (flush) begin
      // Flush only kills speculative rename state; committed architectural
      // values must remain intact.
      for (int i = 0; i < 31; i++) begin
        gp_reg[i].busy    <= 1'b0;
        gp_reg[i].rob_idx <= {ROB_IDX_WIDTH{1'b0}};
      end
      nzcv_reg.busy    <= 1'b0;
      nzcv_reg.rob_idx <= {ROB_IDX_WIDTH{1'b0}};
    end else begin
      // --- Commit updates and clears the retiring RST entry ---
      if (commit_en && commit_addr != 5'd31) begin
        // only clear if rob entry is same
        if (gp_reg[commit_addr].rob_idx == commit_rob_idx) begin
          gp_reg[commit_addr].value <= commit_value;
          gp_reg[commit_addr].busy <= 1'b0;
        end
      end
      if (commit_nzcv_en) begin
        if (nzcv_reg.rob_idx == commit_nzcv_rob_idx) begin
          nzcv_reg.value <= {60'b0, commit_nzcv_value};
          nzcv_reg.busy <= 1'b0;
        end
      end

      // dispatch write
      if (disp_wr_en && disp_wr_addr != 5'd31) begin
        gp_reg[disp_wr_addr].busy    <= 1'b1;
        gp_reg[disp_wr_addr].rob_idx <= disp_rob_idx;
      end
      if (disp_nzcv_wr_en) begin
        nzcv_reg.busy    <= 1'b1;
        nzcv_reg.rob_idx <= disp_nzcv_rob_idx;
      end
    end
  end

endmodule
