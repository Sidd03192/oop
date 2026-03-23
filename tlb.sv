module tlb (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        is_tlb_fill,
    input  logic [47:0] vaddr,
    input  logic [29:0] paddr,
    input  logic        start,

    output logic        ready, // ready out
    output logic        valid, // tells l1 if we have an output. 
    output logic [29:0] result_paddr
);

    logic [54:0] ways [16];
    logic [15:0] lrumat [16];
    logic [3:0]  hit_index;
    logic [3:0]  free_index;
    logic        hit_found;
    logic        free_found;
    logic        lookup_pending_valid;
    logic [29:0] lookup_pending_paddr;

    always_comb begin
        free_index = 4'b0;  // Default
        hit_index =  4'b0;
        hit_found =  1'b0;
        free_found =  1'b0;
        
        for (int i = 0; i < 16; i++) begin
            if (!hit_found && ways[i][54] && (ways[i][35:0] == vaddr[47:12])) begin
                hit_found = 1'b1;
                hit_index = i[3:0];
            end
            if (!free_found && (lrumat[i] == 16'b0)) begin
                free_found = 1'b1;
                free_index = i[3:0];
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            // Hit-only, one-cycle-latency model: TLB stays ready and returns
            // lookup results on the following cycle.
            ready <= 1'b1;
            valid <= 1'b0;
            result_paddr <= '0;
            lookup_pending_valid <= 1'b0;
            lookup_pending_paddr <= '0;
            for (int i = 0; i < 16; i++) begin
                ways[i] <= '0;
                lrumat[i] <= '0;
            end
        end else begin
            ready <= 1'b1;
            valid <= lookup_pending_valid;
            if (lookup_pending_valid) begin
                result_paddr <= lookup_pending_paddr;
            end

            lookup_pending_valid <= 1'b0;

            if (start && is_tlb_fill) begin
                // [v, paddr_tag, vaddr_tag], vaddr contains index and block
                ways[free_index] <= {1'b1, paddr[29:12], vaddr[47:12]};
                // update lrumat 
                lrumat[free_index] <= {16{1'b1}};
                for (int j = 0 ; j < 16; j++) begin
                    lrumat[j][free_index] <= 1'b0;
                end
            end else if (start) begin
                lookup_pending_valid <= hit_found;
                lookup_pending_paddr <= {ways[hit_index][53:36], vaddr[11:0]};

                if (hit_found) begin
                    // update lrumat 
                    lrumat[hit_index] <= {16{1'b1}};
                    for (int j = 0; j < 16; j++) begin
                        lrumat[j][hit_index] <= 1'b0;
                    end
                end
            end
        end
    end
endmodule
