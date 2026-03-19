// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmemsys.h for the primary calling header

#include "Vmemsys__pch.h"

void Vmemsys___024root___ctor_var_reset(Vmemsys___024root* vlSelf);

Vmemsys___024root::Vmemsys___024root(Vmemsys__Syms* symsp, const char* namep)
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vmemsys___024root___ctor_var_reset(this);
}

void Vmemsys___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vmemsys___024root::~Vmemsys___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
