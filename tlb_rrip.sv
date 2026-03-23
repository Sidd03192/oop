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
    logic [1:0]  rripmat [16];
    logic [1:0]  rrip_out [16];
    logic [3:0]  hit_index;
    logic [3:0]  free_index;
    logic        hit_found;
    logic        free_found;

    always_comb begin
        logic [1:0] rrip_temp [16];
        free_index = 4'b0;  // Default
        hit_index =  4'b0;
        hit_found =  1'b0;
        free_found =  1'b0;

        
        for (int i = 0; i < 16; i++) begin
            rrip_temp[i] = rripmat[i];
        end
        
        for (int i = 0; i < 16; i++) begin
            if (!hit_found && ways[i][54] && (ways[i][35:0] == vaddr[47:12])) begin
                hit_found = 1'b1;
                hit_index = i[3:0];
            end
            if (!free_found && (rrip_temp[i] == 2'b11)) begin
                free_found = 1'b1;
                free_index = i[3:0];
            end
        end

        // If didn't find, increment all rrip and search again
        if (!free_found) begin
            for (int i = 0; i < 16; i++) begin
                rrip_temp[i] = rrip_temp[i] + 1;
            end

            for (int i = 0; i < 16; i++) begin
                if (!free_found && (rrip_temp[i] == 2'b11)) begin
                    free_found = 1'b1;
                    free_index = i[3:0];
                end
            end
        end

        if (!free_found) begin
            for (int i = 0; i < 16; i++) begin
                rrip_temp[i] = rrip_temp[i] + 1;
            end

            for (int i = 0; i < 16; i++) begin
                if (!free_found && (rrip_temp[i] == 2'b11)) begin
                    free_found = 1'b1;
                    free_index = i[3:0];
                end
            end
        end

        // Worst case, if all lines were "0", this should set them all to 3 and find a line to evict
        if (!free_found) begin
            for (int i = 0; i < 16; i++) begin
                rrip_temp[i] = rrip_temp[i] + 1;
            end

            for (int i = 0; i < 16; i++) begin
                if (!free_found && (rrip_temp[i] == 2'b11)) begin
                    free_found = 1'b1;
                    free_index = i[3:0];
                end
            end
        end

        for (int i = 0; i < 16; i++) begin
            rrip_out[i] = rrip_temp[i];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            // clear array and set everything to :(
            ready <= 1;
            valid <= 0;
            for (int i = 0; i < 16; i++) begin
                ways[i] <= '0;
                rripmat[i] <= '1;
            end
        end else if (start) begin
            ready <= 0;
            if (is_tlb_fill) begin
                // [v, paddr_tag, vaddr_tag], vaddr contains index and block
                ways[free_index] <= {1'b1, paddr[29:12], vaddr[47:12]};

                // update rripmat, adding line so set to 3
                for (int i = 0; i < 16; i++) begin
                    rripmat[i] <= rrip_out[i];
                end
                rripmat[free_index] <= {2'b11};
                
            end else begin
                // tlb index
                // Check valid bit and if the virtual addresses match (in always)
                if (hit_found) begin
                    result_paddr <= {ways[hit_index][53:36], vaddr[11:0]};
                    
                    // update rripmat, hit a line so set to 0 
                    rripmat[hit_index] <= {2'b00};
                end
            end
    
            valid <= ~is_tlb_fill; // tell l1 if we have an output
        end else begin
            ready <= 1;
            valid <= 0;
        end
    end
endmodule

