// `timescale 1ns/1ps
// Instruction TLB: 16-entry fully-associative VA->PA translation for fetch,
// miss detection, and page-table refill interface.
module ozone_itlb
#(
    parameter VA_BITS = 48,
    parameter VPN_BITS = VA_BITS - 12,
    parameter PA_BITS = 30,
    parameter PPN_BITS = PA_BITS - 12,
    parameter NUM_ENTRIES = 16,
    parameter LOG2_NUM_ENTRIES = $clog2(NUM_ENTRIES)
)
(
    input logic clk_i,
    input logic rst_ni, // active low
    
    input logic lookup_req_i,
    input logic [VA_BITS-1:0] lookup_vaddr_i,

    output logic lookup_hit_o, // registered
    output logic [PA_BITS-1:0] lookup_paddr_o,

    input logic fill_req_i,
    input logic [VPN_BITS-1:0] fill_vpn_i,
    input logic [PPN_BITS-1:0] fill_ppn_i,

    input logic flush_all_i,

    output logic lookup_ack_o,
    output logic fill_ack_o, // sign
    output logic flush_ack_o
);

    typedef struct packed {
        logic valid;
        logic [VPN_BITS-1:0] vpn;
        logic [PPN_BITS-1:0] ppn;
    } tlb_entry_t;

    tlb_entry_t entries[NUM_ENTRIES];
    logic [LOG2_NUM_ENTRIES-1:0] clock_hand;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            for (int j = 0; j < NUM_ENTRIES; j++) begin
                entries[j].valid <= 0;
            end

            clock_hand <= '0;
        end else begin
            if (fill_ack_o) begin
                entries[clock_hand].valid <= 1;
                entries[clock_hand].vpn <= fill_vpn_i;
                entries[clock_hand].ppn <= fill_ppn_i;
                clock_hand <= clock_hand + 1;
            end

            if (flush_ack_o) begin
                for (int j = 0; j < NUM_ENTRIES; j++) begin
                    entries[j].valid <= 0;
                end
            end
        end
    end

    always_comb begin
        logic [LOG2_NUM_ENTRIES-1:0] index;
        logic valid;

        valid = 0;
        index = 0;

        flush_ack_o = flush_all_i;
        lookup_ack_o = !flush_all_i && lookup_req_i;
        fill_ack_o = !flush_all_i && !lookup_req_i && fill_req_i;

        lookup_hit_o = 1'b0;
        lookup_paddr_o = '0;

        if (lookup_ack_o) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                if (entries[i].valid && entries[i].vpn == lookup_vaddr_i[VA_BITS-1:VA_BITS-VPN_BITS]) begin
                    index = (LOG2_NUM_ENTRIES)'(i);
                    valid = 1;
                end
            end

            if (valid) begin
                lookup_hit_o = 1;
                lookup_paddr_o = {entries[index].ppn, lookup_vaddr_i[VA_BITS-VPN_BITS-1:0]};
            end else begin
                lookup_hit_o = 0;
            end
        end

    end
endmodule
