#!/usr/bin/env bash
# Compile and run the full memory_subsystem integration testbench via Verilator.
# Usage: ./test_memory_subsystem.sh

set -euo pipefail

SRCS="mem_pkg.sv mainmem.sv l2.sv l1.sv tlb.sv lsq.sv memsys.sv tb_memory_subsystem.sv"
OUT="tb_memory_subsystem_v"
OBJ_DIR="obj_dir"

echo "=== Compiling with Verilator ==="
verilator --binary --timing -sv +1800-2012ext+sv \
  -Wno-WIDTH -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
  --top-module tb_memory_subsystem $SRCS -o "$OUT"

echo ""
echo "=== Running tests ==="
"$OBJ_DIR/$OUT"
