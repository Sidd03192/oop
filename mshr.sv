/*
    states:
        0 - Empty
        1 - Pending Resolution
        2 - Pending Eviction Info
        3 - Pending Eviction Ack
*/
module MSHR #(
    parameter PA_WIDTH          = 48,
    parameter BLOCK_SIZE        = 64
)(
    input   logic                           clk_in,
    input   logic                           rst_n,

    // input from superior memory
    input   logic                           miss_in,
    input   logic[PA_WIDTH-1:0]             paddr_in,
    input   logic                           wd_in,    // write/dirty signal
    input   logic                           superior_data_in,
    input   logic                           evict_in,

    // input from inferior memory
    input   logic                           resolve_in,
    input   logic[BLOCK_SIZE*8-1:0]         inferior_data_in,
    input   logic                           eack_in,

    // output for superior memory
    output  logic                           empty_out,
    output  logic                           pending_einfo_out,

    // output for inferior memory
    output  logic                           pending_resolution_out,
    output  logic                           pending_eack_out,
    output  logic[PA_WIDTH-1:0]             paddr_out,
    output  logic                           wd_out,

    // output for both memory systems
    output  logic[BLOCK_SIZE*8-1:0]         data_out
);
    logic[1:0]              state;
    
    always_ff @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            empty_out <= 1
            pending_resolution_out <= 0
            pending_einfo_out <= 0;
            pending_eack_out <= 0;
            wd_out <= 0;
            data_out <= 0;
        end else if (state == 0) begin
            if (miss_in) begin
                state <= 1;
                empty_out <= 0;
                pending_resolution_out <= 1;
                paddr_out <= paddr_in;
                wd_out <= wd_in;
                data_out <= superior_data_in;
            end
        end else if (state == 1) begin
            if (resolve_in) begin
                state <= 2;
                pending_resolution_out <= 0;
                pending_einfo_out <= 1;
                data_out <= inferior_data_in;
             end
        end else if (state == 2) begin
            if (evict_in) begin
                pending_einfo_out <= 0;
                paddr_out <= paddr_in;
                wd_out <= wd_in;
                if (wd_in) begin
                    state <= 3;
                    data_out <= superior_data_in;
                    pending_eack_out <= 1;
                end else begin
                    state <= 0;
                    empty_out <= 1;
                end
            end
        end else if (state == 3) begin
            if (eack_in) begin
                state <= 0;
                pending_eack_out <= 1;
                empty_out <= 0;
            end
        end
    end

endmodule