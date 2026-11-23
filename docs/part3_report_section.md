# Part III: Fault-Detection Challenge

Two intentionally faulty variants of the HW2 modules are in `mutants/`. The reference RTL in `rtl/` was not edited. Each fault has one minimal exposing test in `part3/`. Run all four simulations (each test on the reference and on its mutant) with:

```
bash scripts/run_part3.sh        # Icarus Verilog 12; transcript in sim/part3.log
```

A test passes on the reference and reports `FAIL: fault ... DETECTED` on the mutant. The script prints `PART III: PASS` only if both of those hold for both faults.

## Fault A: signed SLT implemented as an unsigned compare (`mutants/A/alu8.sv`)

**Minimal exposing test** (`part3/min_fault_A.sv`): `alu_control = 3'b101` (SLT), `a = 0x80` (-128), `b = 0x01` (+1). One operand pair with opposite signs.

| | result |
|---|---|
| Expected (signed: -128 < +1) | `0x01` |
| Reference `alu8` | `0x01` |
| Mutant A | `0x00` |

**Diagnosis.** The reference computes SLT as `arithmetic_result[7] ^ arithmetic_overflow`: the sign of `a - b` corrected by the signed-overflow flag. The mutant computes `a < b` on unsigned vectors. `0x80` is 128 unsigned, which is greater than 1, so the mutant returns 0. The two definitions agree whenever both operands have the same sign. They differ only when the signs differ, so a test using only same-sign operands cannot see this fault. A test with opposite-sign operands such as `0x80` versus `0x01` exposes it with a single vector.

## Fault B: stall has priority over redirect (`mutants/B/program_counter.sv`)

**Minimal exposing test** (`part3/min_fault_B.sv`): reset for one edge, then one normal edge (PC = `0x04`), then assert `stall = 1`, `redirect = 1`, `redirect_target = 0x20` together and apply one rising edge.

| | pc after edge |
|---|---|
| Expected (reset > redirect > stall) | `0x20` |
| Reference `program_counter` | `0x20` |
| Mutant B | `0x04` (held) |

**Diagnosis.** The reference applies its priority checks in the order reset, redirect, stall, increment. In the mutant the `if (stall) pc_next = pc;` line is moved after the redirect line, so stall overrides redirect. The fault shows up only when stall and redirect are asserted at the same edge. Stalling alone, redirecting alone and normal increments all behave correctly in the mutant. A test must therefore assert both controls on the same edge. The check is on the post-edge PC value, which differs (`0x04` vs `0x20`) by a full redirect target.

## Summary

| Fault | Module | Exposing stimulus | Expected | Mutant output |
|---|---|---|---|---|
| A | `alu8` | SLT, `0x80` vs `0x01` | `0x01` | `0x00` |
| B | `program_counter` | stall + redirect (target `0x20`) at one edge | `pc = 0x20` | `pc = 0x04` |
