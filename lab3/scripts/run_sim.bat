@echo off
rem ==========================================================================
rem  Lab 3 (SPI master, Verilog), variant 12 - functional simulation
rem  Tools: Icarus Verilog (iverilog, vvp) + GTKWave from OSS CAD Suite.
rem  Run: double-click this file. OSS CAD Suite is expected in C:\oss-cad-suite
rem  (or set the OSS_CAD variable to the folder where it was extracted).
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

rem go to the lab3 folder (one level above this script)
cd /d "%~dp0.."
if not exist build mkdir build

echo === Compiling (iverilog) ===
iverilog -g2005 -o build\spi_tb.vvp rtl\spi_master_tx.v rtl\spi_master_rx.v rtl\spi_master.v tb\spi_slave_model.v tb\spi_master_tb.v
if errorlevel 1 goto fail

echo === Running testbench (vvp) ===
cd build
vvp -n spi_tb.vvp
if errorlevel 1 goto fail

echo === Opening waveforms (GTKWave) ===
start "" gtkwave spi_master_tb.vcd ..\sim\spi_master_tb.gtkw
pause
exit /b 0

:fail
echo *** ERROR: see messages above ***
pause
exit /b 1
