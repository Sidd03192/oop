`timescale 1ns/1ps

module tb_avl_first2;
    localparam int MAX_WAIT_CYCLES = 64;

    logic        clk;
    logic        rst_n;

    logic [5:0]  avs_address;
    logic        avs_write;
    logic        avs_read;
    logic [31:0] avs_writedata;
    logic [31:0] avs_readdata;

    logic [28:0] avm_address;
    logic  [7:0] avm_burstcount;
    logic        avm_read;
    logic        avm_write;
    logic [63:0] avm_writedata;
    logic  [7:0] avm_byteenable;
    logic [63:0] avm_readdata;
    logic        avm_readdatavalid;
    logic        avm_waitrequest;

    logic        read_active;
    logic [28:0] read_base;
    integer      read_count;
    integer      wait_cycles;
    integer      accept_cycles;

    logic [127:0] trace0_words;
    logic [127:0] trace1_words;

    memory_subsystem_avl_wrapper dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .avs_address       (avs_address),
        .avs_write         (avs_write),
        .avs_read          (avs_read),
        .avs_writedata     (avs_writedata),
        .avs_readdata      (avs_readdata),
        .avm_address       (avm_address),
        .avm_burstcount    (avm_burstcount),
        .avm_read          (avm_read),
        .avm_write         (avm_write),
        .avm_writedata     (avm_writedata),
        .avm_byteenable    (avm_byteenable),
        .avm_readdata      (avm_readdata),
        .avm_readdatavalid (avm_readdatavalid),
        .avm_waitrequest   (avm_waitrequest)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic idle_bus;
        begin
            avs_address   = '0;
            avs_write     = 1'b0;
            avs_read      = 1'b0;
            avs_writedata = '0;
        end
    endtask

    task automatic mmio_write(
        input logic [5:0]  addr,
        input logic [31:0] data
    );
        begin
            @(negedge clk);
            avs_address   = addr;
            avs_writedata = data;
            avs_write     = 1'b1;
            @(posedge clk);
            @(negedge clk);
            avs_write     = 1'b0;
            avs_writedata = '0;
        end
    endtask

    task automatic wait_ready(
        input string label
    );
        begin
            wait_cycles = 0;
            avs_address = 2'd3;
            avs_read    = 1'b1;
            @(posedge clk);
            while (!avs_readdata[0]) begin
                wait_cycles = wait_cycles + 1;
                if (wait_cycles > MAX_WAIT_CYCLES) begin
                    $fatal(1, "%s: trace_ready stayed low for %0d cycles", label, wait_cycles);
                end
                @(posedge clk);
            end
            $display("%s: trace_ready high after %0d cycle(s)", label, wait_cycles);
            @(negedge clk);
            avs_read = 1'b0;
        end
    endtask

    task automatic wait_valid_clear(
        input string label
    );
        begin
            accept_cycles = 0;
            avs_address = 2'd2;
            avs_read    = 1'b1;
            @(posedge clk);
            if (!dut.trace_valid_reg) begin
                $fatal(1, "%s: trace_valid_reg never asserted after submit", label);
            end
            while (avs_readdata[0]) begin
                accept_cycles = accept_cycles + 1;
                if (accept_cycles > MAX_WAIT_CYCLES) begin
                    $fatal(1, "%s: trace_valid_reg did not auto-clear", label);
                end
                @(posedge clk);
            end
            $display("%s: trace_valid_reg cleared after %0d cycle(s)", label, accept_cycles);
            @(negedge clk);
            avs_read = 1'b0;
        end
    endtask

    task automatic send_trace_record(
        input string label,
        input logic [127:0] words
    );
        begin
            wait_ready({label, " pre-send"});
            for (int index = 0; index < 4; index++) begin
                mmio_write(2'd0, index[31:0]);
                mmio_write(2'd1, words[index*32 +: 32]);
            end
            mmio_write(2'd2, 32'h1);
            wait_valid_clear({label, " submit"});
            $display("%s: internal trace_ready=%0b trace_valid_reg=%0b", label, dut.trace_ready_wire, dut.trace_valid_reg);
        end
    endtask

    initial begin
        trace0_words = {32'h00000000, 32'h00200000, 32'h00C07FFF, 32'h10A1F000};
        trace1_words = {32'h01000000, 32'h00000000, 32'h02807FFF, 32'h10A1F770};

        idle_bus();
        rst_n             = 1'b0;
        avm_waitrequest   = 1'b0;
        avm_readdata      = '0;
        avm_readdatavalid = 1'b0;
        read_active       = 1'b0;
        read_base         = '0;
        read_count        = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("Running first two traces from dgemm3_lsq88.bin through Avalon wrapper");
        send_trace_record("trace0_tlb_fill", trace0_words);
        send_trace_record("trace1_load", trace1_words);

        wait_ready("post-trace idle");

        repeat (40) @(posedge clk);

        if (dut.trace_valid_reg !== 1'b0) begin
            $fatal(1, "trace_valid_reg still asserted after first two traces");
        end

        $display("PASS: first two traces accepted without wrapper-side stalling");
        $finish;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            avm_readdatavalid <= 1'b0;
            avm_readdata      <= '0;
            read_active       <= 1'b0;
            read_base         <= '0;
            read_count        <= 0;
        end else begin
            avm_readdatavalid <= 1'b0;

            if (!read_active && avm_read && !avm_waitrequest) begin
                read_active <= 1'b1;
                read_base   <= avm_address;
                read_count  <= 0;
            end else if (read_active) begin
                avm_readdatavalid <= 1'b1;
                avm_readdata      <= {29'b0, read_base, read_count[5:0]};
                if (read_count == 7) begin
                    read_active <= 1'b0;
                    read_count  <= 0;
                end else begin
                    read_count <= read_count + 1;
                end
            end
        end
    end
endmodule
