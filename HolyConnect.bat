@echo off
:: HolyConnect - daily USB launcher
:: Normal use after first-time SD setup is done.
:: For first-time setup use HolyConnect-Run-First.bat.

setlocal
set "TARGET_BAT=%~dp0windows\HolyConnect.bat"
cd /d "%~dp0"

if not exist "%TARGET_BAT%" (
    echo Could not find windows\HolyConnect.bat. Extract the full HolyConnect package before using this launcher.
    echo Nao encontrei windows\HolyConnect.bat. Extrai o pacote completo do HolyConnect antes de usar este launcher.
    pause
    exit /b 1
)

call "%TARGET_BAT%" %*
exit /b %errorlevel%