Definition
In this lab you will design an out-of-order processor for the chArm-v6 ISA with a useful testing interface on the DE10-Nano. We affectionately call this the Ozone processor ("out-of-order → OOO → O3 → Ozone"). We provide a large amount of code for the testing harness Download the testing harness. Here is an overview of the expected process.

On the DE10-Nano, the user will run a program on the HPS to communicate with the FPGA. The teaching staff have provided this tool. It is configured via config file. Running it without arguments will provide help information. This is what we will be used to grade. It can:
load programs into either the FPGAs memory or a Verilator testbench's memory;
reset the processor;
poll the processor for a completion signal;
inspect the state of memory and registers after completion.
After downloading the Ozone design to the FPGA, the user will load a program into the processor's memory and pass a reset signal to it. The HPS will then begin to poll for the completion signal output by the processor.
Upon receiving the reset signal, the processor will begin executing in EL1, starting at a hardcoded entry point (set in the config). At EL1, the processor is always direct-mapped to DRAM.
The code beginning at this hardcoded entry point is a "bootloader" for our program. The bootloader runs at EL1. Its job is to:
set the special-purpose registers relevant for this program (SP_EL0, SPSR_EL1, ELR_EL1);
write the EL0 memory mappings relevant for this particular program. The mappings will be stored in a single paged marked in the config. This single page will serve as the "translation table" for the processor (or a "page table" in x86 terms) and can hold at most 200 entries. A "page walk" will just be an O(1) lookup of this table by the processor.
In the bootloader, the processor will reach an ERET instruction which switches it to EL0 and branches to the userspace program's entry point.
Upon jumping to userspace, the processor will experience a TLB miss, upon which it perform a "page walk" to find its mapping, and then retry the instruction.
The processor will run userspace code out-of-order. More details about the specs of the processor are detailed in a different section below.
The final userspace instruction of the processor will be a RET to 0x0. This is expected to cause an un-recoverable exception and transfer control to EL1. The exact exception is an Instruction Fetch Memory Abort, though, should you not do any extra credit, you may simplify this and treat all exceptions the same.
The segfault exception handler (location specified in config) will never return. This is done by writing a terminate value to the special-purpose register ACTLR_EL1, which the processor will use to fire a termination signal (and if running on the FPGA, blink a light to indicate the program has completed). The handler will then spinloop forever.
The HPS will see that the completion signal has been set and print out the modified memory state of the processor.
The chArm-v6 Instruction Set Architecture
Here are all the instructions in the chArm-v6 ISA. As always, the Armv8-A manual is the definitive reference for their expected behavior.

chArm-v6 ISA

The Ozone Processor Specification
The processor design and implementation must have the following features.

Single core, single-issue, no SMT.
Out-of-order execution with speculation and precise exceptions (meaning Tomasulo + ROB).
Cracks opcodes into micro-op sequences (detailed below) destined for different functional units.
Contains a fully-associative 16-entry iTLB.
Contains a branch target buffer (BTB), updated on branch resolution.
Contains a Two-Level Adaptive Branch Predictor, updated on branch resolution.
Contains at least 1 arithmetic unit (adder). This should be simple.
Contains at least 1 shifter (lsl, lsr, asr). Reuse yours from the first project, or create a simple one yourself.
Contains at least 1 logic unit (xor, and, or, not). This should be simple.
Contains an address generation unit (AGU). This is just an adder which is used only to compute effective addresses.
Contains a memory unit. Reuse your unit from the memory project.
Contains a floating point unit. A parameterized FPU designLinks to an external site. is available on GitHub, and has been used on the CVA6, a reputable open-source processor. The docs explain how the interface works; the ready-valid handshake should look familiar.
Micro-Ops (uops) and Other Matters
The table below shows various micro-architectural details of the chArm-v6 ISA as implemented on the Ozone processor.
Pay careful attention to the syntax of uOPs.
The form uOP1+uOP2 denotes sequencing, i.e., uOP1 followed by uOP2. This is dictated by a data dependence between the uOPs.
The form uOP1 & uOP2 denotes concurrency, i.e., uOP1 and uOP2 can be executed in parallel.
The form (uOP) is used for clarity where the form of the uOP involves multiple words.
Think through the details of instruction commit when a single instruction contains multiple uOPs.
chArm-v6 uOPs details

Deliverables
18 pts: You must provide six original test cases that do something interesting. At least three of the test cases must use floating-point computations. We expect these test cases to run unprivileged code. (Talk to us if you want to create an EL1 test case.)
52 pts: Your baseline processor design compiles and simulates successfully in Verilator.
20 pts: Your baseline processor works on the DE10-Nano dev board.
Extras
10 pts: Distinguish between different types of exceptions.
10 pts: Make it so writing a terminate value to the special-purpose register ACTLR_EL1 causes the processor to enter a low power state. This will be tested by either placing a finger on the FPGA to see if it's hot, or seeing whether a core is being hogged by Verilator.
30 pts: Make your front end 2-way superscalar, and beef up your back end so that it has the capacity to handle this without stalling uselessly.
30 pts: Add the SVC instruction, and use a particular value to do clean termination, rather than using just a segfault. You should be able to differentiate between a segfault termination and an SVC termination.   Effectively, this is implementing a sycall. Syscalls with different numbers should fail with a completely different error (in a different exception handler).
Submission & Grading
Please submit a zip or tar file including:

Your test cases.
Your SystemVerilog files.
Your entire Quartus project directory.
A brief README or Makefile that tells the teaching staff how to build and run your simulator and/or your build.
The test files will also be run on an actual ARM processor.  You will be graded on your ability to match the output of the provided testcases using the provided tool. All architectural state is expected to match. There are no hidden testcases.

Tips
We are not concerned with the speeding up fetching much beyond branch prediction and an iTLB. You do not need to create an L1i cache.
We only care about the valid bit on a translation block ("page"). Don't worry about other flags such as execute, read-only, etc.
All branches can execute speculatively, and your processor must be able to handle mispredictions.
We make certain guarantees about what inputs this processor will be given. You are encouraged to hardcode the behavior of your processor to fit only these use cases.