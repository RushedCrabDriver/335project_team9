#!/usr/bin/env bash
# Part II regression: build and run the sequence_detector self-checking testbench.
# Usage (from the project root, i.e. the folder that holds rtl/ and tb/):
#   bash scripts/run_part2.sh            # Icarus Verilog (default)
#   SIM=verilator bash scripts/run_part2.sh
# Outputs: sim/part2.log (full transcript) and sim/part2_timing.csv (timing table).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/sim"
mkdir -p "$OUT"
cd "$OUT"
SRCS=("$ROOT/rtl/sequence_detector.sv" "$ROOT/tb/tb_sequence_detector.sv")
DUT_SRC="${DUT_SRC:-}"          # optional: override the DUT file (e.g. a faulty copy)
if [[ -n "$DUT_SRC" ]]; then SRCS[0]="$DUT_SRC"; fi

case "${SIM:-iverilog}" in
  iverilog)
    iverilog -g2012 -Wall -o part2.vvp "${SRCS[@]}"
    set +e; vvp -n part2.vvp | tee part2.log; rc=${PIPESTATUS[0]}; set -e ;;
  verilator)
    verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style \
      --top-module tb_sequence_detector -Mdir "${TMPDIR:-/tmp}/obj_part2" -o vtb_part2 "${SRCS[@]}" >/dev/null
    set +e; "${TMPDIR:-/tmp}/obj_part2/vtb_part2" | tee part2.log; rc=${PIPESTATUS[0]}; set -e ;;
  *) echo "unknown SIM=${SIM}"; exit 2 ;;
esac

if [[ $rc -eq 0 ]] && grep -q "^TEST PASSED" part2.log; then
  echo "PART II REGRESSION: PASS"
else
  echo "PART II REGRESSION: FAIL"; exit 1
fi
