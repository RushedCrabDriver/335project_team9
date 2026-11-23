# Outputs: sim/part2.log (console log) and sim/part2_timing.csv (timing table).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/sim"
iverilog -g2012 -Wall -o "$ROOT/sim/part2.vvp" "$ROOT/rtl/sequence_detector.sv" "$ROOT/tb/tb_sequence_detector.sv" || exit 1
cd "$ROOT/sim" && vvp -n part2.vvp | tee part2.log
if grep -q "^TEST PASSED" part2.log; then echo "PART II REGRESSION: PASS"
else echo "PART II REGRESSION: FAIL"; exit 1; fi
