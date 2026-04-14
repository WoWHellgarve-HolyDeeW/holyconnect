<#
.SYNOPSIS
    HolyConnect - Prepare a clean Pi-Star SD card from Windows
.DESCRIPTION
    Detects a mounted Pi-Star boot partition, copies the HolyConnect installer,
    and patches boot files so the Pi self-installs HolyConnect on first boot.
.PARAMETER BootPath
    Optional path to the mounted Pi-Star boot partition.
.PARAMETER Lang
    Language: 'pt' for Portuguese, 'en' for English.
#>

param(
    [string]$BootPath,
    [string]$WifiConfigPath,
    [switch]$NoPause,
    [ValidateSet('pt','en')][string]$Lang
)

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'HolyConnect SD Prep'
$InstallerPath = Join-Path $PSScriptRoot 'pi-setup\install.sh'
$PreferredImageRoot = Join-Path $PSScriptRoot 'pistar-image'
$OptionalWifiConfigPath = Join-Path $PreferredImageRoot 'wpa_supplicant.conf'
$ResolvedWifiConfigPath = if ($WifiConfigPath) { $WifiConfigPath } else { $OptionalWifiConfigPath }

if (-not $Lang) {
    $sysLang = (Get-Culture).TwoLetterISOLanguageName
    $Lang = if ($sysLang -eq 'pt') { 'pt' } else { 'en' }
}

$T = @{}
if ($Lang -eq 'pt') {
    $T.Title             = 'HolyConnect - Preparar cartao Pi-Star'
    $T.Step1             = 'A procurar particao boot do Pi-Star...'
    $T.Step2             = 'A preparar ficheiros de arranque...'
    $T.InstallerMissing  = 'Nao encontrei pi-setup/install.sh. Extrai o pacote completo do HolyConnect antes de correr este preparador.'
    $T.BootDetected      = 'Particao boot detetada: {0}'
    $T.MultipleBoots     = 'Foram encontradas varias particoes boot do Raspberry Pi:'
    $T.ChooseBoot        = 'Escolhe o numero da particao a preparar'
    $T.NoBootAuto        = 'Nenhuma particao boot do Pi-Star foi detetada automaticamente.'
    $T.EnterBootPath     = 'Indica a letra/unidade ou caminho da particao boot'
    $T.InvalidBootPath   = 'Caminho invalido ou nao parece ser uma particao boot do Pi-Star: {0}'
    $T.BackupReady       = 'Backup criado: {0}'
    $T.CopiedInstaller   = 'install.sh copiado para a particao boot'
    $T.CmdlinePatched    = 'cmdline.txt atualizado com bootstrap HolyConnect'
    $T.ConfigPatched     = 'config.txt atualizado com dtoverlay=dwc2'
    $T.WifiConfigCopied  = 'wpa_supplicant.conf opcional copiado para a particao boot'
    $T.WifiConfigSkipped = 'Sem wpa_supplicant.conf opcional. O HolyConnect por USB continua a funcionar normalmente.'
    $T.Prepared          = 'Cartao preparado para o primeiro arranque do HolyConnect.'
    $T.NextStep1         = 'Proximo passo: coloca o cartao no Pi e arranca uma vez.'
    $T.NextStep2         = 'O primeiro boot corre o instalador, reinicia sozinho, e depois podes usar HolyConnect.bat.'
    $T.PressKey          = 'Prima qualquer tecla para sair...'
} else {
    $T.Title             = 'HolyConnect - Prepare Pi-Star SD card'
    $T.Step1             = 'Searching for Pi-Star boot partition...'
    $T.Step2             = 'Preparing boot files...'
    $T.InstallerMissing  = 'Could not find pi-setup/install.sh. Extract the full HolyConnect package before running this helper.'
    $T.BootDetected      = 'Boot partition detected: {0}'
    $T.MultipleBoots     = 'Multiple Raspberry Pi boot partitions were found:'
    $T.ChooseBoot        = 'Choose the number of the partition to prepare'
    $T.NoBootAuto        = 'No Pi-Star boot partition was detected automatically.'
    $T.EnterBootPath     = 'Enter the drive letter or path of the boot partition'
    $T.InvalidBootPath   = 'Invalid path or it does not look like a Pi-Star boot partition: {0}'
    $T.BackupReady       = 'Backup created: {0}'
    $T.CopiedInstaller   = 'install.sh copied to the boot partition'
    $T.CmdlinePatched    = 'cmdline.txt updated with HolyConnect bootstrap'
    $T.ConfigPatched     = 'config.txt updated with dtoverlay=dwc2'
    $T.WifiConfigCopied  = 'Optional wpa_supplicant.conf copied to the boot partition'
    $T.WifiConfigSkipped = 'No optional wpa_supplicant.conf found. HolyConnect over USB still works normally.'
    $T.Prepared          = 'SD card prepared for HolyConnect first boot.'
    $T.NextStep1         = 'Next step: put the card into the Pi and boot once.'
    $T.NextStep2         = 'The first boot runs the installer, reboots automatically, and then you can use HolyConnect.bat.'
    $T.PressKey          = 'Press any key to exit...'
}

function Write-Step($msg) { Write-Host "`n$msg" -ForegroundColor Yellow }
function Write-OK($msg) { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "  $msg" -ForegroundColor Gray }
function Write-Fail($msg) { Write-Host "  [X] $msg" -ForegroundColor Red }

function Set-AsciiContent {
    param(
        [string]$Path,
        [string]$Content
    )

    $encoding = [System.Text.Encoding]::ASCII
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

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
    $candidates = foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        if (-not (Test-PiStarBootPath -Path $drive.Root)) { continue }

        $label = $null
        if ($drive.Name -match '^[A-Z]$') {
            try {
                $label = (Get-Volume -DriveLetter $drive.Name -ErrorAction Stop).FileSystemLabel
            } catch {}
        }

        [pscustomobject]@{
            Root = $drive.Root
            Drive = $drive.Name
            Label = $label
        }
    }

    return @($candidates | Sort-Object Root)
}

function Resolve-BootPartition {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-PiStarBootPath -Path $RequestedPath)) {
            throw ($T.InvalidBootPath -f $RequestedPath)
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $candidates = Get-BootCandidates
    if ($candidates.Count -eq 1) {
        Write-Info ($T.BootDetected -f $candidates[0].Root)
        return $candidates[0].Root
    }

    if ($candidates.Count -gt 1) {
        Write-Info $T.MultipleBoots
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            $labelText = if ($candidates[$i].Label) { " [$($candidates[$i].Label)]" } else { '' }
            Write-Host ("  {0}. {1}{2}" -f ($i + 1), $candidates[$i].Root, $labelText) -ForegroundColor White
        }

        while ($true) {
            $choice = Read-Host "$($T.ChooseBoot)"
            $parsed = 0
            if ([int]::TryParse($choice, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le $candidates.Count) {
                return $candidates[$parsed - 1].Root
            }
        }
    }

    Write-Info $T.NoBootAuto
    $manualPath = Read-Host "$($T.EnterBootPath)"
    if (-not (Test-PiStarBootPath -Path $manualPath)) {
        throw ($T.InvalidBootPath -f $manualPath)
    }

    return (Resolve-Path -LiteralPath $manualPath).Path
}

function Backup-FileIfNeeded {
    param([string]$Path)

    $backupPath = "$Path.holyconnect.bak"
    if (-not (Test-Path -LiteralPath $backupPath)) {
        Copy-Item -LiteralPath $Path -Destination $backupPath -Force
        Write-Info ($T.BackupReady -f $backupPath)
    }
}

function Update-CmdlineFile {
    param([string]$Path)

    $raw = Get-Content -LiteralPath $Path -Raw
    $tokens = @(($raw -replace "`r", ' ' -replace "`n", ' ') -split '\s+' | Where-Object { $_ })
    $updatedTokens = [System.Collections.Generic.List[string]]::new()
    $sawModulesLoad = $false

    foreach ($token in $tokens) {
        if ($token -match '^systemd\.run=' -or $token -match '^systemd\.run_success_action=' -or $token -match '^systemd\.run_failure_action=') {
            continue
        }

        if ($token -match '^modules-load=') {
            $modules = @($token.Substring('modules-load='.Length).Split(',') | Where-Object { $_ -and $_ -ne 'g_ether' })
            if ('dwc2' -notin $modules) {
                $modules = @('dwc2') + $modules
            }
            $updatedTokens.Add('modules-load=' + (($modules | Select-Object -Unique) -join ','))
            $sawModulesLoad = $true
            continue
        }

        $updatedTokens.Add($token)
    }

    if (-not $sawModulesLoad) {
        $updatedTokens.Add('modules-load=dwc2')
    }

    foreach ($token in @(
        'systemd.run=/boot/install.sh',
        'systemd.run_success_action=reboot',
        'systemd.run_failure_action=reboot'
    )) {
        $updatedTokens.Add($token)
    }

    Set-AsciiContent -Path $Path -Content (($updatedTokens -join ' ').Trim())
}

function Update-ConfigFile {
    param([string]$Path)

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -match '(?m)^\s*dtoverlay=dwc2\s*$') {
        return
    }

    $updated = $content.TrimEnd("`r", "`n") + "`r`n`r`n# HolyConnect USB bootstrap`r`ndtoverlay=dwc2`r`n"
    Set-AsciiContent -Path $Path -Content $updated
}

function Copy-OptionalWifiConfig {
    param([string]$BootRoot)

    if (-not (Test-Path -LiteralPath $ResolvedWifiConfigPath)) {
        Write-Info $T.WifiConfigSkipped
        return
    }

    $targetPath = Join-Path $BootRoot 'wpa_supplicant.conf'
    if (Test-Path -LiteralPath $targetPath) {
        Backup-FileIfNeeded -Path $targetPath
    }

    Copy-Item -LiteralPath $ResolvedWifiConfigPath -Destination $targetPath -Force
    Write-OK $T.WifiConfigCopied
}

Clear-Host
Write-Host ''
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host '   HolyConnect - Pi-Star SD Bootstrap Prep   ' -ForegroundColor Cyan
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host ''

try {
    if (-not (Test-Path -LiteralPath $InstallerPath)) {
        throw $T.InstallerMissing
    }

    Write-Step $T.Step1
    $resolvedBootPath = Resolve-BootPartition -RequestedPath $BootPath
    Write-OK ($T.BootDetected -f $resolvedBootPath)

    Write-Step $T.Step2
    $cmdlinePath = Join-Path $resolvedBootPath 'cmdline.txt'
    $configPath = Join-Path $resolvedBootPath 'config.txt'
    $targetInstaller = Join-Path $resolvedBootPath 'install.sh'

    Backup-FileIfNeeded -Path $cmdlinePath
    Backup-FileIfNeeded -Path $configPath

    Copy-Item -LiteralPath $InstallerPath -Destination $targetInstaller -Force
    Write-OK $T.CopiedInstaller

    Update-CmdlineFile -Path $cmdlinePath
    Write-OK $T.CmdlinePatched

    Update-ConfigFile -Path $configPath
    Write-OK $T.ConfigPatched

    Copy-OptionalWifiConfig -BootRoot $resolvedBootPath

    Write-Host ''
    Write-Host "  $($T.Prepared)" -ForegroundColor Green
    Write-Host "  $($T.NextStep1)" -ForegroundColor White
    Write-Host "  $($T.NextStep2)" -ForegroundColor White
} catch {
    Write-Fail $_.Exception.Message
    if (-not $NoPause) {
        Write-Host ''
        Write-Host "  $($T.PressKey)" -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    exit 1
}

if (-not $NoPause) {
    Write-Host ''
    Write-Host "  $($T.PressKey)" -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}