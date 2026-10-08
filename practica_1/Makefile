# Uso:
#   make            -> compila y simula base_test
#   make comp       -> solo compila
#   make run        -> solo simula
#   make run TEST=otro_test SEED=5 ARGS="+UVM_MAX_QUIT_COUNT=5"
#   make clean

TEST ?= base_test
SEED ?= 1
ARGS ?=

VCS_FLAGS = -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps -l comp.log
SIM_FLAGS = +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) -l sim.log $(ARGS)

all: comp run

comp:
	vcs $(VCS_FLAGS) seq_lab_pkg.sv tb_top.sv

run:
	./simv $(SIM_FLAGS)

clean:
	rm -rf simv simv.daidir csrc *.log ucli.key vc_hdrs.h

.PHONY: all comp run clean
