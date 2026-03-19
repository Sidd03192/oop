// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vmemsys.h for the primary calling header

#ifndef VERILATED_VMEMSYS___024ROOT_H_
#define VERILATED_VMEMSYS___024ROOT_H_  // guard

#include "verilated.h"


class Vmemsys__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vmemsys___024root final {
  public:

    // DESIGN SPECIFIC STATE
    // Anonymous structures to workaround compiler member-count bugs
    struct {
        VL_IN8(clk,0,0);
        VL_IN8(rst_n,0,0);
        VL_IN8(trace_valid,0,0);
        VL_OUT8(trace_ready,0,0);
        VL_OUT8(avm_burstcount,7,0);
        VL_OUT8(avm_read,0,0);
        VL_OUT8(avm_write,0,0);
        VL_OUT8(avm_byteenable,7,0);
        VL_IN8(avm_readdatavalid,0,0);
        VL_IN8(avm_waitrequest,0,0);
        CData/*0:0*/ memory_subsystem__DOT__lsq_trace_valid;
        CData/*0:0*/ memory_subsystem__DOT__tlb_ready;
        CData/*0:0*/ memory_subsystem__DOT__tlb_valid;
        CData/*0:0*/ memory_subsystem__DOT__is_tlb_fill_now;
        CData/*0:0*/ memory_subsystem__DOT__lsq_valid_to_l1;
        CData/*2:0*/ memory_subsystem__DOT__lsq_issue_op;
        CData/*0:0*/ memory_subsystem__DOT__lsq_sq_ready;
        CData/*0:0*/ memory_subsystem__DOT__issue_buf_valid;
        CData/*2:0*/ memory_subsystem__DOT__issue_buf_op;
        CData/*0:0*/ memory_subsystem__DOT__launch_issue_now;
        CData/*0:0*/ memory_subsystem__DOT__tlb_start;
        CData/*0:0*/ memory_subsystem__DOT__l2_l1_wb_ack;
        CData/*0:0*/ memory_subsystem__DOT__l1_l2_req_valid;
        CData/*0:0*/ memory_subsystem__DOT__l2_l1_data_valid;
        CData/*0:0*/ memory_subsystem__DOT__mem_req_valid;
        CData/*0:0*/ memory_subsystem__DOT__mem_req_is_write;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__lq_head;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__lq_tail;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__sq_head;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__sq_tail;
        CData/*0:0*/ memory_subsystem__DOT__u_lsq__DOT__lq_found;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__lq_found_entry;
        CData/*0:0*/ memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store;
        CData/*0:0*/ memory_subsystem__DOT__u_lsq__DOT__sq_found;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__sq_found_entry;
        CData/*0:0*/ memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load;
        CData/*0:0*/ memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk13__DOT__unnamedblk14__DOT__idx;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk15__DOT__unnamedblk16__DOT__idx;
        CData/*0:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk17__DOT__resolve_done;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk17__DOT__unnamedblk18__DOT__unnamedblk19__DOT__idx;
        CData/*0:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk20__DOT__resolve_done;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk20__DOT__unnamedblk21__DOT__unnamedblk22__DOT__idx;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk23__DOT__unnamedblk24__DOT__idx;
        CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk25__DOT__unnamedblk26__DOT__idx;
        CData/*3:0*/ memory_subsystem__DOT__u_tlb__DOT__hit_index;
        CData/*3:0*/ memory_subsystem__DOT__u_tlb__DOT__free_index;
        CData/*0:0*/ memory_subsystem__DOT__u_tlb__DOT__hit_found;
        CData/*3:0*/ memory_subsystem__DOT__u_l1__DOT__lru;
        CData/*2:0*/ memory_subsystem__DOT__u_l1__DOT__state;
        CData/*1:0*/ memory_subsystem__DOT__u_l1__DOT__curr_index;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__curr_is_write;
        CData/*2:0*/ memory_subsystem__DOT__u_l1__DOT__curr_word_offset;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__mshr_dup;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__mshr_dup_idx;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__evict_way_l;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__mshr_install_done;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__wb_head;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__wb_tail;
        CData/*1:0*/ memory_subsystem__DOT__u_l1__DOT__wb_count;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__wb_push;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__wb_pop;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__wb_empty;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__wb_full;
    };
    struct {
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__victim_dirty;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__mshr_full;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__mshr_free_idx;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__hit;
        CData/*0:0*/ memory_subsystem__DOT__u_l1__DOT__hit_way;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__mshr_issued_one;
        CData/*1:0*/ memory_subsystem__DOT__u_l2__DOT__wb_head;
        CData/*1:0*/ memory_subsystem__DOT__u_l2__DOT__wb_tail;
        CData/*2:0*/ memory_subsystem__DOT__u_l2__DOT__wb_count;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__wb_push;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__wb_pop;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__wb_full;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__req_hit;
        CData/*1:0*/ memory_subsystem__DOT__u_l2__DOT__req_hit_way;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__mshr_dup;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__mshr_full_l2;
        CData/*1:0*/ memory_subsystem__DOT__u_l2__DOT__mshr_free_idx;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__wb_hit;
        CData/*1:0*/ memory_subsystem__DOT__u_l2__DOT__wb_hit_way;
        CData/*1:0*/ memory_subsystem__DOT__u_l2__DOT__wb_victim_way;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__wb_found_invalid;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__wb_victim_dirty;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__wb_is_lru;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__mshr_install_done;
        CData/*3:0*/ memory_subsystem__DOT__u_l2__DOT__mshr_inst_index;
        CData/*1:0*/ memory_subsystem__DOT__u_l2__DOT__mshr_inst_victim;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__mshr_inst_found_invalid;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__mshr_inst_victim_dirty;
        CData/*0:0*/ memory_subsystem__DOT__u_l2__DOT__mshr_inst_is_lru;
        CData/*2:0*/ memory_subsystem__DOT__avm_sdram__DOT__state;
        CData/*2:0*/ memory_subsystem__DOT__avm_sdram__DOT__burst_cnt;
        CData/*0:0*/ __VstlFirstIteration;
        CData/*0:0*/ __VicoFirstIteration;
        CData/*0:0*/ __Vtrigprevexpr___TOP__clk__0;
        CData/*0:0*/ __Vtrigprevexpr___TOP__rst_n__0;
        VL_INW(trace_data,120,0,4);
        VL_OUT(avm_address,28,0);
        IData/*29:0*/ memory_subsystem__DOT__tlb_result_paddr;
        IData/*29:0*/ memory_subsystem__DOT__l1_l2_wb_paddr;
        VlWide<16>/*511:0*/ memory_subsystem__DOT__l1_l2_wb_data;
        IData/*29:0*/ memory_subsystem__DOT__l1_l2_req_paddr;
        IData/*29:0*/ memory_subsystem__DOT__l2_l1_data_paddr;
        VlWide<16>/*511:0*/ memory_subsystem__DOT__l2_l1_data;
        IData/*29:0*/ memory_subsystem__DOT__mem_req_addr;
        IData/*29:0*/ memory_subsystem__DOT__mem_resp_paddr;
        VlWide<16>/*511:0*/ memory_subsystem__DOT__mem_resp_rdata;
        VlWide<16>/*511:0*/ memory_subsystem__DOT__u_l1__DOT__install_block;
        IData/*29:0*/ memory_subsystem__DOT__u_l1__DOT__wb_push_paddr;
        VlWide<16>/*511:0*/ memory_subsystem__DOT__u_l1__DOT__wb_push_data;
        IData/*29:0*/ memory_subsystem__DOT__u_l1__DOT__victim_paddr;
        VlWide<16>/*511:0*/ memory_subsystem__DOT__u_l1__DOT__victim_data;
        IData/*29:0*/ memory_subsystem__DOT__u_l2__DOT__wb_push_paddr;
        VlWide<16>/*511:0*/ memory_subsystem__DOT__u_l2__DOT__wb_push_data;
        IData/*19:0*/ memory_subsystem__DOT__u_l2__DOT__mshr_inst_tag;
        IData/*28:0*/ memory_subsystem__DOT__avm_sdram__DOT__r_addr;
        IData/*31:0*/ __VactIterCount;
        VL_OUT64(avm_writedata,63,0);
        VL_IN64(avm_readdata,63,0);
        QData/*47:0*/ memory_subsystem__DOT__lsq_vaddr_to_l1;
        QData/*63:0*/ memory_subsystem__DOT__lsq_wdata_to_l1;
        QData/*47:0*/ memory_subsystem__DOT__issue_buf_vaddr;
        QData/*63:0*/ memory_subsystem__DOT__issue_buf_wdata;
        QData/*47:0*/ memory_subsystem__DOT__tlb_vaddr_mux;
        QData/*63:0*/ memory_subsystem__DOT__u_l1__DOT__curr_wdata;
    };
    struct {
        VlUnpacked<CData/*1:0*/, 8> memory_subsystem__DOT__u_lsq__DOT__lq_state;
        VlUnpacked<QData/*47:0*/, 8> memory_subsystem__DOT__u_lsq__DOT__lq_vaddr;
        VlUnpacked<CData/*3:0*/, 8> memory_subsystem__DOT__u_lsq__DOT__lq_id;
        VlUnpacked<CData/*7:0*/, 8> memory_subsystem__DOT__u_lsq__DOT__lq_before_vec;
        VlUnpacked<CData/*2:0*/, 8> memory_subsystem__DOT__u_lsq__DOT__sq_state;
        VlUnpacked<QData/*47:0*/, 8> memory_subsystem__DOT__u_lsq__DOT__sq_vaddr;
        VlUnpacked<QData/*63:0*/, 8> memory_subsystem__DOT__u_lsq__DOT__sq_wdata;
        VlUnpacked<CData/*3:0*/, 8> memory_subsystem__DOT__u_lsq__DOT__sq_id;
        VlUnpacked<CData/*7:0*/, 8> memory_subsystem__DOT__u_lsq__DOT__sq_before_vec;
        VlUnpacked<QData/*54:0*/, 16> memory_subsystem__DOT__u_tlb__DOT__ways;
        VlUnpacked<SData/*15:0*/, 16> memory_subsystem__DOT__u_tlb__DOT__lrumat;
        VlUnpacked<VlUnpacked<VlWide<16>/*511:0*/, 2>, 4> memory_subsystem__DOT__u_l1__DOT__set_contents;
        VlUnpacked<VlUnpacked<IData/*21:0*/, 2>, 4> memory_subsystem__DOT__u_l1__DOT__tags;
        VlUnpacked<CData/*1:0*/, 4> memory_subsystem__DOT__u_l1__DOT__set_valids;
        VlUnpacked<CData/*1:0*/, 4> memory_subsystem__DOT__u_l1__DOT__set_dirty;
        VlUnpacked<CData/*1:0*/, 2> memory_subsystem__DOT__u_l1__DOT__mshr_state;
        VlUnpacked<IData/*29:0*/, 2> memory_subsystem__DOT__u_l1__DOT__mshr_paddr;
        VlUnpacked<CData/*1:0*/, 2> memory_subsystem__DOT__u_l1__DOT__mshr_index;
        VlUnpacked<VlWide<16>/*511:0*/, 2> memory_subsystem__DOT__u_l1__DOT__mshr_block;
        VlUnpacked<CData/*7:0*/, 2> memory_subsystem__DOT__u_l1__DOT__mshr_store_mask;
        VlUnpacked<VlWide<16>/*511:0*/, 2> memory_subsystem__DOT__u_l1__DOT__mshr_store_data;
        VlUnpacked<IData/*29:0*/, 2> memory_subsystem__DOT__u_l1__DOT__wb_paddr_q;
        VlUnpacked<VlWide<16>/*511:0*/, 2> memory_subsystem__DOT__u_l1__DOT__wb_data_q;
        VlUnpacked<VlUnpacked<VlWide<16>/*511:0*/, 4>, 16> memory_subsystem__DOT__u_l2__DOT__set_contents;
        VlUnpacked<VlUnpacked<IData/*19:0*/, 4>, 16> memory_subsystem__DOT__u_l2__DOT__tags;
        VlUnpacked<CData/*3:0*/, 16> memory_subsystem__DOT__u_l2__DOT__set_valids;
        VlUnpacked<CData/*3:0*/, 16> memory_subsystem__DOT__u_l2__DOT__set_dirty;
        VlUnpacked<VlUnpacked<VlUnpacked<CData/*0:0*/, 4>, 4>, 16> memory_subsystem__DOT__u_l2__DOT__lru_matrix;
        VlUnpacked<CData/*1:0*/, 4> memory_subsystem__DOT__u_l2__DOT__mshr_state;
        VlUnpacked<IData/*29:0*/, 4> memory_subsystem__DOT__u_l2__DOT__mshr_paddr;
        VlUnpacked<VlWide<16>/*511:0*/, 4> memory_subsystem__DOT__u_l2__DOT__mshr_block;
        VlUnpacked<CData/*0:0*/, 4> memory_subsystem__DOT__u_l2__DOT__mshr_mem_issued;
        VlUnpacked<IData/*29:0*/, 4> memory_subsystem__DOT__u_l2__DOT__wb_paddr_q;
        VlUnpacked<VlWide<16>/*511:0*/, 4> memory_subsystem__DOT__u_l2__DOT__wb_data_q;
        VlUnpacked<QData/*63:0*/, 8> memory_subsystem__DOT__avm_sdram__DOT__r_val_burst;
        VlUnpacked<QData/*63:0*/, 8> memory_subsystem__DOT__avm_sdram__DOT__w_val_burst;
        VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
        VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
        VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
        VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;
    };

    // INTERNAL VARIABLES
    Vmemsys__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vmemsys___024root(Vmemsys__Syms* symsp, const char* namep);
    ~Vmemsys___024root();
    VL_UNCOPYABLE(Vmemsys___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
