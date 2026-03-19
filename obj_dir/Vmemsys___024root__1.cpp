// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmemsys.h for the primary calling header

#include "Vmemsys__pch.h"

void Vmemsys___024root___nba_sequent__TOP__0(Vmemsys___024root* vlSelf);

void Vmemsys___024root___eval_nba(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_nba\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((3ULL & vlSelfRef.__VnbaTriggered[0U])) {
        Vmemsys___024root___nba_sequent__TOP__0(vlSelf);
    }
}

void Vmemsys___024root___trigger_orInto__act(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___trigger_orInto__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

void Vmemsys___024root___eval_triggers__act(Vmemsys___024root* vlSelf);

bool Vmemsys___024root___eval_phase__act(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_phase__act\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vmemsys___024root___eval_triggers__act(vlSelf);
    Vmemsys___024root___trigger_orInto__act(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    return (0U);
}

void Vmemsys___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___trigger_clear__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

bool Vmemsys___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);

bool Vmemsys___024root___eval_phase__nba(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_phase__nba\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vmemsys___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        Vmemsys___024root___eval_nba(vlSelf);
        Vmemsys___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmemsys___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
bool Vmemsys___024root___eval_phase__ico(Vmemsys___024root* vlSelf);
#ifdef VL_DEBUG
VL_ATTR_COLD void Vmemsys___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

void Vmemsys___024root___eval(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VicoIterCount;
    IData/*31:0*/ __VnbaIterCount;
    // Body
    __VicoIterCount = 0U;
    vlSelfRef.__VicoFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00000064U < __VicoIterCount)))) {
#ifdef VL_DEBUG
            Vmemsys___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
#endif
            VL_FATAL_MT("memsys.sv", 16, "", "DIDNOTCONVERGE: Input combinational region did not converge after 100 tries");
        }
        __VicoIterCount = ((IData)(1U) + __VicoIterCount);
    } while (Vmemsys___024root___eval_phase__ico(vlSelf));
    __VnbaIterCount = 0U;
    do {
        if (VL_UNLIKELY(((0x00000064U < __VnbaIterCount)))) {
#ifdef VL_DEBUG
            Vmemsys___024root___dump_triggers__act(vlSelfRef.__VnbaTriggered, "nba"s);
#endif
            VL_FATAL_MT("memsys.sv", 16, "", "DIDNOTCONVERGE: NBA region did not converge after 100 tries");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        vlSelfRef.__VactIterCount = 0U;
        do {
            if (VL_UNLIKELY(((0x00000064U < vlSelfRef.__VactIterCount)))) {
#ifdef VL_DEBUG
                Vmemsys___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
#endif
                VL_FATAL_MT("memsys.sv", 16, "", "DIDNOTCONVERGE: Active region did not converge after 100 tries");
            }
            vlSelfRef.__VactIterCount = ((IData)(1U) 
                                         + vlSelfRef.__VactIterCount);
        } while (Vmemsys___024root___eval_phase__act(vlSelf));
    } while (Vmemsys___024root___eval_phase__nba(vlSelf));
}

#ifdef VL_DEBUG
void Vmemsys___024root___eval_debug_assertions(Vmemsys___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmemsys___024root___eval_debug_assertions\n"); );
    Vmemsys__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if (VL_UNLIKELY(((vlSelfRef.clk & 0xfeU)))) {
        Verilated::overWidthError("clk");
    }
    if (VL_UNLIKELY(((vlSelfRef.rst_n & 0xfeU)))) {
        Verilated::overWidthError("rst_n");
    }
    if (VL_UNLIKELY(((vlSelfRef.trace_data[3U] & 0xfe000000U)))) {
        Verilated::overWidthError("trace_data");
    }
    if (VL_UNLIKELY(((vlSelfRef.trace_valid & 0xfeU)))) {
        Verilated::overWidthError("trace_valid");
    }
    if (VL_UNLIKELY(((vlSelfRef.avm_readdatavalid & 0xfeU)))) {
        Verilated::overWidthError("avm_readdatavalid");
    }
    if (VL_UNLIKELY(((vlSelfRef.avm_waitrequest & 0xfeU)))) {
        Verilated::overWidthError("avm_waitrequest");
    }
}
#endif  // VL_DEBUG
