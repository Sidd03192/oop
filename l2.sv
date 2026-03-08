module l2_cache #(
    parameter L2_CAPACITY   = 4096,
    parameter L2_WAYS       = 4,
    parameter BLOCK_SIZE    = 64,
    parameter L1_MSHRS      = 2,
    parameter L2_MSHRS      = 4,
    parameter PA_WIDTH      = 30,
    parameter DATA_WIDTH    = 64,
    parameter TAG_SIZE      = 20
)(
    input   logic                        clk,
    input   logic                        rst_n,

    // input from superior MSHRS
    input   logic                           pending_res_in[L1_MSHRS],
    input   logic                           pending_eack_in[L1_MSHRS],
    input   logic[PA_WIDTH-1:0]             paddr_in,[L1_MSHRS],
    input   logic                           wd_in[L1_MSHRS],
    input   logic[BLOCK_SIZE*8-1:0]         data_in[L1_MSHRS],


    // output to superior MSHRS
    output  logic                           resolve_out[L1_MSHRS],
    output  logic[BLOCK_SIZE*8-1:0]         superior_data_out[L1_MSHRS],
    output  logic                           eack_out[L1_MSHRS]
);



endmodule