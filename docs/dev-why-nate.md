# `dev/why-nate` Debug Branch

This branch adds two things for FPGA bring-up:

1. An L1-to-memory bypass path so you can test without L2 in the middle.
2. Avalon-visible debug registers so a stall prints useful state instead of hanging silently.

## What Changed

- `memory_subsystem` now has a `BYPASS_L2` parameter.
- `memory_subsystem_avl_wrapper` passes `BYPASS_L2=1` by default on this branch.
- `send_trace.c` now times out on hard stalls and dumps debug register contents.
- `lsq.sv` now exposes `dbg_duplicate_store_id`, which goes high when two live SQ entries share the same store ID.

## Bypass Mode

On this branch, the Avalon wrapper enables the bypass path by default:

- [mem_avl_wrapper.sv](/Users/spotta/Desktop/School/aca/memlab/mem_avl_wrapper.sv)

That means:

- L1 miss reads go straight to the memory interface.
- L1 writebacks go straight to the memory interface.
- L2 is skipped for the FPGA wrapper build.

If you want to compare against the original path, set `BYPASS_L2` back to `1'b0` in the wrapper instantiation or override the parameter from your top-level.

## Avalon Debug Register Map

The wrapper address space is now wider than the original 4-word map.

Base control registers:

- `0x00` `trace_addr`
- `0x04` `trace_data`
- `0x08` `trace_valid`
- `0x0C` `trace_ready`

Debug registers:

- `0x10` `debug_status0`
- `0x14` `debug_status1`
- `0x18` `sq[0]`
- `0x1C` `sq[1]`
- `0x20` `sq[2]`
- `0x24` `sq[3]`
- `0x28` `sq[4]`
- `0x2C` `sq[5]`
- `0x30` `sq[6]`
- `0x34` `sq[7]`

`debug_status0` bit layout:

- bit 0: `trace_valid_reg`
- bit 1: `trace_ready_wire`
- bit 2: `trace_fire`
- bit 3: `lsq_lq_ready`
- bit 4: `lsq_sq_ready`
- bit 5: `l1_busy_to_lsq`
- bit 6: `issue_buf_valid`
- bit 7: `u_l1.mshr_full`
- bit 8: `dbg_l2_req_pending_valid`
- bit 9: `dbg_l2_install_pending_valid`
- bit 10: `u_lsq.dbg_duplicate_store_id`
- bit 11: `BYPASS_L2`
- bit 12: `mem_req_valid`
- bit 13: `mem_req_is_write`

`debug_status1` bit layout:

- bits `[2:0]`: `trace_op`
- bits `[5:3]`: `u_l1.state`
- bits `[8:6]`: `u_lsq.sq_head`
- bits `[11:9]`: `u_lsq.sq_tail`
- bits `[15:12]`: count of live `sq_id == 8` entries

Each `sq[i]` register packs:

- bit 7: entry active
- bits `[6:3]`: `sq_id`
- bits `[2:0]`: `sq_state`

SQ state encoding from `lsq.sv`:

- `0`: `SQ_EMPTY`
- `1`: `SQ_UNRESOLVED`
- `2`: `SQ_WAITING_ADDR`
- `3`: `SQ_WAITING_DATA`
- `4`: `SQ_WAITING_ISSUE`

## How To Use It

Build the sender:

```bash
gcc -Wall -Wextra -std=c11 -o send_trace_debug send_trace.c
```

Run it the same way as before:

```bash
./send_trace_debug mem-traces-v2/traces/dgemm3_lsq88_real.bin
```

If the FPGA hard-stalls, the program now prints:

- whether the blocked record is stuck on `trace_ready`
- whether `sq_ready` is low
- whether `u_l1.mshr_full` is high
- whether duplicate live store IDs exist
- the full SQ state and IDs for entries `0..7`

## What To Look For

If trace 195 is blocked before acceptance, the most important pattern is:

- `trace_valid_reg = 1`
- `trace_ready_wire = 0`
- `lsq_sq_ready = 0`

That means the incoming store is blocked at the SQ boundary.

If `dbg_duplicate_store_id = 1` or `sq_id8_live_count > 1`, that is strong evidence for the ID-reuse theory.

If `u_l1.mshr_full = 1`, then the bypass/L2 comparison becomes very informative:

- stall disappears with `BYPASS_L2=1`: L2 path is a strong suspect
- stall still happens with `BYPASS_L2=1`: focus on LSQ/L1/trace flow first

## Notes

- The wrapper Avalon slave address bus widened from 2 bits to 6 bits. If your Platform Designer wrapper hardcodes the old width, regenerate or reconnect that interface before testing.
- The normal simulation path is still intact. `tb_memsys_v2` still passes the 5k smoke run on this branch.
