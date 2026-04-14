@echo off
:: HolyConnect - Prepare a clean Pi-Star SD card for first boot
:: Double-click to run. Auto-elevates to Administrator.
:: https://github.com/WoWHellgarve-HolyDeeW/holyconnect

setlocal
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "TARGET_PS1=%~dp0PreparePiStarSD.ps1"
cd /d "%~dp0"

"%PS_EXE%" -NoProfile -Command "$p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent()); if ($p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }"
if %errorlevel% neq 0 (
    echo Requesting administrator rights / A pedir permissoes de administrador...
    "%PS_EXE%" -NoProfile -Command "$target = '%TARGET_PS1%'; $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$target); try { Start-Process -FilePath '%PS_EXE%' -WorkingDirectory '%~dp0' -Verb RunAs -ArgumentList $args -ErrorAction Stop | Out-Null; exit 0 } catch { exit 1 }"
    if %errorlevel% neq 0 pause
    exit /b
)

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%TARGET_PS1%"
if %errorlevel% neq 0 pause