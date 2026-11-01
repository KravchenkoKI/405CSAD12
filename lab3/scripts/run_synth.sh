#!/usr/bin/env bash
# Lab 3 (SPI master, Verilog), variant 12 - synthesis, P&R, resources and Fmax
# Tools: Yosys + nextpnr-ecp5. Target: Lattice ECP5 LFE5U-25F-6BG381C.
set -e
[ -n "$OSS_CAD" ] && export PATH="$OSS_CAD/bin:$PATH"
cd "$(dirname "$0")/.."
mkdir -p build
yosys -q -l build/yosys.log -p "read_verilog rtl/spi_master_tx.v rtl/spi_master_rx.v rtl/spi_master.v; synth_ecp5 -top spi_master -json build/spi_master.json; tee -o build/synth_stat.txt stat"
cat build/synth_stat.txt
nextpnr-ecp5 --25k --package CABGA381 --speed 6 --json build/spi_master.json --lpf constraints/spi_master.lpf --lpf-allow-unconstrained --report build/nextpnr_report.json --log build/nextpnr.log
echo "================== RESULTS =================="
grep -E "TRELLIS_COMB:|TRELLIS_FF:|TRELLIS_IO:|Max frequency" build/nextpnr.log
