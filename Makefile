# CSCI 335 project - Part I testbenches + mutants
#
#   make all       run everything (4 testbenches, then both mutants)
#   make test      only the 4 testbenches on the reference rtl
#   make mutants   ALU tb on mutant A, PC tb on mutant B
#   make alu / control_branch / pc / regfile / mutant_A / mutant_B
#   make clean
#
# default simulator is verilator, for icarus: make all SIM=iverilog
# rtl/ and mutants/ are never edited, mutant is just a different file in the list

SIM   ?= verilator
RTL   := rtl
TB    := tb
BUILD := build
LOGS  := logs

VFLAGS := --binary --timing -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-DECLFILENAME
IFLAGS := -g2012

# testbench first, then the modules it needs
ALU_SRCS  := $(TB)/tb_alu8.sv $(RTL)/addsub8.sv $(RTL)/alu8.sv
CB_SRCS   := $(TB)/tb_control_branch.sv $(RTL)/control_unit.sv $(RTL)/addsub8.sv $(RTL)/branch_unit.sv
PC_SRCS   := $(TB)/tb_program_counter.sv $(RTL)/program_counter.sv
RF_SRCS   := $(TB)/tb_register_file.sv $(RTL)/register_file.sv

MUTA_SRCS := $(TB)/tb_alu8.sv $(RTL)/addsub8.sv mutants/A/alu8.sv
MUTB_SRCS := $(TB)/tb_program_counter.sv mutants/B/program_counter.sv

TEST_LOGS := $(LOGS)/alu8.log $(LOGS)/control_branch.log $(LOGS)/program_counter.log $(LOGS)/register_file.log

# $(call sim,name,top module,files): build, run, save output to logs/name.log
ifeq ($(SIM),iverilog)
define sim
	@mkdir -p $(BUILD) $(LOGS)
	@iverilog $(IFLAGS) -s $(2) -o $(BUILD)/$(1).vvp $(3) > $(BUILD)/$(1).build.log 2>&1 || (cat $(BUILD)/$(1).build.log; exit 1)
	@vvp -n $(BUILD)/$(1).vvp | tee $(LOGS)/$(1).log
endef
else
define sim
	@mkdir -p $(BUILD) $(LOGS)
	@verilator $(VFLAGS) --top-module $(2) --Mdir $(BUILD)/$(1) -o sim $(3) > $(BUILD)/$(1).build.log 2>&1 || (cat $(BUILD)/$(1).build.log; exit 1)
	@$(BUILD)/$(1)/sim | tee $(LOGS)/$(1).log
endef
endif

.PHONY: all test summary alu control_branch pc regfile mutants mutant_A mutant_B clean

all: test mutants

test: alu control_branch pc regfile summary

alu:
	@echo; echo "######## I.A  alu8 + addsub8 ########"
	$(call sim,alu8,tb_alu8,$(ALU_SRCS))

control_branch:
	@echo; echo "######## I.B  control_unit + branch_unit ########"
	$(call sim,control_branch,tb_control_branch,$(CB_SRCS))

pc:
	@echo; echo "######## I.C  program_counter ########"
	$(call sim,program_counter,tb_program_counter,$(PC_SRCS))

regfile:
	@echo; echo "######## I.D  register_file ########"
	$(call sim,register_file,tb_register_file,$(RF_SRCS))

# reads the last line of each log, fails if any testbench failed
summary:
	@echo; echo "==================== REGRESSION SUMMARY ===================="
	@grep -hE "TESTS (PASSED|FAILED)" $(TEST_LOGS)
	@if grep -q "TESTS FAILED" $(TEST_LOGS); then \
	   echo "RESULT: FAIL"; exit 1; \
	 else \
	   echo "RESULT: PASS"; \
	 fi

# here FAIL is what we want to see
mutants: mutant_A mutant_B
	@echo; echo "==================== MUTANTS ===================="
	@for m in A B; do \
	   if grep -q "TESTS FAILED" $(LOGS)/mutant_$$m.log; then \
	     echo "mutant $$m: DETECTED, first fail:"; \
	     grep -m1 "FAIL" $(LOGS)/mutant_$$m.log; \
	   else echo "mutant $$m: NOT DETECTED"; fi; \
	 done

mutant_A:
	@echo; echo "######## mutant A: alu8, SLT unsigned ########"
	$(call sim,mutant_A,tb_alu8,$(MUTA_SRCS))

mutant_B:
	@echo; echo "######## mutant B: program_counter, stall over redirect ########"
	$(call sim,mutant_B,tb_program_counter,$(MUTB_SRCS))

clean:
	rm -rf $(BUILD) $(LOGS) obj_dir
