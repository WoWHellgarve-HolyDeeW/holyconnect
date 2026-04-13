@echo off
:: HolyConnect - Pi-Star USB Tethering
:: Double-click to run. Auto-elevates to Administrator.
:: https://github.com/WoWHellgarve-HolyDeeW/holyconnect

cd /d "%~dp0"
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c cd /d \"%~dp0\" && powershell -ExecutionPolicy Bypass -File \"%~dp0HolyConnect.ps1\"' -Verb RunAs"
    exit /b
)
powershell -ExecutionPolicy Bypass -File "%~dp0HolyConnect.ps1"
