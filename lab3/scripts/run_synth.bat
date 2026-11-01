@echo off
rem ==========================================================================
rem  Lab 3 (SPI master, Verilog), variant 12 - synthesis, place and route,
rem  resource usage and timing analysis (Fmax).
rem  Tools: Yosys (synth_ecp5) + nextpnr-ecp5 from OSS CAD Suite.
rem  Target FPGA: Lattice ECP5 LFE5U-25F-6BG381C (ULX3S board).
rem ==========================================================================
setlocal
if not defined OSS_CAD set "OSS_CAD=C:\oss-cad-suite"
if not exist "%OSS_CAD%\environment.bat" (
    echo OSS CAD Suite was not found in "%OSS_CAD%".
    echo Extract it to C:\oss-cad-suite or set OSS_CAD to its folder.
    pause
    exit /b 1
)
call "%OSS_CAD%\environment.bat"

cd /d "%~dp0.."
if not exist build mkdir build

echo === Synthesis (Yosys) ===
yosys -q -l build\yosys.log -p "read_verilog rtl/spi_master_tx.v rtl/spi_master_rx.v rtl/spi_master.v; synth_ecp5 -top spi_master -json build/spi_master.json; tee -o build/synth_stat.txt stat"
if errorlevel 1 goto fail
type build\synth_stat.txt

echo === Place and route + timing analysis (nextpnr-ecp5) ===
nextpnr-ecp5 --25k --package CABGA381 --speed 6 --json build\spi_master.json --lpf constraints\spi_master.lpf --lpf-allow-unconstrained --report build\nextpnr_report.json --log build\nextpnr.log
if errorlevel 1 goto fail

echo.
echo ================== RESULTS ==================
findstr /C:"TRELLIS_COMB:" /C:"TRELLIS_FF:" /C:"TRELLIS_IO:" /C:"Max frequency" build\nextpnr.log
echo =============================================
echo The LAST "Max frequency" line is the result after routing.
pause
exit /b 0

:fail
echo *** ERROR: see messages above ***
pause
exit /b 1
