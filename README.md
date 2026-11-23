FOR PART 2.

**\# Outputs: sim/part2.log and sim/part2\_timing.csv (timing table).**

**ROOT="$(cd "$(dirname "$0")/.." && pwd)"**

**mkdir -p "$ROOT/sim"**

**iverilog -g2012 -Wall -o "$ROOT/sim/part2.vvp" "$ROOT/rtl/sequence\_detector.sv" "$ROOT/tb/tb\_sequence\_detector.sv" || exit 1**

**cd "$ROOT/sim" && vvp -n part2.vvp | tee part2.log**

**if grep -q "^TEST PASSED" part2.log; then echo "PART II REGRESSION: PASS"**

**else echo "PART II REGRESSION: FAIL"; exit 1; fi**





FOR PART 3.

iverilog -g2012 -o a\_true part3/fault\_A.sv rtl/alu8.sv rtl/addsub8.sv && vvp a\_true iverilog -g2012 -o a\_mut part3/fault\_A.sv mutants/A/alu8.sv rtl/addsub8.sv && vvp a\_mut iverilog -g2012 -o b\_true part3/fault\_B.sv rtl/program\_counter.sv && vvp b\_true iverilog -g2012 -o b\_mut part3/fault\_B.sv mutants/B/program\_counter.sv && vvp b\_mut

