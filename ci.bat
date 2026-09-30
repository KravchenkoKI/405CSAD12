@echo off
setlocal

if not exist "%~dp0build" mkdir "%~dp0build"
if errorlevel 1 exit /b 1

cd /d "%~dp0build"
if errorlevel 1 exit /b 1

cmake .. -G "Visual Studio 17 2022" -A x64 -DBUILD_TESTING=ON
if errorlevel 1 exit /b 1

cmake --build . --config Release
if errorlevel 1 exit /b 1

ctest --output-on-failure -C Release
if errorlevel 1 exit /b 1

endlocal