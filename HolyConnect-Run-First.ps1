<#
.SYNOPSIS
    HolyConnect - one-click first-time setup launcher
.DESCRIPTION
    Detects whether the inserted SD card already contains a clean Pi-Star boot
    partition. If it does, runs PreparePiStarSD.ps1. Otherwise, runs
    FlashPiStarSD.ps1.
.PARAMETER NoPause
    Exit without waiting for a key press.
.PARAMETER Lang
    Language: 'pt' for Portuguese, 'en' for English.
#>

param(
    [switch]$NoPause,
    [ValidateSet('pt','en')][string]$Lang
)

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'HolyConnect First-Time Setup'
$FlashScriptPath = Join-Path $PSScriptRoot 'FlashPiStarSD.ps1'
$PrepareScriptPath = Join-Path $PSScriptRoot 'PreparePiStarSD.ps1'
$PowerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

if (-not $Lang) {
    $sysLang = (Get-Culture).TwoLetterISOLanguageName
    $Lang = if ($sysLang -eq 'pt') { 'pt' } else { 'en' }
}

$T = @{}
if ($Lang -eq 'pt') {
    $T.MissingFlash = 'Nao encontrei FlashPiStarSD.ps1. Extrai o pacote completo do HolyConnect antes de usar este launcher.'
    $T.MissingPrep = 'Nao encontrei PreparePiStarSD.ps1. Extrai o pacote completo do HolyConnect antes de usar este launcher.'
    $T.RunPrep = 'Foi detetado um cartao Pi-Star ja gravado. Vou abrir o preparador automaticamente.'
    $T.RunFlash = 'Nao foi detetado um cartao Pi-Star gravado. Vou abrir o flasher automaticamente.'
    $T.PressKey = 'Prima qualquer tecla para sair...'
} else {
    $T.MissingFlash = 'Could not find FlashPiStarSD.ps1. Extract the full HolyConnect package before using this launcher.'
    $T.MissingPrep = 'Could not find PreparePiStarSD.ps1. Extract the full HolyConnect package before using this launcher.'
    $T.RunPrep = 'Detected an already flashed Pi-Star SD card. Launching the prep helper automatically.'
    $T.RunFlash = 'Did not detect an already flashed Pi-Star SD card. Launching the flasher automatically.'
    $T.PressKey = 'Press any key to exit...'
}

function Write-Info($msg) { Write-Host "  $msg" -ForegroundColor Gray }
function Write-Fail($msg) { Write-Host "  [X] $msg" -ForegroundColor Red }

function Test-PiStarBootPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    foreach ($name in @('cmdline.txt', 'config.txt', 'start.elf')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Path $name))) {
            return $false
        }
    }

    return (Test-Path -LiteralPath (Join-Path $Path 'overlays'))
}

function Get-BootCandidates {
    $candidates = New-Object System.Collections.Generic.List[object]
    $seenRoots = @{}

    foreach ($drive in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Sort-Object Root)) {
        if (-not (Test-PiStarBootPath -Path $drive.Root)) { continue }
        if ($seenRoots.ContainsKey($drive.Root)) { continue }

        $candidates.Add([pscustomobject]@{
            Root = $drive.Root
            DiskNumber = $null
            PartitionNumber = $null
        })
        $seenRoots[$drive.Root] = $true
    }

    $disks = @(Get-Disk -ErrorAction SilentlyContinue | Where-Object {
        $_.Number -ne 0 -and
        -not $_.IsBoot -and
        -not $_.IsSystem
    })

    foreach ($disk in $disks) {
        $partitions = @(Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Sort-Object PartitionNumber)
        foreach ($partition in $partitions) {
            if ([string]$partition.Type -match '^Unknown$|Reserved') {
                continue
            }

            $driveLetter = $partition.DriveLetter
            $assignedTemporarily = $false
            if (-not $driveLetter) {
                try {
                    Add-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -AssignDriveLetter -ErrorAction Stop
                    $assignedTemporarily = $true
                } catch {}

                try {
                    $partition = Get-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -ErrorAction Stop
                    $driveLetter = $partition.DriveLetter
                } catch {}
            }

            if (-not $driveLetter) {
                continue
            }

            $root = '{0}:\' -f $driveLetter
            if (Test-PiStarBootPath -Path $root) {
                if (-not $seenRoots.ContainsKey($root)) {
                    $candidates.Add([pscustomobject]@{
                        Root = $root
                        DiskNumber = $disk.Number
                        PartitionNumber = $partition.PartitionNumber
                    })
                    $seenRoots[$root] = $true
                }
                continue
            }

            if ($assignedTemporarily) {
                try {
                    Remove-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -AccessPath $root -ErrorAction Stop
                } catch {}
            }
        }
    }

    return @($candidates | Sort-Object Root)
}

function Invoke-HolyConnectScript {
    param(
        [string]$ScriptPath,
        [string[]]$ExtraArguments
    )

    $arguments = [System.Collections.Generic.List[string]]::new()
    $arguments.Add('-NoProfile')
    $arguments.Add('-ExecutionPolicy')
    $arguments.Add('Bypass')
    $arguments.Add('-File')
    $arguments.Add($ScriptPath)

    if ($NoPause) {
        $arguments.Add('-NoPause')
    }

    if ($Lang) {
        $arguments.Add('-Lang')
        $arguments.Add($Lang)
    }

    foreach ($argument in @($ExtraArguments)) {
        if (-not [string]::IsNullOrWhiteSpace($argument)) {
            $arguments.Add($argument)
        }
    }

    & $PowerShellExe @arguments
    exit $LASTEXITCODE
}

Clear-Host
Write-Host ''
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host '   HolyConnect - One-Click First Setup       ' -ForegroundColor Cyan
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host ''

try {
    if (-not (Test-Path -LiteralPath $FlashScriptPath)) {
        throw $T.MissingFlash
    }

    if (-not (Test-Path -LiteralPath $PrepareScriptPath)) {
        throw $T.MissingPrep
    }

    $bootCandidates = Get-BootCandidates
    if ($bootCandidates.Count -gt 0) {
        Write-Info $T.RunPrep
        $extraArguments = @()
        if ($bootCandidates.Count -eq 1) {
            $extraArguments = @('-BootPath', $bootCandidates[0].Root)
        }
        Invoke-HolyConnectScript -ScriptPath $PrepareScriptPath -ExtraArguments $extraArguments
    }

    Write-Info $T.RunFlash
    Invoke-HolyConnectScript -ScriptPath $FlashScriptPath
} catch {
    Write-Fail $_.Exception.Message
    if (-not $NoPause) {
        Write-Host ''
        Write-Host "  $($T.PressKey)" -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    exit 1
}
