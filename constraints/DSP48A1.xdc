# ============================================================
#  Vivado Constraints File — DSP48A1
#  Target FPGA : xc7a200tffg1156-3
#                (chosen to accommodate the large I/O count)
#  Clock       : 100 MHz on pin W5 (Basys3-compatible mapping)
# ============================================================

# ── Clock constraint ─────────────────────────────────────────
# Pin W5 on Basys3 — LVCMOS33, 100 MHz (10 ns period)
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports CLK]

create_clock -period 10.000 \
             -name sys_clk_pin \
             -waveform {0.000 5.000} \
             -add [get_ports CLK]

# ── Configuration options ────────────────────────────────────
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS         VCCO [current_design]

# ── Bitstream options ────────────────────────────────────────
set_property BITSTREAM.GENERAL.COMPRESS  TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33   [current_design]
set_property CONFIG_MODE SPIx4                [current_design]

# ── Note ─────────────────────────────────────────────────────
# All switch, LED, and button pin mappings are intentionally
# left commented out. The DSP48A1 I/O count exceeds the Basys3
# (xc7a35t) capacity; use xc7a200tffg1156-3 in the Vivado
# project settings to avoid I/O placement errors.
