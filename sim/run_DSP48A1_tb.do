# ============================================================
#  QuestaSim / ModelSim Do File — DSP48A1
#  Usage: vsim -do run_DSP48A1_tb.do
# ============================================================

# Create and map work library
vlib work

# Compile RTL and testbench
vlog ../src/grey_mux.v ../src/DSP48A1.v DSP48A1_tb.v

# Launch simulation with full visibility (+acc)
vsim -voptargs=+acc work.DSP48A1_tb

# Add all top-level signals to the wave window
add wave *

# Run the full simulation
run -all

# Uncomment to close the simulator automatically after run
# quit -sim
