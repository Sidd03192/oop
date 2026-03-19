// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vmemsys__pch.h"

//============================================================
// Constructors

Vmemsys::Vmemsys(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vmemsys__Syms(contextp(), _vcname__, this)}
    , clk{vlSymsp->TOP.clk}
    , rst_n{vlSymsp->TOP.rst_n}
    , trace_valid{vlSymsp->TOP.trace_valid}
    , trace_ready{vlSymsp->TOP.trace_ready}
    , avm_burstcount{vlSymsp->TOP.avm_burstcount}
    , avm_read{vlSymsp->TOP.avm_read}
    , avm_write{vlSymsp->TOP.avm_write}
    , avm_byteenable{vlSymsp->TOP.avm_byteenable}
    , avm_readdatavalid{vlSymsp->TOP.avm_readdatavalid}
    , avm_waitrequest{vlSymsp->TOP.avm_waitrequest}
    , trace_data{vlSymsp->TOP.trace_data}
    , avm_address{vlSymsp->TOP.avm_address}
    , avm_writedata{vlSymsp->TOP.avm_writedata}
    , avm_readdata{vlSymsp->TOP.avm_readdata}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vmemsys::Vmemsys(const char* _vcname__)
    : Vmemsys(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vmemsys::~Vmemsys() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vmemsys___024root___eval_debug_assertions(Vmemsys___024root* vlSelf);
#endif  // VL_DEBUG
void Vmemsys___024root___eval_static(Vmemsys___024root* vlSelf);
void Vmemsys___024root___eval_initial(Vmemsys___024root* vlSelf);
void Vmemsys___024root___eval_settle(Vmemsys___024root* vlSelf);
void Vmemsys___024root___eval(Vmemsys___024root* vlSelf);

void Vmemsys::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vmemsys::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vmemsys___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vmemsys___024root___eval_static(&(vlSymsp->TOP));
        Vmemsys___024root___eval_initial(&(vlSymsp->TOP));
        Vmemsys___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vmemsys___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vmemsys::eventsPending() { return false; }

uint64_t Vmemsys::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vmemsys::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vmemsys___024root___eval_final(Vmemsys___024root* vlSelf);

VL_ATTR_COLD void Vmemsys::final() {
    Vmemsys___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vmemsys::hierName() const { return vlSymsp->name(); }
const char* Vmemsys::modelName() const { return "Vmemsys"; }
unsigned Vmemsys::threads() const { return 1; }
void Vmemsys::prepareClone() const { contextp()->prepareClone(); }
void Vmemsys::atClone() const {
    contextp()->threadPoolpOnClone();
}
