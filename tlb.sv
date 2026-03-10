module tlb (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        is_tlb_fill,
    input  logic [47:0] vaddr,
    input  logic [29:0] paddr,
    input  logic        start,

    output logic        ready, // ready out
    output logic        valid, // tells l1 if we have an output. 
    output logic [29:0] result_paddr,
    output logic        panic_tlb_miss
);

    logic [60:0] ways [16];
    logic [15:0] lrumat [16];
    logic [3:0]  hit_index;
    logic [3:0]  free_index;
    logic        hit_found;
    logic        free_found;

    always_comb begin
        free_index = 4'b0;  // Default
        hit_index =  4'b0;
        hit_found =  1'b0;
        free_found =  1'b0;
        
        for (int i = 0; i < 16; i++) begin
            if (!hit_found && ways[i][60] && (ways[i][35:0] == vaddr[47:12])) begin
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
            // clear array and set everything to :(
            ready <= 1;
            valid <= 0;
            panic_tlb_miss <= 0;
            for (int i = 0; i < 16; i++) begin
                ways[i] <= '0;
                lrumat[i] <= '0;
            end
        end else if (start) begin
            ready <= 0;
            if (is_tlb_fill) begin
                // [v, paddr_tag, vaddr_tag], vaddr contains index and block
                ways[free_index] <= {1'b1, paddr[29:6], vaddr[47:12]};
                // update lrumat 
                lrumat[free_index] <= {16{1'b1}};
                for (int j = 0 ; j < 16; j++) begin
                    lrumat[j][free_index] <= 1'b0;
                end
                
            end else begin
                // tlb index
                // Check valid bit and if the virtual addresses match (in always)
                if (hit_found) begin
                    result_paddr <= {ways[hit_index][59:36], vaddr[5:0]};
                    
                    // update lrumat 
                    lrumat[hit_index] <= {16{1'b1}};
                    for (int j = 0; j < 16; j++) begin
                        lrumat[j][hit_index] <= 1'b0;
                    end

                    panic_tlb_miss <= 1'b0;
                end else begin
                    panic_tlb_miss <= 1'b1;
                end
            end
    
            valid <= ~is_tlb_fill; // tell l1 if we have an output
        end else begin
            ready <= 1;
            valid <= 0;
        end
    end
endmodule

