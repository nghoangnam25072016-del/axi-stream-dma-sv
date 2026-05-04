# -----------------------------------------------------------------------------
# Simulation Makefile
# -----------------------------------------------------------------------------
# Usage:
#   make SIM=questa run
#   make SIM=questa run SEED=123 WAVES=1
#   make SIM=vcs run
#   make SIM=xcelium run
#   make regress
# -----------------------------------------------------------------------------

SIM      ?= questa
SEED     ?= 12648430
WAVES    ?= 0
ASSERTS  ?= 1
COVERAGE ?= 0

ROOT     := $(abspath ..)
RTL_DIR  := $(ROOT)/rtl
TB_DIR   := $(ROOT)/tb
BUILD    := $(ROOT)/sim/build

RTL_FILES := \
  $(RTL_DIR)/axi_lite_regs.sv \
  $(RTL_DIR)/dma_engine.sv \
  $(RTL_DIR)/dma_top.sv

TB_FILES := \
  $(TB_DIR)/dma_assertions.sv \
  $(TB_DIR)/tb_dma.sv

DEFINES := +incdir+$(RTL_DIR)
ifeq ($(ASSERTS),1)
  DEFINES += +define+ASSERT_ON
endif
ifeq ($(COVERAGE),1)
  DEFINES += +define+COVERAGE_ON
endif
ifeq ($(WAVES),1)
  PLUSARGS += +WAVES
endif
PLUSARGS += +SEED=$(SEED)

.PHONY: run regress clean questa vcs xcelium

run:
ifeq ($(SIM),questa)
	$(MAKE) questa
else ifeq ($(SIM),vcs)
	$(MAKE) vcs
else ifeq ($(SIM),xcelium)
	$(MAKE) xcelium
else
	$(error Unknown SIM=$(SIM). Use SIM=questa, SIM=vcs, or SIM=xcelium)
endif

questa:
	mkdir -p $(BUILD)
	cd $(BUILD) && vlib work
	cd $(BUILD) && vlog -sv $(DEFINES) $(RTL_FILES) $(TB_FILES)
	cd $(BUILD) && vsim -c tb_dma -do "run -all; quit" $(PLUSARGS)

vcs:
	mkdir -p $(BUILD)
	cd $(BUILD) && vcs -full64 -sverilog -debug_access+all $(DEFINES) $(RTL_FILES) $(TB_FILES) -o simv
	cd $(BUILD) && ./simv $(PLUSARGS)

xcelium:
	mkdir -p $(BUILD)
	cd $(BUILD) && xrun -64bit -sv $(DEFINES) $(RTL_FILES) $(TB_FILES) $(PLUSARGS)

regress:
	python3 $(ROOT)/scripts/run_random_tests.py --sim $(SIM) --count 20

clean:
	rm -rf $(BUILD) transcript vsim.wlf work csrc simv simv.daidir xcelium.d *.vcd *.log
