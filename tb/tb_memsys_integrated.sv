`timescale 1ns/1ps

// Integrated directed testbench for memory_subsystem.
//
// This bench drives the trace port so the full path is exercised:
//   trace -> LSQ -> TLB -> L1 -> L2 -> memory
//
// The checks are cycle-accurate relative to reset release and focus on:
//   1. LSQ issue timing
//   2. TLB lookup timing
//   3. L1 miss allocation timing
//   4. L2 MSHR / memory request timing
//   5. L1 dirty eviction writeback timing into L2
//   6. LSQ RESOLVE-path issue timing
//   7. L2 LRU victim selection observed on mem_req writeback

module tb_memsys_integrated;

    localparam int VA_WIDTH    = 48;
    localparam int PA_WIDTH    = 30;
    localparam int DATA_WIDTH  = 64;
    localparam int BLOCK_SIZE  = 64;
    localparam int TRACE_WIDTH = 121;

    localparam logic [2:0] OP_MEM_LOAD    = 3'd0;
    localparam logic [2:0] OP_MEM_STORE   = 3'd1;
    localparam logic [2:0] OP_MEM_RESOLVE = 3'd2;
    localparam logic [2:0] OP_TLB_FILL    = 3'd4;

    localparam logic [1:0] L1_MS_IDLE       = 2'b00;
    localparam logic [1:0] L1_MS_UNRESOLVED = 2'b01;
    localparam logic [1:0] L1_MS_RESOLVED   = 2'b10;

    localparam logic [1:0] L2_MS_IDLE       = 2'b00;
    localparam logic [1:0] L2_MS_UNRESOLVED = 2'b01;
    localparam logic [1:0] L2_MS_WAIT_MEM   = 2'b10;
    localparam logic [1:0] L2_MS_RESOLVED   = 2'b11;

    localparam logic [PA_WIDTH-1:0] PA_A = {22'h000001, 2'b00, 6'h00};
    localparam logic [PA_WIDTH-1:0] PA_B = {22'h000002, 2'b00, 6'h00};
    localparam logic [PA_WIDTH-1:0] PA_C = {22'h000003, 2'b00, 6'h00};
    localparam logic [PA_WIDTH-1:0] PA_R = {22'h00000A, 2'b10, 6'h00};

    localparam logic [PA_WIDTH-1:0] PA_L2_0   = {20'h00010, 4'h6, 6'h00};
    localparam logic [PA_WIDTH-1:0] PA_L2_1   = {20'h00011, 4'h6, 6'h00};
    localparam logic [PA_WIDTH-1:0] PA_L2_2   = {20'h00012, 4'h6, 6'h00};
    localparam logic [PA_WIDTH-1:0] PA_L2_3   = {20'h00013, 4'h6, 6'h00};
    localparam logic [PA_WIDTH-1:0] PA_L2_NEW = {20'h00014, 4'h6, 6'h00};

    // Same L1 index [7:6] == 2'b00, different VPNs for separate TLB entries.
    localparam logic [VA_WIDTH-1:0] VA_A = 48'h0000_0000_0000;
    localparam logic [VA_WIDTH-1:0] VA_B = 48'h0001_0000_0000;
    localparam logic [VA_WIDTH-1:0] VA_C = 48'h0002_0000_0000;
    localparam logic [VA_WIDTH-1:0] VA_R = 48'h0005_0000_0080;
    localparam logic [VA_WIDTH-1:0] VA_L2_NEW = 48'h0006_0000_0080;

    localparam logic [DATA_WIDTH-1:0] STORE_WORD_A = 64'h1122_3344_5566_7788;

    localparam logic [BLOCK_SIZE*8-1:0] BLOCK_A = {8{64'hAAAA_AAAA_AAAA_AAAA}};
    localparam logic [BLOCK_SIZE*8-1:0] BLOCK_B = {8{64'hBBBB_BBBB_BBBB_BBBB}};
    localparam logic [BLOCK_SIZE*8-1:0] BLOCK_C = {8{64'hCCCC_CCCC_CCCC_CCCC}};
    localparam logic [BLOCK_SIZE*8-1:0] BLOCK_D = {8{64'hDDDD_DDDD_DDDD_DDDD}};
    localparam logic [BLOCK_SIZE*8-1:0] BLOCK_E = {8{64'hEEEE_EEEE_EEEE_EEEE}};
    localparam logic [BLOCK_SIZE*8-1:0] BLOCK_F = {8{64'hF0F0_F0F0_F0F0_F0F0}};
    localparam logic [BLOCK_SIZE*8-1:0] BLOCK_G = {8{64'h0A0A_0A0A_0A0A_0A0A}};
    localparam logic [BLOCK_SIZE*8-1:0] BLOCK_A_DIRTY = {BLOCK_A[BLOCK_SIZE*8-1:64], STORE_WORD_A};

    localparam int L2_SET_A = PA_A[9:6];
    localparam int L2_SET_T4 = PA_L2_NEW[9:6];

    logic                     clk;
    logic                     rst_n;
    logic [TRACE_WIDTH-1:0]   trace_data;
    logic                     trace_valid;
    wire                      trace_ready;
    wire                      mem_req_valid;
    wire                      mem_req_is_write;
    wire [PA_WIDTH-1:0]       mem_req_addr;
    wire [BLOCK_SIZE*8-1:0]   mem_req_wdata;
    logic                     mem_req_ready;
    logic                     mem_resp_valid;
    logic [PA_WIDTH-1:0]      mem_resp_paddr;
    logic [BLOCK_SIZE*8-1:0]  mem_resp_rdata;

    integer pass_cnt;
    integer fail_cnt;
    integer cycle_ctr;

    memory_subsystem dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .trace_data     (trace_data),
        .trace_valid    (trace_valid),
        .trace_ready    (trace_ready),
        .mem_req_valid  (mem_req_valid),
        .mem_req_is_write(mem_req_is_write),
        .mem_req_addr   (mem_req_addr),
        .mem_req_wdata  (mem_req_wdata),
        .mem_req_ready  (mem_req_ready),
        .mem_resp_valid (mem_resp_valid),
        .mem_resp_paddr (mem_resp_paddr),
        .mem_resp_rdata (mem_resp_rdata)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_ctr <= 0;
        else
            cycle_ctr <= cycle_ctr + 1;
    end

    function automatic [TRACE_WIDTH-1:0] make_mem_trace(
        input logic [2:0]        op,
        input logic [3:0]        id,
        input logic [VA_WIDTH-1:0] vaddr,
        input logic              vaddr_valid,
        input logic [DATA_WIDTH-1:0] value,
        input logic              value_valid
    );
        begin
            make_mem_trace = '0;
            make_mem_trace[120]    = value_valid;
            make_mem_trace[119:56] = value;
            make_mem_trace[55]     = vaddr_valid;
            make_mem_trace[54:52]  = op;
            make_mem_trace[51:48]  = id;
            make_mem_trace[47:0]   = vaddr;
        end
    endfunction

    function automatic [TRACE_WIDTH-1:0] make_tlb_fill_trace(
        input logic [VA_WIDTH-1:0] vaddr,
        input logic [PA_WIDTH-1:0] paddr
    );
        begin
            make_tlb_fill_trace = '0;
            make_tlb_fill_trace[85:56] = paddr;
            make_tlb_fill_trace[55]    = 1'b1;
            make_tlb_fill_trace[54:52] = OP_TLB_FILL;
            make_tlb_fill_trace[47:0]  = vaddr;
        end
    endfunction

    function automatic [3:0] l2_index_of(input logic [PA_WIDTH-1:0] paddr);
        begin
            l2_index_of = paddr[9:6];
        end
    endfunction

    function automatic [19:0] l2_tag_of(input logic [PA_WIDTH-1:0] paddr);
        begin
            l2_tag_of = paddr[29:10];
        end
    endfunction

    task automatic chk_bit;
        input [255:0] name;
        input         got;
        input         exp;
        begin
            if (got === exp) begin
                $display("  PASS  %0s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %0s  got=%b exp=%b @cycle=%0d time=%0t", name, got, exp, cycle_ctr, $time);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic chk_state;
        input [255:0] name;
        input [1:0]   got;
        input [1:0]   exp;
        begin
            if (got === exp) begin
                $display("  PASS  %0s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %0s  got=%b exp=%b @cycle=%0d time=%0t", name, got, exp, cycle_ctr, $time);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic chk_pa;
        input [255:0]        name;
        input [PA_WIDTH-1:0] got;
        input [PA_WIDTH-1:0] exp;
        begin
            if (got === exp) begin
                $display("  PASS  %0s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %0s  got=%0h exp=%0h @cycle=%0d time=%0t", name, got, exp, cycle_ctr, $time);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic chk_64;
        input [255:0] name;
        input [63:0]  got;
        input [63:0]  exp;
        begin
            if (got === exp) begin
                $display("  PASS  %0s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %0s  got=%0h exp=%0h @cycle=%0d time=%0t", name, got, exp, cycle_ctr, $time);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic chk_wide;
        input [255:0]            name;
        input [BLOCK_SIZE*8-1:0] got;
        input [BLOCK_SIZE*8-1:0] exp;
        begin
            if (got === exp) begin
                $display("  PASS  %0s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %0s @cycle=%0d time=%0t", name, cycle_ctr, $time);
                $display("         got=%0h", got);
                $display("         exp=%0h", exp);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic chk_cycle;
        input [255:0] name;
        input integer exp;
        begin
            if (cycle_ctr == exp) begin
                $display("  PASS  %0s at cycle %0d", name, exp);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %0s  got cycle %0d exp cycle %0d", name, cycle_ctr, exp);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic idle_inputs;
        begin
            trace_data     = '0;
            trace_valid    = 1'b0;
            mem_req_ready  = 1'b0;
            mem_resp_valid = 1'b0;
            mem_resp_paddr = '0;
            mem_resp_rdata = '0;
        end
    endtask

    task automatic apply_reset;
        begin
            idle_inputs();
            rst_n = 1'b0;
            repeat (2) @(negedge clk);
            rst_n = 1'b1;
            @(posedge clk);
            #1;
        end
    endtask

    task automatic wait_for_cycle;
        input integer target_cycle;
        begin
            while (cycle_ctr < target_cycle) begin
                @(posedge clk);
                #1;
            end
            #1;
        end
    endtask

    task automatic send_trace_at;
        input integer              target_cycle;
        input [TRACE_WIDTH-1:0]    packet;
        input [255:0]              name;
        begin
            wait_for_cycle(target_cycle - 1);
            @(negedge clk);
            if (!trace_ready) begin
                $display("  FAIL  %0s  trace_ready low before scheduled send at cycle %0d", name, target_cycle);
                fail_cnt = fail_cnt + 1;
            end
            trace_data  = packet;
            trace_valid = 1'b1;
            @(negedge clk);
            trace_data  = '0;
            trace_valid = 1'b0;
        end
    endtask

    task automatic accept_mem_at;
        input integer         target_cycle;
        input [PA_WIDTH-1:0]  exp_addr;
        input                 exp_is_write;
        input [255:0]         name;
        begin
            wait_for_cycle(target_cycle - 1);
            @(negedge clk);
            if (!(mem_req_valid && mem_req_addr == exp_addr && mem_req_is_write == exp_is_write)) begin
                $display("  FAIL  %0s  mem_req mismatch before cycle %0d", name, target_cycle);
                $display("         got valid=%b write=%b addr=%0h", mem_req_valid, mem_req_is_write, mem_req_addr);
                $display("         exp valid=1 write=%b addr=%0h", exp_is_write, exp_addr);
                fail_cnt = fail_cnt + 1;
            end
            mem_req_ready = 1'b1;
            @(negedge clk);
            mem_req_ready = 1'b0;
        end
    endtask

    task automatic return_mem_at;
        input integer               target_cycle;
        input [PA_WIDTH-1:0]        paddr;
        input [BLOCK_SIZE*8-1:0]    block;
        begin
            wait_for_cycle(target_cycle - 1);
            @(negedge clk);
            mem_resp_valid = 1'b1;
            mem_resp_paddr = paddr;
            mem_resp_rdata = block;
            @(negedge clk);
            mem_resp_valid = 1'b0;
            mem_resp_paddr = '0;
            mem_resp_rdata = '0;
        end
    endtask

    task automatic preload_l2_line;
        input integer               way;
        input [PA_WIDTH-1:0]        paddr;
        input [BLOCK_SIZE*8-1:0]    block;
        input                       dirty;
        integer set_idx;
        begin
            @(negedge clk);
            set_idx = l2_index_of(paddr);
            dut.u_l2.set_contents[set_idx][way] = block;
            dut.u_l2.tags[set_idx][way]         = l2_tag_of(paddr);
            dut.u_l2.set_valids[set_idx][way]   = 1'b1;
            dut.u_l2.set_dirty[set_idx][way]    = dirty;
        end
    endtask

    task automatic mark_l2_way_mru;
        input integer set_idx;
        input integer way;
        integer k;
        begin
            @(negedge clk);
            for (k = 0; k < 4; k = k + 1) begin
                dut.u_l2.lru_matrix[set_idx][way][k] = 1'b1;
                dut.u_l2.lru_matrix[set_idx][k][way] = 1'b0;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_memsys_integrated.vcd");
        $dumpvars(0, tb_memsys_integrated);

        pass_cnt = 0;
        fail_cnt = 0;
        idle_inputs();
        rst_n = 1'b1;

        $display("\n=== T1: Reset / idle ===");
        apply_reset();
        chk_cycle("T1 first live cycle after reset", 1);
        chk_bit  ("T1 trace_ready high",               trace_ready,                 1'b1);
        chk_state("T1 L1 mshr[0] idle",               dut.u_l1.mshr_state[0],      L1_MS_IDLE);
        chk_state("T1 L2 mshr[0] idle",               dut.u_l2.mshr_state[0],      L2_MS_IDLE);
        chk_bit  ("T1 no memory request",             mem_req_valid,               1'b0);
        chk_bit  ("T1 no writeback pending",          dut.l1_l2_wb_valid,          1'b0);

        // Cycle plan:
        //   2  tlb_fill(A)
        //   4  load(A)
        //   5  LSQ issues A
        //   6  TLB returns PA_A
        //   7  L1 mshr unresolved, l2_req asserted
        //   8  L2 mshr unresolved, mem read request visible
        //   9  accept mem read A
        //  10  return block A
        //  11  L2 captures mem response
        //  12  L2 returns data to L1
        //  13  L1 mshr resolved
        //  14  L1 install complete
        $display("\n=== T2: Cold miss path through LSQ/TLB/L1/L2 ===");
        send_trace_at(2, make_tlb_fill_trace(VA_A, PA_A), "T2 tlb fill A");
        send_trace_at(4, make_mem_trace(OP_MEM_LOAD, 4'd0, VA_A, 1'b1, '0, 1'b0), "T2 load A");

        wait_for_cycle(5);
        chk_cycle("T2 LSQ issues load A", 5);
        chk_bit  ("T2 lsq valid_out high",            dut.u_lsq.valid_out,         1'b1);
        chk_pa   ("T2 lsq issue_vaddr low bits",      dut.u_lsq.issue_vaddr[29:0], VA_A[29:0]);

        wait_for_cycle(6);
        chk_cycle("T2 TLB lookup completes", 6);
        chk_bit  ("T2 tlb valid high",                dut.u_tlb.valid,             1'b1);
        chk_pa   ("T2 tlb result paddr",              dut.u_tlb.result_paddr,      PA_A);

        wait_for_cycle(7);
        chk_cycle("T2 L1 miss allocates MSHR", 7);
        chk_state("T2 L1 mshr[0] unresolved",         dut.u_l1.mshr_state[0],      L1_MS_UNRESOLVED);
        chk_pa   ("T2 L1 mshr[0] paddr",              dut.u_l1.mshr_paddr[0],      PA_A);
        chk_bit  ("T2 l1->l2 req valid",              dut.l1_l2_req_valid,         1'b1);
        chk_pa   ("T2 l1->l2 req paddr",              dut.l1_l2_req_paddr,         PA_A);

        wait_for_cycle(8);
        chk_cycle("T2 L2 allocates MSHR", 8);
        chk_state("T2 L2 mshr[0] unresolved",         dut.u_l2.mshr_state[0],      L2_MS_UNRESOLVED);
        chk_bit  ("T2 mem_req_valid high",            mem_req_valid,               1'b1);
        chk_bit  ("T2 mem_req_is_write low",          mem_req_is_write,            1'b0);
        chk_pa   ("T2 mem_req_addr is PA_A",          mem_req_addr,                PA_A);

        accept_mem_at(9, PA_A, 1'b0, "T2 memory accepts read A");
        wait_for_cycle(9);
        chk_cycle("T2 L2 waits for memory", 9);
        chk_state("T2 L2 mshr[0] wait_mem",           dut.u_l2.mshr_state[0],      L2_MS_WAIT_MEM);

        return_mem_at(10, PA_A, BLOCK_A);
        wait_for_cycle(11);
        chk_cycle("T2 L2 captures memory response", 11);
        chk_state("T2 L2 mshr[0] resolved",           dut.u_l2.mshr_state[0],      L2_MS_RESOLVED);

        wait_for_cycle(12);
        chk_cycle("T2 L2 returns fill to L1", 12);
        chk_bit  ("T2 l2->l1 data_valid",             dut.l2_l1_data_valid,        1'b1);
        chk_pa   ("T2 l2->l1 data_paddr",             dut.l2_l1_data_paddr,        PA_A);
        chk_wide ("T2 l2->l1 block",                  dut.l2_l1_data,              BLOCK_A);
        chk_state("T2 L2 mshr[0] freed",              dut.u_l2.mshr_state[0],      L2_MS_IDLE);

        wait_for_cycle(13);
        chk_cycle("T2 L1 sees returned block", 13);
        chk_state("T2 L1 mshr[0] resolved",           dut.u_l1.mshr_state[0],      L1_MS_RESOLVED);

        wait_for_cycle(14);
        chk_cycle("T2 L1 installs returned block", 14);
        chk_state("T2 L1 mshr[0] idle",               dut.u_l1.mshr_state[0],      L1_MS_IDLE);
        chk_wide ("T2 L1 set0 way0 has block A",      dut.u_l1.set_contents[0][0], BLOCK_A);

        // Cycle plan:
        //  15  store(A)
        //  16  LSQ issues store A
        //  18  store hit updates dirty line in L1
        //  20  tlb_fill(B)
        //  22  load(B)
        //  25  L1 miss B, 26 L2 miss B, 27 accept, 28 return, 32 install B
        //  34  tlb_fill(C)
        //  36  load(C)
        //  39  L1 miss C, 40 L2 miss C, 41 accept, 42 return, 46 install C + wb(A)
        //  47  L2 acknowledges wb(A)
        //  48  L1 wb fifo drains
        $display("\n=== T3: Dirty eviction from L1 into L2 ===");
        send_trace_at(15, make_mem_trace(OP_MEM_STORE, 4'd8, VA_A, 1'b1, STORE_WORD_A, 1'b1), "T3 store A");

        wait_for_cycle(16);
        chk_cycle("T3 LSQ issues store A", 16);
        chk_bit  ("T3 lsq valid_out high for store",  dut.u_lsq.valid_out,         1'b1);
        chk_bit  ("T3 lsq issue_op is store",         dut.u_lsq.issue_op == OP_MEM_STORE, 1'b1);

        wait_for_cycle(18);
        chk_cycle("T3 L1 store hit commits", 18);
        chk_bit  ("T3 L1 line A dirty",               dut.u_l1.set_dirty[0][0],    1'b1);
        chk_64   ("T3 L1 line A word0 updated",       dut.u_l1.set_contents[0][0][63:0], STORE_WORD_A);

        send_trace_at(20, make_tlb_fill_trace(VA_B, PA_B), "T3 tlb fill B");
        send_trace_at(22, make_mem_trace(OP_MEM_LOAD, 4'd1, VA_B, 1'b1, '0, 1'b0), "T3 load B");

        wait_for_cycle(25);
        chk_cycle("T3 L1 allocates miss B", 25);
        chk_state("T3 L1 mshr[0] unresolved for B",   dut.u_l1.mshr_state[0],      L1_MS_UNRESOLVED);
        chk_pa   ("T3 L1 request paddr is B",         dut.l1_l2_req_paddr,         PA_B);

        wait_for_cycle(26);
        chk_cycle("T3 L2 allocates miss B", 26);
        chk_state("T3 L2 mshr[0] unresolved for B",   dut.u_l2.mshr_state[0],      L2_MS_UNRESOLVED);
        chk_pa   ("T3 mem_req for B",                 mem_req_addr,                PA_B);

        accept_mem_at(27, PA_B, 1'b0, "T3 memory accepts read B");
        return_mem_at(28, PA_B, BLOCK_B);

        wait_for_cycle(32);
        chk_cycle("T3 L1 installs B", 32);
        chk_state("T3 L1 mshr[0] idle after B",       dut.u_l1.mshr_state[0],      L1_MS_IDLE);
        chk_wide ("T3 L1 set0 way1 has block B",      dut.u_l1.set_contents[0][1], BLOCK_B);

        send_trace_at(34, make_tlb_fill_trace(VA_C, PA_C), "T3 tlb fill C");
        send_trace_at(36, make_mem_trace(OP_MEM_LOAD, 4'd2, VA_C, 1'b1, '0, 1'b0), "T3 load C");

        wait_for_cycle(39);
        chk_cycle("T3 L1 allocates miss C", 39);
        chk_state("T3 L1 mshr[0] unresolved for C",   dut.u_l1.mshr_state[0],      L1_MS_UNRESOLVED);
        chk_pa   ("T3 L1 request paddr is C",         dut.l1_l2_req_paddr,         PA_C);

        wait_for_cycle(40);
        chk_cycle("T3 L2 allocates miss C", 40);
        chk_state("T3 L2 mshr[0] unresolved for C",   dut.u_l2.mshr_state[0],      L2_MS_UNRESOLVED);
        chk_pa   ("T3 mem_req for C",                 mem_req_addr,                PA_C);

        accept_mem_at(41, PA_C, 1'b0, "T3 memory accepts read C");
        return_mem_at(42, PA_C, BLOCK_C);

        wait_for_cycle(46);
        chk_cycle("T3 L1 installs C and exposes wb(A)", 46);
        chk_state("T3 L1 mshr[0] idle after C",       dut.u_l1.mshr_state[0],      L1_MS_IDLE);
        chk_bit  ("T3 l1->l2 wb_valid high",          dut.l1_l2_wb_valid,          1'b1);
        chk_pa   ("T3 l1->l2 wb paddr is A",          dut.l1_l2_wb_paddr,          PA_A);
        chk_wide ("T3 l1->l2 wb data is dirty A",     dut.l1_l2_wb_data,           BLOCK_A_DIRTY);

        wait_for_cycle(47);
        chk_cycle("T3 L2 accepts wb(A)", 47);
        chk_bit  ("T3 L2 wb ack high",                dut.l2_l1_wb_ack,            1'b1);
        chk_bit  ("T3 no memory write for wb hit",    mem_req_is_write,            1'b0);
        chk_64   ("T3 L2 line A word0 updated",       dut.u_l2.set_contents[L2_SET_A][0][63:0], STORE_WORD_A);
        chk_bit  ("T3 L2 line A dirty",               dut.u_l2.set_dirty[L2_SET_A][0], 1'b1);

        wait_for_cycle(48);
        chk_cycle("T3 L1 wb fifo drains after ack", 48);
        chk_bit  ("T3 l1->l2 wb_valid low",           dut.l1_l2_wb_valid,          1'b0);
        chk_wide ("T3 L1 set0 replacement is C",      dut.u_l1.set_contents[0][0], BLOCK_C);

        // Cycle plan:
        //   2  tlb_fill(R)
        //   4  unresolved load(id=3)
        //   5  no LSQ issue yet
        //   6  resolve(id=3, VA_R)
        //   7  LSQ finally issues
        //   8  TLB lookup completes with PA_R
        $display("\n=== T4: LSQ resolve path only issues after RESOLVE ===");
        apply_reset();
        send_trace_at(2, make_tlb_fill_trace(VA_R, PA_R), "T4 tlb fill R");
        send_trace_at(4, make_mem_trace(OP_MEM_LOAD, 4'd3, '0, 1'b0, '0, 1'b0), "T4 unresolved load");

        wait_for_cycle(5);
        chk_cycle("T4 no issue before resolve", 5);
        chk_bit  ("T4 lsq valid low before resolve", dut.u_lsq.valid_out, 1'b0);
        chk_bit  ("T4 tlb valid low before resolve", dut.u_tlb.valid,     1'b0);

        send_trace_at(6, make_mem_trace(OP_MEM_RESOLVE, 4'd3, VA_R, 1'b1, '0, 1'b0), "T4 resolve load id3");

        wait_for_cycle(7);
        chk_cycle("T4 LSQ issues after resolve", 7);
        chk_bit  ("T4 lsq valid high after resolve", dut.u_lsq.valid_out, 1'b1);
        chk_pa   ("T4 lsq issue_vaddr is VA_R",      dut.u_lsq.issue_vaddr[29:0], VA_R[29:0]);

        wait_for_cycle(8);
        chk_cycle("T4 TLB translates resolved load", 8);
        chk_bit  ("T4 tlb valid high after resolve",    dut.u_tlb.valid,          1'b1);
        chk_pa   ("T4 tlb result is PA_R",              dut.u_tlb.result_paddr,   PA_R);

        // Cycle plan:
        //   2  preload L2 set in one negedge, make way1 the dirty LRU victim
        //   3  tlb_fill(new)
        //   5  load(new)
        //   9  L2 miss advertises mem read
        //  10  accept read
        //  11  return fill
        //  13  L2 installs new line into way1
        //  14  mem_req switches to dirty wb for evicted PA_L2_1
        $display("\n=== T5: L2 LRU replacement drives correct memory writeback ===");
        apply_reset();
        @(negedge clk);
        dut.u_l2.set_contents[L2_SET_T4][0] = BLOCK_B;
        dut.u_l2.tags[L2_SET_T4][0]         = l2_tag_of(PA_L2_0);
        dut.u_l2.set_valids[L2_SET_T4][0]   = 1'b1;
        dut.u_l2.set_dirty[L2_SET_T4][0]    = 1'b0;
        dut.u_l2.set_contents[L2_SET_T4][1] = BLOCK_C;
        dut.u_l2.tags[L2_SET_T4][1]         = l2_tag_of(PA_L2_1);
        dut.u_l2.set_valids[L2_SET_T4][1]   = 1'b1;
        dut.u_l2.set_dirty[L2_SET_T4][1]    = 1'b1;
        dut.u_l2.set_contents[L2_SET_T4][2] = BLOCK_D;
        dut.u_l2.tags[L2_SET_T4][2]         = l2_tag_of(PA_L2_2);
        dut.u_l2.set_valids[L2_SET_T4][2]   = 1'b1;
        dut.u_l2.set_dirty[L2_SET_T4][2]    = 1'b0;
        dut.u_l2.set_contents[L2_SET_T4][3] = BLOCK_E;
        dut.u_l2.tags[L2_SET_T4][3]         = l2_tag_of(PA_L2_3);
        dut.u_l2.set_valids[L2_SET_T4][3]   = 1'b1;
        dut.u_l2.set_dirty[L2_SET_T4][3]    = 1'b0;
        dut.u_l2.lru_matrix[L2_SET_T4][0][0] = 1'b1;
        dut.u_l2.lru_matrix[L2_SET_T4][0][1] = 1'b1;
        dut.u_l2.lru_matrix[L2_SET_T4][0][2] = 1'b0;
        dut.u_l2.lru_matrix[L2_SET_T4][0][3] = 1'b0;
        dut.u_l2.lru_matrix[L2_SET_T4][1][0] = 1'b0;
        dut.u_l2.lru_matrix[L2_SET_T4][1][1] = 1'b0;
        dut.u_l2.lru_matrix[L2_SET_T4][1][2] = 1'b0;
        dut.u_l2.lru_matrix[L2_SET_T4][1][3] = 1'b0;
        dut.u_l2.lru_matrix[L2_SET_T4][2][0] = 1'b1;
        dut.u_l2.lru_matrix[L2_SET_T4][2][1] = 1'b1;
        dut.u_l2.lru_matrix[L2_SET_T4][2][2] = 1'b1;
        dut.u_l2.lru_matrix[L2_SET_T4][2][3] = 1'b0;
        dut.u_l2.lru_matrix[L2_SET_T4][3][0] = 1'b1;
        dut.u_l2.lru_matrix[L2_SET_T4][3][1] = 1'b1;
        dut.u_l2.lru_matrix[L2_SET_T4][3][2] = 1'b1;
        dut.u_l2.lru_matrix[L2_SET_T4][3][3] = 1'b1;
        send_trace_at(3, make_tlb_fill_trace(VA_L2_NEW, PA_L2_NEW), "T5 tlb fill new");
        send_trace_at(5, make_mem_trace(OP_MEM_LOAD, 4'd4, VA_L2_NEW, 1'b1, '0, 1'b0), "T5 load new");

        wait_for_cycle(9);
        chk_cycle("T5 L2 miss for new line", 9);
        chk_state("T5 L2 mshr[0] unresolved",         dut.u_l2.mshr_state[0],      L2_MS_UNRESOLVED);
        chk_pa   ("T5 mem_req read addr is new line", mem_req_addr,                PA_L2_NEW);
        chk_bit  ("T5 mem_req is read",               mem_req_is_write,            1'b0);

        accept_mem_at(10, PA_L2_NEW, 1'b0, "T5 memory accepts read for new line");
        return_mem_at(11, PA_L2_NEW, BLOCK_G);

        wait_for_cycle(13);
        chk_cycle("T5 L2 fill installs in LRU slot", 13);
        chk_state("T5 L2 mshr[0] freed",                dut.u_l2.mshr_state[0],      L2_MS_IDLE);
        chk_wide ("T5 way1 replaced with new block",    dut.u_l2.set_contents[L2_SET_T4][1], BLOCK_G);
        chk_bit  ("T5 new line installed clean",        dut.u_l2.set_dirty[L2_SET_T4][1],    1'b0);

        wait_for_cycle(14);
        chk_cycle("T5 dirty victim writes to memory", 14);
        chk_bit  ("T5 mem_req switches to writeback",   mem_req_valid,               1'b1);
        chk_bit  ("T5 mem_req is write",                mem_req_is_write,            1'b1);
        chk_pa   ("T5 wb addr is dirty LRU victim",     mem_req_addr,                PA_L2_1);
        chk_wide ("T5 wb data is victim block",         mem_req_wdata,               BLOCK_C);

        $display("\n========================================");
        $display("Integrated memsys test complete: pass=%0d fail=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        if (fail_cnt != 0)
            $fatal(1, "tb_memsys_integrated failed");
        $finish;
    end

endmodule
