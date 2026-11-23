
FOR PART 3.

iverilog -g2012 -o a_true part3/fault_A.sv rtl/alu8.sv rtl/addsub8.sv && vvp a_true
iverilog -g2012 -o a_mut part3/fault_A.sv mutants/A/alu8.sv rtl/addsub8.sv && vvp a_mut
iverilog -g2012 -o b_true part3/fault_B.sv rtl/program_counter.sv && vvp b_true
iverilog -g2012 -o b_mut part3/fault_B.sv mutants/B/program_counter.sv && vvp b_mut
