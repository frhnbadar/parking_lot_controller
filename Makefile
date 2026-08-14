# ==========================================================
# Parking Lot Controller - Makefile
# Author: Farhan
# ==========================================================

# ----------------------------------------------------------
# Tools
# ----------------------------------------------------------

IVERILOG = iverilog
VVP      = vvp
VERILATOR = verilator
GTKWAVE  = gtkwave

# ----------------------------------------------------------
# Directories
# ----------------------------------------------------------

RTL_DIR = rtl
TB_DIR  = tb
SIM_DIR = sim

# ----------------------------------------------------------
# Files
# ----------------------------------------------------------

RTL = $(RTL_DIR)/parking_lot_controller.sv
TB  = $(TB_DIR)/parking_lot_controller_tb.sv

SIM = $(SIM_DIR)/parking_lot_controller_sim
VCD = parking_lot_controller.vcd

# ----------------------------------------------------------
# Default target
# ----------------------------------------------------------

.PHONY: all
all: run

# ----------------------------------------------------------
# Compile
# ----------------------------------------------------------

.PHONY: compile
compile:
	@mkdir -p $(SIM_DIR)
	$(IVERILOG) -g2012 \
		-o $(SIM) \
		$(RTL) \
		$(TB)

# ----------------------------------------------------------
# Run simulation
# ----------------------------------------------------------

.PHONY: run
run: compile
	$(VVP) $(SIM)

# ----------------------------------------------------------
# Run + open GTKWave
# ----------------------------------------------------------

.PHONY: wave
wave: run
	$(GTKWAVE) $(VCD)

# ----------------------------------------------------------
# Lint RTL using Verilator
# ----------------------------------------------------------

.PHONY: lint
lint:
	$(VERILATOR) \
		--lint-only \
		-Wall \
		--language 1800-2012 \
		$(RTL)

# ----------------------------------------------------------
# Clean simulation files
# ----------------------------------------------------------

.PHONY: clean
clean:
	rm -rf $(SIM_DIR)
	rm -f $(VCD)
	rm -f *.vcd
	rm -f *.log
	rm -f *.key
	rm -f *.out
	rm -f simv
	rm -f ucli.key

# ----------------------------------------------------------
# Help
# ----------------------------------------------------------

.PHONY: help
help:
	@echo ""
	@echo "Parking Lot Controller - Available Targets"
	@echo ""
	@echo "  make          Compile and run simulation"
	@echo "  make compile  Compile RTL + testbench"
	@echo "  make run      Compile and run simulation"
	@echo "  make wave     Run simulation and open GTKWave"
	@echo "  make lint     Run Verilator lint"
	@echo "  make clean    Remove generated files"
	@echo "  make help     Show this help"
	@echo ""