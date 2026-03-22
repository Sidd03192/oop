`timescale 1ns/1ps

module tb_memsys_trace;

    localparam int VA_WIDTH          = 48;
    localparam int PA_WIDTH          = 30;
    localparam int DATA_WIDTH        = 64;
    localparam int BLOCK_SIZE        = 64;
    localparam int TRACE_WIDTH       = 121;
    localparam int OFFSET_BITS       = 6;
    localparam int WORD_OFFSET_BITS  = 3;
    localparam int LINE_DATA_WIDTH   = BLOCK_SIZE * 8;

    localparam logic [2:0] OP_MEM_LOAD    = 3'd0;
    localparam logic [2:0] OP_MEM_STORE   = 3'd1;
    localparam logic [2:0] OP_MEM_RESOLVE = 3'd2;
    localparam logic [2:0] OP_TLB_FILL    = 3'd4;

    localparam logic [1:0] L1_MS_IDLE = 2'b00;
    localparam logic [1:0] L2_MS_IDLE = 2'b00;

    localparam int SHADOW_Q_SIZE       = 64;
    localparam int TLB_TABLE_SIZE      = 2048;
    localparam int EXPECTED_WORD_SIZE  = 32768;
    localparam int LINE_TABLE_SIZE     = 8192;
    localparam int READ_PENDING_DEPTH  = 32;
    localparam int READ_LATENCY        = 3;
    localparam int MAX_MISMATCH_PRINTS = 12;

    logic                     clk;
    logic                     rst_n;
    logic [TRACE_WIDTH-1:0]   trace_data;
    logic                     trace_valid;
    wire                      trace_ready;
    wire                      mem_req_valid;
    wire                      mem_req_is_write;
    wire [PA_WIDTH-1:0]       mem_req_addr;
    wire [LINE_DATA_WIDTH-1:0] mem_req_wdata;
    logic                     mem_req_ready;
    logic                     mem_resp_valid;
    logic [PA_WIDTH-1:0]      mem_resp_paddr;
    logic [LINE_DATA_WIDTH-1:0] mem_resp_rdata;

    integer cycle_ctr;
    integer pass_cnt;
    integer fail_cnt;
    integer checker_error_cnt;
    integer records_seen;
    integer mem_ops_seen;
    integer records_sent;
    integer mismatch_prints;

    integer trace_fd;
    integer trace_limit;
    integer timeout_cycles;
    integer trace_read_count;
    integer plusarg_status;
    string trace_file;
    byte trace_buffer [0:15];
    logic stopped_by_limit;
    logic reached_eof;

    integer shadow_head;
    integer shadow_tail;
    integer shadow_access_num;
    logic [2:0]        shadow_op          [0:SHADOW_Q_SIZE-1];
    logic [VA_WIDTH-1:0] shadow_vaddr     [0:SHADOW_Q_SIZE-1];
    logic              shadow_vaddr_valid [0:SHADOW_Q_SIZE-1];
    logic [DATA_WIDTH-1:0] shadow_value   [0:SHADOW_Q_SIZE-1];
    logic              shadow_value_valid [0:SHADOW_Q_SIZE-1];
    logic [3:0]        shadow_id          [0:SHADOW_Q_SIZE-1];
    integer            shadow_access_idx  [0:SHADOW_Q_SIZE-1];

    logic                     tlb_map_valid [0:TLB_TABLE_SIZE-1];
    logic [35:0]              tlb_map_vpn   [0:TLB_TABLE_SIZE-1];
    logic [17:0]              tlb_map_ptag  [0:TLB_TABLE_SIZE-1];

    logic                     expected_valid [0:EXPECTED_WORD_SIZE-1];
    logic [PA_WIDTH-1:0]      expected_paddr [0:EXPECTED_WORD_SIZE-1];
    logic [VA_WIDTH-1:0]      expected_vaddr [0:EXPECTED_WORD_SIZE-1];
    logic [DATA_WIDTH-1:0]    expected_value [0:EXPECTED_WORD_SIZE-1];
    integer                   expected_last_access [0:EXPECTED_WORD_SIZE-1];

    logic                     line_valid [0:LINE_TABLE_SIZE-1];
    logic [PA_WIDTH-1:0]      line_addr  [0:LINE_TABLE_SIZE-1];
    logic [LINE_DATA_WIDTH-1:0] line_data [0:LINE_TABLE_SIZE-1];

    logic                     pending_valid [0:READ_PENDING_DEPTH-1];
    logic [PA_WIDTH-1:0]      pending_addr  [0:READ_PENDING_DEPTH-1];
    integer                   pending_count [0:READ_PENDING_DEPTH-1];

    memory_subsystem dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .trace_data      (trace_data),
        .trace_valid     (trace_valid),
        .trace_ready     (trace_ready),
        .mem_req_valid   (mem_req_valid),
        .mem_req_is_write(mem_req_is_write),
        .mem_req_addr    (mem_req_addr),
        .mem_req_wdata   (mem_req_wdata),
        .mem_req_ready   (mem_req_ready),
        .mem_resp_valid  (mem_resp_valid),
        .mem_resp_paddr  (mem_resp_paddr),
        .mem_resp_rdata  (mem_resp_rdata)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_ctr <= 0;
        else
            cycle_ctr <= cycle_ctr + 1;
    end

    function automatic integer hash_index(
        input logic [63:0] key,
        input integer table_size
    );
        begin
            hash_index = key % table_size;
        end
    endfunction

    task automatic clear_all_state;
        integer i;
        begin
            for (i = 0; i < SHADOW_Q_SIZE; i = i + 1) begin
                shadow_op[i]          = '0;
                shadow_vaddr[i]       = '0;
                shadow_vaddr_valid[i] = 1'b0;
                shadow_value[i]       = '0;
                shadow_value_valid[i] = 1'b0;
                shadow_id[i]          = '0;
                shadow_access_idx[i]  = 0;
            end
            shadow_head = 0;
            shadow_tail = 0;
            shadow_access_num = 0;

            for (i = 0; i < TLB_TABLE_SIZE; i = i + 1) begin
                tlb_map_valid[i] = 1'b0;
                tlb_map_vpn[i]   = '0;
                tlb_map_ptag[i]  = '0;
            end

            for (i = 0; i < EXPECTED_WORD_SIZE; i = i + 1) begin
                expected_valid[i]       = 1'b0;
                expected_paddr[i]       = '0;
                expected_vaddr[i]       = '0;
                expected_value[i]       = '0;
                expected_last_access[i] = 0;
            end

            for (i = 0; i < LINE_TABLE_SIZE; i = i + 1) begin
                line_valid[i] = 1'b0;
                line_addr[i]  = '0;
                line_data[i]  = '0;
            end

            for (i = 0; i < READ_PENDING_DEPTH; i = i + 1) begin
                pending_valid[i] = 1'b0;
                pending_addr[i]  = '0;
                pending_count[i] = 0;
            end
        end
    endtask

    task automatic idle_inputs;
        begin
            trace_data      = '0;
            trace_valid     = 1'b0;
            mem_resp_valid  = 1'b0;
            mem_resp_paddr  = '0;
            mem_resp_rdata  = '0;
            mem_req_ready   = 1'b1;
        end
    endtask

    task automatic apply_reset;
        begin
            idle_inputs();
            rst_n = 1'b0;
            repeat (3) @(negedge clk);
            rst_n = 1'b1;
            @(negedge clk);
        end
    endtask

    task automatic decode_trace_word(
        output logic [TRACE_WIDTH-1:0] packet
    );
        integer i;
        begin
            packet = '0;
            for (i = 0; i < 16; i = i + 1)
                packet[i*8 +: 8] = trace_buffer[i];
        end
    endtask

    task automatic send_trace_packet(
        input logic [TRACE_WIDTH-1:0] packet
    );
        begin
            @(negedge clk);
            trace_data  = packet;
            trace_valid = 1'b1;
            @(posedge clk);
            while (!trace_ready)
                @(posedge clk);
            @(negedge clk);
            trace_valid = 1'b0;
            trace_data  = '0;
            records_sent = records_sent + 1;
        end
    endtask

    task automatic line_get_slot(
        input  logic [PA_WIDTH-1:0] addr,
        output integer slot
    );
        integer idx;
        integer probe;
        begin
            slot = -1;
            idx = hash_index(addr >> OFFSET_BITS, LINE_TABLE_SIZE);
            begin : find_slot
                for (probe = 0; probe < LINE_TABLE_SIZE; probe = probe + 1) begin
                    if (!line_valid[idx] || line_addr[idx] == addr) begin
                        slot = idx;
                        disable find_slot;
                    end
                    idx = idx + 1;
                    if (idx == LINE_TABLE_SIZE)
                        idx = 0;
                end
            end
        end
    endtask

    task automatic line_read(
        input  logic [PA_WIDTH-1:0] addr,
        output logic [LINE_DATA_WIDTH-1:0] data
    );
        integer slot;
        begin
            line_get_slot(addr, slot);
            if (slot >= 0 && line_valid[slot] && line_addr[slot] == addr)
                data = line_data[slot];
            else
                data = '0;
        end
    endtask

    task automatic line_write(
        input logic [PA_WIDTH-1:0] addr,
        input logic [LINE_DATA_WIDTH-1:0] data
    );
        integer slot;
        begin
            line_get_slot(addr, slot);
            if (slot < 0) begin
                $display("ERROR: line table overflow for addr=0x%0h", addr);
                checker_error_cnt = checker_error_cnt + 1;
            end else begin
                line_valid[slot] = 1'b1;
                line_addr[slot]  = addr;
                line_data[slot]  = data;
            end
        end
    endtask

    task automatic tlb_map_update(
        input logic [VA_WIDTH-1:0] vaddr,
        input logic [PA_WIDTH-1:0] paddr
    );
        integer idx;
        integer probe;
        logic [35:0] vpn;
        begin
            vpn = vaddr[47:12];
            idx = hash_index(vpn, TLB_TABLE_SIZE);
            begin : tlb_insert
                for (probe = 0; probe < TLB_TABLE_SIZE; probe = probe + 1) begin
                    if (!tlb_map_valid[idx] || tlb_map_vpn[idx] == vpn) begin
                        tlb_map_valid[idx] = 1'b1;
                        tlb_map_vpn[idx]   = vpn;
                        tlb_map_ptag[idx]  = paddr[29:12];
                        disable tlb_insert;
                    end
                    idx = idx + 1;
                    if (idx == TLB_TABLE_SIZE)
                        idx = 0;
                end
            end
        end
    endtask

    task automatic tlb_translate(
        input  logic [VA_WIDTH-1:0] vaddr,
        output logic                found,
        output logic [PA_WIDTH-1:0] paddr
    );
        integer idx;
        integer probe;
        logic [35:0] vpn;
        begin
            vpn = vaddr[47:12];
            found = 1'b0;
            paddr = '0;
            idx = hash_index(vpn, TLB_TABLE_SIZE);
            begin : tlb_lookup
                for (probe = 0; probe < TLB_TABLE_SIZE; probe = probe + 1) begin
                    if (!tlb_map_valid[idx]) begin
                        disable tlb_lookup;
                    end
                    if (tlb_map_vpn[idx] == vpn) begin
                        found = 1'b1;
                        paddr = {tlb_map_ptag[idx], vaddr[11:0]};
                        disable tlb_lookup;
                    end
                    idx = idx + 1;
                    if (idx == TLB_TABLE_SIZE)
                        idx = 0;
                end
            end
        end
    endtask

    task automatic expected_store_word(
        input logic [PA_WIDTH-1:0]   paddr,
        input logic [VA_WIDTH-1:0]   vaddr,
        input logic [DATA_WIDTH-1:0] value,
        input integer                access_num
    );
        integer idx;
        integer probe;
        logic [PA_WIDTH-1:0] aligned_word_addr;
        begin
            aligned_word_addr = {paddr[PA_WIDTH-1:3], 3'b000};
            idx = hash_index(aligned_word_addr >> 3, EXPECTED_WORD_SIZE);
            begin : expected_insert
                for (probe = 0; probe < EXPECTED_WORD_SIZE; probe = probe + 1) begin
                    if (!expected_valid[idx] || expected_paddr[idx] == aligned_word_addr) begin
                        expected_valid[idx]       = 1'b1;
                        expected_paddr[idx]       = aligned_word_addr;
                        expected_vaddr[idx]       = vaddr;
                        expected_value[idx]       = value;
                        expected_last_access[idx] = access_num;
                        disable expected_insert;
                    end
                    idx = idx + 1;
                    if (idx == EXPECTED_WORD_SIZE)
                        idx = 0;
                end
            end
        end
    endtask

    task automatic shadow_queue_push(
        input logic [2:0]         op,
        input logic [3:0]         id,
        input logic [VA_WIDTH-1:0] vaddr,
        input logic               vaddr_valid,
        input logic [DATA_WIDTH-1:0] value,
        input logic               value_valid
    );
        integer next_tail;
        begin
            next_tail = shadow_tail + 1;
            if (next_tail == SHADOW_Q_SIZE)
                next_tail = 0;

            if (next_tail == shadow_head) begin
                $display("ERROR: shadow queue overflow at record %0d", records_seen);
                checker_error_cnt = checker_error_cnt + 1;
            end else begin
                shadow_op[shadow_tail]          = op;
                shadow_id[shadow_tail]          = id;
                shadow_vaddr[shadow_tail]       = vaddr;
                shadow_vaddr_valid[shadow_tail] = vaddr_valid;
                shadow_value[shadow_tail]       = value;
                shadow_value_valid[shadow_tail] = value_valid;
                shadow_access_idx[shadow_tail]  = shadow_access_num;
                shadow_tail = next_tail;
                shadow_access_num = shadow_access_num + 1;
                mem_ops_seen = mem_ops_seen + 1;
            end
        end
    endtask

    task automatic shadow_find_resolve_target(
        input  logic [3:0] id,
        output integer idx
    );
        integer cur;
        begin
            idx = -1;
            cur = shadow_head;
            while (cur != shadow_tail) begin
                if (shadow_id[cur] == id &&
                    !(shadow_vaddr_valid[cur] && shadow_value_valid[cur])) begin
                    idx = cur;
                    cur = shadow_tail;
                end else begin
                    cur = cur + 1;
                    if (cur == SHADOW_Q_SIZE)
                        cur = 0;
                end
            end
        end
    endtask

    task automatic shadow_commit_ready;
        logic                tlb_hit;
        logic [PA_WIDTH-1:0] translated_paddr;
        begin
            while (shadow_head != shadow_tail &&
                   shadow_vaddr_valid[shadow_head] &&
                   shadow_value_valid[shadow_head]) begin
                if (shadow_op[shadow_head] == OP_MEM_STORE) begin
                    tlb_translate(shadow_vaddr[shadow_head], tlb_hit, translated_paddr);
                    if (!tlb_hit) begin
                        $display("ERROR: missing shadow TLB translation for committed store vaddr=0x%0h access=%0d",
                                 shadow_vaddr[shadow_head], shadow_access_idx[shadow_head]);
                        checker_error_cnt = checker_error_cnt + 1;
                    end else begin
                        expected_store_word(
                            translated_paddr,
                            shadow_vaddr[shadow_head],
                            shadow_value[shadow_head],
                            shadow_access_idx[shadow_head]
                        );
                    end
                end

                shadow_head = shadow_head + 1;
                if (shadow_head == SHADOW_Q_SIZE)
                    shadow_head = 0;
            end
        end
    endtask

    task automatic shadow_process_trace(
        input logic [TRACE_WIDTH-1:0] packet
    );
        logic [2:0]          op;
        logic [3:0]          id;
        logic [VA_WIDTH-1:0] vaddr;
        logic                vaddr_valid;
        logic [DATA_WIDTH-1:0] value;
        logic                value_valid;
        logic [PA_WIDTH-1:0] tlb_paddr;
        integer              idx;
        begin
            op          = packet[54:52];
            id          = packet[51:48];
            vaddr       = packet[47:0];
            vaddr_valid = packet[55];
            value       = packet[119:56];
            value_valid = packet[120];
            tlb_paddr   = packet[85:56];

            case (op)
                OP_MEM_LOAD,
                OP_MEM_STORE: begin
                    shadow_queue_push(op, id, vaddr, vaddr_valid, value, value_valid);
                end

                OP_MEM_RESOLVE: begin
                    shadow_find_resolve_target(id, idx);
                    if (idx < 0) begin
                        $display("ERROR: resolve without pending target id=%0d record=%0d", id, records_seen);
                        checker_error_cnt = checker_error_cnt + 1;
                    end else begin
                        if (vaddr_valid) begin
                            shadow_vaddr[idx]       = vaddr;
                            shadow_vaddr_valid[idx] = 1'b1;
                        end
                        if (value_valid) begin
                            shadow_value[idx]       = value;
                            shadow_value_valid[idx] = 1'b1;
                        end
                    end
                end

                OP_TLB_FILL: begin
                    tlb_map_update(vaddr, tlb_paddr);
                end

                default: begin
                    $display("WARN: unknown trace op=%0d at record=%0d", op, records_seen);
                end
            endcase

            shadow_commit_ready();
        end
    endtask

    task automatic wait_all_idle(
        input integer max_cycles
    );
        integer waited;
        integer i;
        logic done;
        logic lsq_quiescent;
        begin
            waited = 0;
            done = 1'b0;
            while (waited < max_cycles && !done) begin
                lsq_quiescent = 1'b1;
                for (i = 0; i < 8; i = i + 1) begin
                    if (dut.u_lsq.lq_state[i] == 2)
                        lsq_quiescent = 1'b0;
                    if (dut.u_lsq.sq_state[i] == 4)
                        lsq_quiescent = 1'b0;
                end
                if (dut.u_l1.mshr_state[0] == L1_MS_IDLE &&
                    dut.u_l1.mshr_state[1] == L1_MS_IDLE &&
                    dut.u_l1.state == 3'd0 &&
                    dut.u_l2.mshr_state[0] == L2_MS_IDLE &&
                    dut.u_l2.mshr_state[1] == L2_MS_IDLE &&
                    dut.u_l2.mshr_state[2] == L2_MS_IDLE &&
                    dut.u_l2.mshr_state[3] == L2_MS_IDLE &&
                    dut.u_l1.wb_empty &&
                    dut.u_l2.wb_empty &&
                    dut.u_tlb.ready &&
                    !dut.u_lsq.valid_out &&
                    lsq_quiescent) begin
                    done = 1'b1;
                end else begin
                    @(negedge clk);
                    waited = waited + 1;
                end
            end

            if (!done) begin
                $display("ERROR: wait_all_idle timed out after %0d cycles @cycle=%0d", max_cycles, cycle_ctr);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task automatic actual_word_from_hierarchy(
        input  logic [PA_WIDTH-1:0]   paddr,
        input  logic [VA_WIDTH-1:0]   vaddr,
        output logic [DATA_WIDTH-1:0] value
    );
        integer set_idx;
        integer way;
        integer word_idx;
        integer slot;
        logic found;
        logic [21:0] l1_tag;
        logic [19:0] l2_tag;
        logic [LINE_DATA_WIDTH-1:0] backing_line;
        begin
            found = 1'b0;
            value = '0;
            word_idx = paddr[5:3];

            set_idx = vaddr[7:6];
            l1_tag = paddr[29:8];
            for (way = 0; way < 2; way = way + 1) begin
                if (!found &&
                    dut.u_l1.set_valids[set_idx][way] &&
                    dut.u_l1.tags[set_idx][way] == l1_tag) begin
                    value = dut.u_l1.set_contents[set_idx][way][word_idx*DATA_WIDTH +: DATA_WIDTH];
                    found = 1'b1;
                end
            end

            if (!found) begin
                set_idx = paddr[9:6];
                l2_tag = paddr[29:10];
                for (way = 0; way < 4; way = way + 1) begin
                    if (!found &&
                        dut.u_l2.set_valids[set_idx][way] &&
                        dut.u_l2.tags[set_idx][way] == l2_tag) begin
                        value = dut.u_l2.set_contents[set_idx][way][word_idx*DATA_WIDTH +: DATA_WIDTH];
                        found = 1'b1;
                    end
                end
            end

            if (!found) begin
                line_read({paddr[PA_WIDTH-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}}, backing_line);
                value = backing_line[word_idx*DATA_WIDTH +: DATA_WIDTH];
            end
        end
    endtask

    task automatic compare_expected_state;
        integer i;
        logic [DATA_WIDTH-1:0] actual_value;
        begin
            for (i = 0; i < EXPECTED_WORD_SIZE; i = i + 1) begin
                if (expected_valid[i]) begin
                    actual_word_from_hierarchy(expected_paddr[i], expected_vaddr[i], actual_value);
                    if (actual_value === expected_value[i]) begin
                        pass_cnt = pass_cnt + 1;
                    end else begin
                        fail_cnt = fail_cnt + 1;
                        if (mismatch_prints < MAX_MISMATCH_PRINTS) begin
                            $display("MISMATCH[%0d] paddr=0x%0h vaddr=0x%0h actual=0x%016h expected=0x%016h last_access=%0d",
                                     mismatch_prints,
                                     expected_paddr[i],
                                     expected_vaddr[i],
                                     actual_value,
                                     expected_value[i],
                                     expected_last_access[i]);
                        end
                        mismatch_prints = mismatch_prints + 1;
                    end
                end
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin : backing_memory
        integer i;
        integer slot;
        integer free_idx;
        logic [LINE_DATA_WIDTH-1:0] read_line;
        begin
            if (!rst_n) begin
                mem_resp_valid <= 1'b0;
                mem_resp_paddr <= '0;
                mem_resp_rdata <= '0;
                mem_req_ready  <= 1'b1;
                for (i = 0; i < READ_PENDING_DEPTH; i = i + 1) begin
                    pending_valid[i] <= 1'b0;
                    pending_addr[i]  <= '0;
                    pending_count[i] <= 0;
                end
            end else begin
                mem_req_ready  <= 1'b1;
                mem_resp_valid <= 1'b0;
                mem_resp_paddr <= '0;
                mem_resp_rdata <= '0;

                for (i = 0; i < READ_PENDING_DEPTH; i = i + 1) begin
                    if (pending_valid[i] && pending_count[i] > 0)
                        pending_count[i] <= pending_count[i] - 1;
                end

                for (i = 0; i < READ_PENDING_DEPTH; i = i + 1) begin
                    if (!mem_resp_valid && pending_valid[i] && pending_count[i] == 0) begin
                        line_read(pending_addr[i], read_line);
                        mem_resp_valid    <= 1'b1;
                        mem_resp_paddr    <= pending_addr[i];
                        mem_resp_rdata    <= read_line;
                        pending_valid[i]  <= 1'b0;
                    end
                end

                if (mem_req_valid && mem_req_ready) begin
                    if (mem_req_is_write) begin
                        line_write(mem_req_addr, mem_req_wdata);
                    end else begin
                        free_idx = -1;
                        for (i = 0; i < READ_PENDING_DEPTH; i = i + 1) begin
                            if (free_idx < 0 && !pending_valid[i])
                                free_idx = i;
                        end
                        if (free_idx < 0) begin
                            $display("ERROR: pending read queue overflow @cycle=%0d addr=0x%0h", cycle_ctr, mem_req_addr);
                            checker_error_cnt = checker_error_cnt + 1;
                        end else begin
                            pending_valid[free_idx] <= 1'b1;
                            pending_addr[free_idx]  <= mem_req_addr;
                            pending_count[free_idx] <= READ_LATENCY - 1;
                        end
                    end
                end
            end
        end
    end

    initial begin
        $dumpfile("tb_memsys_trace.vcd");
        $dumpvars(0, tb_memsys_trace);

        pass_cnt          = 0;
        fail_cnt          = 0;
        checker_error_cnt = 0;
        records_seen      = 0;
        mem_ops_seen      = 0;
        records_sent      = 0;
        mismatch_prints   = 0;
        trace_limit       = 5000;
        timeout_cycles    = 250000;
        trace_file        = "mem-traces-v2/traces/dgemm3_lsq88_real.bin";

        plusarg_status = $value$plusargs("TRACE_FILE=%s", trace_file);
        plusarg_status = $value$plusargs("TRACE_LIMIT=%d", trace_limit);
        plusarg_status = $value$plusargs("TIMEOUT_CYCLES=%d", timeout_cycles);
        stopped_by_limit = 1'b0;
        reached_eof = 1'b0;

        if (trace_limit == 0)
            timeout_cycles = timeout_cycles < 1000000 ? 1000000 : timeout_cycles;

        clear_all_state();
        idle_inputs();
        rst_n = 1'b1;

        trace_fd = $fopen(trace_file, "rb");
        if (trace_fd == 0) begin
            $display("ERROR: failed to open trace file '%0s'", trace_file);
            $finish;
        end

        $display("TRACE FILE     : %0s", trace_file);
        $display("TRACE LIMIT    : %0d", trace_limit);
        $display("TIMEOUT CYCLES : %0d", timeout_cycles);

        apply_reset();

        begin : drive_trace
            logic [TRACE_WIDTH-1:0] packet;
            while ($fread(trace_buffer, trace_fd) == 16) begin
                if (trace_limit > 0 && records_seen >= trace_limit) begin
                    stopped_by_limit = 1'b1;
                    disable drive_trace;
                end

                decode_trace_word(packet);
                records_seen = records_seen + 1;
                shadow_process_trace(packet);
                send_trace_packet(packet);
            end
            reached_eof = 1'b1;
        end

        $fclose(trace_fd);
        wait_all_idle(timeout_cycles);

        if (!stopped_by_limit && shadow_head != shadow_tail) begin
            $display("ERROR: shadow queue still has unresolved operations after drain");
            checker_error_cnt = checker_error_cnt + 1;
        end

        compare_expected_state();

        if (checker_error_cnt != 0)
            fail_cnt = fail_cnt + checker_error_cnt;

        $display("========================================");
        $display("Trace-driven memsys summary");
        $display("  records_seen      = %0d", records_seen);
        $display("  records_sent      = %0d", records_sent);
        $display("  mem_ops_seen      = %0d", mem_ops_seen);
        $display("  checker_errors    = %0d", checker_error_cnt);
        $display("  mismatches        = %0d", mismatch_prints);
        $display("  pass_count        = %0d", pass_cnt);
        $display("  fail_count        = %0d", fail_cnt);
        $display("========================================");

        if (fail_cnt != 0)
            $fatal(1, "tb_memsys_trace failed");
        $finish;
    end

    always @(posedge clk) begin
        if (rst_n && cycle_ctr > timeout_cycles) begin
            $display("ERROR: simulation timed out at cycle %0d", cycle_ctr);
            $display("  records_seen=%0d records_sent=%0d stopped_by_limit=%0b reached_eof=%0b", records_seen, records_sent, stopped_by_limit, reached_eof);
            $display("  trace_valid=%0b trace_ready=%0b mem_req_valid=%0b mem_req_is_write=%0b mem_req_addr=0x%0h",
                     trace_valid, trace_ready, mem_req_valid, mem_req_is_write, mem_req_addr);
            $display("  lsq_lq_ready=%0b lsq_sq_ready=%0b lsq_valid_out=%0b", dut.u_lsq.lq_ready, dut.u_lsq.sq_ready, dut.u_lsq.valid_out);
            $display("  l1_state=%0d l1_mshr={%0d,%0d} l1_wb_empty=%0b", dut.u_l1.state, dut.u_l1.mshr_state[0], dut.u_l1.mshr_state[1], dut.u_l1.wb_empty);
            $display("  l2_mshr={%0d,%0d,%0d,%0d} l2_wb_empty=%0b",
                     dut.u_l2.mshr_state[0], dut.u_l2.mshr_state[1], dut.u_l2.mshr_state[2], dut.u_l2.mshr_state[3], dut.u_l2.wb_empty);
            $fatal(1, "tb_memsys_trace timeout");
        end
    end

endmodule
