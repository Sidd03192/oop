module mainmem #(
    parameter PA_WIDTH                  = 30,
    parameter MEM_CAPAITY               = 1073741824, // 2**30,
    parameter BLOCK_SIZE                = 64
)(
    input   logic                       clk,
    input   logic                       rst_n,

    input   logic                       start_in,
    input   logic                       paddr_in,
    input   logic                       w_in,
    input   logic                       data_in,

    output  logic                       processing_out,
    output  logic                       ready_out,
    output  logic                       data_out
);

    logic data[MEM_CAPACITY*8-1:0]      mem;

    always_ff @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            mem <= '0;
        end else if (!processing_out) begin
            if (start_in) begin
                processing_out = 1;
                if (w_in) begin
                    mem[(paddr_in + BLOCK_SIZE)*8-1:paddr_in*8] = data_in;
                end else begin
                    data_out = mem[(paddr_in + BLOCK_SIZE)*8-1:paddr_in*8];
                    ready_out = 1;
                end
                processing_out = 0;
            end
        end else if (ready_out) begin
            read_out = 0;
        end
    end      


endmodule