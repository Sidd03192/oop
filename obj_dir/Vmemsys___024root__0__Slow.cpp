// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmemsys.h for the primary calling header

#include "Vmemsys__pch.h"

VL_ATTR_COLD void Vmemsys___024root___eval_static(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_static\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__Vtrigprevexpr___TOP__clk__0 = vlSelfRef.clk;
    vlSelfRef.__Vtrigprevexpr___TOP__rst_n__0 = vlSelfRef.rst_n;
}

VL_ATTR_COLD void Vmemsys___024root___eval_initial(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_initial\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.avm_burstcount = 8U;
    vlSelfRef.avm_byteenable = 0xffU;
}

VL_ATTR_COLD void Vmemsys___024root___eval_initial__TOP(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_initial__TOP\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.avm_burstcount = 8U;
    vlSelfRef.avm_byteenable = 0xffU;
}

VL_ATTR_COLD void Vmemsys___024root___eval_final(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_final\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmemsys___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vmemsys___024root___eval_phase__stl(Vmemsys___024root* vlSelf);

VL_ATTR_COLD void Vmemsys___024root___eval_settle(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_settle\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VstlIterCount;
    // Body
    __VstlIterCount = 0U;
    vlSelfRef.__VstlFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00000064U < __VstlIterCount)))) {
#ifdef VL_DEBUG
            Vmemsys___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
#endif
            VL_FATAL_MT("memsys.sv", 16, "", "DIDNOTCONVERGE: Settle region did not converge after 100 tries");
        }
        __VstlIterCount = ((IData)(1U) + __VstlIterCount);
    } while (Vmemsys___024root___eval_phase__stl(vlSelf));
}

VL_ATTR_COLD void Vmemsys___024root___eval_triggers__stl(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_triggers__stl\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VstlTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VstlTriggered
                                      [0U]) | (IData)((IData)(vlSelfRef.__VstlFirstIteration)));
    vlSelfRef.__VstlFirstIteration = 0U;
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vmemsys___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
    }
#endif
}

VL_ATTR_COLD bool Vmemsys___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmemsys___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(Vmemsys___024root___trigger_anySet__stl(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD bool Vmemsys___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___trigger_anySet__stl\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

extern const VlWide<16>/*511:0*/ Vmemsys__ConstPool__CONST_h93e1b771_0;

VL_ATTR_COLD void Vmemsys___024root___stl_sequent__TOP__0(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___stl_sequent__TOP__0\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ memory_subsystem__DOT__trace_fire;
    memory_subsystem__DOT__trace_fire = 0;
    VlWide<16>/*511:0*/ memory_subsystem__DOT__mem_req_wdata;
    VL_ZERO_W(512, memory_subsystem__DOT__mem_req_wdata);
    CData/*0:0*/ memory_subsystem__DOT__u_lsq__DOT__sq_unresolved;
    memory_subsystem__DOT__u_lsq__DOT__sq_unresolved = 0;
    CData/*0:0*/ memory_subsystem__DOT__u_lsq__DOT__terminate_loop;
    memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 0;
    CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx;
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx = 0;
    CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx;
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx = 0;
    CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx;
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx = 0;
    CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx;
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx = 0;
    CData/*2:0*/ memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx;
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx = 0;
    CData/*0:0*/ memory_subsystem__DOT__u_tlb__DOT__free_found;
    memory_subsystem__DOT__u_tlb__DOT__free_found = 0;
    // Body
    vlSelfRef.avm_write = 0U;
    if (((1U == (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__state)) 
         || (2U == (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__state)))) {
        vlSelfRef.avm_write = 1U;
    }
    vlSelfRef.avm_read = 0U;
    if ((1U & (~ ((1U == (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__state)) 
                  || (2U == (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__state)))))) {
        if ((3U == (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__state))) {
            vlSelfRef.avm_read = 1U;
        }
    }
    vlSelfRef.avm_address = vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_addr;
    vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_empty 
        = (0U == (IData)(vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_count));
    vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_full 
        = (2U == (IData)(vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_count));
    vlSelfRef.memory_subsystem__DOT__mem_req_is_write 
        = (0U != (IData)(vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_count));
    vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_full 
        = (4U == (IData)(vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_count));
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[0U] 
        = (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                  [0U]);
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[1U] 
        = (IData)((vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                   [0U] >> 0x00000020U));
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[2U] 
        = (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                  [1U]);
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[3U] 
        = (IData)((vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                   [1U] >> 0x00000020U));
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[4U] 
        = (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                  [2U]);
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[5U] 
        = (IData)((vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                   [2U] >> 0x00000020U));
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[6U] 
        = (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                  [3U]);
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[7U] 
        = (IData)((vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                   [3U] >> 0x00000020U));
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[8U] 
        = (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                  [4U]);
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[9U] 
        = (IData)((vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                   [4U] >> 0x00000020U));
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[0x0000000aU] 
        = (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                  [5U]);
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[0x0000000bU] 
        = (IData)((vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                   [5U] >> 0x00000020U));
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[0x0000000cU] 
        = (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                  [6U]);
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[0x0000000dU] 
        = (IData)((vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                   [6U] >> 0x00000020U));
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[0x0000000eU] 
        = (IData)(vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                  [7U]);
    vlSelfRef.memory_subsystem__DOT__mem_resp_rdata[0x0000000fU] 
        = (IData)((vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__r_val_burst
                   [7U] >> 0x00000020U));
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_paddr 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_paddr_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[0U] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][0U];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[1U] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][1U];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[2U] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][2U];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[3U] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][3U];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[4U] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][4U];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[5U] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][5U];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[6U] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][6U];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[7U] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][7U];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[8U] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][8U];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[9U] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][9U];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[0x0000000aU] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][0x0000000aU];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[0x0000000bU] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][0x0000000bU];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[0x0000000cU] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][0x0000000cU];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[0x0000000dU] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][0x0000000dU];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[0x0000000eU] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][0x0000000eU];
    vlSelfRef.memory_subsystem__DOT__l1_l2_wb_data[0x0000000fU] 
        = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_data_q
        [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__wb_head][0x0000000fU];
    vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 0U;
    memory_subsystem__DOT__u_tlb__DOT__free_found = 0U;
    if ((0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
         [0U])) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 0U;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [1U]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 1U;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [2U]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 2U;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [3U]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 3U;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [4U]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 4U;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [5U]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 5U;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [6U]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 6U;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [7U]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 7U;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [8U]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 8U;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [9U]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 9U;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [0x0aU]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 0x0aU;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [0x0bU]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 0x0bU;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [0x0cU]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 0x0cU;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [0x0dU]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 0x0dU;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [0x0eU]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 0x0eU;
    }
    if (((~ (IData)(memory_subsystem__DOT__u_tlb__DOT__free_found)) 
         & (0U == vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__lrumat
            [0x0fU]))) {
        memory_subsystem__DOT__u_tlb__DOT__free_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__free_index = 0x0fU;
    }
    vlSelfRef.memory_subsystem__DOT__l1_l2_req_valid = 0U;
    vlSelfRef.memory_subsystem__DOT__l1_l2_req_paddr = 0U;
    if ((1U == vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_state
         [0U])) {
        vlSelfRef.memory_subsystem__DOT__l1_l2_req_valid = 1U;
        vlSelfRef.memory_subsystem__DOT__l1_l2_req_paddr 
            = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_paddr
            [0U];
    }
    if (((1U == vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_state
          [1U]) & (~ (IData)(vlSelfRef.memory_subsystem__DOT__l1_l2_req_valid)))) {
        vlSelfRef.memory_subsystem__DOT__l1_l2_req_valid = 1U;
        vlSelfRef.memory_subsystem__DOT__l1_l2_req_paddr 
            = vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_paddr
            [1U];
    }
    vlSelfRef.memory_subsystem__DOT__u_l1__DOT__hit = 0U;
    if ((vlSelfRef.memory_subsystem__DOT__u_l1__DOT__set_valids
         [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__curr_index] 
         & (vlSelfRef.memory_subsystem__DOT__u_l1__DOT__tags
            [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__curr_index]
            [0U] == (0x003fffffU & (vlSelfRef.memory_subsystem__DOT__tlb_result_paddr 
                                    >> 8U))))) {
        vlSelfRef.memory_subsystem__DOT__u_l1__DOT__hit = 1U;
        vlSelfRef.memory_subsystem__DOT__u_l1__DOT__hit_way = 0U;
        vlSelfRef.memory_subsystem__DOT__u_l1__DOT__hit_way = 0U;
    } else {
        vlSelfRef.memory_subsystem__DOT__u_l1__DOT__hit_way = 0U;
    }
    if (((vlSelfRef.memory_subsystem__DOT__u_l1__DOT__set_valids
          [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__curr_index] 
          >> 1U) & (vlSelfRef.memory_subsystem__DOT__u_l1__DOT__tags
                    [vlSelfRef.memory_subsystem__DOT__u_l1__DOT__curr_index]
                    [1U] == (0x003fffffU & (vlSelfRef.memory_subsystem__DOT__tlb_result_paddr 
                                            >> 8U))))) {
        vlSelfRef.memory_subsystem__DOT__u_l1__DOT__hit = 1U;
        vlSelfRef.memory_subsystem__DOT__u_l1__DOT__hit_way = 1U;
    }
    vlSelfRef.memory_subsystem__DOT__mem_req_valid = 0U;
    vlSelfRef.memory_subsystem__DOT__mem_req_addr = 0U;
    if ((0U == (IData)(vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_count))) {
        if ((((1U == vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_state
               [0U]) & (~ vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_mem_issued
                        [0U])) & (~ (IData)(vlSelfRef.memory_subsystem__DOT__mem_req_valid)))) {
            vlSelfRef.memory_subsystem__DOT__mem_req_valid = 1U;
            vlSelfRef.memory_subsystem__DOT__mem_req_addr 
                = vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_paddr
                [0U];
        }
        if ((((1U == vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_state
               [1U]) & (~ vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_mem_issued
                        [1U])) & (~ (IData)(vlSelfRef.memory_subsystem__DOT__mem_req_valid)))) {
            vlSelfRef.memory_subsystem__DOT__mem_req_valid = 1U;
            vlSelfRef.memory_subsystem__DOT__mem_req_addr 
                = vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_paddr
                [1U];
        }
        if ((((1U == vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_state
               [2U]) & (~ vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_mem_issued
                        [2U])) & (~ (IData)(vlSelfRef.memory_subsystem__DOT__mem_req_valid)))) {
            vlSelfRef.memory_subsystem__DOT__mem_req_valid = 1U;
            vlSelfRef.memory_subsystem__DOT__mem_req_addr 
                = vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_paddr
                [2U];
        }
        if ((((1U == vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_state
               [3U]) & (~ vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_mem_issued
                        [3U])) & (~ (IData)(vlSelfRef.memory_subsystem__DOT__mem_req_valid)))) {
            vlSelfRef.memory_subsystem__DOT__mem_req_valid = 1U;
            vlSelfRef.memory_subsystem__DOT__mem_req_addr 
                = vlSelfRef.memory_subsystem__DOT__u_l2__DOT__mshr_paddr
                [3U];
        }
    } else {
        vlSelfRef.memory_subsystem__DOT__mem_req_valid = 1U;
        vlSelfRef.memory_subsystem__DOT__mem_req_addr 
            = vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_paddr_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head];
    }
    vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_full = 1U;
    vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_free_idx = 0U;
    if ((0U == vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_state
         [0U])) {
        vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_full = 0U;
        vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_free_idx = 0U;
    }
    if (((0U == vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_state
          [1U]) & (IData)(vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_full))) {
        vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_full = 0U;
        vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_free_idx = 1U;
    }
    vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found = 0U;
    vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry = 0U;
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx 
        = vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head;
    if ((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
         [memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx])) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx 
        = (7U & ((IData)(1U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found)) 
         & (2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx 
        = (7U & ((IData)(2U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found)) 
         & (2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx 
        = (7U & ((IData)(3U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found)) 
         & (2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx 
        = (7U & ((IData)(4U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found)) 
         & (2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx 
        = (7U & ((IData)(5U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found)) 
         & (2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx 
        = (7U & ((IData)(6U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found)) 
         & (2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx 
        = (7U & ((IData)(7U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found)) 
         & (2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk1__DOT__unnamedblk2__DOT__idx;
    }
    vlSelfRef.memory_subsystem__DOT__lsq_sq_ready = 
        (0U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
         [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_tail]);
    vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found = 0U;
    vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry = 0U;
    memory_subsystem__DOT__u_lsq__DOT__sq_unresolved = 0U;
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx 
        = vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head;
    if ((4U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
         [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx])) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx;
    } else if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
                 & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
                & ((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]) 
                   | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx])))) {
        memory_subsystem__DOT__u_lsq__DOT__sq_unresolved = 1U;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx 
        = (7U & ((IData)(1U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
          & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
         & (4U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx;
    } else if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
                 & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
                & ((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]) 
                   | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx])))) {
        memory_subsystem__DOT__u_lsq__DOT__sq_unresolved = 1U;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx 
        = (7U & ((IData)(2U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
          & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
         & (4U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx;
    } else if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
                 & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
                & ((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]) 
                   | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx])))) {
        memory_subsystem__DOT__u_lsq__DOT__sq_unresolved = 1U;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx 
        = (7U & ((IData)(3U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
          & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
         & (4U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx;
    } else if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
                 & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
                & ((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]) 
                   | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx])))) {
        memory_subsystem__DOT__u_lsq__DOT__sq_unresolved = 1U;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx 
        = (7U & ((IData)(4U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
          & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
         & (4U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx;
    } else if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
                 & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
                & ((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]) 
                   | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx])))) {
        memory_subsystem__DOT__u_lsq__DOT__sq_unresolved = 1U;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx 
        = (7U & ((IData)(5U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
          & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
         & (4U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx;
    } else if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
                 & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
                & ((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]) 
                   | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx])))) {
        memory_subsystem__DOT__u_lsq__DOT__sq_unresolved = 1U;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx 
        = (7U & ((IData)(6U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
          & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
         & (4U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx;
    } else if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
                 & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
                & ((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]) 
                   | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx])))) {
        memory_subsystem__DOT__u_lsq__DOT__sq_unresolved = 1U;
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx 
        = (7U & ((IData)(7U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
          & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
         & (4U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
            [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]))) {
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry 
            = memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx;
    } else if ((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__sq_unresolved)) 
                 & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found))) 
                & ((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx]) 
                   | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk5__DOT__unnamedblk6__DOT__idx])))) {
        memory_subsystem__DOT__u_lsq__DOT__sq_unresolved = 1U;
    }
    memory_subsystem__DOT__mem_req_wdata[0U] = Vmemsys__ConstPool__CONST_h93e1b771_0[0U];
    memory_subsystem__DOT__mem_req_wdata[1U] = Vmemsys__ConstPool__CONST_h93e1b771_0[1U];
    memory_subsystem__DOT__mem_req_wdata[2U] = Vmemsys__ConstPool__CONST_h93e1b771_0[2U];
    memory_subsystem__DOT__mem_req_wdata[3U] = Vmemsys__ConstPool__CONST_h93e1b771_0[3U];
    memory_subsystem__DOT__mem_req_wdata[4U] = Vmemsys__ConstPool__CONST_h93e1b771_0[4U];
    memory_subsystem__DOT__mem_req_wdata[5U] = Vmemsys__ConstPool__CONST_h93e1b771_0[5U];
    memory_subsystem__DOT__mem_req_wdata[6U] = Vmemsys__ConstPool__CONST_h93e1b771_0[6U];
    memory_subsystem__DOT__mem_req_wdata[7U] = Vmemsys__ConstPool__CONST_h93e1b771_0[7U];
    memory_subsystem__DOT__mem_req_wdata[8U] = Vmemsys__ConstPool__CONST_h93e1b771_0[8U];
    memory_subsystem__DOT__mem_req_wdata[9U] = Vmemsys__ConstPool__CONST_h93e1b771_0[9U];
    memory_subsystem__DOT__mem_req_wdata[0x0000000aU] 
        = Vmemsys__ConstPool__CONST_h93e1b771_0[0x0000000aU];
    memory_subsystem__DOT__mem_req_wdata[0x0000000bU] 
        = Vmemsys__ConstPool__CONST_h93e1b771_0[0x0000000bU];
    memory_subsystem__DOT__mem_req_wdata[0x0000000cU] 
        = Vmemsys__ConstPool__CONST_h93e1b771_0[0x0000000cU];
    memory_subsystem__DOT__mem_req_wdata[0x0000000dU] 
        = Vmemsys__ConstPool__CONST_h93e1b771_0[0x0000000dU];
    memory_subsystem__DOT__mem_req_wdata[0x0000000eU] 
        = Vmemsys__ConstPool__CONST_h93e1b771_0[0x0000000eU];
    memory_subsystem__DOT__mem_req_wdata[0x0000000fU] 
        = Vmemsys__ConstPool__CONST_h93e1b771_0[0x0000000fU];
    if ((0U != (IData)(vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_count))) {
        memory_subsystem__DOT__mem_req_wdata[0U] = 
            vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][0U];
        memory_subsystem__DOT__mem_req_wdata[1U] = 
            vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][1U];
        memory_subsystem__DOT__mem_req_wdata[2U] = 
            vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][2U];
        memory_subsystem__DOT__mem_req_wdata[3U] = 
            vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][3U];
        memory_subsystem__DOT__mem_req_wdata[4U] = 
            vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][4U];
        memory_subsystem__DOT__mem_req_wdata[5U] = 
            vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][5U];
        memory_subsystem__DOT__mem_req_wdata[6U] = 
            vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][6U];
        memory_subsystem__DOT__mem_req_wdata[7U] = 
            vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][7U];
        memory_subsystem__DOT__mem_req_wdata[8U] = 
            vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][8U];
        memory_subsystem__DOT__mem_req_wdata[9U] = 
            vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][9U];
        memory_subsystem__DOT__mem_req_wdata[0x0000000aU] 
            = vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][0x0000000aU];
        memory_subsystem__DOT__mem_req_wdata[0x0000000bU] 
            = vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][0x0000000bU];
        memory_subsystem__DOT__mem_req_wdata[0x0000000cU] 
            = vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][0x0000000cU];
        memory_subsystem__DOT__mem_req_wdata[0x0000000dU] 
            = vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][0x0000000dU];
        memory_subsystem__DOT__mem_req_wdata[0x0000000eU] 
            = vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][0x0000000eU];
        memory_subsystem__DOT__mem_req_wdata[0x0000000fU] 
            = vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_data_q
            [vlSelfRef.memory_subsystem__DOT__u_l2__DOT__wb_head][0x0000000fU];
    }
    vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store = 0U;
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx 
        = vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head;
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx))) 
             & (((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                  [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                 | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx])) 
                | ((3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                   & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx] 
                      == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_vaddr
                      [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry]))))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx 
        = (7U & ((IData)(1U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx))) 
             & (((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                  [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                 | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx])) 
                | ((3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                   & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx] 
                      == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_vaddr
                      [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry]))))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx 
        = (7U & ((IData)(2U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx))) 
             & (((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                  [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                 | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx])) 
                | ((3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                   & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx] 
                      == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_vaddr
                      [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry]))))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx 
        = (7U & ((IData)(3U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx))) 
             & (((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                  [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                 | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx])) 
                | ((3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                   & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx] 
                      == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_vaddr
                      [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry]))))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx 
        = (7U & ((IData)(4U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx))) 
             & (((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                  [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                 | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx])) 
                | ((3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                   & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx] 
                      == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_vaddr
                      [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry]))))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx 
        = (7U & ((IData)(5U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx))) 
             & (((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                  [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                 | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx])) 
                | ((3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                   & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx] 
                      == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_vaddr
                      [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry]))))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx 
        = (7U & ((IData)(6U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx))) 
             & (((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                  [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                 | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx])) 
                | ((3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                   & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx] 
                      == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_vaddr
                      [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry]))))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx 
        = (7U & ((IData)(7U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx))) 
             & (((2U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                  [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                 | (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx])) 
                | ((3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                    [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx]) 
                   & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                      [memory_subsystem__DOT__u_lsq__DOT__unnamedblk3__DOT__unnamedblk4__DOT__idx] 
                      == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_vaddr
                      [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_found_entry]))))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store = 1U;
        }
    }
    vlSelfRef.trace_ready = ((4U == (7U & (vlSelfRef.trace_data[1U] 
                                           >> 0x00000014U)))
                              ? (IData)(vlSelfRef.memory_subsystem__DOT__tlb_ready)
                              : ((0U == (7U & (vlSelfRef.trace_data[1U] 
                                               >> 0x00000014U)))
                                  ? (0U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
                                     [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_tail])
                                  : ((1U == (7U & (
                                                   vlSelfRef.trace_data[1U] 
                                                   >> 0x00000014U)))
                                      ? (IData)(vlSelfRef.memory_subsystem__DOT__lsq_sq_ready)
                                      : (2U == (7U 
                                                & (vlSelfRef.trace_data[1U] 
                                                   >> 0x00000014U))))));
    vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load = 0U;
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx 
        = vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head;
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx))) 
             & (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
                [memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx 
        = (7U & ((IData)(1U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx))) 
             & (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
                [memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx 
        = (7U & ((IData)(2U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx))) 
             & (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
                [memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx 
        = (7U & ((IData)(3U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx))) 
             & (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
                [memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx 
        = (7U & ((IData)(4U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx))) 
             & (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
                [memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx 
        = (7U & ((IData)(5U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx))) 
             & (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
                [memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx 
        = (7U & ((IData)(6U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx))) 
             & (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
                [memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx 
        = (7U & ((IData)(7U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_head)));
    vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store = 0U;
    memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 0U;
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx 
        = vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head;
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load)) 
              & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_before_vec
                 [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                 >> (IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx))) 
             & (1U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__lq_state
                [memory_subsystem__DOT__u_lsq__DOT__unnamedblk7__DOT__unnamedblk8__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load = 1U;
        }
        if (((IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx) 
             == (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry))) {
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        } else if (((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__terminate_loop)) 
                      & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store))) 
                     & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                        == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx])) 
                    & (3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                       [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store = 1U;
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx 
        = (7U & ((IData)(1U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if (((IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx) 
             == (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry))) {
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        } else if (((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__terminate_loop)) 
                      & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store))) 
                     & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                        == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx])) 
                    & (3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                       [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store = 1U;
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx 
        = (7U & ((IData)(2U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if (((IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx) 
             == (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry))) {
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        } else if (((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__terminate_loop)) 
                      & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store))) 
                     & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                        == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx])) 
                    & (3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                       [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store = 1U;
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx 
        = (7U & ((IData)(3U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if (((IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx) 
             == (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry))) {
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        } else if (((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__terminate_loop)) 
                      & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store))) 
                     & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                        == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx])) 
                    & (3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                       [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store = 1U;
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx 
        = (7U & ((IData)(4U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if (((IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx) 
             == (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry))) {
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        } else if (((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__terminate_loop)) 
                      & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store))) 
                     & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                        == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx])) 
                    & (3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                       [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store = 1U;
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx 
        = (7U & ((IData)(5U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if (((IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx) 
             == (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry))) {
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        } else if (((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__terminate_loop)) 
                      & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store))) 
                     & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                        == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx])) 
                    & (3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                       [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store = 1U;
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx 
        = (7U & ((IData)(6U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if (((IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx) 
             == (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry))) {
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        } else if (((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__terminate_loop)) 
                      & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store))) 
                     & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                        == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx])) 
                    & (3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                       [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store = 1U;
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        }
    }
    memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx 
        = (7U & ((IData)(7U) + (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_head)));
    if (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found) {
        if (((IData)(memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx) 
             == (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry))) {
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        } else if (((((~ (IData)(memory_subsystem__DOT__u_lsq__DOT__terminate_loop)) 
                      & (~ (IData)(vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store))) 
                     & (vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_found_entry] 
                        == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_vaddr
                        [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx])) 
                    & (3U == vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__sq_state
                       [memory_subsystem__DOT__u_lsq__DOT__unnamedblk9__DOT__unnamedblk10__DOT__idx]))) {
            vlSelfRef.memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store = 1U;
            memory_subsystem__DOT__u_lsq__DOT__terminate_loop = 1U;
        }
    }
    vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__w_val_burst[0U] 
        = (((QData)((IData)(memory_subsystem__DOT__mem_req_wdata[1U])) 
            << 0x00000020U) | (QData)((IData)(memory_subsystem__DOT__mem_req_wdata[0U])));
    vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__w_val_burst[1U] 
        = (((QData)((IData)(memory_subsystem__DOT__mem_req_wdata[3U])) 
            << 0x00000020U) | (QData)((IData)(memory_subsystem__DOT__mem_req_wdata[2U])));
    vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__w_val_burst[2U] 
        = (((QData)((IData)(memory_subsystem__DOT__mem_req_wdata[5U])) 
            << 0x00000020U) | (QData)((IData)(memory_subsystem__DOT__mem_req_wdata[4U])));
    vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__w_val_burst[3U] 
        = (((QData)((IData)(memory_subsystem__DOT__mem_req_wdata[7U])) 
            << 0x00000020U) | (QData)((IData)(memory_subsystem__DOT__mem_req_wdata[6U])));
    vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__w_val_burst[4U] 
        = (((QData)((IData)(memory_subsystem__DOT__mem_req_wdata[9U])) 
            << 0x00000020U) | (QData)((IData)(memory_subsystem__DOT__mem_req_wdata[8U])));
    vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__w_val_burst[5U] 
        = (((QData)((IData)(memory_subsystem__DOT__mem_req_wdata[0x0000000bU])) 
            << 0x00000020U) | (QData)((IData)(memory_subsystem__DOT__mem_req_wdata[0x0000000aU])));
    vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__w_val_burst[6U] 
        = (((QData)((IData)(memory_subsystem__DOT__mem_req_wdata[0x0000000dU])) 
            << 0x00000020U) | (QData)((IData)(memory_subsystem__DOT__mem_req_wdata[0x0000000cU])));
    vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__w_val_burst[7U] 
        = (((QData)((IData)(memory_subsystem__DOT__mem_req_wdata[0x0000000fU])) 
            << 0x00000020U) | (QData)((IData)(memory_subsystem__DOT__mem_req_wdata[0x0000000eU])));
    memory_subsystem__DOT__trace_fire = ((IData)(vlSelfRef.trace_ready) 
                                         & (IData)(vlSelfRef.trace_valid));
    vlSelfRef.avm_writedata = vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__w_val_burst
        [vlSelfRef.memory_subsystem__DOT__avm_sdram__DOT__burst_cnt];
    vlSelfRef.memory_subsystem__DOT__lsq_trace_valid 
        = ((IData)(memory_subsystem__DOT__trace_fire) 
           & ((0U == (7U & (vlSelfRef.trace_data[1U] 
                            >> 0x00000014U))) | ((1U 
                                                  == 
                                                  (7U 
                                                   & (vlSelfRef.trace_data[1U] 
                                                      >> 0x00000014U))) 
                                                 | (2U 
                                                    == 
                                                    (7U 
                                                     & (vlSelfRef.trace_data[1U] 
                                                        >> 0x00000014U))))));
    vlSelfRef.memory_subsystem__DOT__is_tlb_fill_now 
        = ((IData)(memory_subsystem__DOT__trace_fire) 
           & (0x00400000U == (0x00700000U & vlSelfRef.trace_data[1U])));
    vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
        = (0x0000ffffffffffffULL & ((IData)(vlSelfRef.memory_subsystem__DOT__is_tlb_fill_now)
                                     ? (((QData)((IData)(
                                                         vlSelfRef.trace_data[1U])) 
                                         << 0x00000020U) 
                                        | (QData)((IData)(
                                                          vlSelfRef.trace_data[0U])))
                                     : vlSelfRef.memory_subsystem__DOT__issue_buf_vaddr));
    vlSelfRef.memory_subsystem__DOT__launch_issue_now 
        = ((~ (IData)(vlSelfRef.memory_subsystem__DOT__is_tlb_fill_now)) 
           & ((IData)(vlSelfRef.memory_subsystem__DOT__issue_buf_valid) 
              & ((~ ((0U != (IData)(vlSelfRef.memory_subsystem__DOT__u_l1__DOT__state)) 
                     | (IData)(vlSelfRef.memory_subsystem__DOT__u_l1__DOT__mshr_full))) 
                 & (IData)(vlSelfRef.memory_subsystem__DOT__tlb_ready))));
    vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 0U;
    vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 0U;
    if (((IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                  [0U] >> 0x36U)) & ((0x0000000fffffffffULL 
                                      & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                      [0U]) == (0x0000000fffffffffULL 
                                                & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                                   >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 0U;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [1U] >> 0x36U))) & ((0x0000000fffffffffULL 
                                          & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                          [1U]) == 
                                         (0x0000000fffffffffULL 
                                          & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                             >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 1U;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [2U] >> 0x36U))) & ((0x0000000fffffffffULL 
                                          & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                          [2U]) == 
                                         (0x0000000fffffffffULL 
                                          & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                             >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 2U;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [3U] >> 0x36U))) & ((0x0000000fffffffffULL 
                                          & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                          [3U]) == 
                                         (0x0000000fffffffffULL 
                                          & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                             >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 3U;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [4U] >> 0x36U))) & ((0x0000000fffffffffULL 
                                          & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                          [4U]) == 
                                         (0x0000000fffffffffULL 
                                          & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                             >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 4U;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [5U] >> 0x36U))) & ((0x0000000fffffffffULL 
                                          & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                          [5U]) == 
                                         (0x0000000fffffffffULL 
                                          & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                             >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 5U;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [6U] >> 0x36U))) & ((0x0000000fffffffffULL 
                                          & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                          [6U]) == 
                                         (0x0000000fffffffffULL 
                                          & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                             >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 6U;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [7U] >> 0x36U))) & ((0x0000000fffffffffULL 
                                          & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                          [7U]) == 
                                         (0x0000000fffffffffULL 
                                          & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                             >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 7U;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [8U] >> 0x36U))) & ((0x0000000fffffffffULL 
                                          & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                          [8U]) == 
                                         (0x0000000fffffffffULL 
                                          & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                             >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 8U;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [9U] >> 0x36U))) & ((0x0000000fffffffffULL 
                                          & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                          [9U]) == 
                                         (0x0000000fffffffffULL 
                                          & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                             >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 9U;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [0x0aU] >> 0x36U))) & ((0x0000000fffffffffULL 
                                             & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                             [0x0aU]) 
                                            == (0x0000000fffffffffULL 
                                                & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                                   >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 0x0aU;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [0x0bU] >> 0x36U))) & ((0x0000000fffffffffULL 
                                             & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                             [0x0bU]) 
                                            == (0x0000000fffffffffULL 
                                                & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                                   >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 0x0bU;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [0x0cU] >> 0x36U))) & ((0x0000000fffffffffULL 
                                             & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                             [0x0cU]) 
                                            == (0x0000000fffffffffULL 
                                                & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                                   >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 0x0cU;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [0x0dU] >> 0x36U))) & ((0x0000000fffffffffULL 
                                             & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                             [0x0dU]) 
                                            == (0x0000000fffffffffULL 
                                                & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                                   >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 0x0dU;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [0x0eU] >> 0x36U))) & ((0x0000000fffffffffULL 
                                             & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                             [0x0eU]) 
                                            == (0x0000000fffffffffULL 
                                                & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                                   >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 0x0eU;
    }
    if ((((~ (IData)(vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found)) 
          & (IData)((vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                     [0x0fU] >> 0x36U))) & ((0x0000000fffffffffULL 
                                             & vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__ways
                                             [0x0fU]) 
                                            == (0x0000000fffffffffULL 
                                                & (vlSelfRef.memory_subsystem__DOT__tlb_vaddr_mux 
                                                   >> 0x0cU))))) {
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_found = 1U;
        vlSelfRef.memory_subsystem__DOT__u_tlb__DOT__hit_index = 0x0fU;
    }
    vlSelfRef.memory_subsystem__DOT__tlb_start = ((IData)(vlSelfRef.memory_subsystem__DOT__is_tlb_fill_now) 
                                                  | (IData)(vlSelfRef.memory_subsystem__DOT__launch_issue_now));
}

VL_ATTR_COLD void Vmemsys___024root___eval_stl(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_stl\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VstlTriggered[0U])) {
        Vmemsys___024root___stl_sequent__TOP__0(vlSelf);
    }
}

VL_ATTR_COLD bool Vmemsys___024root___eval_phase__stl(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_phase__stl\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VstlExecute;
    // Body
    Vmemsys___024root___eval_triggers__stl(vlSelf);
    __VstlExecute = Vmemsys___024root___trigger_anySet__stl(vlSelfRef.__VstlTriggered);
    if (__VstlExecute) {
        Vmemsys___024root___eval_stl(vlSelf);
    }
    return (__VstlExecute);
}

bool Vmemsys___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmemsys___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (IData)(Vmemsys___024root___trigger_anySet__ico(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

bool Vmemsys___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmemsys___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(Vmemsys___024root___trigger_anySet__act(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: @(posedge clk)\n");
    }
    if ((1U & (IData)((triggers[0U] >> 1U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 1 is active: @(negedge rst_n)\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vmemsys___024root___ctor_var_reset(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___ctor_var_reset\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
    vlSelf->clk = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 16707436170211756652ull);
    vlSelf->rst_n = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 1638864771569018232ull);
    VL_SCOPED_RAND_RESET_W(121, vlSelf->trace_data, __VscopeHash, 2099819338854512805ull);
    vlSelf->trace_valid = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 13633812473643571344ull);
    vlSelf->trace_ready = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 11344107219959298951ull);
    vlSelf->avm_address = VL_SCOPED_RAND_RESET_I(29, __VscopeHash, 5112085388710105444ull);
    vlSelf->avm_burstcount = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 3208885328359288432ull);
    vlSelf->avm_read = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 5632225227845640601ull);
    vlSelf->avm_write = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 4458380006902512272ull);
    vlSelf->avm_writedata = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 6454087740803427708ull);
    vlSelf->avm_byteenable = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 841647532907098410ull);
    vlSelf->avm_readdata = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 17266425150692792044ull);
    vlSelf->avm_readdatavalid = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 13073551615116878615ull);
    vlSelf->avm_waitrequest = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 2175940966374500423ull);
    vlSelf->memory_subsystem__DOT__lsq_trace_valid = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 4822149937768096877ull);
    vlSelf->memory_subsystem__DOT__tlb_ready = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8263405719320284021ull);
    vlSelf->memory_subsystem__DOT__tlb_valid = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 4843524777729848034ull);
    vlSelf->memory_subsystem__DOT__tlb_result_paddr = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 6993362101922252285ull);
    vlSelf->memory_subsystem__DOT__is_tlb_fill_now = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 15239370643939393358ull);
    vlSelf->memory_subsystem__DOT__lsq_vaddr_to_l1 = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 6519157749417644671ull);
    vlSelf->memory_subsystem__DOT__lsq_valid_to_l1 = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 15430175245856969755ull);
    vlSelf->memory_subsystem__DOT__lsq_wdata_to_l1 = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 11634481756167236655ull);
    vlSelf->memory_subsystem__DOT__lsq_issue_op = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 1171822028222769068ull);
    vlSelf->memory_subsystem__DOT__lsq_sq_ready = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 10282269528307178727ull);
    vlSelf->memory_subsystem__DOT__issue_buf_valid = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 14421882440004005246ull);
    vlSelf->memory_subsystem__DOT__issue_buf_vaddr = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 17472134041663331512ull);
    vlSelf->memory_subsystem__DOT__issue_buf_wdata = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 11488777292140429399ull);
    vlSelf->memory_subsystem__DOT__issue_buf_op = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 10213651444719198439ull);
    vlSelf->memory_subsystem__DOT__launch_issue_now = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 10600856536392741743ull);
    vlSelf->memory_subsystem__DOT__tlb_start = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 1918819769837053095ull);
    vlSelf->memory_subsystem__DOT__tlb_vaddr_mux = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 7765845674406881927ull);
    vlSelf->memory_subsystem__DOT__l1_l2_wb_paddr = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 11215136689331161113ull);
    VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__l1_l2_wb_data, __VscopeHash, 12081254635479543207ull);
    vlSelf->memory_subsystem__DOT__l2_l1_wb_ack = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 3506135671358967591ull);
    vlSelf->memory_subsystem__DOT__l1_l2_req_valid = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 11645235935107414367ull);
    vlSelf->memory_subsystem__DOT__l1_l2_req_paddr = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 6697185619907452774ull);
    vlSelf->memory_subsystem__DOT__l2_l1_data_valid = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 4018589147299579170ull);
    vlSelf->memory_subsystem__DOT__l2_l1_data_paddr = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 17947771113576467938ull);
    VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__l2_l1_data, __VscopeHash, 14511153455600156700ull);
    vlSelf->memory_subsystem__DOT__mem_req_valid = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 756798016109346807ull);
    vlSelf->memory_subsystem__DOT__mem_req_is_write = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8201365760312018118ull);
    vlSelf->memory_subsystem__DOT__mem_req_addr = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 3218564227080806632ull);
    vlSelf->memory_subsystem__DOT__mem_resp_paddr = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 3419988592122877956ull);
    VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__mem_resp_rdata, __VscopeHash, 14137377174840545024ull);
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_lsq__DOT__lq_state[__Vi0] = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 4177160531672216136ull);
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_lsq__DOT__lq_vaddr[__Vi0] = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 13810495657514917406ull);
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_lsq__DOT__lq_id[__Vi0] = VL_SCOPED_RAND_RESET_I(4, __VscopeHash, 8356234762965653394ull);
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_lsq__DOT__lq_before_vec[__Vi0] = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 2185085328427157867ull);
    }
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__lq_head = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 11714639744486858852ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__lq_tail = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 5909788928892115002ull);
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_lsq__DOT__sq_state[__Vi0] = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 4490448480822857762ull);
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_lsq__DOT__sq_vaddr[__Vi0] = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 18316220266770013325ull);
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_lsq__DOT__sq_wdata[__Vi0] = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 10131063033634821522ull);
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_lsq__DOT__sq_id[__Vi0] = VL_SCOPED_RAND_RESET_I(4, __VscopeHash, 1039526820204740905ull);
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_lsq__DOT__sq_before_vec[__Vi0] = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 8124210558390274682ull);
    }
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__sq_head = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 3158662446266423548ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__sq_tail = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 8209706212966623250ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__lq_found = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 325675538294232750ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__lq_found_entry = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 16824435086268040783ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__is_unresolved_store = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8531004037407155306ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__sq_found = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 4917895417712346846ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__sq_found_entry = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 5363663102114891982ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__is_unresolved_load = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8720926179037213438ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__unresolved_val_store = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 2031298839710165791ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__unnamedblk13__DOT__unnamedblk14__DOT__idx = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 4979245226774008906ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__unnamedblk15__DOT__unnamedblk16__DOT__idx = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 15556899473584370725ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__unnamedblk17__DOT__resolve_done = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 12218970345837407004ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__unnamedblk17__DOT__unnamedblk18__DOT__unnamedblk19__DOT__idx = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 1832612020003262170ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__unnamedblk20__DOT__resolve_done = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6571790196203655824ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__unnamedblk20__DOT__unnamedblk21__DOT__unnamedblk22__DOT__idx = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 1471002765685632249ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__unnamedblk23__DOT__unnamedblk24__DOT__idx = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 1183325006621499776ull);
    vlSelf->memory_subsystem__DOT__u_lsq__DOT__unnamedblk25__DOT__unnamedblk26__DOT__idx = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 1105154064658248479ull);
    for (int __Vi0 = 0; __Vi0 < 16; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_tlb__DOT__ways[__Vi0] = VL_SCOPED_RAND_RESET_Q(55, __VscopeHash, 17915948558097499553ull);
    }
    for (int __Vi0 = 0; __Vi0 < 16; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_tlb__DOT__lrumat[__Vi0] = VL_SCOPED_RAND_RESET_I(16, __VscopeHash, 5468135342232334907ull);
    }
    vlSelf->memory_subsystem__DOT__u_tlb__DOT__hit_index = VL_SCOPED_RAND_RESET_I(4, __VscopeHash, 17485369051311849594ull);
    vlSelf->memory_subsystem__DOT__u_tlb__DOT__free_index = VL_SCOPED_RAND_RESET_I(4, __VscopeHash, 9887691072451217287ull);
    vlSelf->memory_subsystem__DOT__u_tlb__DOT__hit_found = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 4057733543497172136ull);
    for (int __Vi0 = 0; __Vi0 < 4; ++__Vi0) {
        for (int __Vi1 = 0; __Vi1 < 2; ++__Vi1) {
            VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__u_l1__DOT__set_contents[__Vi0][__Vi1], __VscopeHash, 16854863344883186573ull);
        }
    }
    for (int __Vi0 = 0; __Vi0 < 4; ++__Vi0) {
        for (int __Vi1 = 0; __Vi1 < 2; ++__Vi1) {
            vlSelf->memory_subsystem__DOT__u_l1__DOT__tags[__Vi0][__Vi1] = VL_SCOPED_RAND_RESET_I(22, __VscopeHash, 16701937118869948518ull);
        }
    }
    vlSelf->memory_subsystem__DOT__u_l1__DOT__lru = VL_SCOPED_RAND_RESET_I(4, __VscopeHash, 5499660573543507152ull);
    for (int __Vi0 = 0; __Vi0 < 4; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l1__DOT__set_valids[__Vi0] = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 4474726065824946227ull);
    }
    for (int __Vi0 = 0; __Vi0 < 4; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l1__DOT__set_dirty[__Vi0] = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 17224230861403738943ull);
    }
    vlSelf->memory_subsystem__DOT__u_l1__DOT__state = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 2712871623372154508ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__curr_index = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 2404099320335578497ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__curr_is_write = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 15503041580897464756ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__curr_wdata = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 283891603587686754ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__curr_word_offset = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 3815839711374900243ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__mshr_dup = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 15075939784374730929ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__mshr_dup_idx = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 10879046494105985103ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__evict_way_l = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 15025335664804901853ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__mshr_install_done = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 4062536282935885693ull);
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l1__DOT__mshr_state[__Vi0] = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 14105011766812970434ull);
    }
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l1__DOT__mshr_paddr[__Vi0] = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 8854377661599503835ull);
    }
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l1__DOT__mshr_index[__Vi0] = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 10994135618008481588ull);
    }
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__u_l1__DOT__mshr_block[__Vi0], __VscopeHash, 6789029764499198164ull);
    }
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l1__DOT__mshr_store_mask[__Vi0] = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 11082069024920125492ull);
    }
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__u_l1__DOT__mshr_store_data[__Vi0], __VscopeHash, 3125218425397553047ull);
    }
    VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__u_l1__DOT__install_block, __VscopeHash, 13791723759144126270ull);
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l1__DOT__wb_paddr_q[__Vi0] = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 171257077387444244ull);
    }
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__u_l1__DOT__wb_data_q[__Vi0], __VscopeHash, 10294356127146662708ull);
    }
    vlSelf->memory_subsystem__DOT__u_l1__DOT__wb_head = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 17835411389219574354ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__wb_tail = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 2037057366370579606ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__wb_count = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 10662739418972800981ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__wb_push = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 2825513364277687221ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__wb_push_paddr = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 13743415184595413753ull);
    VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__u_l1__DOT__wb_push_data, __VscopeHash, 3841910895684862400ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__wb_pop = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 7744434549756184466ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__wb_empty = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 7584168330551440546ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__wb_full = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 2788771366996843603ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__victim_dirty = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 12466211359601810423ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__victim_paddr = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 2367333899778611885ull);
    VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__u_l1__DOT__victim_data, __VscopeHash, 12606580786572905800ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__mshr_full = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6426496113473634018ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__mshr_free_idx = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 3191220558062881493ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__hit = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 13430642725410859627ull);
    vlSelf->memory_subsystem__DOT__u_l1__DOT__hit_way = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 359526186874024527ull);
    for (int __Vi0 = 0; __Vi0 < 16; ++__Vi0) {
        for (int __Vi1 = 0; __Vi1 < 4; ++__Vi1) {
            VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__u_l2__DOT__set_contents[__Vi0][__Vi1], __VscopeHash, 13180198442979234374ull);
        }
    }
    for (int __Vi0 = 0; __Vi0 < 16; ++__Vi0) {
        for (int __Vi1 = 0; __Vi1 < 4; ++__Vi1) {
            vlSelf->memory_subsystem__DOT__u_l2__DOT__tags[__Vi0][__Vi1] = VL_SCOPED_RAND_RESET_I(20, __VscopeHash, 12721666868963977745ull);
        }
    }
    for (int __Vi0 = 0; __Vi0 < 16; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l2__DOT__set_valids[__Vi0] = VL_SCOPED_RAND_RESET_I(4, __VscopeHash, 6109452533100038411ull);
    }
    for (int __Vi0 = 0; __Vi0 < 16; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l2__DOT__set_dirty[__Vi0] = VL_SCOPED_RAND_RESET_I(4, __VscopeHash, 7346839655140297319ull);
    }
    for (int __Vi0 = 0; __Vi0 < 16; ++__Vi0) {
        for (int __Vi1 = 0; __Vi1 < 4; ++__Vi1) {
            for (int __Vi2 = 0; __Vi2 < 4; ++__Vi2) {
                vlSelf->memory_subsystem__DOT__u_l2__DOT__lru_matrix[__Vi0][__Vi1][__Vi2] = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 3780003105531238351ull);
            }
        }
    }
    for (int __Vi0 = 0; __Vi0 < 4; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_state[__Vi0] = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 10658481730882498262ull);
    }
    for (int __Vi0 = 0; __Vi0 < 4; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_paddr[__Vi0] = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 6237920813453556927ull);
    }
    for (int __Vi0 = 0; __Vi0 < 4; ++__Vi0) {
        VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_block[__Vi0], __VscopeHash, 16117769389061718380ull);
    }
    for (int __Vi0 = 0; __Vi0 < 4; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_mem_issued[__Vi0] = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 7426932650177992104ull);
    }
    vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_issued_one = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 18288493559474517260ull);
    for (int __Vi0 = 0; __Vi0 < 4; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_paddr_q[__Vi0] = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 12356167367290760367ull);
    }
    for (int __Vi0 = 0; __Vi0 < 4; ++__Vi0) {
        VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_data_q[__Vi0], __VscopeHash, 17655659027374932334ull);
    }
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_head = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 6549627833237818879ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_tail = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 15185673413873886858ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_count = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 11419017746123526396ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_push = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 5137832439331512178ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_push_paddr = VL_SCOPED_RAND_RESET_I(30, __VscopeHash, 5723471205530821997ull);
    VL_SCOPED_RAND_RESET_W(512, vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_push_data, __VscopeHash, 13706827351261723837ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_pop = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8480278893916705371ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_full = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 14988155796580892543ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__req_hit = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 10935124012976239550ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__req_hit_way = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 9589919688182167229ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_dup = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 5256632717041109983ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_full_l2 = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 1865998148962918765ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_free_idx = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 3178757950278155633ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_hit = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 14031985922792086106ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_hit_way = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 8955989562087048436ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_victim_way = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 7384700733895287496ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_found_invalid = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 10384405498300048956ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_victim_dirty = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 2113979495611828498ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__wb_is_lru = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8969800118060104377ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_install_done = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 13663549531341456215ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_inst_index = VL_SCOPED_RAND_RESET_I(4, __VscopeHash, 13929973195665883503ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_inst_tag = VL_SCOPED_RAND_RESET_I(20, __VscopeHash, 11961286627767523124ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_inst_victim = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 8317709277451815688ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_inst_found_invalid = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 83399851455766636ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_inst_victim_dirty = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 11796828715626144886ull);
    vlSelf->memory_subsystem__DOT__u_l2__DOT__mshr_inst_is_lru = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6997310011994438423ull);
    vlSelf->memory_subsystem__DOT__avm_sdram__DOT__state = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 14560884139058350644ull);
    vlSelf->memory_subsystem__DOT__avm_sdram__DOT__r_addr = VL_SCOPED_RAND_RESET_I(29, __VscopeHash, 13187772007045855816ull);
    vlSelf->memory_subsystem__DOT__avm_sdram__DOT__burst_cnt = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 8938615008871475802ull);
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__avm_sdram__DOT__r_val_burst[__Vi0] = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 3796152662385178235ull);
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->memory_subsystem__DOT__avm_sdram__DOT__w_val_burst[__Vi0] = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 13666553423748593246ull);
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VstlTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VicoTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VactTriggered[__Vi0] = 0;
    }
    vlSelf->__Vtrigprevexpr___TOP__clk__0 = 0;
    vlSelf->__Vtrigprevexpr___TOP__rst_n__0 = 0;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VnbaTriggered[__Vi0] = 0;
    }
}
