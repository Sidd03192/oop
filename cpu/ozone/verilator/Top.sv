module Top (
    input clk,
    input reset,

    // Simple Memory Interface
    output reg [63:0] mem_addr,
    input      [31:0] mem_rdata,
    output reg        mem_en,

    // Status
    output reg        done,

    // Register File (Exposed for testbench to copy to SHM)
    output reg [63:0] x_regs [0:30]
);

    reg [31:0] state;
    reg [47:0] pc;
    reg [29:0] pa_pc;

    reg [17:0] ttbr0;

    logic [63:0] tte;
    logic [31:0] insn_bits;

    logic        itlb_lookup_req;
    logic [47:0] itlb_vaddr;
    logic        itlb_hit;
    logic [29:0] itlb_paddr;
    logic        itlb_fill_req;
    logic [35:0] itlb_fill_vpn;
    logic [17:0] itlb_fill_ppn;
    logic        itlb_flush;
    logic        itlb_lookup_ack_o;
    logic        itlb_fill_ack_o;
    logic        itlb_flush_ack_o;

    logic halt_fetch;
    
    ozone_itlb ozone_itlb (
        .clk_i         (clk),
        .rst_ni        (~reset),
        .lookup_req_i  (itlb_lookup_req),
        .lookup_vaddr_i(itlb_vaddr),
        .lookup_hit_o  (itlb_hit),
        .lookup_paddr_o(itlb_paddr),
        .fill_req_i    (itlb_fill_req),
        .fill_vpn_i    (itlb_fill_vpn),
        .fill_ppn_i    (itlb_fill_ppn),
        .flush_all_i   (itlb_flush),
        .lookup_ack_o  (itlb_lookup_ack_o),
        .fill_ack_o    (itlb_fill_ack_o),
        .flush_ack_o   (itlb_flush_ack_o)
    );

    always @(posedge clk) begin
        if (reset) begin
            state <= 0;
            done <= 0;
            pc <= 48'h20000000; // Default reset vector
            mem_en <= 0;
            for (int i=0; i<31; i++) x_regs[i] <= 0;

            $display("Did reset!\n");
        end else if (!done) begin
            case (state)
                0: begin
                    if (!halt_fetch) begin
                        itlb_lookup_req <= 1;
                        itlb_vaddr <= pc;
                        state <= 1;
                    end
                end

                1: begin
                    if (itlb_lookup_ack_o) begin
                        itlb_lookup_req <= 0;
                        if (itlb_hit) begin
                            pa_pc <= itlb_paddr;
                            state <= 5;
                        end else begin
                            // PT lookup.
                            // TODO: Check bounds, handle page fault.
                            logic [35:0] pc_vpn;
                            logic [29:0] entry_addr;
                            logic [29:0] ind;

                            pc_vpn = pc[47:12];

                            // TODO: Check bounds here.
                            ind = pc_vpn[29:0];

                            // Are the entries 8 or 4 bytes?
                            entry_addr = {ttbr0, 12'b0} + (ind << 3);

                            mem_addr <= {34'b0, entry_addr};
                            mem_en <= 1;
                            state <= 2;
                        end
                    end
                end

                2: begin
                    // ITLB miss, read memory (lower 4 bytes of entry)
                    tte[31:0] <= mem_rdata;
                    state <= 3;

                    // CHECK HERE IF THE TTE IS INVALID.
                end

                3: begin
                    // TLB fill, read memory (upper 4 bytes of entry)
                    mem_en <= 0;
                    mem_addr <= mem_addr + 4;
                    tte[63:32] <= mem_rdata;

                    itlb_fill_req <= 1;
                    itlb_fill_ppn <= tte[29:12];
                    itlb_fill_vpn <= pc[47:12];
                end

                4: begin
                    // wait for the fill op
                    if (itlb_fill_ack_o) begin
                        itlb_fill_req <= 0;
                        state <= 0;
                    end
                end

                5: begin
                    // pc translated. read instruction, send to decode and bp.
                    mem_en <= 1;
                    mem_addr <= {34'b0, pa_pc};
                    state <= 6;
                end

                6: begin
                    // wait for address to be read.
                    mem_en <= 0;
                    state <= 7;
                    insn_bits <= mem_rdata;
                end

                7: begin
                    if (halt_fetch) begin
                        // Don't send yet.
                    end else begin
                        // Send to decode.
                    end
                end
                
                /*
                0: begin // Fetch
                    mem_addr <= pc;
                    mem_en <= 1;
                    state <= 1;
                end
                1: begin // Wait for memory
                    state <= 2;
                end
                2: begin // "Execute" (Dummy: just dump and stop)
                    $display("[RTL] Executing at PC 0x%h: Instruction 0x%h", pc, mem_rdata);

                    // Dummy side effects to prove SHM works
                    x_regs[0] <= 64'hCAFEBABE;
                    x_regs[1] <= {32'h0, mem_rdata}; // Copy instruction to X1

                    // If we see 0 (likely end of program or unmapped), stop
                    if (mem_rdata == 0 || pc > 64'h20000100) begin
                        done <= 1;
                    end else begin
                        pc <= pc + 4;
                        state <= 0;
                    end
                end
                */
            endcase
        end
    end

endmodule
