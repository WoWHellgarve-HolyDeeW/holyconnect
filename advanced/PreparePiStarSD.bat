@echo off
:: HolyConnect - advanced helper: force Pi-Star boot prep on an already clean card
:: Most users should use ..\HolyConnect-Run-First.bat instead.

setlocal
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "TARGET_PS1=%~dp0..\PreparePiStarSD.ps1"
cd /d "%~dp0.."

"%PS_EXE%" -NoProfile -Command "$p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent()); if ($p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }"
if %errorlevel% neq 0 (
    echo Advanced helper: force Pi-Star boot prep / Helper avancado: forcar preparacao boot do Pi-Star
    echo For normal use, run HolyConnect-Run-First.bat / Para uso normal, corre HolyConnect-Run-First.bat
    echo Requesting administrator rights / A pedir permissoes de administrador...
    "%PS_EXE%" -NoProfile -Command "$target = '%TARGET_PS1%'; $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$target); try { Start-Process -FilePath '%PS_EXE%' -WorkingDirectory '%~dp0..' -Verb RunAs -ArgumentList $args -ErrorAction Stop | Out-Null; exit 0 } catch { exit 1 }"
    if %errorlevel% neq 0 pause
    exit /b
)

echo Advanced helper: force Pi-Star boot prep / Helper avancado: forcar preparacao boot do Pi-Star
echo For normal use, run HolyConnect-Run-First.bat / Para uso normal, corre HolyConnect-Run-First.bat
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%TARGET_PS1%"
if %errorlevel% neq 0 pause