// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VMEMSYS__SYMS_H_
#define VERILATED_VMEMSYS__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vmemsys.h"

// INCLUDE MODULE CLASSES
#include "Vmemsys___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES) Vmemsys__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vmemsys* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vmemsys___024root              TOP;

    // CONSTRUCTORS
    Vmemsys__Syms(VerilatedContext* contextp, const char* namep, Vmemsys* modelp);
    ~Vmemsys__Syms();

    // METHODS
    const char* name() const { return TOP.vlNamep; }
};

#endif  // guard
