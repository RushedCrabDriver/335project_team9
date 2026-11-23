#!/usr/bin/env bash
# Part III: run each minimal exposing test against the reference RTL (must PASS)
# and against the faulty variant in mutants/ (must report FAIL = fault detected).
# Usage: bash scripts/run_part3.sh      Output: sim/part3.log
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"; mkdir -p sim; B=sim/p3
run() { iverilog -g2012 -o "${B}_$1" "${@:2}" 2>/dev/null && vvp -n "${B}_$1" | grep -v finish; }
B=sim/p3
{
echo "=== Fault A: reference alu8 ===";  run Aref part3/min_fault_A.sv rtl/alu8.sv rtl/addsub8.sv
echo "=== Fault A: MUTANT A ===";        run Amut part3/min_fault_A.sv mutants/A/alu8.sv rtl/addsub8.sv
echo "=== Fault B: reference PC ===";    run Bref part3/min_fault_B.sv rtl/program_counter.sv
echo "=== Fault B: MUTANT B ===";        run Bmut part3/min_fault_B.sv mutants/B/program_counter.sv
} 2>&1 | tee sim/part3.log
rm -f ${B}_*
ok=1
grep -A4 "reference alu8" sim/part3.log | grep -q "^PASS" || ok=0
grep -A4 "reference PC"   sim/part3.log | grep -q "^PASS" || ok=0
grep -A4 "MUTANT A" sim/part3.log | grep -q "FAIL: fault A DETECTED" || ok=0
grep -A4 "MUTANT B" sim/part3.log | grep -q "FAIL: fault B DETECTED" || ok=0
[[ $ok == 1 ]] && echo "PART III: PASS (both faults detected, references clean)" || { echo "PART III: FAIL"; exit 1; }
