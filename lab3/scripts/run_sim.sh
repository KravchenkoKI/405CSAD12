#!/usr/bin/env bash
# Lab 3 (SPI master, Verilog), variant 12 - functional simulation (Linux/macOS)
# Tools: Icarus Verilog + GTKWave (OSS CAD Suite in PATH or OSS_CAD set).
set -e
[ -n "$OSS_CAD" ] && export PATH="$OSS_CAD/bin:$PATH"
cd "$(dirname "$0")/.."
mkdir -p build
iverilog -g2005 -o build/spi_tb.vvp rtl/spi_master_tx.v rtl/spi_master_rx.v rtl/spi_master.v tb/spi_slave_model.v tb/spi_master_tb.v
cd build
vvp -n spi_tb.vvp
if [ "$1" != "--no-gui" ]; then gtkwave spi_master_tb.vcd ../sim/spi_master_tb.gtkw & fi
